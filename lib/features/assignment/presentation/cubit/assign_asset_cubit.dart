import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/cubit/async_guards.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/usecases/asset_usecases.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../../employees/domain/usecases/employee_usecases.dart';
import '../../domain/entities/assignment.dart';

/// What the assign-asset screen renders (spec §7).
class AssignAssetState extends ViewState {
  const AssignAssetState({
    super.status,
    super.failure,
    this.asset,
    this.candidates = const <Employee>[],
    this.selected,
    this.assignedOn,
    this.notes,
    this.isSearching = false,
    this.isSubmitting = false,
    this.assigned,
  });

  final Asset? asset;

  /// Typeahead results for the employee picker.
  final List<Employee> candidates;

  final Employee? selected;

  /// Defaults to today, which is what the overwhelming majority of handovers
  /// are; the field stays editable for a handover being recorded late.
  final DateTime? assignedOn;

  final String? notes;

  final bool isSearching;
  final bool isSubmitting;

  /// The updated asset, set once the assignment succeeds.
  final Asset? assigned;

  bool get canSubmit => selected != null && assignedOn != null && !isSubmitting;

  AssignAssetState copyWith({
    ViewStatus? status,
    Asset? asset,
    List<Employee>? candidates,
    Employee? selected,
    DateTime? assignedOn,
    String? notes,
    bool? isSearching,
    bool? isSubmitting,
    Asset? assigned,
    Failure? failure,
    bool clearFailure = false,
  }) => AssignAssetState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    asset: asset ?? this.asset,
    candidates: candidates ?? this.candidates,
    selected: selected ?? this.selected,
    assignedOn: assignedOn ?? this.assignedOn,
    notes: notes ?? this.notes,
    isSearching: isSearching ?? this.isSearching,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    assigned: assigned ?? this.assigned,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    asset,
    candidates,
    selected,
    assignedOn,
    notes,
    isSearching,
    isSubmitting,
    assigned,
  ];
}

/// The assign-asset workflow's ViewModel.
class AssignAssetCubit extends Cubit<AssignAssetState> {
  AssignAssetCubit({
    required GetAsset getAsset,
    required SearchEmployees searchEmployees,
    required AssignAsset assignAsset,
    DateTime Function()? clock,
  }) : _getAsset = getAsset,
       _searchEmployees = searchEmployees,
       _assignAsset = assignAsset,
       _now = clock ?? DateTime.now,
       super(const AssignAssetState());

  final GetAsset _getAsset;
  final SearchEmployees _searchEmployees;
  final AssignAsset _assignAsset;

  /// Injectable so a test can pin "today" instead of racing the clock.
  final DateTime Function() _now;

  final Debouncer _search = Debouncer();
  final RequestTicket _ticket = RequestTicket();

  Future<void> start(int assetId) async {
    emit(
      AssignAssetState(status: ViewStatus.loading, assignedOn: _startOfToday()),
    );

    final result = await _getAsset(assetId);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(status: ViewStatus.failure, failure: failure)),
      (asset) => emit(state.copyWith(status: ViewStatus.success, asset: asset)),
    );

    // An empty query returns the first page of employees, so the picker opens
    // with something to choose rather than an empty box.
    searchEmployees('');
  }

  void searchEmployees(String term) => _search.run(() => _runSearch(term));

  Future<void> _runSearch(String term) async {
    final ticket = _ticket.take();
    emit(state.copyWith(isSearching: true));

    final result = await _searchEmployees(term);
    if (_ticket.isStale(ticket) || isClosed) return;

    result.fold(
      // A failed lookup leaves the previous candidates alone: an empty list
      // would read as "nobody by that name", which is a different fact.
      (_) => emit(state.copyWith(isSearching: false)),
      (employees) =>
          emit(state.copyWith(isSearching: false, candidates: employees)),
    );
  }

  void selectEmployee(Employee employee) =>
      emit(state.copyWith(selected: employee));

  void setDate(DateTime date) => emit(state.copyWith(assignedOn: date));

  void setNotes(String notes) => emit(state.copyWith(notes: notes));

  Future<void> submit() async {
    final asset = state.asset;
    final employee = state.selected;
    final date = state.assignedOn;

    if (asset == null || employee == null || date == null) return;
    if (state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _assignAsset(
      AssignmentRequest(
        assetId: asset.id,
        employeeId: employee.id,
        employeeName: employee.name,
        assignedOn: date,
        notes: state.notes,
      ),
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (updated) => state.copyWith(isSubmitting: false, assigned: updated),
      ),
    );
  }

  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));

  /// Midnight today — a date field must not carry a time, or "today" stops
  /// being equal to itself an hour later.
  DateTime _startOfToday() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Future<void> close() {
    _search.dispose();
    return super.close();
  }
}
