import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/router/home_shell.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/network/odoo/odoo_capability_service.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/assignment/presentation/pages/assign_asset_page.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';
import 'package:sijil_it/shared/widgets/tool_tile.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The version and app-availability matrix (spec §28 · acceptance criterion 14).
///
/// ## Two different questions, deliberately in one file
///
/// **Which Odoo release is this?** — 17, 18 and 19 differ in ways no field
/// probe can see, because the difference is in a *method signature*
/// (`name_search`) rather than in the data. Those cases need the fallback
/// ladder exercised in both directions.
///
/// **Which apps are installed?** — a customer with Maintenance but no HR is
/// not a broken instance, it is a common one. The app probes `ir.model` and
/// removes what it cannot support, rather than showing a screen whose only
/// possible outcome is an apology (docs/ARCHITECTURE.md §5).
///
/// Combining them matters because the interesting failures live at the
/// intersection: Odoo 19 *and* no HR is where the employee picker faulted for
/// two different reasons at once, and fixing one hid the other.
void main() {
  late AppL10n l10n;

  setUp(() async => l10n = await loadL10n());
  tearDown(() async => sl.reset());

  /// Every version the app claims to support, oldest first.
  ///
  /// The `name_search` dialect is not a guess: 17 and 18 take
  /// `(name, args, operator)`, 19 renamed those to `(name, domain)`. Pairing
  /// them here keeps the fake honest — a test cannot accidentally run Odoo 19
  /// with the old signature and call it a pass.
  const versions = <({String version, bool legacyNameSearch})>[
    (version: '17.0', legacyNameSearch: true),
    (version: '18.0', legacyNameSearch: true),
    (version: '19.0', legacyNameSearch: false),
  ];

  /// Builds a seeded instance pinned to one release, optionally with apps
  /// uninstalled.
  FakeOdooData instance({
    required String version,
    required bool legacyNameSearch,
    Set<String> without = const <String>{},
  }) {
    final seed = FakeOdooData.seeded();
    final models = seed.installedModels.toSet()..removeAll(without);

    return FakeOdooData(
      serverVersion: version,
      database: seed.database,
      login: seed.login,
      secret: seed.secret,
      userId: seed.userId,
      installedModels: models,
      records: {
        for (final model in seed.installedModels) model: seed.tableOf(model),
      },
    )..speaksLegacyNameSearch = legacyNameSearch;
  }

  Future<FakeOdooData> signInTo(FakeOdooData data) async {
    await configureTestDependencies(data: data);
    await signInForTest(data);
    return data;
  }

  /// Pumps a screen and lets its debounced work run.
  ///
  /// `pumpAndSettle` only advances while frames are scheduled, and a pending
  /// `Timer` schedules none — so the assign screen's debounced employee lookup
  /// is still waiting when the assertions run without the explicit advance.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      RoutedTestApp(size: TestSizes.phone, child: signedInScreen(screen)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Types into the picker and lets the debounce fire, for the same reason.
  Future<void> typeAndSettle(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField).first, term);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // ── Version axis ──────────────────────────────────────────────────────────

  group('every supported release signs in and lists assets', () {
    for (final release in versions) {
      testWidgets('Odoo ${release.version}', (tester) async {
        await signInTo(
          instance(
            version: release.version,
            legacyNameSearch: release.legacyNameSearch,
          ),
        );

        expect(
          sl<AuthCubit>().state.isSignedIn,
          isTrue,
          reason: 'Sign-in failed on Odoo ${release.version}.',
        );
        expect(
          sl<AuthCubit>().state.capabilities.assetSource,
          AssetSource.maintenanceEquipment,
          reason: 'Asset source was not resolved on ${release.version}.',
        );

        await pump(tester, const AssetListPage());
        expect(
          find.byType(AssetRow),
          findsWidgets,
          reason: 'The asset list came back empty on ${release.version}.',
        );
      });
    }
  });

  group('name_search speaks both dialects', () {
    // The employee *list* filters with an ilike domain; the *picker* on the
    // assign screen is the one that goes through `name_search`. Targeting the
    // list here would have tested nothing — this file caught exactly that.
    const availableAssetId = 104;

    for (final release in versions) {
      testWidgets('Odoo ${release.version} — the assign picker finds people', (
        tester,
      ) async {
        final data = await signInTo(
          instance(
            version: release.version,
            legacyNameSearch: release.legacyNameSearch,
          ),
        );

        await pump(tester, const AssignAssetPage(assetId: availableAssetId));

        expect(
          data.nameSearchCallCount,
          greaterThan(0),
          reason: 'The picker never reached name_search at all.',
        );
        expect(
          find.byType(AppSelectableTile),
          findsWidgets,
          reason:
              'name_search returned nothing on ${release.version}. On a real '
              'instance the symptom is an employee picker that is silently '
              'always empty — see docs/ODOO_COMPATIBILITY.md §1.',
        );
      });
    }

    testWidgets('the working signature is memoised, not re-probed', (
      tester,
    ) async {
      // On a legacy server the modern call faults first, so the client pays
      // one extra round trip. Paying it on every keystroke of a typeahead is
      // the difference between a picker that feels instant and one that does
      // not.
      final data = await signInTo(
        instance(version: '17.0', legacyNameSearch: true),
      );

      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      final afterOpen = data.nameSearchCallCount;

      await typeAndSettle(tester, 'Mos');
      final afterFirst = data.nameSearchCallCount;

      await typeAndSettle(tester, 'Most');
      final afterSecond = data.nameSearchCallCount;

      expect(
        afterOpen,
        2,
        reason:
            'Opening the picker on a legacy server should cost exactly two '
            'calls: the modern signature, which faults, then the legacy one.',
      );
      expect(
        (afterFirst - afterOpen, afterSecond - afterFirst),
        (1, 1),
        reason:
            'A later search re-probed the signature. The fallback must be '
            'remembered for the life of the process, not rediscovered on '
            'every keystroke.',
      );
    });
  });

  // ── Installed-apps axis ───────────────────────────────────────────────────

  group('an instance without the HR app', () {
    for (final release in versions) {
      testWidgets('Odoo ${release.version} — assets still work', (
        tester,
      ) async {
        await signInTo(
          instance(
            version: release.version,
            legacyNameSearch: release.legacyNameSearch,
            without: <String>{
              OdooModels.hrEmployee,
              OdooModels.hrDepartment,
              OdooModels.hrJob,
            },
          ),
        );

        final capabilities = sl<AuthCubit>().state.capabilities;
        expect(capabilities.hasHrEmployees, isFalse);
        expect(capabilities.canAssignToEmployees, isFalse);
        expect(
          capabilities.assetSource,
          AssetSource.maintenanceEquipment,
          reason: 'Losing HR must not cost the app its asset register.',
        );

        await pump(tester, const AssetListPage());
        expect(find.byType(AssetRow), findsWidgets);
      });
    }
  });

  group('an instance without the Maintenance requests model', () {
    testWidgets('the More tab drops the Maintenance tile', (tester) async {
      await signInTo(
        instance(
          version: '18.0',
          legacyNameSearch: true,
          without: <String>{OdooModels.maintenanceRequest},
        ),
      );

      expect(
        sl<AuthCubit>().state.capabilities.hasMaintenanceRequests,
        isFalse,
      );

      await pump(tester, const MorePage());

      expect(
        find.widgetWithText(AppToolTile, l10n.maintenanceTitle),
        findsNothing,
        reason:
            'A tile that can only lead to an apology should not be offered.',
      );
      // The tools that need nothing beyond the asset model stay.
      expect(find.widgetWithText(AppToolTile, l10n.auditTitle), findsOneWidget);
      expect(
        find.widgetWithText(AppToolTile, l10n.handoverTitle),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppToolTile, l10n.settingsTitle),
        findsOneWidget,
      );
    });

    testWidgets('the Maintenance tile is present when the model is', (
      tester,
    ) async {
      await signInTo(instance(version: '18.0', legacyNameSearch: true));
      await pump(tester, const MorePage());

      expect(
        find.widgetWithText(AppToolTile, l10n.maintenanceTitle),
        findsOneWidget,
        reason: 'The control case: the gate must not hide the tile always.',
      );
    });
  });

  group('an instance with no asset-capable model at all', () {
    testWidgets('capabilities report no source rather than guessing one', (
      tester,
    ) async {
      // Odoo with neither Maintenance nor Inventory. There is nothing for the
      // app to manage, and the honest answer is to say so — not to pick a
      // model at random and fail on the first read.
      await signInTo(
        instance(
          version: '19.0',
          legacyNameSearch: false,
          without: <String>{
            OdooModels.maintenanceEquipment,
            OdooModels.maintenanceRequest,
            OdooModels.maintenanceEquipmentCategory,
          },
        ),
      );

      final capabilities = sl<AuthCubit>().state.capabilities;
      expect(capabilities.hasMaintenance, isFalse);
      expect(capabilities.assetSource, AssetSource.none);
      expect(capabilities.assetSource.modelName, isNull);
    });
  });

  // ── The version string itself ─────────────────────────────────────────────

  group('the reported release is recorded, not acted on', () {
    for (final release in versions) {
      test('Odoo ${release.version} is probed, never branched on', () async {
        final data = await signInTo(
          instance(
            version: release.version,
            legacyNameSearch: release.legacyNameSearch,
          ),
        );

        // Every version reaches identical capabilities on an identically
        // configured instance. If this ever diverges, something started
        // version-sniffing — which is exactly what the probe-first rule in
        // docs/ARCHITECTURE.md §5 exists to prevent.
        expect(
          sl<AuthCubit>().state.capabilities.assetSource,
          AssetSource.maintenanceEquipment,
        );
        expect(data.serverVersion, release.version);
      });
    }
  });
}
