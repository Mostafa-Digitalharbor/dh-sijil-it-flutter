/// The lifecycle state of an IT asset (spec §6).
///
/// ## Where the value comes from
///
/// Standard Odoo has no single "IT asset status" field, and spec §2 forbids
/// shipping a custom addon to create one. The status is therefore *resolved*
/// at read time by `AssetStatusResolver`, in this precedence order:
///
/// 1. **A real Odoo field**, if the customer already has one. The resolver
///    looks for a configurable selection field (default `x_sijil_status`) via
///    `OdooCapabilityService.fieldExists`. When present, Odoo is the single
///    source of truth and the local overlay is bypassed entirely.
/// 2. **Derived from standard fields** — see [AssetStatusResolver] for the
///    exact rules. Covers Available, Assigned, Under Maintenance and Retired
///    without storing anything locally.
/// 3. **A note in the asset's Odoo chatter**, for the three states standard
///    Odoo genuinely cannot express: Reserved, Damaged and Lost. The app has
///    posted one on every such change since the first release; `AssetStateStore`
///    reads the newest one back, so the state is the same on every device and
///    visible in the web client. The encrypted `local_asset_state` box mirrors
///    it for offline reads.
///
/// The overlay is deliberately narrow: it never contradicts a state Odoo can
/// prove (an asset with `employee_id` set always reads as Assigned).
///
/// What [isLocalOnly] marks is therefore *not* "only on this phone" — it is
/// "recorded in the log rather than in a field", which is why an Odoo user
/// filtering on a status field will not find these three.
enum AssetStatus {
  available,
  assigned,
  reserved,
  underMaintenance,
  damaged,
  lost,
  retired;

  /// Whether this state is recorded in the asset's log rather than derived
  /// from an Odoo field. Surfaced in the UI with a small marker, because it is
  /// the difference between a value the Odoo web client can filter on and one
  /// it can only be read to.
  bool get isLocalOnly => switch (this) {
    AssetStatus.reserved || AssetStatus.damaged || AssetStatus.lost => true,
    _ => false,
  };

  /// An asset in one of these states can be handed to an employee.
  bool get isAssignable => switch (this) {
    AssetStatus.available || AssetStatus.reserved => true,
    _ => false,
  };

  bool get isReturnable => this == AssetStatus.assigned;

  /// Counts toward the "in service" figure on the dashboard.
  bool get isActive => switch (this) {
    AssetStatus.retired || AssetStatus.lost => false,
    _ => true,
  };

  static AssetStatus? fromName(String? value) {
    if (value == null) return null;
    for (final status in AssetStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }
}

/// Condition recorded when an asset comes back from an employee (spec §8).
enum ReturnCondition {
  good,
  minorDamage,
  damaged,
  needsMaintenance;

  /// The status the asset moves to once a return with this condition is
  /// confirmed. Encodes the return workflow's business rule in one place.
  AssetStatus get resultingStatus => switch (this) {
    ReturnCondition.good => AssetStatus.available,
    ReturnCondition.minorDamage => AssetStatus.available,
    ReturnCondition.damaged => AssetStatus.damaged,
    ReturnCondition.needsMaintenance => AssetStatus.underMaintenance,
  };

  /// A damaged or maintenance-needing return should offer to open a
  /// `maintenance.request` right away, when Maintenance is installed.
  bool get suggestsMaintenanceRequest => switch (this) {
    ReturnCondition.damaged || ReturnCondition.needsMaintenance => true,
    _ => false,
  };

  static ReturnCondition? fromName(String? value) {
    if (value == null) return null;
    for (final condition in ReturnCondition.values) {
      if (condition.name == value) return condition;
    }
    return null;
  }
}
