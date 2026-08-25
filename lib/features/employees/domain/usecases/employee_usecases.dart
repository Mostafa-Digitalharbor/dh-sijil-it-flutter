import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class GetEmployeesPage
    extends UseCase<PaginatedResult<Employee>, EmployeeQuery> {
  const GetEmployeesPage(this._repository);

  final EmployeeRepository _repository;

  @override
  ResultFuture<PaginatedResult<Employee>> call(EmployeeQuery params) =>
      _repository.getEmployees(filters: params.filters, page: params.page);
}

class GetEmployee extends UseCase<Employee, int> {
  const GetEmployee(this._repository);

  final EmployeeRepository _repository;

  @override
  ResultFuture<Employee> call(int params) => _repository.getEmployee(params);
}

/// Typeahead for the assignment picker (spec §7).
class SearchEmployees extends UseCase<List<Employee>, String> {
  const SearchEmployees(this._repository);

  final EmployeeRepository _repository;

  @override
  ResultFuture<List<Employee>> call(String params) =>
      _repository.search(params);
}

class GetDepartments extends UseCaseWithoutParams<List<OdooNameRef>> {
  const GetDepartments(this._repository);

  final EmployeeRepository _repository;

  @override
  ResultFuture<List<OdooNameRef>> call() => _repository.departments();
}

/// One page request for the directory.
class EmployeeQuery extends Equatable {
  const EmployeeQuery({
    this.filters = const EmployeeFilters(),
    this.page = const PageRequest(),
  });

  final EmployeeFilters filters;
  final PageRequest page;

  EmployeeQuery next() => EmployeeQuery(filters: filters, page: page.next());

  EmployeeQuery first() => EmployeeQuery(filters: filters, page: page.first());

  EmployeeQuery copyWith({EmployeeFilters? filters, PageRequest? page}) =>
      EmployeeQuery(filters: filters ?? this.filters, page: page ?? this.page);

  @override
  List<Object?> get props => [filters, page];
}
