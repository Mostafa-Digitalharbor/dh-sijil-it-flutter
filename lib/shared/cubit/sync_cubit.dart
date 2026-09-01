import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/connectivity/network_info.dart';
import '../../core/sync/offline_reads.dart';
import '../../core/sync/outbox_entry.dart';
import '../../core/sync/outbox_store.dart';
import '../../core/sync/sync_service.dart';

/// What the app knows about its own connection to Odoo.
class SyncViewState extends Equatable {
  const SyncViewState({
    this.isOffline = false,
    this.servingFrom,
    this.pending = const <OutboxEntry>[],
    this.quarantined = const <OutboxEntry>[],
    this.isSyncing = false,
    this.lastReport,
  });

  /// The device has no transport at all. Distinct from [servingFrom]: a phone
  /// on hotel wifi that cannot reach the customer's Odoo is online and stale.
  final bool isOffline;

  /// When the data on screen was last read from Odoo, or null when it is live.
  final DateTime? servingFrom;

  /// Writes still on their way to Odoo.
  final List<OutboxEntry> pending;

  /// Writes the app has stopped trying to send, newest failure first.
  ///
  /// Separate from [pending] because they need a different sentence and a
  /// different control: nothing will happen to these on its own, and the user
  /// has to either fix what Odoo objected to and retry, or discard them.
  final List<OutboxEntry> quarantined;

  final bool isSyncing;
  final SyncReport? lastReport;

  bool get hasPending => pending.isNotEmpty;

  bool get hasQuarantined => quarantined.isNotEmpty;

  /// Whether there is anything worth interrupting the user about.
  ///
  /// Being offline with nothing queued and a live-enough screen is not news —
  /// a banner that is always there is a banner nobody reads.
  bool get shouldWarn =>
      isOffline || servingFrom != null || hasPending || hasQuarantined;

  SyncViewState copyWith({
    bool? isOffline,
    DateTime? servingFrom,
    bool clearServingFrom = false,
    List<OutboxEntry>? pending,
    List<OutboxEntry>? quarantined,
    bool? isSyncing,
    SyncReport? lastReport,
  }) => SyncViewState(
    isOffline: isOffline ?? this.isOffline,
    servingFrom: clearServingFrom ? null : (servingFrom ?? this.servingFrom),
    pending: pending ?? this.pending,
    quarantined: quarantined ?? this.quarantined,
    isSyncing: isSyncing ?? this.isSyncing,
    lastReport: lastReport ?? this.lastReport,
  );

  @override
  List<Object?> get props => <Object?>[
    isOffline,
    servingFrom,
    pending,
    quarantined,
    isSyncing,
    lastReport?.sent,
    lastReport?.remaining,
  ];
}

/// The ViewModel behind the offline banner and the sync screen.
///
/// One instance, provided above the router, because being offline is a fact
/// about the app rather than about a screen — and the banner has to survive
/// the navigation that happens while a technician walks back into signal.
class SyncCubit extends Cubit<SyncViewState> {
  SyncCubit({
    required OutboxStore outbox,
    required SyncService service,
    required SyncTrail trail,
    required NetworkInfo network,
  }) : _outbox = outbox,
       _service = service,
       _trail = trail,
       _network = network,
       super(const SyncViewState());

  final OutboxStore _outbox;
  final SyncService _service;
  final SyncTrail _trail;
  final NetworkInfo _network;

  final List<StreamSubscription<void>> _watches = <StreamSubscription<void>>[];

  Future<void> start() async {
    emit(state.copyWith(isOffline: !await _network.isConnected));
    await _refreshQueue();

    _watches
      ..add(
        _network.onConnectivityChanged.listen((connected) {
          if (isClosed) return;
          emit(state.copyWith(isOffline: !connected));
        }),
      )
      ..add(
        _trail.changes.listen((servedFrom) {
          if (isClosed) return;
          emit(
            state.copyWith(
              servingFrom: servedFrom,
              clearServingFrom: servedFrom == null,
            ),
          );
        }),
      )
      ..add(
        _outbox.depthChanged.listen((_) {
          if (!isClosed) unawaited(_refreshQueue());
        }),
      )
      ..add(
        _service.reports.listen((report) {
          if (isClosed) return;
          emit(state.copyWith(lastReport: report, isSyncing: false));
          unawaited(_refreshQueue());
        }),
      );
  }

  /// Sends the queue now, because the user asked.
  Future<void> syncNow() async {
    if (state.isSyncing) return;
    emit(state.copyWith(isSyncing: true));
    await _service.drain();
    if (isClosed) return;
    emit(state.copyWith(isSyncing: false));
    await _refreshQueue();
  }

  /// Throws the queue away.
  ///
  /// Destructive and deliberately not offered casually: these are writes Odoo
  /// has never seen, so this is the one control in the app that loses work on
  /// purpose. The screen asks first.
  Future<void> discardQueue() async {
    await _outbox.clear();
    await _refreshQueue();
  }

  /// Puts one given-up write back in the queue and sends it.
  ///
  /// The reason these fail is usually outside the app — a permission, a record
  /// rule, a required field — so the retry is offered per entry: an
  /// administrator grants one thing, and the user sends the one write that was
  /// waiting on it without disturbing the rest.
  Future<void> retryQuarantined(String id) async {
    await _outbox.retry(id);
    await _refreshQueue();
    await syncNow();
  }

  /// Discards one given-up write, leaving everything else alone.
  Future<void> discardQuarantined(String id) async {
    await _outbox.remove(id);
    await _refreshQueue();
  }

  /// Discards every given-up write, leaving the live queue alone.
  Future<void> discardAllQuarantined() async {
    await _outbox.clearQuarantined();
    await _refreshQueue();
  }

  Future<void> _refreshQueue() async {
    final pending = await _outbox.pending();
    final quarantined = await _outbox.quarantined();
    if (isClosed) return;
    emit(state.copyWith(pending: pending, quarantined: quarantined));
  }

  @override
  Future<void> close() async {
    for (final watch in _watches) {
      await watch.cancel();
    }
    return super.close();
  }
}
