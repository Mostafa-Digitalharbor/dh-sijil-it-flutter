import '../../../../core/network/odoo/odoo_chatter_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/asset_status.dart';
import 'asset_note_vocabulary.dart';
import 'local_asset_state_store.dart';

/// Where Reserved, Damaged and Lost are kept.
///
/// ## What changed, and why it had to
///
/// These three states have no field in standard Odoo and spec §2 forbids
/// shipping an addon to create one, so the app used to hold them in an
/// encrypted box on the device. That worked exactly once: the phone that
/// recorded "Damaged" was the only phone that knew. A colleague opening the
/// same asset saw "Available", the web client saw "Available", and a lost
/// laptop reverted to available the moment the technician was handed a new
/// device — silently, with nothing in the product to suggest it had happened.
///
/// The app had been posting a note to the asset's chatter on every one of
/// those writes since the first release. That note was the record all along;
/// nothing read it back. This store does:
///
/// ```
/// write → the chatter note is the write   (posted by AssetRepository)
///       → the local box mirrors it        (so the next read is instant)
/// read  → Odoo's newest status note wins
///       → the mirror answers when Odoo cannot be reached
/// ```
///
/// It works on data already in the customer's database — every status note
/// ever written parses — so there is no migration and nothing to backfill.
///
/// ## Why the mirror stays
///
/// Not as a second source of truth: as a cache and an offline answer. A
/// technician in a basement server room with no signal still sees the state
/// they recorded upstairs. Where the two disagree, Odoo wins on the next
/// successful read, because the two devices that disagree cannot both be
/// right and only one of them is shared.
class AssetStateStore {
  const AssetStateStore({
    required LocalAssetStateStore mirror,
    required OdooChatterService chatter,
  }) : _mirror = mirror,
       _chatter = chatter;

  final LocalAssetStateStore _mirror;
  final OdooChatterService _chatter;

  /// The state recorded for one asset, or null when none ever was.
  Future<AssetStatus?> read(String model, int id) async {
    final remote = await _readRemote(model, <int>[id]);
    if (remote == null) return _mirror.read(model, id);

    // A resolved read is authoritative in both directions: an *absent* entry
    // means the state was cleared in Odoo, and honouring the mirror there is
    // how a stale "Damaged" outlives the return that cleared it.
    final status = remote[id];
    if (status != await _mirror.read(model, id)) {
      await _syncMirror(model, id, status);
    }
    return status;
  }

  /// States for a whole page, in one round trip.
  Future<Map<int, AssetStatus>> readAll(String model, List<int> ids) async {
    final remote = await _readRemote(model, ids);
    if (remote == null) return _mirror.readAll(model, ids);

    // Only what actually changed is written back. Almost no asset carries one
    // of these states, so a page of fifty is normally fifty *reads* and zero
    // writes — where syncing unconditionally would be fifty deletes, on every
    // scroll, to remove keys that were never there.
    final held = await _mirror.readAll(model, ids);
    for (final id in ids) {
      if (remote[id] == held[id]) continue;
      await _syncMirror(model, id, remote[id]);
    }
    return remote;
  }

  /// Every state currently recorded across the fleet, for the dashboard's
  /// per-status counts. Values only — the caller is counting, not addressing.
  Future<List<AssetStatus>> statuses(String model) async {
    final remote = await _readRemote(model, null);
    if (remote == null) return _mirror.statuses(model);
    return remote.values.toList();
  }

  /// Mirrors a state the repository has just written to the chatter.
  ///
  /// Deliberately does not post the note itself. The note is the write, and it
  /// has to fail loudly — a mirror-only write would report success while
  /// leaving no record anywhere but this device, which is the exact failure
  /// this class exists to end.
  Future<void> mirror(String model, int id, AssetStatus status) =>
      _mirror.write(model, id, status);

  Future<void> clear(String model, int id) => _mirror.clear(model, id);

  /// Drops the offline mirror. Settings → Clear cache, and now genuinely a
  /// cache clear: the states come back on the next read from Odoo.
  Future<void> clearAll() => _mirror.clearAll();

  /// Reads the newest status note per asset, or null when Odoo could not
  /// answer at all.
  ///
  /// Null and an empty map are different answers, and the difference is the
  /// whole contract: empty means "Odoo says none of these assets has a
  /// recorded state" and must clear the mirror; null means "Odoo was not
  /// reachable" and must leave it alone.
  Future<Map<int, AssetStatus>?> _readRemote(String model, List<int>? ids) async {
    try {
      final bodies = await _chatter.latestBodies(
        model: model,
        ids: ids,
        contains: AssetNoteVocabulary.statusPrefix,
      );

      final states = <int, AssetStatus>{};
      for (final entry in bodies.entries) {
        final status = AssetNoteVocabulary.statusIn(entry.value);
        // Only the three Odoo cannot express are carried. A note recording a
        // move back to Available is how the state gets *cleared*, so it must
        // leave nothing behind — dropping it here is that.
        if (status != null && status.isLocalOnly) states[entry.key] = status;
      }
      return states;
    } on Object catch (error) {
      // Not surfaced: the asset still resolves to its derived status, which is
      // correct, just less specific. Failing the list screen over a refinement
      // would be a worse trade than showing it.
      AppLogger.warn('Asset states unavailable from Odoo — $error');
      return null;
    }
  }

  Future<void> _syncMirror(String model, int id, AssetStatus? status) async {
    if (status == null) {
      await _mirror.clear(model, id);
    } else {
      await _mirror.write(model, id, status);
    }
  }
}
