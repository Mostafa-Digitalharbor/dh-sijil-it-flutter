import 'dart:async';

import '../../features/assets/domain/entities/asset_status.dart';
import '../../features/assets/domain/repositories/asset_repository.dart';
import '../../features/assignment/domain/entities/assignment.dart';
import '../error/failures.dart';
import '../network/connectivity/network_info.dart';
import '../utils/logger.dart';
import 'outbox_entry.dart';
import 'outbox_store.dart';
import 'write_queue.dart';

/// The result of one attempt to empty the queue.
class SyncReport {
  const SyncReport({
    this.sent = 0,
    this.failed = 0,
    this.remaining = 0,
    this.quarantined = 0,
  });

  final int sent;
  final int failed;
  final int remaining;

  /// How many writes this drain gave up on. They are kept and shown with the
  /// reason rather than deleted — see [OutboxEntry.quarantinedAt].
  final int quarantined;

  bool get isClean => failed == 0 && remaining == 0;
}

/// Replays the outbox against Odoo.
///
/// ## Why it calls the repository rather than Odoo
///
/// A queued assignment is not a stored XML-RPC payload — it is the *request*
/// the user made. Replaying it through [AssetRepository.assign] means the note
/// vocabulary, the overlay bookkeeping and the field-support probe all run
/// exactly as they do online, from one implementation. Storing the wire call
/// instead would have frozen whatever the field set looked like on the day the
/// technician lost signal.
///
/// ## Ordering
///
/// Strictly oldest-first, and it stops at the first entry that fails with
/// anything other than a permanent rejection. Assign-then-return replayed out
/// of order leaves the asset held by somebody who handed it back, and a queue
/// that skips over a stuck entry reorders itself silently.
class SyncService {
  SyncService({
    required OutboxStore outbox,
    required WriteQueue queue,
    required NetworkInfo network,
    required AssetRepository Function() assets,
  }) : _outbox = outbox,
       _queue = queue,
       _network = network,
       _assets = assets;

  final OutboxStore _outbox;
  final WriteQueue _queue;
  final NetworkInfo _network;

  /// Resolved lazily: the repository is built with the queue this service
  /// drains, so holding it directly would be a cycle at construction time.
  final AssetRepository Function() _assets;

  StreamSubscription<bool>? _watch;
  bool _running = false;

  final StreamController<SyncReport> _reports =
      StreamController<SyncReport>.broadcast();

  /// Emits after every drain, so a screen can say what happened.
  Stream<SyncReport> get reports => _reports.stream;

  /// Starts draining whenever the device comes back online.
  ///
  /// And once immediately, which is not the same thing: connectivity only
  /// *emits* on a change, so a queue written in a basement yesterday and
  /// opened on a desk today would sit there — the transition back to signal
  /// happened while the app was closed and nothing was listening for it.
  void start() {
    _watch ??= _network.onConnectivityChanged.listen((connected) {
      if (connected) unawaited(drain());
    });
    unawaited(drain());
  }

  /// Sends everything that is waiting.
  ///
  /// Safe to call at any time: it is a no-op while another drain is running,
  /// while the device is offline, and when the queue is empty.
  Future<SyncReport> drain() async {
    if (_running) return const SyncReport();
    if (!await _network.isConnected) {
      return SyncReport(remaining: await _outbox.depth());
    }

    _running = true;
    _queue.beginDrain();

    var sent = 0;
    var failed = 0;
    var quarantined = 0;

    try {
      for (final entry in await _outbox.pending()) {
        final failure = await _replay(entry);
        if (failure == null) {
          await _outbox.remove(entry.id);
          sent++;
          continue;
        }

        failed++;

        // Counted whether or not it is retried again: the request was sent and
        // Odoo answered, and a queue screen that shows nought attempts beside
        // a failure is describing something that did not happen.
        final attempted = entry.copyWith(
          attempts: entry.attempts + 1,
          lastError: failure.kind.name,
        );

        // Odoo has refused this for a reason retrying cannot fix — an ACL, a
        // record rule, a constraint on the value. Quarantined on the first
        // rejection rather than after five: the four extra attempts change
        // nothing, and every one of them is a round trip that keeps the asset
        // wrongly overlaid for longer.
        if (!failure.isRetryable) {
          await _outbox.quarantine(attempted, reason: failure.kind.name);
          quarantined++;
          continue;
        }

        // Retryable, but it has now failed as often as retrying is worth. The
        // count only moves when a replay was actually attempted — which needs
        // a connection — so reaching it means the request keeps being refused
        // while the network is fine.
        if (attempted.isBlocked) {
          await _outbox.quarantine(attempted, reason: failure.kind.name);
          quarantined++;
          continue;
        }

        await _outbox.save(attempted);

        // A connectivity failure means the window closed again; everything
        // after this entry would fail the same way, and trying anyway would
        // burn an attempt off each one for nothing.
        break;
      }
    } finally {
      _queue.endDrain();
      _running = false;
    }

    final left = await _outbox.depth();
    final report = SyncReport(
      sent: sent,
      failed: failed,
      remaining: left,
      quarantined: quarantined,
    );

    if (!_reports.isClosed) _reports.add(report);
    AppLogger.info(
      'Sync: $sent sent, $failed failed, $quarantined given up, '
      '$left waiting',
    );
    return report;
  }

  /// Runs one entry. Returns null on success, or why it did not go.
  Future<Failure?> _replay(OutboxEntry entry) async {
    final payload = entry.payload;
    final assets = _assets();

    final result = switch (entry.kind) {
      OutboxKind.assignAsset => await assets.assign(
        AssignmentRequest(
          assetId: entry.subjectId,
          employeeId: payload['employeeId'] as int? ?? 0,
          employeeName: '${payload['employeeName'] ?? ''}',
          assignedOn:
              DateTime.tryParse('${payload['assignedOn']}') ?? entry.queuedAt,
          // Absent on entries queued by a build that predates due dates, and
          // `tryParse` answers null for that as well as for "no date set" —
          // which are the same thing to a replay.
          dueOn: DateTime.tryParse('${payload['dueOn']}'),
          notes: payload['notes'] as String?,
        ),
      ),
      OutboxKind.returnAsset => await assets.unassign(
        ReturnRequest(
          assetId: entry.subjectId,
          condition:
              ReturnCondition.values
                  .where((c) => c.name == payload['condition'])
                  .firstOrNull ??
              ReturnCondition.good,
          returnedOn:
              DateTime.tryParse('${payload['returnedOn']}') ?? entry.queuedAt,
          employeeName: payload['employeeName'] as String?,
          notes: payload['notes'] as String?,
          photoPaths: <String>[
            for (final path in payload['photoPaths'] as List? ?? const [])
              '$path',
          ],
        ),
      ),
      OutboxKind.setAssetStatus => await assets.setLocalStatus(
        entry.subjectId,
        AssetStatus.values
                .where((s) => s.name == payload['status'])
                .firstOrNull ??
            AssetStatus.available,
      ),
    };

    // Exhaustive on purpose: a new [OutboxKind] must be a compile error here
    // rather than an entry that silently never goes out.
    return result.fold((failure) => failure, (_) => null);
  }

  Future<void> dispose() async {
    await _watch?.cancel();
    await _reports.close();
  }
}
