import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../shared/cubit/async_guards.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/employee.dart';
import '../../domain/usecases/employee_usecases.dart';

/// What the employee directory renders (spec §9).
class EmployeeListState extends ViewState {
  const EmployeeListState({
    super.status,
    super.failure,
    this.page = const PaginatedResult<Employee>.empty(),
    this.query = const EmployeeQuery(),
    this.departments = const <OdooNameRef>[],
    this.isLoadingMore = false,
  });

  final PaginatedResult<Employee> page;
  final EmployeeQuery query;
  final List<OdooNameRef> departments;
  final bool isLoadingMore;

  List<Employee> get employees => page.items;

  EmployeeFilters get filters => query.filters;

  bool get hasMore => page.hasMore;

  bool get isFilteredEmpty => employees.isEmpty && filters.isNotEmpty;

  EmployeeListState copyWith({
    ViewStatus? status,
    PaginatedResult<Employee>? page,
    EmployeeQuery? query,
    List<OdooNameRef>? departments,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) => EmployeeListState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    page: page ?? this.page,
    query: query ?? this.query,
    departments: departments ?? this.departments,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    page,
    query,
    departments,
    isLoadingMore,
  ];
}

/// The employee directory's ViewModel.
class EmployeeListCubit extends Cubit<EmployeeListState> {
  EmployeeListCubit({
    required GetEmployeesPage getEmployees,
    required GetDepartments getDepartments,
  }) : _getEmployees = getEmployees,
       _getDepartments = getDepartments,
       super(const EmployeeListState());

  final GetEmployeesPage _getEmployees;
  final GetDepartments _getDepartments;

  final Debouncer _search = Debouncer();
  final RequestTicket _ticket = RequestTicket();

  Future<void> load({bool refresh = false}) async {
    emit(
      state.copyWith(
        status: refresh ? ViewStatus.refreshing : ViewStatus.loading,
        clearFailure: true,
      ),
    );

    if (state.departments.isEmpty) unawaited(_loadDepartments());

    await _fetch(state.query.first(), append: false);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status.isBusy) return;
    emit(state.copyWith(isLoadingMore: true));
    await _fetch(state.query.next(), append: true);
  }

  void search(String term) {
    _search.run(() {
      final trimmed = term.trim();
      if (trimmed == (state.query.filters.query ?? '')) return;

      _applyQuery(
        state.query.copyWith(
          filters: trimmed.isEmpty
              ? state.query.filters.copyWith(clearQuery: true)
              : state.query.filters.copyWith(query: trimmed),
        ),
      );
    });
  }

  void filterByDepartment(int? departmentId) {
    if (departmentId == state.query.filters.departmentId) return;
    _applyQuery(
      state.query.copyWith(
        filters: departmentId == null
            ? state.query.filters.copyWith(clearDepartment: true)
            : state.query.filters.copyWith(departmentId: departmentId),
      ),
    );
  }

  void _applyQuery(EmployeeQuery query) {
    emit(
      state.copyWith(
        query: query,
        status: ViewStatus.loading,
        clearFailure: true,
      ),
    );
    unawaited(_fetch(query.first(), append: false));
  }

  Future<void> _fetch(EmployeeQuery query, {required bool append}) async {
    final ticket = _ticket.take();
    final result = await _getEmployees(query);
    if (_ticket.isStale(ticket) || isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(
          status: ViewStatus.failure,
          failure: failure,
          isLoadingMore: false,
        ),
        (fetched) => state.copyWith(
          status: ViewStatus.success,
          query: query,
          page: append ? state.page.merge(fetched) : fetched,
          isLoadingMore: false,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _loadDepartments() async {
    final result = await _getDepartments();
    if (isClosed) return;
    result.fold(
      (_) {},
      (departments) => emit(state.copyWith(departments: departments)),
    );
  }

  @override
  Future<void> close() {
    _search.dispose();
    return super.close();
  }
}
