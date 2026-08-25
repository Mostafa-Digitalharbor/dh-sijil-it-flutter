import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_form_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The create/edit form (spec §14).
///
/// The create tests exist because of a real defect: stock Odoo marks
/// `maintenance.equipment.effective_date` **required**, and the app used to
/// send Odoo's "empty" sentinel `false` for it whenever the user left the
/// purchase date blank. That overrides the server-side default the constraint
/// relies on, so every asset created without a purchase date was rejected —
/// on a stock instance, that is most of them.
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  const existingId = 101;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Future<void> pump(WidgetTester tester, {int? assetId}) async {
    await tester.pumpWidget(
      RoutedTestApp(
        size: TestSizes.phone,
        child: signedInScreen(AssetFormPage(assetId: assetId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Map<String, dynamic>> equipment() =>
      data.tableOf('maintenance.equipment');

  Finder nameField() => find.byType(TextField).first;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, l10n.actionSave));
    await tester.pumpAndSettle();
  }

  group('create', () {
    testWidgets('saves an asset that has only a name', (tester) async {
      final before = equipment().length;

      await pump(tester);
      await tester.enterText(nameField(), 'Spare ThinkPad');
      await tester.pumpAndSettle();
      await save(tester);

      expect(
        equipment().length,
        before + 1,
        reason: 'a required date the user left blank must not block the save',
      );
      expect(equipment().last['name'], 'Spare ThinkPad');
    });

    testWidgets('omits a required field rather than clearing it', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(nameField(), 'Spare ThinkPad');
      await tester.pumpAndSettle();
      await save(tester);

      // Odoo's default filled it in; the app never sent `false`.
      expect(equipment().last.containsKey('effective_date'), isFalse);
    });

    testWidgets('still clears an optional field the user emptied', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(nameField(), 'Spare ThinkPad');
      await tester.pumpAndSettle();
      await save(tester);

      // `warranty_date` is not required, so an empty one is written as Odoo's
      // empty sentinel rather than silently skipped.
      expect(equipment().last['warranty_date'], false);
    });

    testWidgets('Save is disabled until the asset has a name', (tester) async {
      await pump(tester);

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, l10n.actionSave),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an Odoo rejection is explained, and nothing is created', (
      tester,
    ) async {
      data.deniedOperations.add('maintenance.equipment.create');
      final before = equipment().length;

      await pump(tester);
      await tester.enterText(nameField(), 'Spare ThinkPad');
      await tester.pumpAndSettle();
      await save(tester);

      expect(equipment().length, before);
      expect(find.text(l10n.errorAccessDeniedTitle), findsOneWidget);
      expect(find.textContaining('AccessError'), findsNothing);
    });
  });

  group('edit', () {
    testWidgets('loads the existing values into the form', (tester) async {
      await pump(tester, assetId: existingId);

      final row = equipment().firstWhere((r) => r['id'] == existingId);
      expect(find.text('${row['name']}'), findsOneWidget);
      expect(find.text('${row['serial_no']}'), findsOneWidget);
    });

    testWidgets('writes the change back to Odoo', (tester) async {
      await pump(tester, assetId: existingId);

      await tester.enterText(nameField(), 'Renamed asset');
      await tester.pumpAndSettle();
      await save(tester);

      final row = equipment().firstWhere((r) => r['id'] == existingId);
      expect(row['name'], 'Renamed asset');
    });

    testWidgets('leaves a required field alone on an edit too', (tester) async {
      final before = equipment().firstWhere(
        (r) => r['id'] == existingId,
      )['effective_date'];

      await pump(tester, assetId: existingId);
      await tester.enterText(nameField(), 'Renamed asset');
      await tester.pumpAndSettle();
      await save(tester);

      final row = equipment().firstWhere((r) => r['id'] == existingId);
      expect(row['effective_date'], before);
    });
  });
}
