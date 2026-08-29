import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/sync/offline_reads.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/asset_query.dart';
import 'asset_remote_data_source.dart';

/// [AssetRemoteDataSource] that remembers the last answer to every read.
///
/// A decorator rather than an edit to the strategy it wraps: which model backs
/// assets on a given instance is a question `MaintenanceEquipmentDataSource`
/// and its future siblings answer, and caching is orthogonal to it. Wrapping
/// means a second strategy gets the offline behaviour for free and neither
/// class grows a reason to know about the other.
///
/// Only the two reads a technician needs in a corridor are cached — the page
/// and the single record. Everything else passes straight through:
///
/// * **Writes** must never be answered from a cache; they go to the outbox
///   instead, which is a different mechanism with a visible queue.
/// * **Categories, manufacturers and field metadata** already have their own
///   TTL cache in `OdooCapabilityService`.
/// * **Permission checks** answered from a cache would let the UI offer an
///   action the server refuses.
class CachingAssetDataSource implements AssetRemoteDataSource {
  const CachingAssetDataSource({
    required AssetRemoteDataSource inner,
    required OfflineReads reads,
  }) : _inner = inner,
       _reads = reads;

  final AssetRemoteDataSource _inner;
  final OfflineReads _reads;

  @override
  String get model => _inner.model;

  /// One cache slot per distinct query, so the filtered list a technician left
  /// open is the one that comes back — not whatever page was read last.
  String _pageKey(AssetQuery query) => '$model|${query.cacheKey}';

  @override
  Future<RawAssetPage> fetchPage(AssetQuery query) => _reads.read(
    box: CacheBoxes.assetPages,
    key: _pageKey(query),
    live: () => _inner.fetchPage(query),
    encode: (page) => <String, dynamic>{
      'records': page.records,
      'total': page.totalCount,
    },
    decode: (stored) {
      final map = stored as Map;
      return RawAssetPage(
        records: <OdooRecord>[
          for (final row in map['records'] as List? ?? const <Object?>[])
            Map<String, dynamic>.from(row as Map),
        ],
        totalCount: map['total'] as int? ?? 0,
      );
    },
    // A page is also the detail of every asset on it — `fetchPage` and
    // `fetchOne` read the same field set, so this is the same record, not a
    // thinner one. Without it a technician can browse the list downstairs and
    // then find every asset on it unopenable.
    onFresh: (page) async {
      for (final record in page.records) {
        final id = record['id'];
        if (id is int) {
          await _reads.remember(CacheBoxes.assetDetails, '$model|$id', record);
        }
      }
    },
  );

  @override
  Future<OdooRecord?> fetchOne(int id) => _reads.read(
    box: CacheBoxes.assetDetails,
    key: '$model|$id',
    live: () => _inner.fetchOne(id),
    // A record that does not exist is cached as such: a deleted asset must
    // not come back to life the moment the phone loses signal.
    encode: (record) => record ?? const <String, dynamic>{},
    decode: (stored) {
      final map = Map<String, dynamic>.from(stored as Map);
      return map.isEmpty ? null : map;
    },
  );

  @override
  Future<OdooRecord?> findBySerial(String serial) =>
      _inner.findBySerial(serial);

  @override
  Future<int> create(Map<String, dynamic> values) => _inner.create(values);

  @override
  Future<void> update(int id, Map<String, dynamic> values) async {
    await _inner.update(id, values);
    // The cached copy is now a lie about a record this device just changed.
    await _reads.forget(CacheBoxes.assetDetails, '$model|$id');
  }

  @override
  Future<void> delete(int id) async {
    await _inner.delete(id);
    await _reads.forget(CacheBoxes.assetDetails, '$model|$id');
  }

  @override
  Future<void> postNote(int id, String body) => _inner.postNote(id, body);

  @override
  Future<void> attach({
    required int id,
    required String filename,
    required String base64Data,
  }) => _inner.attach(id: id, filename: filename, base64Data: base64Data);

  @override
  Future<List<OdooNameRef>> categories() => _inner.categories();

  @override
  Future<List<String>> manufacturers() => _inner.manufacturers();

  @override
  Future<bool> can(String operation) => _inner.can(operation);

  @override
  Future<Set<String>> writableFields() => _inner.writableFields();

  @override
  Future<Set<String>> requiredFields() => _inner.requiredFields();
}
