
import '../../../../core/constants/odoo_models.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_domain_builder.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/network/odoo/odoo_value.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/maintenance_request.dart';
import '../../domain/repositories/maintenance_repository.dart';

/// Reads and writes `maintenance.request` (spec §16).
class MaintenanceRepositoryImpl with RepositoryGuard implements MaintenanceRepository {
  @override
  String get guardLabel => 'maintenance repository';

  const MaintenanceRepositoryImpl({
    required OdooObjectService odoo,
    required OdooCapabilityService capabilities,
  }) : _odoo = odoo,
       _capabilities = capabilities;

  final OdooObjectService _odoo;
  final OdooCapabilityService _capabilities;

  static const String _model = OdooModels.maintenanceRequest;

  @override
  ResultFuture<PaginatedResult<MaintenanceRequest>> getRequests({
    MaintenanceFilters filters = const MaintenanceFilters(),
    PageRequest page = const PageRequest(),
  }) => guard(() async {
    await _capabilities.requireModel(_model);

    final closingStages = await _closingStageIds();
    final domain = _domainFor(filters, closingStages);

    final total = await _odoo.searchCount(model: _model, domain: domain);
    final records = await _odoo.searchReadPage(
      model: _model,
      fields: await _readFields(),
      domain: domain,
      page: PageRequest(
        offset: page.offset,
        limit: page.limit,
        order: '${MaintenanceRequestFields.requestDate} desc',
      ),
    );

    return PaginatedResult<MaintenanceRequest>(
      items: records
          .map((r) => _toEntity(r, closingStages))
          .toList(growable: false),
      totalCount: total,
      request: page,
    );
  });

  @override
  ResultFuture<MaintenanceRequest> getRequest(int id) => guard(() async {
    await _capabilities.requireModel(_model);

    final records = await _odoo.read(
      model: _model,
      ids: <int>[id],
      fields: await _readFields(),
    );
    if (records.isEmpty) throw RecordNotFoundException(_model, id);

    return _toEntity(records.first, await _closingStageIds());
  });

  @override
  ResultFuture<MaintenanceRequest> createRequest({
    required int equipmentId,
    required String name,
    required MaintenanceType type,
    MaintenancePriority priority = MaintenancePriority.normal,
    String? description,
    DateTime? scheduledFor,
  }) => guard(() async {
    await _capabilities.requireModel(_model);

    final supported = await _capabilities.getFields(_model);
    final values = <String, dynamic>{};

    void put(String field, Object value) {
      if (supported.contains(field)) values[field] = value;
    }

    put(MaintenanceRequestFields.name, OdooWrite.text(name));
    put(MaintenanceRequestFields.equipmentId, equipmentId);
    put(MaintenanceRequestFields.maintenanceType, type.odooValue);
    put(MaintenanceRequestFields.priority, priority.odooValue);
    put(MaintenanceRequestFields.description, OdooWrite.html(description));
    if (scheduledFor != null) {
      put(
        MaintenanceRequestFields.scheduleDate,
        OdooWrite.dateTime(scheduledFor),
      );
    }

    final id = await _odoo.create(model: _model, values: values);

    final records = await _odoo.read(
      model: _model,
      ids: <int>[id],
      fields: await _readFields(),
    );
    if (records.isEmpty) throw RecordNotFoundException(_model, id);

    return _toEntity(records.first, await _closingStageIds());
  });

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Stage ids whose `done` flag is set.
  ///
  /// Stages are configurable per instance, so "closed" cannot be a hardcoded
  /// name or id (spec §10) — it is whatever the customer flagged as done.
  Future<Set<int>> _closingStageIds() async {
    if (!await _capabilities.modelExists(OdooModels.maintenanceStage)) {
      return const <int>{};
    }
    try {
      final records = await _odoo.searchRead(
        model: OdooModels.maintenanceStage,
        domain: <Object?>[
          <Object?>['done', '=', true],
        ],
        fields: const <String>['id'],
      );
      return records.map((r) => r.recordId).toSet();
    } on AppException catch (error) {
      AppLogger.warn('Maintenance stages unavailable — ${error.message}');
      return const <int>{};
    }
  }

  OdooDomain _domainFor(MaintenanceFilters filters, Set<int> closingStages) {
    final builder = OdooDomainBuilder();

    builder.contains(MaintenanceRequestFields.name, filters.query);
    builder.equals(MaintenanceRequestFields.equipmentId, filters.equipmentId);
    builder.equals(
      MaintenanceRequestFields.maintenanceType,
      filters.type?.odooValue,
    );

    if (filters.onlyOpen && closingStages.isNotEmpty) {
      builder.notInList(
        MaintenanceRequestFields.stageId,
        closingStages.toList(),
      );
    }

    return builder.build();
  }

  MaintenanceRequest _toEntity(OdooRecord record, Set<int> closingStages) {
    final stage = record.readRef(MaintenanceRequestFields.stageId);

    return MaintenanceRequest(
      id: record.recordId,
      name: record.readString(MaintenanceRequestFields.name) ?? '',
      priority: MaintenancePriority.fromOdoo(
        record.readString(MaintenanceRequestFields.priority),
      ),
      equipment: record.readRef(MaintenanceRequestFields.equipmentId),
      category: record.readRef(MaintenanceRequestFields.categoryId),
      stage: stage,
      type: MaintenanceType.fromOdoo(
        record.readString(MaintenanceRequestFields.maintenanceType),
      ),
      technician: record.readRef(MaintenanceRequestFields.userId),
      requestedOn: record.readDate(MaintenanceRequestFields.requestDate),
      scheduledFor: record.readDate(MaintenanceRequestFields.scheduleDate),
      closedOn: record.readDate(MaintenanceRequestFields.closeDate),
      description: record.readHtmlAsText(MaintenanceRequestFields.description),
      durationHours: record.readDouble(MaintenanceRequestFields.duration),
      isDone: stage != null && closingStages.contains(stage.id),
    );
  }

  Future<List<String>> _readFields() =>
      _capabilities.supportedFields(_model, MaintenanceRequestFields.readSet);
}
