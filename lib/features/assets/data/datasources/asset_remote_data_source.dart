import '../../../../core/constants/odoo_models.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_domain_builder.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/asset_query.dart';
import '../../domain/entities/asset_status.dart';

/// A page of raw records plus the total the same domain matches.
class RawAssetPage {
  const RawAssetPage({required this.records, required this.totalCount});

  final OdooRecords records;
  final int totalCount;
}

/// Where assets come from on this instance (Strategy pattern).
///
/// The interface exists so that supporting `stock.lot` later is a new class
/// rather than an edit to this one — the open/closed rule from
/// docs/ARCHITECTURE.md §4.
abstract interface class AssetRemoteDataSource {
  /// The Odoo model this strategy reads. Needed by the overlay store, which
  /// keys on it.
  String get model;

  Future<RawAssetPage> fetchPage(AssetQuery query);

  Future<OdooRecord?> fetchOne(int id);

  Future<OdooRecord?> findBySerial(String serial);

  Future<int> create(Map<String, dynamic> values);

  Future<void> update(int id, Map<String, dynamic> values);

  /// Applies the same values to many records in one call.
  ///
  /// One `write` rather than a loop: Odoo's ORM takes a list of ids natively,
  /// so moving forty assets to a new department is one round trip and one
  /// transaction. A loop would be forty of each, and a failure halfway through
  /// would leave the fleet split across two departments with nothing saying
  /// where the boundary fell.
  Future<void> updateMany(List<int> ids, Map<String, dynamic> values);

  Future<void> delete(int id);

  /// Writes an internal note to the record's chatter.
  Future<void> postNote(int id, String body);

  /// Attaches a file to the record as an `ir.attachment` (spec §8).
  Future<void> attach({
    required int id,
    required String filename,
    required String base64Data,
  });

  Future<List<OdooNameRef>> categories();

  Future<List<String>> manufacturers();

  Future<bool> can(String operation);

  /// The subset of the app's write set this instance actually exposes.
  Future<Set<String>> writableFields();

  /// Fields this instance marks required, which therefore must never be sent
  /// Odoo's "empty" sentinel.
  Future<Set<String>> requiredFields();
}

/// Reads assets from `maintenance.equipment` — the richest standard fit
/// (docs/ARCHITECTURE.md §5).
class MaintenanceEquipmentDataSource implements AssetRemoteDataSource {
  const MaintenanceEquipmentDataSource(this._odoo, this._capabilities);

  final OdooObjectService _odoo;
  final OdooCapabilityService _capabilities;

  @override
  String get model => OdooModels.maintenanceEquipment;

  /// Fields searched by the free-text box (spec §11).
  static const List<String> _searchableFields = <String>[
    EquipmentFields.name,
    EquipmentFields.serialNo,
    EquipmentFields.model,
    EquipmentFields.partnerRef,
  ];

  @override
  Future<RawAssetPage> fetchPage(AssetQuery query) async {
    final domain = await _buildDomain(query.filters);
    final fields = await _readFields();

    // Counted with the same domain rather than inferred from the page length:
    // "showing 24 of 115" has to be true, and a short page does not mean the
    // end of the list when a limit is in play.
    final total = await _odoo.searchCount(model: model, domain: domain);

    final records = await _odoo.searchReadPage(
      model: model,
      fields: fields,
      domain: domain,
      page: PageRequest(
        offset: query.page.offset,
        limit: query.page.limit,
        order: _orderFor(query.sort),
      ),
    );

    return RawAssetPage(records: records, totalCount: total);
  }

  @override
  Future<OdooRecord?> fetchOne(int id) async {
    final records = await _odoo.read(
      model: model,
      ids: <int>[id],
      fields: await _readFields(),
    );
    return records.isEmpty ? null : records.first;
  }

  @override
  Future<OdooRecord?> findBySerial(String serial) async {
    final term = serial.trim();
    if (term.isEmpty) return null;

    // An exact match on either identifier first — a scanned barcode is a
    // whole value, and `ilike` on a short code would open the wrong asset.
    for (final field in <String>[
      EquipmentFields.serialNo,
      EquipmentFields.partnerRef,
    ]) {
      final records = await _odoo.searchRead(
        model: model,
        domain: <Object?>[
          <Object?>[field, '=', term],
        ],
        fields: await _readFields(),
        limit: 1,
      );
      if (records.isNotEmpty) return records.first;
    }

    return null;
  }

  @override
  Future<int> create(Map<String, dynamic> values) =>
      _odoo.create(model: model, values: values);

  @override
  Future<void> update(int id, Map<String, dynamic> values) =>
      _odoo.write(model: model, ids: <int>[id], values: values);

  @override
  Future<void> updateMany(List<int> ids, Map<String, dynamic> values) =>
      _odoo.write(model: model, ids: ids, values: values);

  @override
  Future<void> delete(int id) => _odoo.unlink(model: model, ids: <int>[id]);

  @override
  Future<void> postNote(int id, String body) => _odoo.executeKw(
    model: model,
    method: OdooMethods.messagePost,
    args: <Object?>[
      <Object?>[id],
    ],
    kwargs: <String, dynamic>{
      MailMessageFields.argBody: body,
      MailMessageFields.argSubtype: MailMessageFields.subtypeNote,
    },
  );

  @override
  Future<void> attach({
    required int id,
    required String filename,
    required String base64Data,
  }) => _odoo.create(
    model: OdooModels.irAttachment,
    values: <String, dynamic>{
      AttachmentFields.name: filename,
      AttachmentFields.datas: base64Data,
      AttachmentFields.resModel: model,
      AttachmentFields.resId: id,
    },
  );

