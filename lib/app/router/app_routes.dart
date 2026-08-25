/// Every route in the app, named once so no path string is ever typed twice.
abstract final class AppRoutes {
  // ── Onboarding / auth ────────────────────────────────────────────────────
  static const String splash = '/';
  static const String connection = '/connection';
  static const String login = '/login';

  // ── Main tabs ────────────────────────────────────────────────────────────
  static const String dashboard = '/dashboard';
  static const String assets = '/assets';
  static const String scan = '/scan';
  static const String employees = '/employees';
  static const String more = '/more';

  // ── Assets ───────────────────────────────────────────────────────────────
  static const String assetDetail = 'detail/:assetId';
  static const String assetCreate = 'create';
  static const String assetEdit = 'detail/:assetId/edit';
  static const String assetQr = 'detail/:assetId/qr';
  static const String assetHistory = 'detail/:assetId/history';
  static const String assetAssign = 'detail/:assetId/assign';
  static const String assetReturn = 'detail/:assetId/return';

  // ── Employees ────────────────────────────────────────────────────────────
  static const String employeeDetail = 'detail/:employeeId';
  static const String employeeAssets = 'detail/:employeeId/assets';

  // ── Maintenance & settings (reached from More) ───────────────────────────
  static const String maintenance = 'maintenance';
  static const String maintenanceDetail = 'maintenance/:requestId';
  static const String audit = 'audit';
  static const String handover = 'handover';
  static const String settings = 'settings';
  static const String debugLog = 'settings/diagnostics';

  // ── Absolute helpers for imperative navigation ───────────────────────────
  static String assetDetailPath(int id) => '$assets/detail/$id';
  static String assetEditPath(int id) => '$assets/detail/$id/edit';
  static String assetQrPath(int id) => '$assets/detail/$id/qr';
  static String assetHistoryPath(int id) => '$assets/detail/$id/history';
  static String assetAssignPath(int id) => '$assets/detail/$id/assign';
  static String assetReturnPath(int id) => '$assets/detail/$id/return';
  static String employeeDetailPath(int id) => '$employees/detail/$id';
  static String employeeAssetsPath(int id) => '$employees/detail/$id/assets';
  static String maintenanceDetailPath(int id) => '$more/maintenance/$id';

  static const String maintenancePath = '$more/maintenance';
  static const String auditPath = '$more/audit';
  static const String handoverPath = '$more/handover';
  static const String settingsPath = '$more/settings';
  static const String debugLogPath = '$more/settings/diagnostics';

  const AppRoutes._();
}
