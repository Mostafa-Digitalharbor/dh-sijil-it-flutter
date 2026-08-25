import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../maintenance/domain/entities/maintenance_request.dart';
import '../../../maintenance/presentation/cubit/maintenance_cubit.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_status.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/usecases/asset_usecases.dart';

/// What the asset detail screen renders (spec §14).
class AssetDetailState extends ViewState {
  const AssetDetailState({
    super.status,
    super.failure,
    this.asset,
    this.permissions = const AssetPermissions(),
    this.isActing = false,
    this.actionFailure,
    this.wasDeleted = false,
    this.openedRequest,
    this.requests = const <MaintenanceRequest>[],
  });

  final Asset? asset;
  final AssetPermissions permissions;

  /// A status change or delete is in flight. Separate from [ViewStatus.loading]
  /// so the screen keeps rendering the asset while the action runs, instead of
  /// blanking to a skeleton.
  final bool isActing;

  /// A failed *action*, shown as a snackbar over the still-valid detail —
  /// unlike [failure], which means the asset itself could not be loaded and
  /// takes over the screen.
  final Failure? actionFailure;

  /// Set once the asset is gone, so the screen can pop itself exactly once.
  final bool wasDeleted;

  /// The maintenance request just opened, for the confirmation message.
  final MaintenanceRequest? openedRequest;

  /// This asset's maintenance history (spec §14). Empty when the Maintenance
  /// app is absent, which hides the section rather than showing an error.
  final List<MaintenanceRequest> requests;

  /// The requests still open, newest first.
  List<MaintenanceRequest> get openRequests =>
      requests.where((r) => r.isOpen).toList(growable: false);

  /// The requests already closed, newest first.
  List<MaintenanceRequest> get closedRequests =>
      requests.where((r) => r.isDone).toList(growable: false);

  bool get canAssign =>
      (asset?.status.isAssignable ?? false) && permissions.canEdit;

  bool get canReturn =>
      (asset?.status.isReturnable ?? false) && permissions.canEdit;

  AssetDetailState copyWith({
    ViewStatus? status,
    Asset? asset,
    AssetPermissions? permissions,
    bool? isActing,
    Failure? failure,
    Failure? actionFailure,
    bool? wasDeleted,
    MaintenanceRequest? openedRequest,
    List<MaintenanceRequest>? requests,
    bool clearFailure = false,
    bool clearActionFailure = false,
    bool clearOpenedRequest = false,
  }) => AssetDetailState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    asset: asset ?? this.asset,
    permissions: permissions ?? this.permissions,
    isActing: isActing ?? this.isActing,
    actionFailure: clearActionFailure
        ? null
        : (actionFailure ?? this.actionFailure),
    wasDeleted: wasDeleted ?? this.wasDeleted,
    openedRequest: clearOpenedRequest
        ? null
        : (openedRequest ?? this.openedRequest),
    requests: requests ?? this.requests,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    asset,
    permissions.canCreate,
    permissions.canEdit,
    permissions.canDelete,
    isActing,
    actionFailure,
    wasDeleted,
    openedRequest,
    requests,
  ];
}

/// The asset detail screen's ViewModel.
class AssetDetailCubit extends Cubit<AssetDetailState> {
  AssetDetailCubit({
    required GetAsset getAsset,
    required SetLocalAssetStatus setLocalStatus,
    required DeleteAsset deleteAsset,
    required GetAssetListOptions getOptions,
    required CreateMaintenanceRequest createRequest,
    required GetMaintenanceRequests getRequests,
    required AssetRepository repository,
  }) : _getAsset = getAsset,
       _setLocalStatus = setLocalStatus,
       _deleteAsset = deleteAsset,
       _getOptions = getOptions,
       _createRequest = createRequest,
       _getRequests = getRequests,
       super(const AssetDetailState()) {
    // A workflow screen above this one writes through the same repository, so
    // this is how the detail hears about it — `context.go` back to a screen
    // already on the stack rebuilds nothing and re-runs no `create`.
    _subscription = repository.changes.listen((changedId) {
      if (changedId == state.asset?.id) {
        unawaited(load(changedId, refresh: true));
      }
    });
  }

