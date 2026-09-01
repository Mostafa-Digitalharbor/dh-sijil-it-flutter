import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_detail_sections.dart';
import 'package:sijil_it/features/settings/presentation/widgets/session_card.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_chip.dart';
import 'package:sijil_it/shared/widgets/app_segmented.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The two screens-worth of new surface, built directly.
///
/// Both are reachable from a screen the responsive sweep already covers, which
/// proves they fit — and proves nothing about what they say. These assert the
/// sentences, because in both cases the sentence *is* the feature: a service
/// life that reports the wrong number is worse than no service life, and a
/// session card that says the wrong date is a promise about when somebody gets
/// logged out.
void main() {
  late AppL10n en;

  setUp(() async {
    await configureTestDependencies(data: FakeOdooData.seeded());
    en = await loadL10n();
  });

  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = TestSizes.phone,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        size: size,
        locale: locale,
        textScale: textScale,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Asset assetBought(DateTime? on, {double? value}) => Asset(
    id: 1,
    name: 'MacBook Pro',
    status: AssetStatus.available,
    purchaseDate: on,
    purchaseValue: value,
    currencySymbol: r'$',
  );

  group('AssetLifecycleSection', () {
    testWidgets('a young asset reports its age without alarm', (tester) async {
      final bought = DateTime.now().subtract(const Duration(days: 400));
      await pump(tester, AssetLifecycleSection(asset: assetBought(bought)));

      // `SectionCard` upper-cases its title.
      expect(find.text(en.lifecycleTitle.toUpperCase()), findsOneWidget);
      expect(
        find.byType(AppChip),
        findsNothing,
        reason: 'a healthy asset is not a finding',
      );
    });

    testWidgets('one near the end of its life asks to be replaced', (
      tester,
    ) async {
      // Fifty-eight months in, against a sixty-month life.
      final bought = DateTime.now().subtract(const Duration(days: 58 * 30));
      await pump(tester, AssetLifecycleSection(asset: assetBought(bought)));

      expect(find.text(en.lifecycleAgeing), findsOneWidget);
    });

    testWidgets('one past it says so more loudly', (tester) async {
      final bought = DateTime.now().subtract(const Duration(days: 7 * 365));
      await pump(tester, AssetLifecycleSection(asset: assetBought(bought)));

      expect(find.text(en.lifecycleOverdue), findsOneWidget);
      expect(find.textContaining('past its expected life'), findsWidgets);
    });

    testWidgets('the cost line appears once there is a price and a year', (
      tester,
    ) async {
      final bought = DateTime.now().subtract(const Duration(days: 4 * 365));
      final asset = assetBought(bought, value: 2400);
      await pump(tester, AssetLifecycleSection(asset: asset));

      expect(find.text(en.lifecycleCostPerYear), findsOneWidget);

      // Derived rather than written out: four years from *today* is not
      // exactly forty-eight months, and a hardcoded 600 here would be a test
      // that passes on one day of the year. The exact arithmetic is pinned in
      // `asset_lifecycle_test.dart` against a fixed clock.
      final perYear = asset.lifecycle.annualisedCost!.round();
      expect(find.textContaining(r'$'), findsWidgets);
      expect(
        find.textContaining('$perYear'),
        findsWidgets,
        reason: 'the figure that argues for buying the better machine',
      );
      expect(perYear, closeTo(600, 20));
    });

    testWidgets('and stays away when there is no price', (tester) async {
      final bought = DateTime.now().subtract(const Duration(days: 4 * 365));
      await pump(tester, AssetLifecycleSection(asset: assetBought(bought)));

      expect(find.text(en.lifecycleCostPerYear), findsNothing);
    });

    testWidgets('an undated asset is asked for a date rather than hidden', (
      tester,
    ) async {
      // Unlike the warranty block, which vanishes. A missing warranty date is
      // Odoo's business; a missing purchase date is a gap somebody here can
      // close, and this is the only place that says so.
      await pump(tester, AssetLifecycleSection(asset: assetBought(null)));

      expect(find.text(en.lifecycleUnknown), findsOneWidget);
      expect(find.text(en.lifecycleUnknownHint), findsOneWidget);
    });

    testWidgets('it fits the worst case the app can reach', (tester) async {
      final bought = DateTime.now().subtract(const Duration(days: 7 * 365));
      await pump(
        tester,
        AssetLifecycleSection(asset: assetBought(bought, value: 2400)),
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  group('SessionCard', () {
    testWidgets('it opens on the default window', (tester) async {
      await pump(tester, const SessionCard());

      expect(find.text(en.sessionTitle.toUpperCase()), findsOneWidget);
      final segmented = tester.widget<AppSegmented<int>>(
        find.byType(AppSegmented<int>),
      );
      expect(segmented.value, AppPreferences.defaultSessionMaxAgeDays);
    });

    testWidgets('choosing a window stores it', (tester) async {
      await pump(tester, const SessionCard());

      await tester.tap(find.text(en.sessionMaxAgeDays(7)));
      await tester.pumpAndSettle();

      expect(sl<AppPreferences>().sessionMaxAgeDays, 7);
    });

    testWidgets('"no limit" is offered and says what it means', (tester) async {
      // The honest name for what the app did before this existed, and a
      // shared shop-floor device should be able to choose it deliberately.
      await pump(tester, const SessionCard());

      await tester.tap(
        find.text(en.sessionMaxAgeDays(AppPreferences.sessionNeverExpires)),
      );
      await tester.pumpAndSettle();

      expect(
        sl<AppPreferences>().sessionMaxAgeDays,
        AppPreferences.sessionNeverExpires,
      );
      expect(find.text(en.sessionNeverExpiresNote), findsOneWidget);
    });

    testWidgets('with a session running it names the date, not the policy', (
      tester,
    ) async {
      // "Signs out on 3 October" is something a person can plan around in a
      // way that "30 days" is not.
      await sl<AppPreferences>().setLastAuthenticated(DateTime.now());
      await pump(tester, const SessionCard());

      expect(find.text(en.sessionNeverExpiresNote), findsNothing);
      expect(find.textContaining('Signs out on'), findsOneWidget);
    });

    testWidgets('it fits the worst case', (tester) async {
      await pump(
        tester,
        const SessionCard(),
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });
}
