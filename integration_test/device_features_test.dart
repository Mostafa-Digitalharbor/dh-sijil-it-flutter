import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/router/home_shell.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/core/export/export_documents.dart';
import 'package:sijil_it/core/export/pdf_document.dart';
import 'package:sijil_it/core/security/app_lock.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/usecases/asset_usecases.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/overdue_assets_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/assignment/domain/entities/assignment.dart';
import 'package:sijil_it/features/assignment/presentation/pages/assign_asset_page.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_lock_cubit.dart';
import 'package:sijil_it/features/settings/presentation/pages/settings_page.dart';
import 'package:sijil_it/features/settings/presentation/widgets/app_lock_card.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../test/fake_odoo/fake_odoo_data.dart';
import '../test/fake_odoo/test_app_harness.dart';

/// The parts of these features a host machine cannot prove.
///
/// The widget suite already covers the logic against a fake Odoo, and it runs
/// on a desktop VM with every platform channel stubbed. Three things are
/// invisible there and all three are where this work could actually be broken
/// on a phone:
///
/// * **The unlock plugin.** `local_auth` needs `MainActivity` to be a
///   `FlutterFragmentActivity` and needs `USE_BIOMETRIC` in the manifest.
///   Neither is a compile error — a plain `FlutterActivity` builds, installs,
///   launches, and then throws the first time somebody turns the setting on.
/// * **The label sheet.** The PDF embeds fonts read from the real asset
///   bundle, which only exists in an installed build.
/// * **The gestures.** A long press that starts multi-select goes through the
///   platform's own touch pipeline here, not a synthetic one.
///
/// Run with: `flutter test integration_test/device_features_test.dart -d <id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeOdooData data;
  late AppL10n l10n;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  group('the device unlock', () {
    testWidgets('the plugin answers over a real platform channel', (
      tester,
    ) async {
      // Called directly, without `AppLock`'s catch-all. That guard is right in
      // production — a device whose enrolment vanished should degrade, not
      // crash — and it is exactly what would hide a missing plugin from every
      // other test in this file.
      //
      // A `MissingPluginException` here means the plugin is not registered; a
      // `PlatformException` about a fragment means `MainActivity` is still a
      // plain `FlutterActivity`.
      final supported = await LocalAuthentication().isDeviceSupported();

      expect(supported, isA<bool>());
    });

    testWidgets('a device with a screen lock can be asked for it', (
      tester,
    ) async {
      // The emulator this runs on has a PIN set (`adb shell locksettings
      // set-pin`). `isDeviceSupported` is true for *any* secure lock, not just
      // a biometric — which is the whole reason the prompt is configured to
      // fall through to the PIN.
      expect(await AppLock().isAvailable(), isTrue);
    });

    testWidgets('the app opens unlocked until somebody turns it on', (
      tester,
    ) async {
      final cubit = sl<AppLockCubit>();

      await cubit.start();

      expect(cubit.state.hasDeviceLock, isTrue);
      expect(cubit.state.isBlocking, isFalse);
    });
  });

  group('the label sheet', () {
    testWidgets('embeds the real fonts and produces a PDF', (tester) async {
      // `rootBundle` is the installed APK's asset bundle here. A path that is
      // wrong, or a font missing from `pubspec.yaml`, fails at this call and
      // nowhere else.
      final theme = await PdfTheme.load(isRtl: true);

      final bytes = await AssetLabelSheetExport.build(
        assets: <Asset>[
          for (var i = 0; i < 30; i++)
            Asset(
              id: 400 + i,
              name: 'ماك بوك برو',
              status: AssetStatus.available,
              assetTag: 'DH-LAP-00$i',
            ),
        ],
        copy: ExportCopy(
          product: l10n.appName,
          generatedOn: 'Generated on device',
          title: l10n.labelSheetTitle,
          subtitle: l10n.labelSheetSubtitle(30),
          columns: const <String>[],
        ),
        theme: theme,
      );

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(10000));
    });
  });

  group('multi-select', () {
    testWidgets('a real long press starts it and a tap adds to it', (
      tester,
    ) async {
      await tester.pumpWidget(
        RoutedTestApp(child: signedInScreen(const AssetListPage())),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssetRow).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.selectionCount(1)), findsOneWidget);

      await tester.tap(find.byType(AssetRow).at(1));
      await tester.pumpAndSettle();
      expect(find.text(l10n.selectionCount(2)), findsOneWidget);
    });
  });

  group('overdue returns', () {
    testWidgets('an asset past its date reaches the screen', (tester) async {
      await sl<AssignAsset>()(
        AssignmentRequest(
          assetId: 104,
          employeeId: 12,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 20),
          dueOn: DateTime(2020, 1, 6),
        ),
      );

      await tester.pumpWidget(
        RoutedTestApp(child: signedInScreen(const OverdueAssetsPage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AssetRow), findsOneWidget);
      expect(find.text(l10n.overdueCount(1)), findsOneWidget);
    });
  });

  group('the new surfaces, drawn by the real engine', () {
    /// Pumps a screen behind a router, and lets the debounced work run.
    ///
    /// A pending `Timer` schedules no frames, so `pumpAndSettle` alone returns
    /// while the assign screen's employee lookup is still waiting.
    Future<void> pump(
      WidgetTester tester,
      Widget screen, {
      Locale? locale,
    }) async {
      await tester.pumpWidget(
        RoutedTestApp(
          locale: locale ?? const Locale('en'),
          child: signedInScreen(screen),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    /// Scrolls the page until [finder] has been built, then returns it.
    ///
    /// Every screen here is a lazily-built `ListView`, so a widget below the
    /// fold does not exist yet — `findsNothing` on a device means "further
    /// down", not "missing". Scrolling is the difference between asserting
    /// about the screen and asserting about the viewport.
    Future<Finder> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      return finder;
    }

    testWidgets('the handover form offers an expected return date', (
      tester,
    ) async {
      await pump(tester, const AssignAssetPage(assetId: 104));

      // Optional, and empty until somebody says otherwise — the default that
      // keeps a permanent handover off the overdue screen.
      expect(
        await reveal(tester, find.text(l10n.assignDueNotSet)),
        findsOneWidget,
      );
      expect(find.text(l10n.assignStepDue), findsWidgets);
    });

    testWidgets('an overdue asset says so on its own screen', (tester) async {
      // Both dates are relative to now, and the count below is derived from
      // the same number rather than written out.
      //
      // This used to pin `dueOn` to 2020-01-06 and assert that
      // `dueOverdueBy(2429)` was *absent*. That passed for years by
      // coincidence: 2,429 days after that date is a single specific day, so
      // on every other day the string simply did not match and the assertion
      // proved nothing. On the day it did match, a correct screen failed the
      // test — the app was right and the expectation was inverted.
      const overdueDays = 30;
      final now = DateTime.now();

      await sl<AssignAsset>()(
        AssignmentRequest(
          assetId: 104,
          employeeId: 12,
          employeeName: 'Ahmed Mohamed',
          assignedOn: now.subtract(const Duration(days: 60)),
          dueOn: now.subtract(const Duration(days: overdueDays)),
        ),
      );

      await pump(tester, const AssetDetailPage(assetId: 104));

      expect(await reveal(tester, find.text(l10n.labelDueBack)), findsWidgets);
      // The long form, not the list row's one-word chip: this is the screen
      // somebody is on when they decide whether to chase it, so the number of
      // days has to be on it.
      expect(find.text(l10n.dueOverdueBy(overdueDays)), findsOneWidget);
      expect(
        find.text(l10n.dueChipOverdue),
        findsNothing,
        reason: 'the one-word chip belongs on a list row, not here',
      );
    });

    testWidgets('settings offers the unlock, enabled on this device', (
      tester,
    ) async {
      await pump(tester, const SettingsPage());

      expect(await reveal(tester, find.byType(AppLockCard)), findsOneWidget);
      // The heading is a `SectionCard`, which upper-cases what it is given —
      // so the assertion follows the widget rather than the raw string.
      expect(find.text(l10n.lockSettingsTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.lockSettingsSubtitle), findsOneWidget);
      // The emulator has a PIN, so the row is live rather than explaining
      // that there is nothing to ask for.
      expect(find.text(l10n.lockUnavailable), findsNothing);
    });

    testWidgets('the tools board links to the overdue list', (tester) async {
      await pump(tester, const MorePage());

      expect(
        await reveal(tester, find.text(l10n.overdueTitle)),
        findsOneWidget,
      );
      expect(find.text(l10n.overdueSubtitle), findsOneWidget);
    });

    testWidgets('the overdue screen lays out in Arabic without overflowing', (
      tester,
    ) async {
      // RTL is where a new row of chips actually breaks, and it breaks in the
      // renderer rather than in the logic — so it can only be caught by
      // laying it out.
      await sl<AssignAsset>()(
        AssignmentRequest(
          assetId: 104,
          employeeId: 12,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 20),
          dueOn: DateTime(2020, 1, 6),
        ),
      );

      await pump(tester, const OverdueAssetsPage(), locale: const Locale('ar'));

      expect(find.byType(AssetRow), findsOneWidget);
      expectNoOverflow(tester);
    });
  });

  group('the manual code entry', () {
    testWidgets('a typed serial resolves on the device too', (tester) async {
      final resolved = await sl<ResolveScannedCode>()('C02XK1YZQ6L4');

      expect(resolved.getOrElse(() => null)?.id, 101);
    });

    testWidgets('so does a printed QR payload', (tester) async {
      final resolved = await sl<ResolveScannedCode>()(
        '${AppConstants.qrScheme}://103',
      );

      expect(resolved.getOrElse(() => null)?.id, 103);
    });
  });
}
