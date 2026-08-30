import '../../../../core/constants/odoo_models.dart';
import '../../../../core/network/odoo/odoo_value.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_draft.dart';
import '../../domain/entities/return_due.dart';
import '../../domain/entities/warranty.dart';
import '../services/asset_status_resolver.dart';

/// Translates between `maintenance.equipment` records and the [Asset] domain
/// entity (Adapter pattern).
///
/// The whole point of this class existing is that Odoo renames fields between
/// versions and different instances expose different subsets. Every field
/// name appears exactly once, here, so a rename is one edit rather than a
/// search across the UI.
abstract final class AssetMapper {
  /// Odoo record → domain entity.
  ///
  /// [status] arrives already resolved, because deciding it needs the local
  /// overlay and a capability probe — both async, and neither the mapper's
  /// business. [dueBackOn] arrives the same way and for the same reason: it
  /// lives in a chatter note, not in a column of this record.
  static Asset toEntity(
    OdooRecord record, {
    required ResolvedStatus status,
    DateTime? dueBackOn,
    DateTime? now,
    bool hasPendingSync = false,
  }) {
    final warrantyEnd = record.readDate(EquipmentFields.warrantyDate);
    final holder = record.readRef(EquipmentFields.employeeId);

    return Asset(
      id: record.recordId,
      name: record.readString(EquipmentFields.name) ?? '',
      status: status.status,
      isStatusLocal: status.isLocal,
      hasPendingSync: hasPendingSync,

      // `partner_ref` is Odoo's vendor reference for the equipment. It is the
      // closest standard field to an inventory tag, and falling back to the
      // serial keeps the list subtitle populated on instances that leave it
      // blank.
      assetTag: record.readString(EquipmentFields.partnerRef),
      serialNumber: record.readString(EquipmentFields.serialNo),
      model: record.readString(EquipmentFields.model),
      category: record.readRef(EquipmentFields.categoryId),

      // Standard Odoo has no manufacturer field on equipment; the vendor
      // partner is what customers actually populate, so it doubles as one.
      manufacturer: record.readRef(EquipmentFields.partnerId)?.name,
      vendor: record.readRef(EquipmentFields.partnerId),

      purchaseDate: record.readDate(EquipmentFields.effectiveDate),
      purchaseValue: record.readDouble(EquipmentFields.cost),

      warranty: Warranty.evaluate(
        startDate: record.readDate(EquipmentFields.effectiveDate),
        endDate: warrantyEnd,
        now: now,
      ),

      assignedEmployee: holder,
      department: record.readRef(EquipmentFields.departmentId),
      assignmentDate: record.readDate(EquipmentFields.assignDate),

      // Evaluated against the holder, not against the date alone. The note
      // recording a due date stays in the chatter after the asset comes back,
      // and an asset on the shelf cannot be late for anything.
      dueBack: ReturnDue.evaluate(
        date: dueBackOn,
        isAssigned: holder != null,
        now: now,
      ),

      notes: record.readHtmlAsText(EquipmentFields.note),
      openMaintenanceCount: record.readCount(
        EquipmentFields.maintenanceOpenCount,
      ),

      createdAt: record.readDate(EquipmentFields.createDate),
      updatedAt: record.readDate(EquipmentFields.writeDate),
    );
  }

  /// Domain draft → an Odoo `create`/`write` payload.
  ///
  /// Only fields the instance actually has are included: [supported] comes
  /// from `OdooCapabilityService.supportedFields`, so a trimmed or older Odoo
  /// never receives an invalid-field write (spec §17).
  static Map<String, dynamic> toWriteValues(
    AssetDraft draft, {
    required Set<String> supported,
    Set<String> required = const <String>{},
  }) {
    final values = <String, dynamic>{};

    void put(String field, Object value) {
      if (!supported.contains(field)) return;

      // A required field cannot be *cleared*. Odoo's "empty" is the boolean
      // `false`, and sending it for a mandatory field overrides the server-side
      // default and then fails Odoo's own constraint — stock Odoo 19 marks
      // `effective_date` required, so a new asset with no purchase date would
      // be rejected outright. Omitting the key lets the default apply on
      // create and leaves the stored value alone on update.
      if (value == false && required.contains(field)) return;

      values[field] = value;
    }

    put(EquipmentFields.name, OdooWrite.text(draft.name));
    put(EquipmentFields.serialNo, OdooWrite.text(draft.serialNumber));
    put(EquipmentFields.model, OdooWrite.text(draft.model));
    put(EquipmentFields.partnerRef, OdooWrite.text(draft.assetTag));
    put(EquipmentFields.categoryId, OdooWrite.ref(draft.categoryId));
    put(EquipmentFields.partnerId, OdooWrite.ref(draft.vendorId));
    put(EquipmentFields.effectiveDate, OdooWrite.date(draft.purchaseDate));
    put(EquipmentFields.warrantyDate, OdooWrite.date(draft.warrantyEnd));
    put(EquipmentFields.note, OdooWrite.html(draft.notes));

    // `cost` is a float, and Odoo rejects `false` for one — an unpriced asset
    // is zero, not "unset".
    put(EquipmentFields.cost, draft.purchaseValue ?? 0);

    return values;
  }

  /// The write payload for handing an asset to an employee (spec §7).
  static Map<String, dynamic> assignmentValues({
    required int employeeId,
    required DateTime assignedOn,
    required Set<String> supported,
  }) {
    final values = <String, dynamic>{};

    if (supported.contains(EquipmentFields.employeeId)) {
      values[EquipmentFields.employeeId] = employeeId;
    }
    if (supported.contains(EquipmentFields.assignDate)) {
      values[EquipmentFields.assignDate] = OdooWrite.date(assignedOn);
    }
    // Odoo's own equipment form keys the visibility of `employee_id` off this
    // selection; leaving it alone would assign the asset in the database but
    // leave the web client showing an empty "Used By".
    if (supported.contains(EquipmentFields.assignTo)) {
      values[EquipmentFields.assignTo] = assignToEmployee;
    }

    return values;
  }

  /// The write payload for taking an asset back (spec §8).
  static Map<String, dynamic> returnValues({
    required Set<String> supported,
    Set<String> required = const <String>{},
  }) {
    final values = <String, dynamic>{};

    // Same rule as [toWriteValues]: a required field is left alone rather than
    // cleared, so an instance that mandates an assignment date does not reject
    // the return that would have emptied it.
    if (supported.contains(EquipmentFields.employeeId) &&
        !required.contains(EquipmentFields.employeeId)) {
      values[EquipmentFields.employeeId] = false;
    }
    if (supported.contains(EquipmentFields.assignDate) &&
        !required.contains(EquipmentFields.assignDate)) {
      values[EquipmentFields.assignDate] = false;
    }
    if (supported.contains(EquipmentFields.assignTo)) {
      values[EquipmentFields.assignTo] = assignToOther;
    }

    return values;
  }

  /// `equipment_assign_to` selection values, as shipped by standard Odoo.
  ///
  /// The app only ever writes [assignToEmployee] and [assignToOther] —
  /// assigning to a department is an Odoo-side choice this product does not
  /// offer. [assignToDepartment] is named anyway so the set on the record is
  /// complete: reading a value back and finding no constant for it is how a
  /// third state gets mistaken for corrupt data.
  static const String assignToEmployee = 'employee';
  static const String assignToDepartment = 'department';
  static const String assignToOther = 'other';
}
