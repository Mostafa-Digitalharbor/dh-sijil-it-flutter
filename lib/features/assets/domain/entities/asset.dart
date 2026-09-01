import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import 'asset_lifecycle.dart';
import 'asset_status.dart';
import 'return_due.dart';
import 'warranty.dart';

/// An IT asset, as the app understands it.
///
/// This is a *domain* entity: it is deliberately independent of both Odoo's
/// field names and the JSON shape of any response. Mappers in
/// `data/mappers/` translate whichever backing model the instance uses
/// (`maintenance.equipment`, `stock.lot`, …) into this one type, so the whole
/// UI is written against a single stable model.
class Asset extends Equatable {
  const Asset({
    required this.id,
    required this.name,
    required this.status,
    this.assetTag,
    this.serialNumber,
    this.category,
    this.manufacturer,
    this.model,
    this.purchaseDate,
    this.purchaseValue,
    this.currencySymbol,
    this.vendor,
    this.warranty = Warranty.unknown,
    this.assignedEmployee,
    this.department,
    this.assignmentDate,
    this.dueBack = ReturnDue.none,
    this.notes,
    this.openMaintenanceCount = 0,
    this.createdAt,
    this.updatedAt,
    this.isStatusLocal = false,
    this.hasPendingSync = false,
  });

  /// The Odoo database id of the backing record. Never rendered to users and
  /// never hardcoded anywhere (spec §10) — it is discovered, not assumed.
  final int id;

  final String name;
  final AssetStatus status;

  /// Human-readable inventory tag, e.g. `DH-LAP-0027`.
  final String? assetTag;

  final String? serialNumber;
  final OdooNameRef? category;
  final String? manufacturer;
  final String? model;
  final DateTime? purchaseDate;
  final double? purchaseValue;
  final String? currencySymbol;
  final OdooNameRef? vendor;
  final Warranty warranty;

  final OdooNameRef? assignedEmployee;
  final OdooNameRef? department;
  final DateTime? assignmentDate;

  /// When this asset is expected back, and whether that date has passed.
  ///
  /// Standard Odoo has no field for it, so — like the three overlay statuses —
  /// it is recorded as a note in the asset's chatter and read back from there
  /// (`AssetDueDateStore`). Which means it is visible to a colleague in the
  /// web client, rather than being a promise one handset made to itself.
  final ReturnDue dueBack;

  final String? notes;
  final int openMaintenanceCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when [status] came from the local overlay rather than from Odoo.
  /// The detail screen shows a small marker so the difference is never hidden
  /// from the user (spec §6).
  final bool isStatusLocal;

  /// True when a change to this asset is still sitting in the outbox.
  ///
  /// Different from [isStatusLocal] in the way that matters: that one is a
  /// state Odoo has no field for and never will, this one is a state Odoo has
  /// simply not been told about yet. The first is permanent and the second is
  /// a promise, so they are marked differently and counted separately.
  final bool hasPendingSync;

  bool get isAssigned => assignedEmployee != null;

  bool get hasOpenMaintenance => openMaintenanceCount > 0;

  /// Past its expected return date and still with somebody.
  bool get isOverdue => dueBack.isOverdue;

  /// How far through its working life this asset is, and what it has cost per
  /// year of it.
  ///
  /// Derived rather than stored, like [subtitle] and unlike [warranty]: it is
  /// a pure function of two fields already on the record, and computing it
  /// here means a row, a detail screen and an export cannot disagree about
  /// what "due for replacement" means.
  ///
  /// Reads the clock, so it is a getter rather than a field — a screen left
  /// open across midnight on the last day of a month should not go on saying
  /// the asset has a month left.
  AssetLifecycle get lifecycle => AssetLifecycle.evaluate(
    purchaseDate: purchaseDate,
    purchaseValue: purchaseValue,
  );

  /// Payload encoded into the asset's QR code (spec §12).
  ///
  /// Carries only the internal identifier — never a URL, credential, database
  /// name or session token.
  String get qrPayload => '${AppConstants.qrScheme}://$id';

  /// What the list row shows under the asset name: tag, else serial, else
  /// model.
  String? get subtitle => assetTag ?? serialNumber ?? model;

  Asset copyWith({
    String? name,
    AssetStatus? status,
    String? assetTag,
    String? serialNumber,
    OdooNameRef? category,
    String? manufacturer,
    String? model,
    DateTime? purchaseDate,
    double? purchaseValue,
    OdooNameRef? vendor,
    Warranty? warranty,
    OdooNameRef? assignedEmployee,
    OdooNameRef? department,
    DateTime? assignmentDate,
    ReturnDue? dueBack,
    String? notes,
    int? openMaintenanceCount,
    bool? isStatusLocal,
    bool? hasPendingSync,
    bool clearAssignment = false,
  }) {
    return Asset(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      assetTag: assetTag ?? this.assetTag,
      serialNumber: serialNumber ?? this.serialNumber,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseValue: purchaseValue ?? this.purchaseValue,
      currencySymbol: currencySymbol,
      vendor: vendor ?? this.vendor,
      warranty: warranty ?? this.warranty,
      assignedEmployee: clearAssignment
          ? null
          : (assignedEmployee ?? this.assignedEmployee),
      department: clearAssignment ? null : (department ?? this.department),
      assignmentDate: clearAssignment
          ? null
          : (assignmentDate ?? this.assignmentDate),
      // A return ends the obligation as well as the assignment: an asset back
      // on the shelf is not late for anything, and leaving the date attached
      // is how a returned laptop stays on the overdue list.
      dueBack: clearAssignment ? ReturnDue.none : (dueBack ?? this.dueBack),
      notes: notes ?? this.notes,
      openMaintenanceCount: openMaintenanceCount ?? this.openMaintenanceCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isStatusLocal: isStatusLocal ?? this.isStatusLocal,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    status,
    assetTag,
    serialNumber,
    category,
    manufacturer,
    model,
    purchaseDate,
    purchaseValue,
    vendor,
    warranty,
    assignedEmployee,
    department,
    assignmentDate,
    dueBack,
    notes,
    openMaintenanceCount,
    isStatusLocal,
    hasPendingSync,
  ];
}
