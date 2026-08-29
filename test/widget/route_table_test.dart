import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/router/app_router.dart';
import 'package:sijil_it/app/router/app_routes.dart';
import 'package:sijil_it/app/theme/app_theme.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// Every destination the app can navigate to, actually reachable.
///
/// `AppRoutes` holds two kinds of string: the `path:` a route is declared with,
/// and the `…Path(id)` a screen calls `context.go` with. Nothing makes the two
/// agree. Rename a segment in the routing table and the helper still compiles,
/// still returns a string, and lands the user on the not-found page — from a
/// button that worked yesterday.
///
/// The file used to hold a third copy as well: seven constants spelling out
/// full paths that no route and no helper referred to. They are gone; this is
/// what was actually needed.
void main() {
  late FakeOdooData data;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// Ids that exist in the fixture, so a resolved route also renders.
  const assetId = 101;
  const employeeId = 11;
  const requestId = 501;

  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    final auth = sl<AuthCubit>();
    router = AppRouter.create(auth: auth);

    await tester.pumpWidget(
      withAppProviders(
        auth: auth,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          supportedLocales: AppSettingsCubit.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, routed) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: TestSizes.phone),
            child: routed ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Navigates and lets the frame settle, without waiting for quiet.
  ///
  /// The scanner's viewfinder sweeps forever by design, so `pumpAndSettle`
  /// never returns on that route. Bounded pumps are enough here: what is under
  /// test is the router's configuration, which updates on the first frame.
  Future<void> goTo(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every path a screen can hand to `context.go`, by the name it is known by.
  final destinations = <String, String>{
    'dashboard': AppRoutes.dashboard,
    'assets': AppRoutes.assets,
    'scan': AppRoutes.scan,
    'employees': AppRoutes.employees,
    'more': AppRoutes.more,
    'asset detail': AppRoutes.assetDetailPath(assetId),
    'asset edit': AppRoutes.assetEditPath(assetId),
    'asset QR': AppRoutes.assetQrPath(assetId),
    'asset history': AppRoutes.assetHistoryPath(assetId),
    'asset assign': AppRoutes.assetAssignPath(assetId),
    'asset return': AppRoutes.assetReturnPath(assetId),
    'employee detail': AppRoutes.employeeDetailPath(employeeId),
    'employee assets': AppRoutes.employeeAssetsPath(employeeId),
    'maintenance': AppRoutes.maintenancePath,
    'maintenance detail': AppRoutes.maintenanceDetailPath(requestId),
    'audit': AppRoutes.auditPath,
    'handover': AppRoutes.handoverPath,
    'settings': AppRoutes.settingsPath,
    'diagnostics': AppRoutes.debugLogPath,
  };

  for (final entry in destinations.entries) {
    testWidgets('${entry.key} resolves to a real route', (tester) async {
      await pumpApp(tester);
      await goTo(tester, entry.value);

      final matches = router.routerDelegate.currentConfiguration;
      expect(
        matches.isError,
        isFalse,
        reason:
            '${entry.value} fell through to the not-found page — the helper '
            'and the routing table disagree',
      );
      expect(matches.uri.toString(), entry.value);
    });
  }

  testWidgets(
    'a path that does not exist explains itself and offers a way out',
    (tester) async {
      // A bad URI is a user-facing state like any other, and the one place the
      // app cannot assume anything about where the user meant to go.
      await pumpApp(tester);
      final l10n = await loadL10n();

      await goTo(tester, '/assets/detail/101/nonsense');

      expect(find.text(l10n.errorRouteNotFoundTitle), findsOneWidget);
      expect(find.text(l10n.actionGoToDashboard), findsOneWidget);

      await tester.tap(find.text(l10n.actionGoToDashboard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        AppRoutes.dashboard,
      );
    },
  );

  testWidgets('an id that is not a number does not crash the screen', (
    tester,
  ) async {
    // `_intParam` falls back to 0 rather than throwing, so the screen loads
    // and fails the way every other missing record does.
    await pumpApp(tester);

    await goTo(tester, '/assets/detail/not-a-number');

    expect(tester.takeException(), isNull);
  });
}
