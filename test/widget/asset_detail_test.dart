import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_detail_sections.dart';
import 'package:sijil_it/features/attachments/presentation/widgets/photo_section.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The asset detail screen (spec §14).
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  /// From the fixture: assigned, unassigned, and scrapped respectively.
  const assignedId = 101;
  const availableId = 104;
  const retiredId = 105;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    int id, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      RoutedTestApp(
        locale: locale,
        size: TestSizes.phone,
        child: signedInScreen(AssetDetailPage(assetId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Brings a widget below the fold into existence.
  ///
  /// The detail body builds lazily, so a section further down the page has not
  /// been created yet and cannot be found until it is scrolled to.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> record(int id) => data
      .tableOf('maintenance.equipment')
      .firstWhere((row) => row['id'] == id);

  group('content', () {
    testWidgets('renders every section the spec lists', (tester) async {
      await pump(tester, assignedId);

      // The photo strip now leads the screen, so the sections below it start
      // out past the fold and the list has not built them yet. Scrolling to
      // each is the assertion: they exist and are reachable, which is what
      // "renders every section" has to mean for a lazily-built list.
      expect(find.byType(PhotoSection), findsOneWidget);
      expect(find.byType(AssetHeroCard), findsOneWidget);
      expect(find.byType(AssetDeviceSection), findsOneWidget);

      for (final section in <Finder>[
        find.byType(AssetOwnershipSection),
        find.byType(AssetWarrantySection),
        find.byType(AssetPurchaseSection),
      ]) {
        await scrollTo(tester, section);
        expect(section, findsOneWidget);
      }
    });

    testWidgets('shows the serial number Odoo holds', (tester) async {
      await pump(tester, assignedId);
      expect(find.text('${record(assignedId)['serial_no']}'), findsOneWidget);
    });

    testWidgets('names the employee holding it', (tester) async {
      await pump(tester, assignedId);

      final holder = (record(assignedId)['employee_id'] as List<Object?>)[1];
      expect(find.text('$holder'), findsWidgets);
    });

    testWidgets('an unassigned asset says so rather than showing a blank', (
      tester,
    ) async {
      await pump(tester, availableId);
      expect(find.text(l10n.labelUnassigned), findsWidgets);
    });

    testWidgets('an unassigned asset shows no assignment date', (tester) async {
      // Odoo stamps `assign_date` with today on create regardless of whether
      // an employee is set, so the date alone must not drive this row — it
      // read "Unassigned" and "Assigned 24 Aug · 0 days" one under the other.
      record(availableId)['assign_date'] = '2026-08-24';

      await pump(tester, availableId);

      expect(find.text(l10n.labelUnassigned), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(AssetOwnershipSection),
          matching: find.text(l10n.labelAssignedOn),
        ),
        findsNothing,
      );
    });

    testWidgets('an assigned asset does show its assignment date', (
      tester,
    ) async {
      await pump(tester, assignedId);

      // Scoped: "Assigned" is also the status chip's label.
      expect(
        find.descendant(
          of: find.byType(AssetOwnershipSection),
          matching: find.text(l10n.labelAssignedOn),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an asset with no warranty date shows no warranty block', (
      tester,
    ) async {
      record(availableId)['warranty_date'] = false;

      await pump(tester, availableId);

      // The widget is still in the tree; what matters is that it draws
      // nothing, so the assertion is on the heading it would have rendered.
      expect(find.text(l10n.sectionWarranty.toUpperCase()), findsNothing);
    });

    testWidgets('a field Odoo left empty reads as "not recorded"', (
      tester,
    ) async {
      // Odoo sends `false` for an unset char field, and a blank row would look
      // like a rendering bug rather than a missing value.
      record(availableId)['model'] = false;

      await pump(tester, availableId);

      expect(find.text(l10n.labelUnknown), findsWidgets);
    });
  });

  group('actions', () {
    testWidgets('an assigned asset offers Return, not Assign', (tester) async {
      await pump(tester, assignedId);

      expect(find.widgetWithText(AppButton, l10n.actionReturn), findsOneWidget);
      expect(find.widgetWithText(AppButton, l10n.actionAssign), findsNothing);
    });

    testWidgets('an available asset offers Assign, not Return', (tester) async {
      await pump(tester, availableId);

      expect(find.widgetWithText(AppButton, l10n.actionAssign), findsOneWidget);
      expect(find.widgetWithText(AppButton, l10n.actionReturn), findsNothing);
    });

    testWidgets('a retired asset offers neither', (tester) async {
      await pump(tester, retiredId);

      expect(find.widgetWithText(AppButton, l10n.actionAssign), findsNothing);
      expect(find.widgetWithText(AppButton, l10n.actionReturn), findsNothing);
    });

    testWidgets('a read-only user gets no Edit button', (tester) async {
      data.deniedOperations.add('maintenance.equipment.write');
      await pump(tester, assignedId);

      expect(find.widgetWithText(AppButton, l10n.actionEdit), findsNothing);
    });

    testWidgets('a user who may write gets Edit', (tester) async {
      await pump(tester, assignedId);
      expect(find.widgetWithText(AppButton, l10n.actionEdit), findsOneWidget);
    });
  });

  group('failure', () {
    testWidgets('a deleted asset explains itself', (tester) async {
      await pump(tester, 999999);

      expect(find.byType(FailureView), findsOneWidget);
      expect(find.text(l10n.errorRecordNotFoundTitle), findsOneWidget);
    });

    testWidgets('no Odoo internals leak into the message', (tester) async {
      await pump(tester, 999999);

      expect(find.textContaining('maintenance.equipment'), findsNothing);
      expect(find.textContaining('Traceback'), findsNothing);
    });
  });

  testWidgets('renders right to left in Arabic without overflow', (
    tester,
  ) async {
    await pump(tester, assignedId, locale: const Locale('ar', 'EG'));
    expectNoOverflow(tester);
  });
}
