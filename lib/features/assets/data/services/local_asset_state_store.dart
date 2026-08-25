import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/cache/cache_store.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/asset_status.dart';

/// The on-device mirror of the three states standard Odoo cannot express:
/// Reserved, Damaged and Lost (docs/ARCHITECTURE.md §6).
///
/// Deliberately the smallest possible thing. It stores one enum name per
/// asset, in the encrypted `local_asset_state` box, keyed `"<model>:<id>"` so
/// two instances backed by different models never collide.
///
/// **This is no longer where those states live.** [AssetStateStore] reads them
/// from the notes the app posts to the asset's Odoo chatter, which is what
/// makes them visible to a colleague on another handset; this box is the copy
/// that answers while the phone is offline and the one that makes a list open
/// without waiting on a round trip. Where the two disagree, Odoo wins.
///
/// Two rules keep it honest:
///
/// 1. **Only the three non-derivable states may be written.** Anything Odoo
///    can prove is rejected, so the mirror can never contradict the server.
/// 2. **It is now genuinely a cache.** Settings → Clear cache may drop it
///    without losing anything: the next successful read restores it.
class LocalAssetStateStore {
  const LocalAssetStateStore(this._cache);

  final CacheStore _cache;

  static String _key(String model, int id) => '$model:$id';

  /// The overlaid status for one asset, or null when none was ever set.
  Future<AssetStatus?> read(String model, int id) async {
    try {
      final entry = await _cache.get<String>(
        CacheBoxes.localAssetState,
        _key(model, id),
      );
      return AssetStatus.fromName(entry?.value);
    } on Object catch (error) {
      // A missing overlay is not worth failing a screen over: the derived
      // status is still correct, just less specific.
      AppLogger.warn('Local status read failed for $model:$id — $error');
      return null;
    }
  }

  /// Overlays for a whole page of assets in one pass.
  ///
  /// The list screen would otherwise issue one storage read per row; a single
  /// map keeps a 50-row page to one traversal.
  Future<Map<int, AssetStatus>> readAll(String model, List<int> ids) async {
    final result = <int, AssetStatus>{};
    for (final id in ids) {
      final status = await read(model, id);
      if (status != null) result[id] = status;
    }
    return result;
  }

  /// Records an overlay state.
  ///
  /// Silently clears instead of writing when [status] is one Odoo can derive —
  /// that is the invariant, not an error the caller has to remember.
  Future<void> write(String model, int id, AssetStatus status) async {
    if (!status.isLocalOnly) {
      await clear(model, id);
      return;
    }
    await _cache.put(CacheBoxes.localAssetState, _key(model, id), status.name);
  }

  /// Every overlaid status currently held for [model].
  ///
  /// Returns the values, not the ids, because the only caller is the dashboard
  /// counting how many assets sit in each local bucket.
  Future<List<AssetStatus>> statuses(String model) async {
    final prefix = '$model:';
    final statuses = <AssetStatus>[];

    for (final key in await _cache.keys(CacheBoxes.localAssetState)) {
      if (!key.startsWith(prefix)) continue;
      final entry = await _cache.get<String>(CacheBoxes.localAssetState, key);
      final status = AssetStatus.fromName(entry?.value);
      if (status != null) statuses.add(status);
    }

    return statuses;
  }

  Future<void> clear(String model, int id) =>
      _cache.delete(CacheBoxes.localAssetState, _key(model, id));

  /// Drops every overlay. Only Settings → Clear cache calls this.
  Future<void> clearAll() => _cache.clearBox(CacheBoxes.localAssetState);
}
