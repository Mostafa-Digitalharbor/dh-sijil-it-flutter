import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_object_service.dart';

/// Corrective or preventive, as Odoo's `maintenance_type` selection defines it.
enum MaintenanceType {
  corrective,
  preventive;

  /// The wire values standard Odoo uses.
  String get odooValue => switch (this) {
    MaintenanceType.corrective => 'corrective',
    MaintenanceType.preventive => 'preventive',
  };

  static MaintenanceType? fromOdoo(String? value) => switch (value) {
    'corrective' => MaintenanceType.corrective,
    'preventive' => MaintenanceType.preventive,
    _ => null,
  };
}

/// Odoo's four-level priority, which it stores as the strings "0".."3".
enum MaintenancePriority {
  veryLow,
  low,
  normal,
  high;

  String get odooValue => switch (this) {
    MaintenancePriority.veryLow => '0',
    MaintenancePriority.low => '1',
    MaintenancePriority.normal => '2',
    MaintenancePriority.high => '3',
  };

  static MaintenancePriority fromOdoo(String? value) => switch (value) {
    '0' => MaintenancePriority.veryLow,
    '1' => MaintenancePriority.low,
    '3' => MaintenancePriority.high,
    // Odoo leaves priority unset far more often than it sets "2", and an
    // unset priority means an ordinary request.
    _ => MaintenancePriority.normal,
  };

  bool get isUrgent => this == MaintenancePriority.high;
}

/// A `maintenance.request` (spec §16).
///
/// Only reachable when the Maintenance app is installed; every screen that
/// shows one is behind `OdooCapabilities.hasMaintenanceRequests`.
class MaintenanceRequest extends Equatable {
  const MaintenanceRequest({
    required this.id,
    required this.name,
    required this.priority,
    this.equipment,
    this.category,
    this.stage,
    this.type,
    this.technician,
    this.requestedOn,
    this.scheduledFor,
    this.closedOn,
    this.description,
    this.durationHours,
    this.isDone = false,
  });

  final int id;
  final String name;
  final MaintenancePriority priority;

  final OdooNameRef? equipment;
  final OdooNameRef? category;

  /// The workflow stage — "New Request", "In Progress", "Repaired", "Scrap".
  /// Read as a name rather than mapped to an enum: stages are configurable per
  /// instance, so any fixed list would be wrong on a customised Odoo.
  final OdooNameRef? stage;

  final MaintenanceType? type;
  final OdooNameRef? technician;

  final DateTime? requestedOn;
  final DateTime? scheduledFor;
  final DateTime? closedOn;

  final String? description;
  final double? durationHours;

  /// Whether the stage this request sits in is a closing one.
  final bool isDone;

  bool get isOpen => !isDone;

  /// True when the scheduled date has passed and the work is still open.
  bool isOverdue({DateTime? now}) {
    final due = scheduledFor;
    if (due == null || isDone) return false;
    return due.isBefore(now ?? DateTime.now());
  }

  @override
  List<Object?> get props => [
    id,
    name,
    priority,
    equipment,
    category,
    stage,
    type,
    technician,
    requestedOn,
    scheduledFor,
    closedOn,
    description,
    durationHours,
    isDone,
  ];
}

/// Filters the maintenance list supports (spec §16).
class MaintenanceFilters extends Equatable {
  const MaintenanceFilters({
    this.query,
    this.onlyOpen = true,
    this.type,
    this.equipmentId,
  });

  final String? query;

  /// Open requests only, which is what someone opening the screen wants; the
  /// closed ones are history.
  final bool onlyOpen;

  final MaintenanceType? type;

  /// Narrows to one asset's requests, for the asset detail screen.
  final int? equipmentId;

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      type == null &&
      equipmentId == null;

  MaintenanceFilters copyWith({
    String? query,
    bool? onlyOpen,
    MaintenanceType? type,
    int? equipmentId,
    bool clearQuery = false,
    bool clearType = false,
  }) => MaintenanceFilters(
    query: clearQuery ? null : (query ?? this.query),
    onlyOpen: onlyOpen ?? this.onlyOpen,
    type: clearType ? null : (type ?? this.type),
    equipmentId: equipmentId ?? this.equipmentId,
  );

  @override
  List<Object?> get props => [query, onlyOpen, type, equipmentId];
}