  final GetAsset _getAsset;
  final SetLocalAssetStatus _setLocalStatus;
  final DeleteAsset _deleteAsset;
  final GetAssetListOptions _getOptions;
  final CreateMaintenanceRequest _createRequest;
  final GetMaintenanceRequests _getRequests;

  late final StreamSubscription<int> _subscription;

  Future<void> load(int id, {bool refresh = false}) async {
    emit(
      state.copyWith(
        status: refresh ? ViewStatus.refreshing : ViewStatus.loading,
        clearFailure: true,
      ),
    );

    final result = await _getAsset(id);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: ViewStatus.failure, failure: failure),
        (asset) => state.copyWith(
          status: ViewStatus.success,
          asset: asset,
          clearFailure: true,
        ),
      ),
    );

    if (!refresh) await _loadPermissions();
    await _loadRequests(id);
  }

  /// This asset's maintenance history.
  ///
  /// Failure is swallowed: an instance without the Maintenance app returns a
  /// `modelUnavailable` failure, and the right response to that is a section
  /// that is not there — not an error over an asset that loaded fine.
  Future<void> _loadRequests(int assetId) async {
    final result = await _getRequests(
      MaintenanceQuery(
        filters: MaintenanceFilters(equipmentId: assetId, onlyOpen: false),
      ),
    );
    if (isClosed) return;

    result.fold((_) {}, (page) => emit(state.copyWith(requests: page.items)));
  }

  /// Adopts an asset the caller already has — after an assign or return, the
  /// workflow screen returns the updated record, so re-reading it would be a
  /// round trip for data already in hand.
  void adopt(Asset asset) =>
      emit(state.copyWith(status: ViewStatus.success, asset: asset));

  /// Records one of the three device-local states (spec §6).
  Future<void> setStatus(AssetStatus status) async {
    final asset = state.asset;
    if (asset == null || state.isActing) return;

    emit(state.copyWith(isActing: true, clearActionFailure: true));

    final result = await _setLocalStatus(
      SetLocalStatusParams(assetId: asset.id, status: status),
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(isActing: false, actionFailure: failure),
        (updated) => state.copyWith(isActing: false, asset: updated),
      ),
    );
  }

  Future<void> delete() async {
    final asset = state.asset;
    if (asset == null || state.isActing) return;

    emit(state.copyWith(isActing: true, clearActionFailure: true));

    final result = await _deleteAsset(asset.id);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(isActing: false, actionFailure: failure),
        (_) => state.copyWith(isActing: false, wasDeleted: true),
      ),
    );
  }

  /// Opens a maintenance request against this asset (spec §16).
  ///
  /// Re-reads the asset afterwards rather than assuming: the new request moves
  /// it to Under maintenance through `maintenance_open_count`, and that is a
  /// number only Odoo can tell us.
  Future<void> openMaintenanceRequest(String summary) async {
    final asset = state.asset;
    if (asset == null || state.isActing) return;

    emit(state.copyWith(isActing: true, clearActionFailure: true));

    final result = await _createRequest(
      NewMaintenanceRequest(equipmentId: asset.id, name: summary),
    );
    if (isClosed) return;

    await result.fold(
      (failure) async =>
          emit(state.copyWith(isActing: false, actionFailure: failure)),
      (request) async {
        emit(state.copyWith(isActing: false, openedRequest: request));
        await load(asset.id, refresh: true);
      },
    );
  }

  /// Clears an action failure the user has seen, so it does not resurface on
  /// the next rebuild.
  void acknowledgeActionFailure() =>
      emit(state.copyWith(clearActionFailure: true));

  /// Clears the just-opened request once its confirmation has been shown.
  void acknowledgeOpenedRequest() =>
      emit(state.copyWith(clearOpenedRequest: true));

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }

  /// ACLs decide whether Edit, Delete and the workflow buttons appear at all
  /// (spec §21). A failure here leaves the permissive default, so the user
  /// sees Odoo's own error rather than a silently disabled screen.
  Future<void> _loadPermissions() async {
    final result = await _getOptions();
    if (isClosed) return;
    result.fold(
      (_) {},
      (options) => emit(state.copyWith(permissions: options.permissions)),
    );
  }
}
