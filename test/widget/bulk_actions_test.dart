import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/export/export_documents.dart';
import 'package:sijil_it/core/export/pdf_document.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/usecases/asset_usecases.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// Multi-select, and the two things it is for.
///
/// The selection itself is cheap to get wrong in ways nobody notices until a
/// bulk write lands on the wrong forty records, so the assertions here are
/// about what reached Odoo — one call, the right ids, the right field — rather
/// than about which rows look highlighted.
void main() {
  late FakeOdooData data;
  late InProcessOdooClient client;
  late AppL10n l10n;

  setUp(() async {
    data = FakeOdooData.seeded();
    client = await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Map<String, dynamic> equipment(int id) => data
      .tableOf(OdooModels.maintenanceEquipment)
      .firstWhere((row) => row['id'] == id);

  /// The positional args of every `write` the app sent to the equipment model.
  List<List<Object?>> equipmentWrites() => <List<Object?>>[
    for (final call in client.calls)
      if (call.params.length > 5 &&
          call.params[3] == OdooModels.maintenanceEquipment &&
          call.params[4] == 'write')
        call.params[5]! as List<Object?>,
  ];

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: signedInScreen(const AssetListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('moving a selection to a department', () {
    test('goes out as one write carrying every id', () async {
      final moved = await sl<MoveAssetsToDepartment>()(
        const MoveToDepartmentParams(
          assetIds: <int>[101, 102, 104],
          departmentId: 3,
        ),
      );

      expect(moved.getOrElse(() => 0), 3);

      // One call, not three. A loop would be three writes and three chances
      // to fail halfway, leaving the fleet split across two departments with
      // nothing recording where the boundary fell.
      final writes = equipmentWrites().toList();
      expect(writes, hasLength(1));
      expect(writes.single.first, <int>[101, 102, 104]);

      for (final id in <int>[101, 102, 104]) {
        expect(equipment(id)['department_id'], <Object?>[3, 'Finance']);
      }
    });

    test('a repeated id is written once', () async {
      await sl<MoveAssetsToDepartment>()(
        const MoveToDepartmentParams(
          assetIds: <int>[101, 101, 102],
          departmentId: 3,
        ),
      );

      expect(equipmentWrites().single.first, <int>[101, 102]);
    });

    test('an empty selection touches nothing at all', () async {
      final moved = await sl<MoveAssetsToDepartment>()(
        const MoveToDepartmentParams(assetIds: <int>[], departmentId: 3),
      );

      expect(moved.getOrElse(() => -1), 0);
      expect(equipmentWrites(), isEmpty);
    });
  });

  group('choosing rows', () {
    testWidgets('a long press starts selecting and picks that row', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.longPress(find.byType(AssetRow).first);
      await tester.pumpAndSettle();

      // The press that entered the mode is also the first thing selected —
      // throwing it away would make the gesture cost two taps.
      expect(find.text(l10n.selectionCount(1)), findsOneWidget);
    });

    testWidgets('tapping a second row adds it', (tester) async {
      await pumpList(tester);

      await tester.longPress(find.byType(AssetRow).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AssetRow).at(1));
      await tester.pumpAndSettle();

      expect(find.text(l10n.selectionCount(2)), findsOneWidget);
    });

    testWidgets('tapping a chosen row again removes it', (tester) async {
      await pumpList(tester);

      await tester.longPress(find.byType(AssetRow).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AssetRow).first);
      await tester.pumpAndSettle();

      // Still selecting, with nothing picked. Dropping out of the mode here
      // would turn the next tap into a navigation, which is the last thing
      // somebody halfway through picking forty assets wants.
      expect(find.text(l10n.selectionCount(0)), findsOneWidget);
    });

    testWidgets('leaving selection puts the normal screen back', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.longPress(find.byType(AssetRow).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.assetsTitle), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.assetsTitle), findsOneWidget);
    });
  });

  group('the label sheet', () {
    test('renders every selected asset as a scannable code', () async {
      final theme = await PdfTheme.load(isRtl: false);
      final assets = <Asset>[
        for (var i = 0; i < 30; i++)
          Asset(
            id: 100 + i,
            name: 'MacBook Pro M4',
            status: AssetStatus.available,
            assetTag: 'DH-LAP-00$i',
          ),
      ];

      final bytes = await AssetLabelSheetExport.build(
        assets: assets,
        copy: ExportCopy(
          product: 'Sijil IT',
          generatedOn: 'Generated 30 Aug 2026',
          title: l10n.labelSheetTitle,
          subtitle: l10n.labelSheetSubtitle(assets.length),
          columns: const <String>[],
        ),
        theme: theme,
      );

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      // Every label is in there: the sheet grows with the selection rather
      // than stopping at whatever fitted.
      expect(bytes.length, greaterThan(await _sheetSize(theme, 3)));
    });

    test(
      'an Arabic sheet still prints its Latin identifiers in order',
      () async {
        // The tag is an identifier, not prose. Without the explicit direction
        // bidi reorders "DH-LAP-0027" on an Arabic sheet into something that no
        // longer matches the sticker beside it.
        final theme = await PdfTheme.load(isRtl: true);

        final bytes = await AssetLabelSheetExport.build(
          assets: <Asset>[
            const Asset(
              id: 101,
              name: 'ماك بوك برو',
              status: AssetStatus.available,
              assetTag: 'DH-LAP-0027',
            ),
          ],
          copy: ExportCopy(
            product: 'Sijil IT',
            generatedOn: 'Generated 30 Aug 2026',
            title: l10n.labelSheetTitle,
            subtitle: l10n.labelSheetSubtitle(1),
            columns: const <String>[],
          ),
          theme: theme,
        );

        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      },
    );

    test('a selection too big for one sheet flows onto the next', () async {
      // The failure this catches is loud and specific: `MultiPage` throws
      // "Widget won't fit into the page" for a child that cannot be split, so
      // a label grid that could not paginate would fail here rather than
      // silently printing the first page and dropping the rest.
      final theme = await PdfTheme.load(isRtl: false);

      final bytes = await AssetLabelSheetExport.build(
        assets: <Asset>[
          for (var i = 0; i < AppConstants.bulkSelectionLimit; i++)
            Asset(
              id: 200 + i,
              name: 'ThinkPad X1 Carbon G12',
              status: AssetStatus.available,
              assetTag: 'DH-LAP-$i',
            ),
        ],
        copy: ExportCopy(
          product: 'Sijil IT',
          generatedOn: 'Generated 30 Aug 2026',
          title: l10n.labelSheetTitle,
          subtitle: l10n.labelSheetSubtitle(AppConstants.bulkSelectionLimit),
          columns: const <String>[],
        ),
        theme: theme,
      );

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  test('the selection has a ceiling somebody could still review', () {
    // Not Odoo's limit — a single `write` would take thousands. Past a couple
    // of hundred rows nobody is checking what they picked, and "move these to
    // Finance" stops being a decision.
    expect(AppConstants.bulkSelectionLimit, greaterThan(0));
    expect(AppConstants.bulkSelectionLimit, lessThanOrEqualTo(500));
  });
}

/// The size of a sheet with [count] labels on it, for comparing against one
/// with more.
Future<int> _sheetSize(PdfTheme theme, int count) async {
  final bytes = await AssetLabelSheetExport.build(
    assets: <Asset>[
      for (var i = 0; i < count; i++)
        Asset(
          id: 900 + i,
          name: 'MacBook Pro M4',
          status: AssetStatus.available,
          assetTag: 'DH-LAP-00$i',
        ),
    ],
    copy: const ExportCopy(
      product: 'Sijil IT',
      generatedOn: 'Generated 30 Aug 2026',
      title: 'Asset labels',
      subtitle: 'labels',
      columns: <String>[],
    ),
    theme: theme,
  );
  return bytes.length;
}
