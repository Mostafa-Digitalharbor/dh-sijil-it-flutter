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
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

/// Reads employees from `hr.employee` (spec §9).
///
/// Every method begins by confirming the model exists. An instance without the
/// Employees app is not an error state — it is a smaller product, and the
/// capability gate makes that a `modelUnavailable` failure the UI already
/// knows how to render as an explanation rather than a crash.
class EmployeeRepositoryImpl
    with RepositoryGuard
    implements EmployeeRepository {
  @override
  String get guardLabel => 'employee repository';

  const EmployeeRepositoryImpl({
    required OdooObjectService odoo,
    required OdooCapabilityService capabilities,
  }) : _odoo = odoo,
       _capabilities = capabilities;

  final OdooObjectService _odoo;
  final OdooCapabilityService _capabilities;

  static const String _model = OdooModels.hrEmployee;

  @override
  ResultFuture<PaginatedResult<Employee>> getEmployees({
    EmployeeFilters filters = const EmployeeFilters(),
    PageRequest page = const PageRequest(),
  }) => guard(() async {
    await _capabilities.requireModel(_model);

    final domain = _domainFor(filters);
    final total = await _odoo.searchCount(model: _model, domain: domain);

    final records = await _odoo.searchReadPage(
      model: _model,
      fields: await _readFields(),
      domain: domain,
      page: PageRequest(
        offset: page.offset,
        limit: page.limit,
        order: EmployeeFields.name,
      ),
    );

    return PaginatedResult<Employee>(
      items: records.map(_toEntity).toList(growable: false),
      totalCount: total,
      request: page,
    );
  });

  @override
  ResultFuture<Employee> getEmployee(int id) => guard(() async {
    await _capabilities.requireModel(_model);

    final records = await _odoo.read(
      model: _model,
      ids: <int>[id],
      fields: await _readFields(),
    );
    if (records.isEmpty) throw RecordNotFoundException(_model, id);

    final employee = _toEntity(records.first);

    // Counted rather than read: the detail screen shows "4 assets held", and
    // fetching four full equipment rows to learn the number four is exactly
    // the kind of query spec §20 exists to prevent.
    return employee.copyWith(assetCount: await _countAssets(id));
  });

  @override
  ResultFuture<List<Employee>> search(String query, {int limit = 20}) =>
      guard(() async {
        await _capabilities.requireModel(_model);

        final trimmed = query.trim();

        // `name_search` returns only id and display name. The picker shows
        // department and email too, so the matched ids are read back in one
        // follow-up call rather than one per row.
        final matches = await _odoo.nameSearch(
          model: _model,
          query: trimmed,
          limit: limit,
        );
        if (matches.isEmpty) return const <Employee>[];

        final records = await _odoo.read(
          model: _model,
          ids: matches.map((m) => m.id).toList(growable: false),
          fields: await _readFields(),
        );

        // `read` does not preserve the order `name_search` ranked them in, and
        // that ranking is the whole value of a typeahead.
        final byId = <int, OdooRecord>{
          for (final record in records) record.recordId: record,
        };
        return matches
            .map((m) => byId[m.id])
            .whereType<OdooRecord>()
            .map(_toEntity)
            .toList(growable: false);
      });

  @override
  ResultFuture<List<OdooNameRef>> departments() => guard(() async {
    if (!await _capabilities.modelExists(OdooModels.hrDepartment)) {
      return const <OdooNameRef>[];
    }

    final records = await _odoo.searchRead(
      model: OdooModels.hrDepartment,
      fields: NamedRecordFields.readSet,
      order: NamedRecordFields.name,
    );

    return records
        .map(
          (r) => OdooNameRef(
            r.recordId,
            r.readString(NamedRecordFields.name) ?? '',
          ),
        )
        .where((ref) => ref.id != 0)
        .toList(growable: false);
  });

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<int> _countAssets(int employeeId) async {
    if (!await _capabilities.modelExists(OdooModels.maintenanceEquipment)) {
      return 0;
    }
    try {
      return await _odoo.searchCount(
        model: OdooModels.maintenanceEquipment,
        domain: <Object?>[
          <Object?>[EquipmentFields.employeeId, '=', employeeId],
        ],
      );
    } on AppException catch (error) {
      // A count the user cannot read is a missing number, not a broken
      // profile — the rest of the screen is still worth showing.
      AppLogger.warn(
        'Asset count failed for employee $employeeId — ${error.message}',
      );
      return 0;
    }
  }

  OdooDomain _domainFor(EmployeeFilters filters) {
    final builder = OdooDomainBuilder();

    builder.searchAcross(const <String>[
      EmployeeFields.name,
      EmployeeFields.workEmail,
      EmployeeFields.jobTitle,
    ], filters.query);

    builder.equals(EmployeeFields.departmentId, filters.departmentId);

    return builder.build();
  }

  Employee _toEntity(OdooRecord record) => Employee(
    id: record.recordId,
    name: record.readString(EmployeeFields.name) ?? '',
    department: record.readRef(EmployeeFields.departmentId),
    job: record.readRef(EmployeeFields.jobId),
    jobTitle: record.readString(EmployeeFields.jobTitle),
    workEmail: record.readString(EmployeeFields.workEmail),
    workPhone: record.readString(EmployeeFields.workPhone),
    mobilePhone: record.readString(EmployeeFields.mobilePhone),
  );

  Future<List<String>> _readFields() =>
      _capabilities.supportedFields(_model, EmployeeFields.readSet);
}
