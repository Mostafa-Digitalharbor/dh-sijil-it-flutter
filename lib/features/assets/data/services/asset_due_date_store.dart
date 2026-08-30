import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/odoo/odoo_chatter_service.dart';
import '../../../../core/storage/cache/cache_store.dart';
import '../../../../core/utils/logger.dart';
import 'asset_note_vocabulary.dart';

/// Where an asset's expected return date is kept.
///
/// ## Why it is not a field
///
/// `maintenance.equipment` has no "due back" column, and spec §2 forbids
/// shipping an addon to add one. So this follows the path the three
/// non-derivable statuses already take (`AssetStateStore`, and
/// docs/ARCHITECTURE.md §6): the clause the app writes into the assignment's
/// chatter note **is** the record, and this reads it back.
///
/// ```
/// write → the assignment note carries "Due back on 2026-09-30"
///       → the local box mirrors it        (so the next read is instant)
/// read  → Odoo's newest note mentioning the marker wins
///       → the mirror answers when Odoo cannot be reached
/// ```
///
/// The payoff is the same one: a colleague on another handset, and anybody in
/// the Odoo web client, sees the date. A due date that lived only on the phone
/// that typed it would tell nobody the laptop is late — which is the entire
/// point of having one.
///
/// ## What it deliberately does not decide
///
/// Whether an asset is *late*. That needs the assignment as well as the date —
/// a returned asset is not overdue no matter what its chatter still says — and
/// it belongs to `ReturnDue`, which the repository evaluates with both facts
/// in hand.
class AssetDueDateStore {
  const AssetDueDateStore({
    required CacheStore cache,
    required OdooChatterService chatter,
  }) : _cache = cache,
       _chatter = chatter;

  final CacheStore _cache;
  final OdooChatterService _chatter;

  static String _key(String model, int id) => '$model:$id';

  /// The date recorded for one asset, or null when none ever was.
  Future<DateTime?> read(String model, int id) async {
    final remote = await _readRemote(model, <int>[id]);
    if (remote == null) return _readMirror(model, id);

    // A resolved read is authoritative in both directions: an *absent* entry
    // means the newest note set no date, and honouring the mirror there is how
    // a stale date outlives the handover that replaced it.
    final date = remote[id];
    if (date != await _readMirror(model, id)) {
      await _syncMirror(model, id, date);
    }
    return date;
  }

  /// Dates for a whole page, in one round trip.
  Future<Map<int, DateTime>> readAll(String model, List<int> ids) async {
    final remote = await _readRemote(model, ids);
    if (remote == null) return _readAllMirror(model, ids);

    // Only what actually changed is written back. Almost no asset carries a
    // due date, so a page of fifty is normally fifty reads and zero writes.
    final held = await _readAllMirror(model, ids);
    for (final id in ids) {
      if (remote[id] == held[id]) continue;
      await _syncMirror(model, id, remote[id]);
    }
    return remote;
  }

  /// Mirrors a date the repository has just written into the chatter.
  ///
  /// Deliberately does not post the note itself, for the same reason the
  /// status store does not: the note is the write, and a mirror-only write
  /// would report success while leaving the fact on one device.
  Future<void> mirror(String model, int id, DateTime? date) =>
      _syncMirror(model, id, date);

  Future<void> clear(String model, int id) =>
      _cache.delete(CacheBoxes.localAssetDue, _key(model, id));

  /// Drops the offline mirror. Settings → Clear cache; the dates come back on
  /// the next read from Odoo.
  Future<void> clearAll() => _cache.clearBox(CacheBoxes.localAssetDue);

  // ── Odoo ─────────────────────────────────────────────────────────────────

  /// The newest due-date clause per asset, or null when Odoo could not answer.
  ///
  /// Null and an empty map are different answers, and the difference is the
  /// whole contract: empty means "Odoo says none of these assets has a date"
  /// and must clear the mirror; null means "Odoo was not reachable" and must
  /// leave it alone.
  Future<Map<int, DateTime>?> _readRemote(String model, List<int> ids) async {
    try {
      final bodies = await _chatter.latestBodies(
        model: model,
        ids: ids,
        contains: AssetNoteVocabulary.duePrefix,
        limit: AppConstants.dueNoteScanLimit,
      );

      final dates = <int, DateTime>{};
      for (final entry in bodies.entries) {
        final date = AssetNoteVocabulary.dueDateIn(entry.value);
        // A note whose clause says "not set" is how a date gets *cleared*, so
        // it must leave nothing behind — dropping it here is that.
        if (date != null) dates[entry.key] = date;
      }
      return dates;
    } on Object catch (error) {
      // Not surfaced: the asset still reads correctly, just without a date.
      // Failing a list screen over a refinement is the worse trade.
      AppLogger.warn('Asset due dates unavailable from Odoo — $error');
      return null;
    }
  }

  // ── The mirror ───────────────────────────────────────────────────────────

  Future<DateTime?> _readMirror(String model, int id) async {
    try {
      final entry = await _cache.get<String>(
        CacheBoxes.localAssetDue,
        _key(model, id),
      );
      final raw = entry?.value;
      return raw == null ? null : DateTime.tryParse(raw);
    } on Object catch (error) {
      AppLogger.warn('Local due date read failed for $model:$id — $error');
      return null;
    }
  }

  Future<Map<int, DateTime>> _readAllMirror(String model, List<int> ids) async {
    final result = <int, DateTime>{};
    for (final id in ids) {
      final date = await _readMirror(model, id);
      if (date != null) result[id] = date;
    }
    return result;
  }

  Future<void> _syncMirror(String model, int id, DateTime? date) async {
    if (date == null) {
      await clear(model, id);
      return;
    }
    await _cache.put(
      CacheBoxes.localAssetDue,
      _key(model, id),
      // The date only, never the time: a due date compared against "today"
      // must not depend on what o'clock it was recorded.
      AssetNoteVocabulary.isoDay(date),
    );
  }
}
