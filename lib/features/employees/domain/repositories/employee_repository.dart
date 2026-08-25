import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/employee.dart';

/// What the app can do with employees, stated without reference to Odoo.
abstract interface class EmployeeRepository {
  /// One page of the directory.
  ResultFuture<PaginatedResult<Employee>> getEmployees({
    EmployeeFilters filters = const EmployeeFilters(),
    PageRequest page = const PageRequest(),
  });

  ResultFuture<Employee> getEmployee(int id);

  /// Typeahead for the assignment picker (spec §7).
  ///
  /// Backed by `name_search`, which is what Odoo's own many2one widgets use —
  /// so it honours the same record rules and never needs a hardcoded id
  /// (spec §10).
  ResultFuture<List<Employee>> search(String query, {int limit = 20});

  /// Departments, for the directory filter.
  ResultFuture<List<OdooNameRef>> departments();
}
