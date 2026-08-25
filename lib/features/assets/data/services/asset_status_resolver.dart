import '../../../../core/constants/odoo_models.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_value.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/asset_status.dart';

/// Decides an asset's status, in a fixed precedence order
/// (docs/ARCHITECTURE.md §6).
///
/// Chain of responsibility: three links, each consulted only if the one above
/// it produced nothing.
///
/// ```
/// 1. a real Odoo field   → Odoo is the sole source of truth, stop here
/// 2. derived from stock fields (scrap / maintenance / employee)
/// 3. the device-local overlay, for Reserved / Damaged / Lost only
/// ```
///
/// The order is the whole design. Putting the overlay last means a stale
/// "Damaged" note on this device can never hide the fact that Odoo now has the
/// asset assigned to someone — the app would otherwise quietly disagree with
/// the Odoo web client, which is the one thing a companion app must not do.
class AssetStatusResolver {
  const AssetStatusResolver(this._capabilities);

  final OdooCapabilityService _capabilities;

  /// Whether this instance carries a real status field. Probed once and
  /// memoised by the capability service, so calling it per row is cheap.
  Future<bool> hasNativeStatusField(String model) =>
      _capabilities.fieldExists(model, AssetStatusField.name);

  /// Resolves one record.
  ///
  /// [overlay] is the device-local value for this asset, already looked up by
  /// the caller — the resolver stays pure and synchronous once the two async
  /// facts ([nativeField] and [overlay]) are in hand, which is what makes it
  /// trivially unit-testable.
  ResolvedStatus resolve({
    required OdooRecord record,
    required bool hasNativeField,
    AssetStatus? overlay,
  }) {
    // 1 — a real Odoo field wins outright.
    if (hasNativeField) {
      final native = AssetStatus.fromName(
        record.readString(AssetStatusField.name),
      );
      if (native != null) {
        return ResolvedStatus(status: native, isLocal: false);
      }
    }

    // 2 — anything Odoo can prove from its own standard fields.
    final derived = _derive(record);

    // The three derivable *facts* outrank any overlay: a scrapped asset is
    // retired, an asset with an open request is under maintenance, and an
    // asset held by an employee is assigned, whatever this device believes.
    if (derived != AssetStatus.available) {
      return ResolvedStatus(status: derived, isLocal: false);
    }

    // 3 — otherwise the overlay may refine "available" into one of the three
    // states Odoo has no field for.
    if (overlay != null && overlay.isLocalOnly) {
      return ResolvedStatus(status: overlay, isLocal: true);
    }

    return const ResolvedStatus(status: AssetStatus.available, isLocal: false);
  }

  /// The derivation table from docs/ARCHITECTURE.md §6, in precedence order.
  static AssetStatus _derive(OdooRecord record) {
    if (record.readDate(EquipmentFields.scrapDate) != null) {
      return AssetStatus.retired;
    }
    if (record.readCount(EquipmentFields.maintenanceOpenCount) > 0) {
      return AssetStatus.underMaintenance;
    }
    if (record.readRef(EquipmentFields.employeeId) != null) {
      return AssetStatus.assigned;
    }
    return AssetStatus.available;
  }
}

/// A status together with where it came from.
///
/// The origin is not a detail: the UI marks a locally-kept status with a
/// device icon so a user is never misled into thinking a colleague can see it
/// in Odoo.
class ResolvedStatus {
  const ResolvedStatus({required this.status, required this.isLocal});

  final AssetStatus status;
  final bool isLocal;
}
