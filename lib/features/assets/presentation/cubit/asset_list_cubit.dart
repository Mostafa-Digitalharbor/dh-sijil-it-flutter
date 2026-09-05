import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
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
class AssetListState extends PaginatedViewState<Asset> {
  const AssetListState({
    super.status,
    super.failure,
    super.page,
    super.isLoadingMore,
    this.query = const AssetQuery(),
    this.categories = const <OdooNameRef>[],
    this.manufacturers = const <String>[],
    this.departments = const <OdooNameRef>[],
    this.permissions = const AssetPermissions(),
    this.isSelecting = false,
    this.selectedIds = const <int>{},
    this.isBulkWorking = false,
    this.bulkMoved,
  });

  final AssetQuery query;

  /// Filter-sheet options, loaded once alongside the first page.
  final List<OdooNameRef> categories;
  final List<String> manufacturers;

  /// Empty on an Odoo without the Employees app, which hides that filter.
  final List<OdooNameRef> departments;

  final AssetPermissions permissions;

  /// Whether the list is in multi-select mode.
  ///
  /// Held separately from [selectedIds] being empty, because "selecting, with
  /// nothing picked yet" is a real state: the rows have to show their
  /// checkboxes and a tap has to select rather than navigate, before anything
  /// has been chosen.
  final bool isSelecting;

  final Set<int> selectedIds;

  /// A bulk write is in flight.
  final bool isBulkWorking;

  /// The last completed bulk move, for the screen to confirm and acknowledge.
  final BulkMoveResult? bulkMoved;

  List<Asset> get assets => items;

  AssetFilters get filters => query.filters;

  /// True when the list is empty *because* of a search or filter, rather than
  /// because the instance has no assets. The two need different empty states:
  /// one offers to clear the filters, the other offers to create an asset.
  bool get isFilteredEmpty => assets.isEmpty && filters.isNotEmpty;

  /// The selected rows, in the order they appear on screen.
  ///
  /// Resolved against the loaded page rather than kept as a second list: a
  /// selection is a set of ids, and holding entities alongside them is how a
  /// row that has since been refreshed gets acted on in its old shape.
  List<Asset> get selectedAssets =>
      assets.where((a) => selectedIds.contains(a.id)).toList(growable: false);

  bool get hasSelection => selectedIds.isNotEmpty;

  /// Whether one more row can be added to the selection.
  bool get canSelectMore =>
      selectedIds.length < AppConstants.bulkSelectionLimit;

  AssetListState copyWith({
    ViewStatus? status,
    PaginatedResult<Asset>? page,
    AssetQuery? query,
    List<OdooNameRef>? categories,
    List<String>? manufacturers,
    List<OdooNameRef>? departments,
    AssetPermissions? permissions,
    bool? isLoadingMore,
    bool? isSelecting,
    Set<int>? selectedIds,
    bool? isBulkWorking,
    BulkMoveResult? bulkMoved,
    Failure? failure,
    bool clearFailure = false,
    bool clearBulkMoved = false,
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
    isSelecting: isSelecting ?? this.isSelecting,
    selectedIds: selectedIds ?? this.selectedIds,
    isBulkWorking: isBulkWorking ?? this.isBulkWorking,
    bulkMoved: clearBulkMoved ? null : (bulkMoved ?? this.bulkMoved),
  );

  @override
  List<Object?> get props => [
    ...super.props,
    query,
    categories,
    manufacturers,
    departments,
    permissions.canCreate,
    permissions.canEdit,
    permissions.canDelete,
    isSelecting,
    selectedIds,
    isBulkWorking,
    bulkMoved,
  ];
}

/// What a finished bulk move is worth telling the user.
///
/// A value rather than a formatted sentence: the wording lives in the ARB
/// files, and a Cubit that built the message would be a Cubit that has to know
/// which language the screen is in.
class BulkMoveResult extends Equatable {
  const BulkMoveResult({required this.count, required this.department});

  final int count;
  final String department;

