import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/router/app_router.dart';
import 'package:sijil_it/app/router/home_shell.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/app/theme/app_theme.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_list_page.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_nav_bar.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The chrome that is on screen more than anything else in the product.
///
/// `HomeShell` was the one widget in `lib/app/router` that no test built. The
/// `MorePage` beside it in the same file is swept for overflow on every size,
/// which is exactly why the gap survived: the file looked covered.
///
/// What is asserted here is the claim the shell exists to make — that the app
/// is genuinely responsive rather than a stretched phone layout. A bottom bar
/// on a phone and a rail from the tablet breakpoint up is a decision made in
/// one `if`, and nothing outside this file would notice it inverting.
void main() {
  late FakeOdooData data;
  late AppL10n en;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    en = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// The whole app on its real routing table, at a given window size.
  ///
  /// The shell takes a `StatefulNavigationShell`, which only exists inside a
  /// real `StatefulShellRoute` — so this builds the router rather than the
  /// widget. That is the honest way round: the branch order the shell indexes
  /// into is defined in the route table, and a test that faked the shell could
  /// not catch the two disagreeing.
  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    final auth = sl<AuthCubit>();

    await tester.pumpWidget(
      withAppProviders(
        auth: auth,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppSettingsCubit.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          theme: AppTheme.light,
          routerConfig: AppRouter.create(auth: auth),
          builder: (context, routed) => sized(
            context,
            size: size,
            textScale: textScale,
            child: routed ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the navigation follows the window, not the platform', () {
    testWidgets('a phone gets the bottom bar', (tester) async {
      await pumpApp(tester, size: TestSizes.phone);

      expect(find.byType(AppNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a small phone gets it too', (tester) async {
      await pumpApp(tester, size: TestSizes.smallPhone);

      expect(find.byType(AppNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a tablet gets the side rail', (tester) async {
      await pumpApp(tester, size: TestSizes.tablet);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        find.byType(AppNavBar),
        findsNothing,
        reason: 'both at once is a stretched phone with a rail bolted on',
      );
    });

    testWidgets('so does a landscape phone, which is wide enough', (
      tester,
    ) async {
      await pumpApp(tester, size: TestSizes.landscape);

      expect(
        find.byType(NavigationRail),
        findsOneWidget,
        reason:
            'the breakpoint is on width; a bottom bar in landscape eats the '
            'height the content needs',
      );
    });

    testWidgets('and a desktop window', (tester) async {
      await pumpApp(tester, size: TestSizes.desktop);

      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('every tab is reachable and lands where it says', () {
    testWidgets('the shell opens on the dashboard', (tester) async {
      await pumpApp(tester, size: TestSizes.phone);

      expect(find.byType(DashboardPage), findsOneWidget);
    });

    testWidgets('assets, employees and more each open their own screen', (
      tester,
    ) async {
      await pumpApp(tester, size: TestSizes.phone);

      await tester.tap(find.text(en.navAssets));
      await tester.pumpAndSettle();
      expect(find.byType(AssetListPage), findsOneWidget);

      await tester.tap(find.text(en.navEmployees));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeListPage), findsOneWidget);

      await tester.tap(find.text(en.navMore));
      await tester.pumpAndSettle();
      expect(find.byType(MorePage), findsOneWidget);
    });

    testWidgets('the same tabs work from the rail', (tester) async {
      await pumpApp(tester, size: TestSizes.tablet);

      await tester.tap(find.text(en.navAssets));
      await tester.pumpAndSettle();
      expect(find.byType(AssetListPage), findsOneWidget);

      await tester.tap(find.text(en.navDashboard));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardPage), findsOneWidget);
    });

    testWidgets('a tab keeps its own state while the others are away', (
      tester,
    ) async {
      // The whole reason the shell is an IndexedStack: leaving assets and
      // coming back must not re-read the list from Odoo.
      await pumpApp(tester, size: TestSizes.phone);

      await tester.tap(find.text(en.navAssets));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.navEmployees));
      await tester.pumpAndSettle();

      expect(
        find.byType(AssetListPage, skipOffstage: false),
        findsOneWidget,
        reason: 'the branch stays alive off-screen',
      );
    });
  });

  group('it survives the sizes and settings the app allows', () {
    testWidgets('every size, in Arabic, at the text ceiling', (tester) async {
      for (final (name, size) in TestSizes.all) {
        await pumpApp(
          tester,
          size: size,
          locale: const Locale('ar', 'EG'),
          textScale: AppTextScale.max,
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'the shell overflowed on a $name',
        );
      }
    });

    testWidgets('the scan action is offered on every size', (tester) async {
      // By its icon, not its label. In the bottom bar scan is lifted out as a
      // raised button and carries no text — which is the design, and which is
      // why asserting on the word found nothing on a phone.
      for (final (name, size) in TestSizes.all) {
        await pumpApp(tester, size: size);

        expect(
          find.byIcon(Icons.qr_code_scanner_rounded),
          findsWidgets,
          reason:
              'scanning is the most-performed action in the product; it is '
              'not something a $name may drop',
        );
      }
    });

    testWidgets('the rail spells the scan destination out', (tester) async {
      // A rail has room for a label and no raised centre button, so the one
      // destination the bar shows as an icon alone is named here.
      await pumpApp(tester, size: TestSizes.tablet);

      expect(find.text(en.navScan), findsOneWidget);
    });
  });
}
