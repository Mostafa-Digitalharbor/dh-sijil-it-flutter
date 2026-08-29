import 'dart:async';

import '../constants/storage_keys.dart';
import '../storage/cache/cache_store.dart';
import '../utils/logger.dart';
import 'outbox_entry.dart';

/// The queue of writes waiting for a connection.
///
/// Backed by the same encrypted Hive store as the read cache, because the
/// payloads name employees and assets — that is company data, and it sits on
/// the device for as long as the technician is out of signal.
///
/// Ordering is by [OutboxEntry.queuedAt] and it is load-bearing: assigning an
/// asset and then returning it must replay in that order, or the asset ends up
/// held by somebody who gave it back.
class OutboxStore {
  OutboxStore(this._cache);

  final CacheStore _cache;

  final StreamController<int> _depth = StreamController<int>.broadcast();

  /// Emits the queue length on every change, so a badge does not have to poll.
  Stream<int> get depthChanged => _depth.stream;

  int _seq = 0;

  /// Unique within the process, sortable, and no uuid dependency: a single
  /// device is the only writer.
  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  Future<OutboxEntry> add({
    required OutboxKind kind,
    required int subjectId,
    required String subjectName,
    required Map<String, dynamic> payload,
  }) async {
    final entry = OutboxEntry(
      id: _nextId(),
      kind: kind,
      subjectId: subjectId,
      subjectName: subjectName,
      payload: payload,
      queuedAt: DateTime.now(),
    );

    await _cache.put(CacheBoxes.outbox, entry.id, entry.toJson());
    await _announce();
    AppLogger.info('Queued ${kind.name} for asset $subjectId');
    return entry;
  }

  /// Everything waiting, oldest first.
  Future<List<OutboxEntry>> pending() async {
    final keys = await _cache.keys(CacheBoxes.outbox);
    final entries = <OutboxEntry>[];

    for (final key in keys) {
      final raw = await _cache.get<Map<String, dynamic>>(
        CacheBoxes.outbox,
        key,
      );
      final entry = raw == null ? null : OutboxEntry.fromJson(raw.value);
      if (entry == null) {
        // Unreadable rows are dropped rather than left to block the queue.
        await _cache.delete(CacheBoxes.outbox, key);
        continue;
      }
      entries.add(entry);
    }

    entries.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return entries;
  }

  /// How many writes are waiting, including ones that have stopped retrying.
  Future<int> depth() async => (await pending()).length;

  /// The assets the queue is holding a change for, so their rows can say so.
  Future<Set<int>> subjectIds() async =>
      (await pending()).map((e) => e.subjectId).toSet();

  Future<void> remove(String id) async {
    await _cache.delete(CacheBoxes.outbox, id);
    await _announce();
  }

  Future<void> save(OutboxEntry entry) async {
    await _cache.put(CacheBoxes.outbox, entry.id, entry.toJson());
    await _announce();
  }

  Future<void> clear() async {
    await _cache.clearBox(CacheBoxes.outbox);
    await _announce();
  }

  Future<void> _announce() async {
    if (_depth.isClosed) return;
    _depth.add(await depth());
  }

  Future<void> dispose() => _depth.close();
}
