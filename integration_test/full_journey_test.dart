import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sijil_it/app/app.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/connection/presentation/pages/connection_page.dart';
import 'package:sijil_it/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_detail_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_list_page.dart';
import 'package:sijil_it/features/handover/presentation/pages/handover_page.dart';
import 'package:sijil_it/features/maintenance/presentation/pages/maintenance_list_page.dart';
import 'package:sijil_it/features/settings/presentation/pages/settings_page.dart';
import 'package:sijil_it/features/sync/presentation/pages/sync_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';

import '../test/fake_odoo/fake_odoo_data.dart';
import '../test/fake_odoo/test_app_harness.dart';

/// The whole product, on a device, in one sitting.
///
/// The widget suite proves each screen in isolation against a fake Odoo. What
/// it cannot prove is that the *journey* holds: that a cold start with no saved
/// connection lands on the connection screen, that signing in redirects to the
/// dashboard rather than leaving the router mid-redirect, and that every
/// destination reachable from the More page actually builds on a real engine
/// with real fonts, a real image cache and a real isolate.
///
/// It is deliberately a *walk*, not a set of assertions about business rules —
/// those live in the unit and widget suites, which are faster and more precise.
/// What this catches is the class of failure that only appears once the pieces
/// are assembled: a redirect loop, a provider missing above a route, a font
/// that is not in the bundle, an isolate that will not spawn on Android.
///
/// Run with: `flutter test integration_test/full_journey_test.dart -d <id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeOdooData data;
  late AppL10n en;

  /// Settles, but gives real I/O — the socket, the isolate, the image
  /// decoder — a chance to finish first. `pumpAndSettle` alone runs on a fake
  /// clock that never waits for any of them.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pumpAndSettle();
    }
  }

  setUp(() async {
    data = FakeOdooData.seeded();
    en = await loadL10n();
  });

  tearDown(() async => sl.reset());

  testWidgets('a first run walks from splash to the connection screen', (
    tester,
  ) async {
    // Nothing saved: the state a freshly installed app is in.
    await configureTestDependencies(data: data);

    await tester.pumpWidget(const SijilApp());
    await settle(tester);

    // Splash resolves to the connection screen, not to a login for a server
    // the app has never been told about.
    expect(find.byType(ConnectionPage), findsOneWidget);
  });

  testWidgets('a signed-in session opens on the dashboard', (tester) async {
    await configureTestDependencies(data: data);
    await signInForTest(data);

    await tester.pumpWidget(const SijilApp());
    await settle(tester);

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('every tab and every destination behind More', () {
    setUp(() async {
      await configureTestDependencies(data: data);
      await signInForTest(data);
    });

    /// Boots the signed-in app and returns once the dashboard is up.
    Future<void> boot(WidgetTester tester) async {
      await tester.pumpWidget(const SijilApp());
      await settle(tester);
      expect(find.byType(DashboardPage), findsOneWidget);
    }

    /// Taps a bottom-bar destination by its label.
    Future<void> tab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).last);
      await settle(tester);
    }

    testWidgets('the four tabs each build with real data', (tester) async {
      await boot(tester);

      await tab(tester, en.navAssets);
      expect(find.byType(AssetListPage), findsOneWidget);
      expect(find.byType(AssetRow), findsWidgets);

      await tab(tester, en.navEmployees);
      expect(find.byType(EmployeeListPage), findsOneWidget);

      await tab(tester, en.navDashboard);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an asset opens, and its detail loads from Odoo', (
      tester,
    ) async {
      await boot(tester);
      await tab(tester, en.navAssets);

      await tester.tap(find.byType(AssetRow).first);
      await settle(tester);

      expect(find.byType(AssetDetailPage), findsOneWidget);
      // A detail that rendered its skeleton and stopped would pass a
      // "the page is there" check and fail this one.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an employee opens from the list', (tester) async {
      await boot(tester);
      await tab(tester, en.navEmployees);

      await tester.tap(find.byType(AppListTile).first);
      await settle(tester);

      expect(find.byType(EmployeeDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    /// Leaves the current screen by whichever control it offers.
    ///
    /// Not `tester.pageBack()`: that hunts for a Material or Cupertino
    /// `BackButton`, and every screen here is built by [AppScaffold], which
    /// draws its own so the glyph mirrors under Arabic.
    ///
    /// Two controls, deliberately. A page you *navigated into* gets a back
    /// arrow; a task you *started* — the handover flow — gets a close button,
    /// because backing out of a half-filled form one step at a time is not
    /// what anyone means by "leave this".
    Future<void> back(WidgetTester tester) async {
      final arrow = find.byIcon(Icons.arrow_back_rounded);
      final close = find.byIcon(Icons.close_rounded);
      final control = arrow.evaluate().isNotEmpty ? arrow : close;

      expect(
        control,
        findsWidgets,
        reason: 'This screen offers no way back out of it.',
      );
      await tester.tap(control.last);
      await settle(tester);
    }

    testWidgets('maintenance, handover, settings and sync all build', (
      tester,
    ) async {
      await boot(tester);
      await tab(tester, en.navMore);

      /// Opens one More destination and comes back.
      Future<void> visit(String label, Type page) async {
        await tester.tap(find.text(label).last);
        await settle(tester);
        expect(
          find.byType(page),
          findsOneWidget,
          reason: '$label did not open',
        );
        expect(tester.takeException(), isNull);

        await back(tester);
      }

      await visit(en.maintenanceTitle, MaintenanceListPage);
      await visit(en.handoverTitle, HandoverPage);
      await visit(en.settingsTitle, SettingsPage);
      await visit(en.syncTitle, SyncPage);
    });

    testWidgets('switching language flips the app to Arabic and back', (
      tester,
    ) async {
      // The one setting that changes every screen at once, and the one most
      // likely to be broken by a widget that resolved its own direction.
      await boot(tester);
      await tab(tester, en.navMore);

      await tester.tap(find.text(en.settingsTitle).last);
      await settle(tester);

      await tester.tap(find.text(en.languageArabic).last);
      await settle(tester);

      expect(
        Directionality.of(tester.element(find.byType(SettingsPage))),
        TextDirection.rtl,
      );

      final ar = await loadL10n('ar');
      await tester.tap(find.text(ar.languageEnglish).last);
      await settle(tester);

      expect(
        Directionality.of(tester.element(find.byType(SettingsPage))),
        TextDirection.ltr,
      );
    });

    testWidgets('and dark mode repaints every screen without an exception', (
      tester,
    ) async {
      await boot(tester);
      await tab(tester, en.navMore);
      await tester.tap(find.text(en.settingsTitle).last);
      await settle(tester);

      await tester.tap(find.text(en.themeDark).last);
      await settle(tester);
      expect(tester.takeException(), isNull);

      await back(tester);
      await tab(tester, en.navAssets);
      expect(find.byType(AssetListPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
