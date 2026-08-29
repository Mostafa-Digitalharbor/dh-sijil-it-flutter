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
    this.isSyncing = false,
    this.lastReport,
  });

  /// The device has no transport at all. Distinct from [servingFrom]: a phone
  /// on hotel wifi that cannot reach the customer's Odoo is online and stale.
  final bool isOffline;

  /// When the data on screen was last read from Odoo, or null when it is live.
  final DateTime? servingFrom;

  final List<OutboxEntry> pending;
  final bool isSyncing;
  final SyncReport? lastReport;

  bool get hasPending => pending.isNotEmpty;

  int get blockedCount => pending.where((e) => e.isBlocked).length;

  /// Whether there is anything worth interrupting the user about.
  ///
  /// Being offline with nothing queued and a live-enough screen is not news —
  /// a banner that is always there is a banner nobody reads.
  bool get shouldWarn => isOffline || servingFrom != null || hasPending;

  SyncViewState copyWith({
    bool? isOffline,
    DateTime? servingFrom,
    bool clearServingFrom = false,
    List<OutboxEntry>? pending,
    bool? isSyncing,
    SyncReport? lastReport,
  }) => SyncViewState(
    isOffline: isOffline ?? this.isOffline,
    servingFrom: clearServingFrom ? null : (servingFrom ?? this.servingFrom),
    pending: pending ?? this.pending,
    isSyncing: isSyncing ?? this.isSyncing,
    lastReport: lastReport ?? this.lastReport,
  );

  @override
  List<Object?> get props => <Object?>[
    isOffline,
    servingFrom,
    pending,
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

  Future<void> _refreshQueue() async {
    final pending = await _outbox.pending();
    if (isClosed) return;
    emit(state.copyWith(pending: pending));
  }

  @override
  Future<void> close() async {
    for (final watch in _watches) {
      await watch.cancel();
    }
    return super.close();
  }
}