  @override
  Future<List<OdooNameRef>> categories() async {
    const categoryModel = OdooModels.maintenanceEquipmentCategory;
    if (!await _capabilities.modelExists(categoryModel)) {
      return const <OdooNameRef>[];
    }

    final records = await _odoo.searchRead(
      model: categoryModel,
      fields: NamedRecordFields.readSet,
      order: NamedRecordFields.name,
    );

    return records
        .map(
          (r) =>
              OdooNameRef(r['id'] as int? ?? 0, '${r[NamedRecordFields.name]}'),
        )
        .where((ref) => ref.id != 0)
        .toList(growable: false);
  }

  @override
  Future<List<String>> manufacturers() async {
    // Grouped rather than listed: the distinct set is what the filter needs,
    // and `read_group` returns it without downloading every equipment row.
    final result = await _odoo.executeKw(
      model: model,
      method: OdooMethods.readGroup,
      args: <Object?>[
        const <Object?>[],
        <Object?>[EquipmentFields.partnerId],
        <Object?>[EquipmentFields.partnerId],
      ],
      kwargs: const <String, dynamic>{'lazy': true},
    );

    if (result is! List) return const <String>[];

    final names = <String>{};
    for (final group in result.whereType<Map<Object?, Object?>>()) {
      final ref = OdooNameRef.fromPair(group[EquipmentFields.partnerId]);
      if (ref != null) names.add(ref.name);
    }

    return names.toList(growable: false)..sort();
  }

  @override
  Future<bool> can(String operation) =>
      _odoo.checkAccessRights(model: model, operation: operation);

  @override
  Future<Set<String>> writableFields() async => _capabilities.getFields(model);

  @override
  Future<Set<String>> requiredFields() async =>
      _capabilities.requiredFields(model);

  // ── Query construction ───────────────────────────────────────────────────

  /// Turns the domain filter set into an Odoo domain.
  ///
  /// Only the narrowings Odoo can evaluate are included. Warranty buckets and
  /// the three overlay statuses have no server-side field, so they are left to
  /// the repository — pushing an impossible condition here would silently
  /// return nothing rather than degrade.
  Future<OdooDomain> _buildDomain(AssetFilters filters) async {
    final builder = OdooDomainBuilder();
    final available = await _capabilities.getFields(model);

    builder.searchAcross(
      _searchableFields.where(available.contains).toList(),
      filters.query,
    );

    if (filters.categoryIds.isNotEmpty &&
        available.contains(EquipmentFields.categoryId)) {
      builder.inList(EquipmentFields.categoryId, filters.categoryIds.toList());
    }

    if (filters.employeeId != null &&
        available.contains(EquipmentFields.employeeId)) {
      builder.equals(EquipmentFields.employeeId, filters.employeeId);
    }

    if (filters.departmentId != null &&
        available.contains(EquipmentFields.departmentId)) {
      builder.equals(EquipmentFields.departmentId, filters.departmentId);
    }

    if (filters.manufacturer != null &&
        available.contains(EquipmentFields.partnerId)) {
      builder.contains(EquipmentFields.partnerId, filters.manufacturer);
    }

    _applyStatusDomain(builder, filters, available);

    return builder.build();
  }

  /// Maps the server-derivable statuses onto the fields that prove them.
  ///
  /// Mirrors `AssetStatusResolver._derive` exactly — if the two ever disagree,
  /// a filtered list stops matching the chips it is showing.
  void _applyStatusDomain(
    OdooDomainBuilder builder,
    AssetFilters filters,
    Set<String> available,
  ) {
    final hasScrap = available.contains(EquipmentFields.scrapDate);
    final hasEmployee = available.contains(EquipmentFields.employeeId);
    final hasOpenCount = available.contains(
      EquipmentFields.maintenanceOpenCount,
    );

    // Retired assets are excluded unless explicitly asked for, or unless the
    // user filtered *for* them.
    final wantsRetired =
        filters.includeRetired ||
        filters.statuses.contains(AssetStatus.retired);
    if (!wantsRetired && hasScrap) {
      builder.isNotSet(EquipmentFields.scrapDate);
    }

    final serverSide = filters.statuses.where((s) => !s.isLocalOnly).toSet();
    if (serverSide.isEmpty) return;

    // A single status can be expressed exactly. A mixed selection cannot be
    // AND-ed (nothing is both assigned and available), and OR-ing across three
    // different fields produces a domain Odoo evaluates but a human cannot
    // review — so the repository narrows those in Dart instead.
    if (serverSide.length != 1) return;

    switch (serverSide.first) {
      case AssetStatus.assigned:
        if (hasEmployee) builder.isSet(EquipmentFields.employeeId);
      case AssetStatus.available:
        if (hasEmployee) builder.isNotSet(EquipmentFields.employeeId);
        if (hasOpenCount) {
          builder.condition(EquipmentFields.maintenanceOpenCount, '=', 0);
        }
      case AssetStatus.underMaintenance:
        if (hasOpenCount) {
          builder.condition(EquipmentFields.maintenanceOpenCount, '>', 0);
        }
      case AssetStatus.retired:
        if (hasScrap) builder.isSet(EquipmentFields.scrapDate);
      case AssetStatus.reserved:
      case AssetStatus.damaged:
      case AssetStatus.lost:
        break;
    }
  }

  static String _orderFor(AssetSort sort) => switch (sort) {
    AssetSort.recentlyUpdated => '${EquipmentFields.writeDate} desc',
    AssetSort.nameAsc => '${EquipmentFields.name} asc',
    AssetSort.nameDesc => '${EquipmentFields.name} desc',
  };

  /// The read set, narrowed to what this instance exposes (spec §17).
  Future<List<String>> _readFields() => _capabilities.supportedFields(
    model,
    <String>[...EquipmentFields.readSet, AssetStatusField.name],
  );
}
