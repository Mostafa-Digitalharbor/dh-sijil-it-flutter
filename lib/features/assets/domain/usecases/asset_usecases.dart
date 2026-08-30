import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assignment/domain/entities/assignment.dart';
import '../entities/asset.dart';
import '../entities/asset_draft.dart';
import '../entities/asset_history.dart';
import '../entities/asset_query.dart';
import '../entities/asset_status.dart';
import '../repositories/asset_repository.dart';

/// One page of assets for the list screen.
class GetAssetsPage extends UseCase<PaginatedResult<Asset>, AssetQuery> {
  const GetAssetsPage(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<PaginatedResult<Asset>> call(AssetQuery params) =>
      _repository.getAssets(params);
}

/// A single asset, with everything the detail screen renders.
class GetAsset extends UseCase<Asset, int> {
  const GetAsset(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset> call(int params) => _repository.getAsset(params);
}

/// Turns a scanned QR payload or barcode into an asset (spec §13).
class ResolveScannedCode extends UseCase<Asset?, String> {
  const ResolveScannedCode(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset?> call(String params) =>
      _repository.findByScannedCode(params);
}

class CreateAsset extends UseCase<Asset, AssetDraft> {
  const CreateAsset(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset> call(AssetDraft params) =>
      _repository.createAsset(params);
}

class UpdateAsset extends UseCase<Asset, AssetDraft> {
  const UpdateAsset(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset> call(AssetDraft params) =>
      _repository.updateAsset(params);
}

class DeleteAsset extends UseCase<void, int> {
  const DeleteAsset(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<void> call(int params) => _repository.deleteAsset(params);
}

/// Hands an asset to an employee (spec §7).
class AssignAsset extends UseCase<Asset, AssignmentRequest> {
  const AssignAsset(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset> call(AssignmentRequest params) =>
      _repository.assign(params);
}

/// Takes an asset back from an employee (spec §8).
class ReturnAsset extends UseCase<Asset, ReturnRequest> {
  const ReturnAsset(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset> call(ReturnRequest params) =>
      _repository.unassign(params);
}

/// Records a Reserved / Damaged / Lost state in the local overlay.
class SetLocalAssetStatus extends UseCase<Asset, SetLocalStatusParams> {
  const SetLocalAssetStatus(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<Asset> call(SetLocalStatusParams params) =>
      _repository.setLocalStatus(params.assetId, params.status);
}

class SetLocalStatusParams extends Equatable {
  const SetLocalStatusParams({required this.assetId, required this.status});

  final int assetId;
  final AssetStatus status;

  @override
  List<Object?> get props => [assetId, status];
}

/// Moves a selected set of assets to one department (the bulk action behind
/// multi-select).
class MoveAssetsToDepartment extends UseCase<int, MoveToDepartmentParams> {
  const MoveAssetsToDepartment(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<int> call(MoveToDepartmentParams params) =>
      _repository.moveToDepartment(params.assetIds, params.departmentId);
}

class MoveToDepartmentParams extends Equatable {
  const MoveToDepartmentParams({
    required this.assetIds,
    required this.departmentId,
  });

  final List<int> assetIds;
  final int departmentId;

  @override
  List<Object?> get props => [assetIds, departmentId];
}

/// The filter sheet's option lists plus the user's ACLs, fetched together.
///
/// One use case rather than three, because the list screen needs all of it
/// before it can render its chrome, and three separate awaits is three
/// separate chances to show a half-built filter sheet.
class GetAssetListOptions extends UseCaseWithoutParams<AssetListOptions> {
  const GetAssetListOptions(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<AssetListOptions> call() async {
    final categories = await _repository.categories();
    final manufacturers = await _repository.manufacturers();
    final permissions = await _repository.permissions();

    // Option lists are chrome, not content: if either fails the screen still
    // works, it just offers fewer filters. Only a permissions failure — which
    // decides whether destructive controls appear — is propagated.
    return permissions.map(
      (perms) => AssetListOptions(
        categories: categories.getOrElse(() => const []),
        manufacturers: manufacturers.getOrElse(() => const []),
        permissions: perms,
      ),
    );
  }
}

class AssetListOptions extends Equatable {
  const AssetListOptions({
    this.categories = const <OdooNameRef>[],
    this.manufacturers = const <String>[],
    this.permissions = const AssetPermissions(),
  });

  final List<OdooNameRef> categories;
  final List<String> manufacturers;
  final AssetPermissions permissions;

  @override
  List<Object?> get props => [
    categories,
    manufacturers,
    permissions.canCreate,
    permissions.canEdit,
    permissions.canDelete,
  ];
}

/// Everything that has happened to an asset.
class GetAssetHistory extends UseCase<AssetHistory, int> {
  const GetAssetHistory(this._repository);

  final AssetRepository _repository;

  @override
  ResultFuture<AssetHistory> call(int params) => _repository.history(params);

  /// An older page of the same history.
  ResultFuture<AssetHistory> page(int assetId, {required int offset}) =>
      _repository.history(assetId, offset: offset);
}
