import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:sijil_it/features/assignment/domain/entities/assignment.dart';
import 'package:sijil_it/features/assignment/presentation/pages/assign_asset_page.dart';
import 'package:sijil_it/features/assignment/presentation/pages/return_asset_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The assign and return workflows, driven end to end against a fake Odoo.
///
/// These are the app's only *write* paths, so the assertions are about what
/// landed on the server — the employee, the date, the cleared assignment and
/// the chatter note — rather than about what the screen looks like.
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  /// From the fixture: unassigned, and assigned-to-Ahmed respectively.
  const availableAssetId = 104;
  const assignedAssetId = 101;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Map<String, dynamic> equipment(int id) => data
      .tableOf('maintenance.equipment')
      .firstWhere((row) => row['id'] == id);

  List<Map<String, dynamic>> notesFor(int id) =>
      data.tableOf('mail.message').where((row) => row['res_id'] == id).toList();

  /// Pumps a screen and lets its debounced work run.
  ///
  /// `pumpAndSettle` only advances while frames are scheduled, and a pending
  /// `Timer` schedules none — so the assign screen's debounced employee lookup
  /// would still be waiting when the assertions ran.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      RoutedTestApp(size: TestSizes.phone, child: signedInScreen(screen)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('assign', () {
    testWidgets('writes the employee and date to Odoo', (tester) async {
      expect(equipment(availableAssetId)['employee_id'], false);

      await pump(tester, const AssignAssetPage(assetId: availableAssetId));

      // Pick the first employee the typeahead offered.
      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, l10n.assignConfirm));
      await tester.pumpAndSettle();

      final row = equipment(availableAssetId);
      expect(row['employee_id'], isNot(false));
      expect(row['assign_date'], isNot(false));
      // Odoo's own form keys `employee_id` visibility off this selection.
      expect(row['equipment_assign_to'], 'employee');
    });

    testWidgets('posts a chatter note naming the employee', (tester) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));

      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, l10n.assignConfirm));
      await tester.pumpAndSettle();

      final notes = notesFor(availableAssetId);
      expect(notes, hasLength(1));
      expect('${notes.single['body']}', contains('Assigned to'));
    });

    testWidgets('confirm stays disabled until an employee is chosen', (
      tester,
    ) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, l10n.assignConfirm),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an Odoo write rejection is explained, not swallowed', (
      tester,
    ) async {
      data.deniedOperations.add('maintenance.equipment.write');

      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, l10n.assignConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorAccessDeniedTitle), findsOneWidget);
      // The asset is untouched, and no fault text leaked.
      expect(equipment(availableAssetId)['employee_id'], false);
      expect(find.textContaining('AccessError'), findsNothing);
    });
  });

  group('return', () {
    testWidgets('clears the assignment on Odoo', (tester) async {
      expect(equipment(assignedAssetId)['employee_id'], isNot(false));

      await pump(tester, const ReturnAssetPage(assetId: assignedAssetId));
      await tester.tap(find.widgetWithText(AppButton, l10n.returnConfirm));
      await tester.pumpAndSettle();

      final row = equipment(assignedAssetId);
      expect(row['employee_id'], false);
      expect(row['assign_date'], false);
      expect(row['equipment_assign_to'], 'other');
    });

    testWidgets('records the condition in the chatter note', (tester) async {
      await pump(tester, const ReturnAssetPage(assetId: assignedAssetId));

      // Switch from the default "Good" to "Damaged".
      await tester.tap(find.text(l10n.conditionDamaged));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, l10n.returnConfirm));
      await tester.pumpAndSettle();

      final notes = notesFor(assignedAssetId);
      expect(notes, isNotEmpty);
      expect('${notes.last['body']}', contains('Damaged'));
    });

    testWidgets('a damaged return leaves the asset marked damaged', (
      tester,
    ) async {
      await pump(tester, const ReturnAssetPage(assetId: assignedAssetId));

      await tester.tap(find.text(l10n.conditionDamaged));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, l10n.returnConfirm));
      await tester.pumpAndSettle();

      // The status is device-local: Odoo has no field for it, so the proof is
      // that the detail screen now reads Damaged for an asset Odoo reports as
      // simply unassigned.
      await pump(tester, const AssetDetailPage(assetId: assignedAssetId));
      expect(find.text(l10n.statusDamaged), findsWidgets);
      expect(find.text(l10n.statusKeptInLog), findsOneWidget);
    });

    testWidgets('a detail screen already on the stack stops being stale', (
      tester,
    ) async {
      // The bug this covers: assigning from the workflow screen wrote to Odoo
      // but left the detail behind it reading "Unassigned", because
      // `context.go` back to a live screen rebuilds nothing and re-runs no
      // `create`. The repository now announces the change and the detail
      // re-reads.
      await tester.pumpWidget(
        RoutedTestApp(
          size: TestSizes.phone,
          child: signedInScreen(
            const AssetDetailPage(assetId: availableAssetId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.labelUnassigned), findsWidgets);

      // A write through the same repository, as a workflow screen would make.
      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: availableAssetId,
          employeeId: 11,
          employeeName: 'Mostafa Bader',
          assignedOn: DateTime(2026, 8, 24),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.labelUnassigned), findsNothing);
      expect(find.text('Mostafa Bader'), findsWidgets);
    });

    testWidgets('a good return leaves the asset available, not overlaid', (
      tester,
    ) async {
      await pump(tester, const ReturnAssetPage(assetId: assignedAssetId));
      await tester.tap(find.widgetWithText(AppButton, l10n.returnConfirm));
      await tester.pumpAndSettle();

      await pump(tester, const AssetDetailPage(assetId: assignedAssetId));
      expect(find.text(l10n.statusAvailable), findsWidgets);
      // Nothing was stored locally, so no device marker.
      expect(find.text(l10n.statusKeptInLog), findsNothing);
    });
  });
}
