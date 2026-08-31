import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/router/home_shell.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_form_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_history_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_qr_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/overdue_assets_page.dart';
import 'package:sijil_it/features/assignment/presentation/pages/assign_asset_page.dart';
import 'package:sijil_it/features/assignment/presentation/pages/return_asset_page.dart';
import 'package:sijil_it/features/audit/presentation/pages/audit_page.dart';
import 'package:sijil_it/features/auth/presentation/pages/login_page.dart';
import 'package:sijil_it/features/connection/presentation/pages/connection_page.dart';
import 'package:sijil_it/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_assets_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_detail_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_list_page.dart';
import 'package:sijil_it/features/handover/presentation/pages/handover_page.dart';
import 'package:sijil_it/features/maintenance/presentation/pages/maintenance_detail_page.dart';
import 'package:sijil_it/features/maintenance/presentation/pages/maintenance_list_page.dart';
import 'package:sijil_it/features/settings/presentation/pages/debug_log_page.dart';
import 'package:sijil_it/features/settings/presentation/pages/settings_page.dart';
import 'package:sijil_it/features/sync/presentation/pages/sync_page.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// Every screen, at every size the app claims to support, in both languages
/// and at an accessibility text size.
///
/// This is the regression net for "the app is responsive": a fixed height that
/// clips a scaled label, a Row that runs off a 320-px phone, a two-column grid
/// that will not fit — all of them surface here as a failed expectation rather
/// than as a yellow-and-black stripe a reviewer has to notice by eye.
///
/// The screens are built with a live session against the fake Odoo, so each one
/// renders real content rather than an empty state that would overflow nothing.
void main() {
  late FakeOdooData data;

  /// Ids that exist in the fixture.
  const assetId = 101;
  const employeeId = 11;
  const requestId = 501;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// Every screen in the product, by the name it is known by.
  final screens = <String, Widget>{
    'dashboard': const DashboardPage(),
    'asset list': const AssetListPage(),
    'asset detail': const AssetDetailPage(assetId: assetId),
    'asset create': const AssetFormPage(assetId: null),
    'asset edit': const AssetFormPage(assetId: assetId),
    'asset QR': const AssetQrPage(assetId: assetId),
    'asset history': const AssetHistoryPage(assetId: assetId),
    'overdue assets': const OverdueAssetsPage(),
    'assign asset': const AssignAssetPage(assetId: assetId),
    'return asset': const ReturnAssetPage(assetId: assetId),
    'employee list': const EmployeeListPage(),
    'employee detail': const EmployeeDetailPage(employeeId: employeeId),
    'employee assets': const EmployeeAssetsPage(employeeId: employeeId),
    'maintenance list': const MaintenanceListPage(),
    'maintenance detail': const MaintenanceDetailPage(requestId: requestId),
    // The audit's scope step only. The counting step mounts a live camera,
    // which a widget test has no way to provide.
    'audit setup': const AuditPage(),
    'handover': const HandoverPage(),
    'more': const MorePage(),
    'settings': const SettingsPage(),
    'diagnostics': const DebugLogPage(),
    'sync': const SyncPage(),
    // Pre-auth. They render without a session, and they are the two
    // screens a first-time user meets on whatever handset they own.
    'connection': const ConnectionPage(),
    'login': const LoginPage(),
  };

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: size,
        textScale: textScale,
        child: signedInScreen(screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in screens.entries) {
    group(entry.key, () {
      for (final (sizeName, size) in TestSizes.all) {
        testWidgets('fits a $sizeName', (tester) async {
          await pumpScreen(tester, entry.value, size: size);
          expectNoOverflow(tester);
        });
      }

      testWidgets('fits a small phone at 1.6x text', (tester) async {
        // Past the app's own ceiling on purpose: the clamp is in
        // `AppApp.builder`, and a screen that survives beyond it survives a
        // future decision to raise the ceiling.
        await pumpScreen(
          tester,
          entry.value,
          size: TestSizes.smallPhone,
          textScale: 1.6,
        );
        expectNoOverflow(tester);
      });

      testWidgets('fits the worst case the app can actually reach', (
        tester,
      ) async {
        // The narrowest device, the longer language, and the largest text the
        // clamp allows — all at once. Each is tested alone above; layouts
        // break where they meet.
        await pumpScreen(
          tester,
          entry.value,
          size: TestSizes.smallPhone,
          locale: const Locale('ar', 'EG'),
          textScale: AppTextScale.max,
        );
        expectNoOverflow(tester);
      });

      testWidgets('fits a landscape phone at the text ceiling', (tester) async {
        // 390 logical pixels of height with the chrome on top of it: the one
        // place a vertical layout runs out of room rather than a horizontal
        // one.
        await pumpScreen(
          tester,
          entry.value,
          size: TestSizes.landscape,
          textScale: AppTextScale.max,
        );
        expectNoOverflow(tester);
      });

      testWidgets('fits a phone in Arabic', (tester) async {
        await pumpScreen(
          tester,
          entry.value,
          size: TestSizes.phone,
          locale: const Locale('ar', 'EG'),
        );
        expectNoOverflow(tester);
      });

      testWidgets('fits a phone in Arabic at 1.3x text', (tester) async {
        await pumpScreen(
          tester,
          entry.value,
          size: TestSizes.phone,
          locale: const Locale('ar', 'EG'),
          textScale: 1.3,
        );
        expectNoOverflow(tester);
      });

      testWidgets('renders in dark mode', (tester) async {
        await tester.pumpWidget(
          TestApp(
            size: TestSizes.phone,
            themeMode: ThemeMode.dark,
            child: signedInScreen(entry.value),
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    });
  }
}
