import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assignment/domain/entities/assignment.dart';
import '../entities/asset.dart';
import '../entities/asset_draft.dart';
import '../entities/asset_history.dart';
import '../entities/asset_query.dart';
import '../entities/asset_status.dart';

/// What the app can do with assets, stated without reference to Odoo.
///
/// The domain owns this contract; `data/` implements it. Every method returns
/// `Either<Failure, T>` so no exception ever reaches a Cubit, and no caller
/// needs a try/catch.
abstract interface class AssetRepository {
  /// One page of assets matching [query].
  ResultFuture<PaginatedResult<Asset>> getAssets(AssetQuery query);

  /// A single asset with its full detail set.
  ResultFuture<Asset> getAsset(int id);

  /// Resolves a scanned payload to an asset (spec §13).
  ///
  /// Handles both `asset://<id>` and a bare serial or barcode. Returns null
  /// when nothing matches, which is a legitimate outcome the scanner renders
  /// as an offer to create the asset — not a failure.
  ResultFuture<Asset?> findByScannedCode(String code);

  ResultFuture<Asset> createAsset(AssetDraft draft);

  ResultFuture<Asset> updateAsset(AssetDraft draft);

  ResultFuture<void> deleteAsset(int id);

  /// Hands an asset to an employee and posts a chatter note (spec §7).
  ResultFuture<Asset> assign(AssignmentRequest request);

  /// Takes an asset back, applying the condition's resulting status (spec §8).
  ResultFuture<Asset> unassign(ReturnRequest request);

  /// Records one of the three states standard Odoo cannot express
  /// (Reserved / Damaged / Lost), mirroring it into the Odoo chatter.
  ///
  /// Passing a derivable status clears the overlay instead of writing one, so
  /// the app never stores what Odoo can already prove.
  ResultFuture<Asset> setLocalStatus(int id, AssetStatus status);

  /// Everything that has happened to an asset, newest first.
  ///
  /// Reads the chatter this app has been writing to since the first release,
  /// so it works retroactively on data already in the customer's database —
  /// no new fields, no migration.
  ResultFuture<AssetHistory> history(int id);

  /// Which operations the signed-in user's ACLs permit, so the UI can hide
  /// actions rather than let them fail (spec §21).
  ResultFuture<AssetPermissions> permissions();

  /// Distinct manufacturer values present on the instance, for the filter
  /// sheet. Discovered, never hardcoded (spec §10).
  ResultFuture<List<String>> manufacturers();

  /// Asset categories from whichever category model backs this instance.
  ResultFuture<List<OdooNameRef>> categories();

  /// Emits the id of every asset this app changes.
  ///
  /// Observer pattern, for the same reason `OdooSessionManager` uses one: the
  /// screen that *makes* a change and the screens that *show* it are different
  /// objects with separate lifetimes. Assigning an asset from the workflow
  /// screen used to leave the detail behind it reading "Unassigned" — the write
  /// had reached Odoo, but nothing told the screen already on the stack.
  ///
  /// Emits after the write succeeds, so a listener that re-reads sees the new
  /// value.
  Stream<int> get changes;

  /// Drops any cached asset pages, so the next read goes to Odoo.
  Future<void> invalidateCache();
}

/// What the signed-in Odoo user is allowed to do with assets.
///
/// Defaults are permissive: when `check_access_rights` cannot be consulted the
/// UI shows the action and lets Odoo's own ACL produce the authoritative
/// error, which is better than hiding a control the user actually has.
class AssetPermissions {
  const AssetPermissions({
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
  });

  const AssetPermissions.readOnly()
    : canCreate = false,
      canEdit = false,
      canDelete = false;

  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
}
