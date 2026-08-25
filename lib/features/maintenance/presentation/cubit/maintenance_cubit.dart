import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../../shared/cubit/async_guards.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/maintenance_request.dart';
import '../../domain/repositories/maintenance_repository.dart';

/// One page of maintenance requests.
class GetMaintenanceRequests
    extends UseCase<PaginatedResult<MaintenanceRequest>, MaintenanceQuery> {
  const GetMaintenanceRequests(this._repository);

  final MaintenanceRepository _repository;

  @override
  ResultFuture<PaginatedResult<MaintenanceRequest>> call(
    MaintenanceQuery params,
  ) => _repository.getRequests(filters: params.filters, page: params.page);
}

class GetMaintenanceRequest extends UseCase<MaintenanceRequest, int> {
  const GetMaintenanceRequest(this._repository);

  final MaintenanceRepository _repository;

  @override
  ResultFuture<MaintenanceRequest> call(int params) =>
      _repository.getRequest(params);
}

/// Opens a request against an asset (spec §16).
class CreateMaintenanceRequest
    extends UseCase<MaintenanceRequest, NewMaintenanceRequest> {
  const CreateMaintenanceRequest(this._repository);

  final MaintenanceRepository _repository;

  @override
  ResultFuture<MaintenanceRequest> call(NewMaintenanceRequest params) =>
      _repository.createRequest(
        equipmentId: params.equipmentId,
        name: params.name,
        type: params.type,
        priority: params.priority,
        description: params.description,
        scheduledFor: params.scheduledFor,
      );
}

class NewMaintenanceRequest extends Equatable {
  const NewMaintenanceRequest({
    required this.equipmentId,
    required this.name,
    this.type = MaintenanceType.corrective,
    this.priority = MaintenancePriority.normal,
    this.description,
    this.scheduledFor,
  });

  final int equipmentId;
  final String name;
  final MaintenanceType type;
  final MaintenancePriority priority;
  final String? description;
  final DateTime? scheduledFor;

  @override
  List<Object?> get props => [
    equipmentId,
    name,
    type,
    priority,
    description,
    scheduledFor,
  ];
}

class MaintenanceQuery extends Equatable {
  const MaintenanceQuery({
    this.filters = const MaintenanceFilters(),
    this.page = const PageRequest(),
  });

  final MaintenanceFilters filters;
  final PageRequest page;

  MaintenanceQuery next() =>
      MaintenanceQuery(filters: filters, page: page.next());

  MaintenanceQuery first() =>
      MaintenanceQuery(filters: filters, page: page.first());

  MaintenanceQuery copyWith({MaintenanceFilters? filters, PageRequest? page}) =>
      MaintenanceQuery(
        filters: filters ?? this.filters,
        page: page ?? this.page,
      );

  @override
  List<Object?> get props => [filters, page];
}

/// What the maintenance list renders.
class MaintenanceListState extends ViewState {
  const MaintenanceListState({
    super.status,
    super.failure,
    this.page = const PaginatedResult<MaintenanceRequest>.empty(),
    this.query = const MaintenanceQuery(),
    this.isLoadingMore = false,
  });

  final PaginatedResult<MaintenanceRequest> page;
  final MaintenanceQuery query;
  final bool isLoadingMore;

  List<MaintenanceRequest> get requests => page.items;

  bool get hasMore => page.hasMore;

  bool get onlyOpen => query.filters.onlyOpen;

  MaintenanceListState copyWith({
    ViewStatus? status,
    PaginatedResult<MaintenanceRequest>? page,
    MaintenanceQuery? query,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) => MaintenanceListState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    page: page ?? this.page,
    query: query ?? this.query,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [...super.props, page, query, isLoadingMore];
}

/// The maintenance list's ViewModel.
class MaintenanceListCubit extends Cubit<MaintenanceListState> {
  MaintenanceListCubit(this._getRequests) : super(const MaintenanceListState());

  final GetMaintenanceRequests _getRequests;

  final Debouncer _search = Debouncer();
  final RequestTicket _ticket = RequestTicket();

  Future<void> load({bool refresh = false}) async {
    emit(
      state.copyWith(
        status: refresh ? ViewStatus.refreshing : ViewStatus.loading,
        clearFailure: true,
      ),
    );
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

  void showOnlyOpen({required bool value}) {
    if (value == state.query.filters.onlyOpen) return;
    _applyQuery(
      state.query.copyWith(
        filters: state.query.filters.copyWith(onlyOpen: value),
      ),
    );
  }

  void filterByType(MaintenanceType? type) {
    if (type == state.query.filters.type) return;
    _applyQuery(
      state.query.copyWith(
        filters: type == null
            ? state.query.filters.copyWith(clearType: true)
            : state.query.filters.copyWith(type: type),
      ),
    );
  }

  void _applyQuery(MaintenanceQuery query) {
    emit(
      state.copyWith(
        query: query,
        status: ViewStatus.loading,
        clearFailure: true,
      ),
    );
    unawaited(_fetch(query.first(), append: false));
  }

  Future<void> _fetch(MaintenanceQuery query, {required bool append}) async {
    final ticket = _ticket.take();
    final result = await _getRequests(query);
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

  @override
  Future<void> close() {
    _search.dispose();
    return super.close();
  }
}

/// The maintenance detail screen's ViewModel.
class MaintenanceDetailCubit
    extends Cubit<SimpleViewState<MaintenanceRequest>> {
  MaintenanceDetailCubit(this._getRequest)
    : super(const SimpleViewState<MaintenanceRequest>());

  final GetMaintenanceRequest _getRequest;

  Future<void> load(int id, {bool refresh = false}) async {
    emit(refresh ? state.refreshing() : state.loading());

    final result = await _getRequest(id);
    if (isClosed) return;

    emit(result.fold(state.failed, state.success));
  }
}
