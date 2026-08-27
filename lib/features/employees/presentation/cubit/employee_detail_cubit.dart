import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/entities/asset_query.dart';
import '../../../assets/domain/usecases/asset_usecases.dart';
import '../../domain/entities/employee.dart';
import '../../domain/usecases/employee_usecases.dart';

/// What the employee profile renders (spec §9).
class EmployeeDetailState extends ViewState {
  const EmployeeDetailState({
    super.status,
    super.failure,
    this.employee,
    this.assets = const <Asset>[],
    this.isLoadingAssets = false,
    this.hasMoreAssets = false,
  });

  final Employee? employee;

  /// The assets this person currently holds. Loaded after the profile, so the
  /// header can render while the list is still arriving.
  final List<Asset> assets;

  final bool isLoadingAssets;

  /// Whether Odoo holds more assets for this person than the one page read
  /// here. Drives the "see all" link through to the paginated list.
  ///
  /// The page is capped rather than paged on purpose: the two summary tiles
  /// beside it — in service, warranty due — are counted from the assets that
  /// were actually loaded, so shrinking this read to a short preview would
  /// quietly make both of them wrong.
  final bool hasMoreAssets;

  int get heldCount => employee?.assetCount ?? assets.length;

  /// How many of the held assets are actually usable right now — the figure
  /// the profile shows next to the total, because "4 held, 1 in service" is
  /// the sentence an IT manager needs.
  int get inServiceCount => assets.where((a) => a.status.isActive).length;

  /// Held assets whose warranty needs attention, for the third summary tile.
  int get warrantyDueCount =>
      assets.where((a) => a.warranty.state.needsAttention).length;

  EmployeeDetailState copyWith({
    ViewStatus? status,
    Employee? employee,
    List<Asset>? assets,
    bool? isLoadingAssets,
    bool? hasMoreAssets,
    Failure? failure,
    bool clearFailure = false,
  }) => EmployeeDetailState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    employee: employee ?? this.employee,
    assets: assets ?? this.assets,
    isLoadingAssets: isLoadingAssets ?? this.isLoadingAssets,
    hasMoreAssets: hasMoreAssets ?? this.hasMoreAssets,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    hasMoreAssets,
    employee,
    assets,
    isLoadingAssets,
  ];
}

/// The employee profile's ViewModel.
///
/// Reuses [GetAssetsPage] with an `employeeId` filter rather than owning a
/// second way to read assets — the two screens then agree by construction
/// about what "assigned to this person" means.
class EmployeeDetailCubit extends Cubit<EmployeeDetailState> {
  EmployeeDetailCubit({
    required GetEmployee getEmployee,
    required GetAssetsPage getAssets,
  }) : _getEmployee = getEmployee,
       _getAssets = getAssets,
       super(const EmployeeDetailState());

  final GetEmployee _getEmployee;
  final GetAssetsPage _getAssets;

  Future<void> load(int id, {bool refresh = false}) async {
    emit(
      state.copyWith(
        status: refresh ? ViewStatus.refreshing : ViewStatus.loading,
        clearFailure: true,
      ),
    );

    final result = await _getEmployee(id);
    if (isClosed) return;

    final failed = result.fold(
      (failure) {
        emit(state.copyWith(status: ViewStatus.failure, failure: failure));
        return true;
      },
      (employee) {
        emit(
          state.copyWith(
            status: ViewStatus.success,
            employee: employee,
            clearFailure: true,
          ),
        );
        return false;
      },
    );

    if (!failed) await _loadAssets(id);
  }

  Future<void> _loadAssets(int employeeId) async {
    emit(state.copyWith(isLoadingAssets: true));

    final result = await _getAssets(
      AssetQuery(
        filters: AssetFilters(employeeId: employeeId, includeRetired: true),
        page: const PageRequest(limit: AppConstants.employeeAssetsPageSize),
      ),
    );
    if (isClosed) return;

    // A failure here leaves the profile intact and the list empty: the
    // person's contact details are still worth showing, and the empty state
    // reads the same as genuinely holding nothing.
    result.fold(
      (_) => emit(state.copyWith(isLoadingAssets: false)),
      (page) => emit(
        state.copyWith(
          isLoadingAssets: false,
          assets: page.items,
          hasMoreAssets: page.hasMore,
        ),
      ),
    );
  }
}