  @override
  List<Object?> get props => <Object?>[count, department];
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
    required MoveAssetsToDepartment moveToDepartment,
    required AssetRepository repository,
  }) : _getAssets = getAssets,
       _getOptions = getOptions,
       _getDepartments = getDepartments,
       _moveToDepartment = moveToDepartment,
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
  final MoveAssetsToDepartment _moveToDepartment;
  final AssetRepository _repository;

  late final StreamSubscription<int> _subscription;

  final Debouncer _search = Debouncer();

  /// Guards against an out-of-order response overwriting a newer one.
  ///
  /// Typing "mac" fires three queries; if the one for "ma" resolves last, its
  /// results must be discarded rather than shown under the word "mac".
  final RequestTicket _ticket = RequestTicket();

  /// First load, and pull-to-refresh.
  ///
  /// [filters] opens the list already narrowed — how the overdue screen reuses
  /// this ViewModel rather than growing a near-identical one of its own. Given
  /// on the first load only: a refresh keeps whatever the user has since
  /// chosen, which is what makes pull-to-refresh mean "again" rather than
  /// "start over".
  Future<void> load({bool refresh = false, AssetFilters? filters}) async {
    final query = filters == null
        ? state.query
        : state.query.copyWith(filters: filters);

    emit(
      state.copyWith(
        query: query,
        status: refresh ? ViewStatus.refreshing : ViewStatus.loading,
        clearFailure: true,
      ),
    );

    // Options are chrome and only needed once; a refresh keeps what it has.
    if (!refresh || state.categories.isEmpty) {
      unawaited(_loadOptions());
    }

    await _fetch(query.first(), append: false);
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

  // ── Multi-select ─────────────────────────────────────────────────────────

  /// Enters selection mode with [first] already picked.
  ///
  /// Takes a row rather than starting empty because selection is entered by
  /// long-pressing one: arriving in the mode with nothing chosen would throw
  /// away the press that got the user there.
  void startSelection(int first) =>
      emit(state.copyWith(isSelecting: true, selectedIds: <int>{first}));

  /// Leaves selection mode and forgets what was picked.
  void endSelection() => emit(
    state.copyWith(
      isSelecting: false,
      selectedIds: const <int>{},
      clearBulkMoved: true,
    ),
  );

  /// Adds or removes one row.
  ///
  /// Deselecting the last row stays *in* selection mode. Dropping out of it
  /// would mean an accidental double-tap silently turns the next tap into a
  /// navigation, which is the one thing a user in the middle of picking forty
  /// assets does not want.
  void toggleSelection(int id) {
    final next = Set<int>.from(state.selectedIds);
    if (!next.remove(id)) {
      if (!state.canSelectMore) return;
      next.add(id);
    }
    emit(state.copyWith(selectedIds: next));
  }

  /// Selects every row currently loaded — not every row that matches.
  ///
  /// The distinction is the honest one: the app can only act on assets it has
  /// read, and a control that claimed to select two thousand rows would be
  /// promising a write nobody reviewed.
  void selectAllLoaded() => emit(
    state.copyWith(
      isSelecting: true,
      selectedIds: state.assets
          .take(AppConstants.bulkSelectionLimit)
          .map((a) => a.id)
          .toSet(),
    ),
  );

  void clearSelection() => emit(state.copyWith(selectedIds: const <int>{}));

  /// Moves the selection to one department.
  ///
  /// The list is reloaded afterwards rather than patched row by row: a
  /// department move is exactly the change that can drop a row out of an
  /// active department filter, and leaving it on screen would show a list that
  /// contradicts the filter chip above it.
  Future<void> moveSelectionToDepartment(OdooNameRef department) async {
    if (state.isBulkWorking || !state.hasSelection) return;

    final ids = state.selectedIds.toList(growable: false);
    emit(state.copyWith(isBulkWorking: true, clearFailure: true));

    final result = await _moveToDepartment(
      MoveToDepartmentParams(assetIds: ids, departmentId: department.id),
    );
    if (isClosed) return;

    await result.fold(
      (failure) async =>
          emit(state.copyWith(isBulkWorking: false, failure: failure)),
      (count) async {
        emit(
          state.copyWith(
            isBulkWorking: false,
            isSelecting: false,
            selectedIds: const <int>{},
            bulkMoved: BulkMoveResult(
              count: count,
              department: department.name,
            ),
          ),
        );
        await load(refresh: true);
      },
    );
  }

  void acknowledgeBulkMove() => emit(state.copyWith(clearBulkMoved: true));

  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));

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
        // A selection survives a scroll but not a re-query: the rows it names
        // may not be in the next answer, and acting on assets the user can no
        // longer see is how a bulk write surprises somebody.
        isSelecting: false,
        selectedIds: const <int>{},
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
