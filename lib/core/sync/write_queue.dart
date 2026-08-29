import '../network/connectivity/network_info.dart';
import 'offline_reads.dart';

/// Decides whether a write waits in the outbox or is reported as a failure.
///
/// One object rather than an `if` in every repository method, because the
/// decision has a subtlety that is easy to get wrong in the fifth copy: while
/// the queue is *draining*, a write that fails must fail. Otherwise replaying
/// a queued assignment that still cannot reach Odoo would enqueue it a second
/// time, and the queue would grow by one on every attempt to empty it.
class WriteQueue {
  WriteQueue(this._network);

  final NetworkInfo _network;

  bool _draining = false;

  /// True while [SyncService] is replaying. Public so a repository can ask.
  bool get isDraining => _draining;

  /// Called by [SyncService] around a replay. Nothing else may call these:
  /// they suppress queueing, which is safe only while the queue is the caller.
  void beginDrain() => _draining = true;

  void endDrain() => _draining = false;

  /// Whether a write should go straight to the queue without being attempted.
  ///
  /// Asked *before* the request rather than only after it fails, so a
  /// technician with no signal is not made to wait out a socket timeout per
  /// asset — six laptops is six timeouts, which is the difference between a
  /// queue that feels instant and one that feels broken.
  Future<bool> shouldQueue() async {
    if (_draining) return false;
    return !await _network.isConnected;
  }

  /// Whether a write that already failed belongs in the queue rather than in
  /// front of the user.
  bool shouldQueueAfter(Object error) => !_draining && isOfflineShaped(error);
}
