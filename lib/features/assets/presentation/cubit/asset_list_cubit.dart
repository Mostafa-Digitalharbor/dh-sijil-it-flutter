import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../shared/cubit/async_guards.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../employees/domain/usecases/employee_usecases.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_query.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/usecases/asset_usecases.dart';

/// What the assets screen renders (spec §11).
class AssetListState extends ViewState {
  const AssetListState({
    super.status,
    super.failure,
    this.page = const PaginatedResult<Asset>.empty(),
    this.query = const AssetQuery(),
    this.categories = const <OdooNameRef>[],
    this.manufacturers = const <String>[],
    this.departments = const <OdooNameRef>[],
    this.permissions = const AssetPermissions(),
    this.isLoadingMore = false,
  });

  final PaginatedResult<Asset> page;
  final AssetQuery query;

  /// Filter-sheet options, loaded once alongside the first page.
  final List<OdooNameRef> categories;
  final List<String> manufacturers;

  /// Empty on an Odoo without the Employees app, which hides that filter.
  final List<OdooNameRef> departments;

  final AssetPermissions permissions;

  /// A next-page request is in flight. Distinct from [ViewStatus.refreshing],
  /// which replaces the list rather than extending it.
  final bool isLoadingMore;

  List<Asset> get assets => page.items;

  AssetFilters get filters => query.filters;

  bool get hasMore => page.hasMore;

  /// True when the list is empty *because* of a search or filter, rather than
  /// because the instance has no assets. The two need different empty states:
  /// one offers to clear the filters, the other offers to create an asset.
  bool get isFilteredEmpty => assets.isEmpty && filters.isNotEmpty;

  AssetListState copyWith({
    ViewStatus? status,
    PaginatedResult<Asset>? page,
    AssetQuery? query,
    List<OdooNameRef>? categories,
    List<String>? manufacturers,
    List<OdooNameRef>? departments,
    AssetPermissions? permissions,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) => AssetListState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    page: page ?? this.page,
    query: query ?? this.query,
    categories: categories ?? this.categories,
    manufacturers: manufacturers ?? this.manufacturers,
    departments: departments ?? this.departments,
    permissions: permissions ?? this.permissions,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    page,
    query,
    categories,
    manufacturers,
    departments,
    permissions.canCreate,
    permissions.canEdit,
    permissions.canDelete,
    isLoadingMore,
  ];
}

/// The assets screen's ViewModel.
///
/// Owns search debouncing, filtering, sorting and infinite scroll. Holds no
/// `BuildContext` and no widget — every one of its behaviours is testable with
/// `bloc_test` alone.
class AssetListCubit extends Cubit<AssetListState> {
  AssetListCubit({
    required GetAssetsPage getAssets,
    required GetAssetListOptions getOptions,
    required GetDepartments getDepartments,
    required AssetRepository repository,
  }) : _getAssets = getAssets,
       _getOptions = getOptions,
       _getDepartments = getDepartments,
       _repository = repository,
       super(const AssetListState()) {
    // A row the user changed on the detail screen must not keep showing its old
    // status when they come back to the list.
    _subscription = repository.changes.listen(_refreshChangedRow);
  }

  final GetAssetsPage _getAssets;
  final GetAssetListOptions _getOptions;

  /// Borrowed from the employees feature rather than duplicated: a department
  /// is the same record whichever screen filters by it.
  final GetDepartments _getDepartments;
  final AssetRepository _repository;

  late final StreamSubscription<int> _subscription;

  final Debouncer _search = Debouncer();

  /// Guards against an out-of-order response overwriting a newer one.
  ///
  /// Typing "mac" fires three queries; if the one for "ma" resolves last, its
  /// results must be discarded rather than shown under the word "mac".
  final RequestTicket _ticket = RequestTicket();

  /// First load, and pull-to-refresh.
  Future<void> load({bool refresh = false}) async {
    emit(
      state.copyWith(
        status: refresh ? ViewStatus.refreshing : ViewStatus.loading,
        clearFailure: true,
      ),
    );

    // Options are chrome and only needed once; a refresh keeps what it has.
    if (!refresh || state.categories.isEmpty) {
      unawaited(_loadOptions());
    }

    await _fetch(state.query.first(), append: false);
  }

  /// Loads the next page for infinite scroll.
  ///
  /// Ignored while a page is already in flight or the server is exhausted, so
  /// a fast scroll cannot queue five identical requests.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status.isBusy) return;

    emit(state.copyWith(isLoadingMore: true));
    await _fetch(state.query.next(), append: true);
  }

  /// Free-text search, debounced so a typed word is one request, not five
  /// (spec §11).
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

  void applyFilters(AssetFilters filters) {
    if (filters == state.query.filters) return;
    _applyQuery(state.query.copyWith(filters: filters));
  }

  void setSort(AssetSort sort) {
    if (sort == state.query.sort) return;
    _applyQuery(state.query.copyWith(sort: sort));
  }

  void clearFilters() => applyFilters(state.query.filters.cleared());

  /// Replaces one asset in place after a detail-screen action.
  ///
  /// Cheaper and less jarring than reloading the whole list: the row the user
  /// just acted on updates without the scroll position resetting.
  void replaceAsset(Asset updated) {
    final index = state.assets.indexWhere((a) => a.id == updated.id);
    if (index < 0) return;

    final items = [...state.assets]..[index] = updated;
    emit(
      state.copyWith(
        page: PaginatedResult<Asset>(
          items: items,
          totalCount: state.page.totalCount,
          request: state.page.request,
          scannedCount: state.page.scannedCount,
        ),
      ),
    );
  }

  /// Re-reads one row after it changed elsewhere.
  ///
  /// One record rather than the whole page: the user is usually returning to a
  /// list they have scrolled, and refetching every page would lose their place
  /// to update a single chip. A row that has since dropped out of the filter is
  /// left where it is until the next real refresh — removing it under the
  /// user's finger is more startling than a stale position in a list.
  Future<void> _refreshChangedRow(int id) async {
    if (isClosed) return;
    if (!state.assets.any((a) => a.id == id)) return;

    final result = await _repository.getAsset(id);
    if (isClosed) return;

    result.fold((_) {}, replaceAsset);
  }

  void _applyQuery(AssetQuery query) {
    emit(
      state.copyWith(
        query: query,
        status: ViewStatus.loading,
        clearFailure: true,
      ),
    );
    unawaited(_fetch(query.first(), append: false));
  }

  Future<void> _fetch(AssetQuery query, {required bool append}) async {
    final ticket = _ticket.take();
    final result = await _getAssets(query);

    // A newer request has already been issued; this answer is stale.
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

  /// Loads categories, manufacturers and ACLs.
  ///
  /// Failure is swallowed on purpose: these populate the filter sheet and hide
  /// the create button. Losing them makes the screen less capable, not broken,
  /// and the list itself has its own error path.
  Future<void> _loadOptions() async {
    final result = await _getOptions();
    if (isClosed) return;

    result.fold((_) {}, (options) {
      emit(
        state.copyWith(
          categories: options.categories,
          manufacturers: options.manufacturers,
          permissions: options.permissions,
        ),
      );
    });

    final departments = await _getDepartments();
    if (isClosed) return;
    departments.fold((_) {}, (rows) => emit(state.copyWith(departments: rows)));
  }

  @override
  Future<void> close() {
    _search.dispose();
    _subscription.cancel();
    return super.close();
  }
}
