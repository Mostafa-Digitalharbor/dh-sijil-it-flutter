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

  /// Every row on disk, live and quarantined, oldest first.
  Future<List<OutboxEntry>> all() async {
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

  /// Everything still waiting to go, oldest first.
  ///
  /// Excludes quarantined rows, and every caller depends on that: the banner
  /// stops warning, [depth] can reach zero, and [subjectIds] stops naming an
  /// asset whose write Odoo has refused — which is what lets the detail screen
  /// go back to showing the record Odoo actually holds.
  Future<List<OutboxEntry>> pending() async =>
      (await all()).where((e) => !e.isQuarantined).toList();

  /// Writes the app has given up sending, newest failure first.
  ///
  /// Kept rather than deleted: they are still the only copy of work somebody
  /// did, and the reason they failed is often something an administrator can
  /// fix — after which [retry] puts them back in the queue.
  Future<List<OutboxEntry>> quarantined() async {
    final entries = (await all()).where((e) => e.isQuarantined).toList()
      ..sort((a, b) => b.quarantinedAt!.compareTo(a.quarantinedAt!));
    return entries;
  }

  /// How many writes are still waiting to go.
  Future<int> depth() async => (await pending()).length;

  /// The assets the queue is holding a *live* change for, so their rows can
  /// say so. A quarantined write is not pending and must not be overlaid.
  Future<Set<int>> subjectIds() async =>
      (await pending()).map((e) => e.subjectId).toSet();

  /// Stops trying to send [entry], keeping it and the reason it failed.
  Future<void> quarantine(OutboxEntry entry, {required String reason}) async {
    await save(
      entry.copyWith(lastError: reason, quarantinedAt: DateTime.now()),
    );
    AppLogger.warn(
      'Quarantined ${entry.kind.name} for ${entry.subjectId}: '
      '$reason',
    );
  }

  /// Puts a quarantined write back in the queue, with its attempt count reset.
  ///
  /// The count is reset because the thing that was failing is usually outside
  /// the app — a permission, a record rule, a required field somebody has now
  /// filled in — and carrying five spent attempts forward would send it
  /// straight back to quarantine on the first hiccup.
  Future<void> retry(String id) async {
    final entry = (await all()).where((e) => e.id == id).firstOrNull;
    if (entry == null) return;
    await save(entry.copyWith(attempts: 0, clearQuarantine: true));
  }

  /// Discards only the writes that were given up on.
  Future<void> clearQuarantined() async {
    for (final entry in await quarantined()) {
      await _cache.delete(CacheBoxes.outbox, entry.id);
    }
    await _announce();
  }

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
