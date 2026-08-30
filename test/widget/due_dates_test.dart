import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/return_due.dart';
import 'package:sijil_it/features/assets/domain/usecases/asset_usecases.dart';
import 'package:sijil_it/features/assets/presentation/pages/overdue_assets_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/assignment/domain/entities/assignment.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The expected return date, end to end against a fake Odoo.
///
/// `maintenance.equipment` has no column for this, so the whole feature rests
/// on a clause the app writes into the assignment's chatter note and reads
/// back. That round trip is the thing worth testing: it is what makes the date
/// visible to a colleague on another handset and in the Odoo web client,
/// rather than a promise one phone made to itself.
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

  List<Map<String, dynamic>> notesFor(int id) => data
      .tableOf(OdooModels.mailMessage)
      .where((row) => row['res_id'] == id)
      .toList();

  Future<Asset> read(int id) async {
    final result = await sl<GetAsset>()(id);
    return result.getOrElse(() => throw StateError('asset $id did not read'));
  }

  Future<Asset> assign(int id, {DateTime? dueOn}) async {
    final result = await sl<AssignAsset>()(
      AssignmentRequest(
        assetId: id,
        employeeId: 12,
        employeeName: 'Ahmed Mohamed',
        assignedOn: DateTime(2026, 8, 20),
        dueOn: dueOn,
      ),
    );
    return result.getOrElse(() => throw StateError('assign $id failed'));
  }

  group('recording the date', () {
    test('the handover note carries it, so Odoo has it too', () async {
      await assign(availableAssetId, dueOn: DateTime(2026, 9, 30));

      final note = '${notesFor(availableAssetId).single['body']}';
      // One note, not two. The clause rides along with the handover sentence
      // so that one event stays one line of history.
      expect(note, contains('Assigned to Ahmed Mohamed'));
      expect(note, contains('Due back on 2026-09-30'));
    });

    test('a handover with no date still says so', () async {
      await assign(availableAssetId);

      final note = '${notesFor(availableAssetId).single['body']}';
      // The marker is always written. Reading the date back means "the newest
      // note mentioning it", so a silent note would let a previous holder's
      // loan date follow the asset to its next holder.
      expect(note, contains('Due back'));
      expect(note, isNot(contains('Due back on')));
    });

    test('it reads back off the chatter as a due date', () async {
      await assign(availableAssetId, dueOn: DateTime(2026, 9, 30));

      final asset = await read(availableAssetId);

      expect(asset.dueBack.isSet, isTrue);
      expect(asset.dueBack.date, DateTime(2026, 9, 30));
    });

    test('a date in the past makes the asset overdue', () async {
      await assign(availableAssetId, dueOn: DateTime(2020, 1, 6));

      final asset = await read(availableAssetId);

      expect(asset.isOverdue, isTrue);
      expect(asset.dueBack.state, ReturnDueState.overdue);
    });

    test('handing it over again replaces the old date', () async {
      await assign(availableAssetId, dueOn: DateTime(2020, 1, 6));
      expect((await read(availableAssetId)).isOverdue, isTrue);

      // The bug this guards: the second handover writes a note with no date,
      // and the *first* note is still in the chatter saying 2020. Reading the
      // newest one is what stops a freshly-issued laptop being five years late.
      await assign(availableAssetId);

      final asset = await read(availableAssetId);
      expect(asset.dueBack.isSet, isFalse);
      expect(asset.isOverdue, isFalse);
    });

    test('returning it ends the obligation', () async {
      await assign(assignedAssetId, dueOn: DateTime(2020, 1, 6));
      expect((await read(assignedAssetId)).isOverdue, isTrue);

      final returned = await sl<ReturnAsset>()(
        ReturnRequest(
          assetId: assignedAssetId,
          condition: ReturnCondition.good,
          returnedOn: DateTime(2026, 8, 30),
        ),
      );
      returned.getOrElse(() => throw StateError('return failed'));

      // The note that set the date is still in the chatter — it is history.
      // An asset back on the shelf is not late for anything.
      final asset = await read(assignedAssetId);
      expect(asset.isAssigned, isFalse);
      expect(asset.isOverdue, isFalse);
    });
  });

  group('the overdue screen', () {
    testWidgets('lists what is late and nothing else', (tester) async {
      await assign(availableAssetId, dueOn: DateTime(2020, 1, 6));
      // Assigned with a date years away: on loan, not late.
      await assign(assignedAssetId, dueOn: DateTime(2099, 1, 6));

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const OverdueAssetsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AssetRow), findsOneWidget);
      expect(find.text('ThinkPad X1 Carbon G12'), findsOneWidget);
      expect(find.text('MacBook Pro M4'), findsNothing);
      expect(find.text(l10n.overdueCount(1)), findsOneWidget);
    });

    testWidgets('says so plainly when nothing is late', (tester) async {
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const OverdueAssetsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // "Nothing is late" and not an empty list: the fixture's assets are all
      // dateless, which is the normal state of a fleet and not an absence of
      // data.
      expect(find.text(l10n.overdueEmptyTitle), findsOneWidget);
      expect(find.byType(AssetRow), findsNothing);
    });

    test('the filter is the only thing that makes it a different list', () {
      // The screen is the asset list with one filter on it, so the filter has
      // to be the thing that narrows — not a second query written by hand.
      const filters = OverdueAssetsPage.filters;

      expect(filters.overdueOnly, isTrue);
      // Odoo can narrow "assigned" server-side; it cannot compare a date that
      // lives in a chatter note against today, which is why this pairing is
      // what keeps the scan small.
      expect(filters.needsClientSideNarrowing, isTrue);
      expect(filters.activeCount, greaterThan(0));
    });
  });
}
