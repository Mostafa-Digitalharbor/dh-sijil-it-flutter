import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/error/failure_presenter.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/network/odoo/odoo_name_ref.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_detail_sections.dart';
import 'package:sijil_it/features/assignment/presentation/widgets/return_photo_strip.dart';
import 'package:sijil_it/features/assignment/presentation/widgets/workflow_asset_strip.dart';
import 'package:sijil_it/features/handover/domain/entities/handover.dart';
import 'package:sijil_it/features/handover/presentation/cubit/handover_cubit.dart';
import 'package:sijil_it/features/handover/presentation/widgets/asset_picker_sheet.dart';
import 'package:sijil_it/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:sijil_it/features/scanner/presentation/cubit/scanner_cubit.dart';
import 'package:sijil_it/features/scanner/presentation/widgets/scan_result_sheet.dart';
import 'package:sijil_it/features/scanner/presentation/widgets/scanner_viewfinder.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/cubit/view_state.dart';
import 'package:sijil_it/shared/widgets/app_avatar.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';
import 'package:sijil_it/shared/widgets/photo_strip.dart';
import 'package:sijil_it/shared/widgets/status_chip.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The widgets a single feature owns, but that carry a decision of their own.
///
/// A strip of thumbnails, a viewfinder, a sheet of search results: each one is
/// small enough to look obvious and each one has a case that only shows up
/// with a real value in it — a photo the OS has since deleted, a landscape
/// phone with no room for a square, a bundle that is already full.
/// Advances past the search debounce and then lets the frames settle.
Future<void> settleSearch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  late AppL10n en;
  late AppL10n ar;

  setUpAll(() async {
    en = await loadL10n();
    ar = await loadL10n('ar');
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    Size size = TestSizes.phone,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: size,
        textScale: textScale,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  Asset assetWith({
    String name = 'MacBook Pro M4',
    AssetStatus status = AssetStatus.available,
    String? assetTag,
    String? serialNumber,
    String? model,
    String? notes,
    OdooNameRef? holder,
    DateTime? since,
  }) => Asset(
    id: 101,
    name: name,
    status: status,
    assetTag: assetTag,
    serialNumber: serialNumber,
    model: model,
    notes: notes,
    assignedEmployee: holder,
    assignmentDate: since,
  );

  MaintenanceRequest requestWith({
    required int id,
    required String name,
    bool isDone = false,
    String? stage,
    DateTime? scheduledFor,
    DateTime? closedOn,
  }) => MaintenanceRequest(
    id: id,
    name: name,
    priority: MaintenancePriority.normal,
    isDone: isDone,
    stage: stage == null ? null : OdooNameRef(1, stage),
    scheduledFor: scheduledFor,
    closedOn: closedOn,
  );

  group('AssetNotesSection', () {
    testWidgets('an asset with no note gets no block', (tester) async {
      // An empty "Notes" card on every asset is a row of nothing to scroll
      // past on the screen people open most.
      await pump(tester, AssetNotesSection(asset: assetWith()));

      expect(tester.getSize(find.byType(AssetNotesSection)), Size.zero);
    });

    testWidgets('and neither does a note that is only whitespace', (
      tester,
    ) async {
      await pump(tester, AssetNotesSection(asset: assetWith(notes: '')));

      expect(tester.getSize(find.byType(AssetNotesSection)), Size.zero);
    });

    testWidgets('a real note is offered collapsed, and opens on a tap', (
      tester,
    ) async {
      await pump(
        tester,
        AssetNotesSection(asset: assetWith(notes: 'Screen replaced in June.')),
      );

      expect(find.text(en.labelNotes), findsOneWidget);
      final collapsed = tester.getSize(find.byType(AssetNotesSection)).height;

      await tester.tap(find.text(en.labelNotes));
      await tester.pumpAndSettle();

      expect(find.text('Screen replaced in June.'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AssetNotesSection)).height,
        greaterThan(collapsed),
      );
    });
  });

  group('AssetMaintenanceSection', () {
    testWidgets('an asset that has never been serviced gets no block', (
      tester,
    ) async {
      await pump(
        tester,
        AssetMaintenanceSection(
          open: const <MaintenanceRequest>[],
          closed: const <MaintenanceRequest>[],
          onOpenRequest: (_) {},
        ),
      );

      expect(tester.getSize(find.byType(AssetMaintenanceSection)), Size.zero);
    });

    testWidgets('open work is already showing — it is why someone looked', (
      tester,
    ) async {
      await pump(
        tester,
        AssetMaintenanceSection(
          open: <MaintenanceRequest>[
            requestWith(id: 1, name: 'Battery swelling', stage: 'In progress'),
          ],
          closed: const <MaintenanceRequest>[],
          onOpenRequest: (_) {},
        ),
      );

      expect(find.text('Battery swelling'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
    });

    testWidgets('history alone stays folded away', (tester) async {
      await pump(
        tester,
        AssetMaintenanceSection(
          open: const <MaintenanceRequest>[],
          closed: <MaintenanceRequest>[
            requestWith(
              id: 2,
              name: 'Keyboard replaced',
              isDone: true,
              closedOn: DateTime(2026, 8, 21),
            ),
          ],
          onOpenRequest: (_) {},
        ),
      );

      expect(find.text(en.sectionMaintenance), findsOneWidget);
      final folded = tester
          .getSize(find.byType(AssetMaintenanceSection))
          .height;

      await tester.tap(find.text(en.sectionMaintenance));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(AssetMaintenanceSection)).height,
        greaterThan(folded),
      );
      expect(find.text('Keyboard replaced'), findsOneWidget);
    });

    testWidgets('open work is listed before closed work', (tester) async {
      // The order someone triaging a device reads them in.
      await pump(
        tester,
        AssetMaintenanceSection(
          open: <MaintenanceRequest>[requestWith(id: 1, name: 'Battery')],
          closed: <MaintenanceRequest>[
            requestWith(
              id: 2,
              name: 'Keyboard',
              isDone: true,
              closedOn: DateTime(2026, 8, 21),
            ),
          ],
          onOpenRequest: (_) {},
        ),
      );

      expect(
        tester.getTopLeft(find.text('Battery')).dy,
        lessThan(tester.getTopLeft(find.text('Keyboard')).dy),
      );
    });

    testWidgets('a closed request is marked done, an open one is not', (
      tester,
    ) async {
      await pump(
        tester,
        AssetMaintenanceSection(
          open: <MaintenanceRequest>[requestWith(id: 1, name: 'Battery')],
          closed: <MaintenanceRequest>[
            requestWith(
              id: 2,
              name: 'Keyboard',
              isDone: true,
              closedOn: DateTime(2026, 8, 21),
            ),
          ],
          onOpenRequest: (_) {},
        ),
      );

      expect(find.byIcon(Icons.build_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('tapping a row hands back the request that was tapped', (
      tester,
    ) async {
      MaintenanceRequest? opened;
      await pump(
        tester,
        AssetMaintenanceSection(
          open: <MaintenanceRequest>[
            requestWith(id: 1, name: 'Battery'),
            requestWith(id: 7, name: 'Fan noise'),
          ],
          closed: const <MaintenanceRequest>[],
          onOpenRequest: (request) => opened = request,
        ),
      );

      await tester.tap(find.text('Fan noise'));
      await tester.pump();
      expect(opened?.id, 7);
    });

    testWidgets('a scheduled check is named beside the stage', (tester) async {
      await pump(
        tester,
        AssetMaintenanceSection(
          open: <MaintenanceRequest>[
            requestWith(
              id: 1,
              name: 'Annual service',
              stage: 'New',
              scheduledFor: DateTime(2026, 12, 1),
            ),
          ],
          closed: const <MaintenanceRequest>[],
          onOpenRequest: (_) {},
        ),
      );

      expect(find.textContaining(en.maintenanceNextScheduled), findsOneWidget);
    });

    testWidgets('the block survives Arabic at the text ceiling', (
      tester,
    ) async {
      await pump(
        tester,
        AssetMaintenanceSection(
          open: <MaintenanceRequest>[
            requestWith(
              id: 1,
              name: 'انتفاخ في البطارية ويحتاج استبدالًا عاجلًا قبل السفر',
              stage: 'قيد التنفيذ',
              scheduledFor: DateTime(2026, 12, 1),
            ),
          ],
          closed: const <MaintenanceRequest>[],
          onOpenRequest: (_) {},
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(find.text(ar.sectionMaintenance), findsOneWidget);
    });
  });

  group('WorkflowAssetStrip', () {
    testWidgets('the assign screen leads with the asset and its identifier', (
      tester,
    ) async {
      // The chip beside it already carries the status, so the subtitle spends
      // itself on the tag rather than saying "Available · Available".
      await pump(
        tester,
        WorkflowAssetStrip(asset: assetWith(assetTag: 'DH-LAP-0027')),
      );

      expect(find.text('MacBook Pro M4'), findsOneWidget);
      expect(find.text('DH-LAP-0027'), findsOneWidget);
      expect(find.byType(StatusChip), findsOneWidget);
    });

    testWidgets('it falls back to the serial, then the model', (tester) async {
      await pump(
        tester,
        WorkflowAssetStrip(
          asset: assetWith(serialNumber: 'C02XK1YZQ6L4', model: 'A2779'),
        ),
      );
      expect(find.text('C02XK1YZQ6L4'), findsOneWidget);

      await pump(tester, WorkflowAssetStrip(asset: assetWith(model: 'A2779')));
      expect(find.text('A2779'), findsOneWidget);
    });

    testWidgets('and an asset with no identifier at all still renders', (
      tester,
    ) async {
      await pump(tester, WorkflowAssetStrip(asset: assetWith()));

      expect(find.text('MacBook Pro M4'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('the return screen leads with the holder instead', (
      tester,
    ) async {
      await pump(
        tester,
        WorkflowAssetStrip(
          showHolder: true,
          asset: assetWith(
            status: AssetStatus.assigned,
            holder: const OdooNameRef(11, 'Ahmed Mohamed'),
            since: DateTime.now().subtract(const Duration(days: 12)),
          ),
        ),
      );

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.byType(AppLeadingTile), findsNothing);
      expect(find.textContaining('Ahmed Mohamed'), findsOneWidget);
      expect(find.textContaining(en.returnHeldFor(12)), findsOneWidget);
    });

    testWidgets('a handover this morning reads as zero days, not a fraction', (
      tester,
    ) async {
      await pump(
        tester,
        WorkflowAssetStrip(
          showHolder: true,
          asset: assetWith(
            status: AssetStatus.assigned,
            holder: const OdooNameRef(11, 'Ahmed Mohamed'),
            since: DateTime.now(),
          ),
        ),
      );

      expect(find.textContaining(en.returnHeldFor(0)), findsOneWidget);
    });

    testWidgets('an assigned asset with no holder does not claim one', (
      tester,
    ) async {
      // Odoo can hold an "assigned" state with the relation cleared.
      await pump(
        tester,
        WorkflowAssetStrip(
          showHolder: true,
          asset: assetWith(status: AssetStatus.assigned),
        ),
      );

      expect(find.byType(AppLeadingTile), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('it fits a small phone in Arabic at the text ceiling', (
      tester,
    ) async {
      await pump(
        tester,
        WorkflowAssetStrip(
          showHolder: true,
          asset: assetWith(
            name: 'حاسوب ماك بوك برو الجيل الرابع عشر بوصة',
            status: AssetStatus.assigned,
            holder: const OdooNameRef(11, 'أحمد محمد عبد الرحمن'),
            since: DateTime.now().subtract(const Duration(days: 12)),
          ),
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  group('WorkflowDateField', () {
    testWidgets('today is marked, because today is what it defaults to', (
      tester,
    ) async {
      await pump(
        tester,
        WorkflowDateField(
          label: 'Date',
          value: DateTime.now(),
          onChanged: (_) {},
        ),
      );

      expect(find.text(en.actionToday), findsOneWidget);
    });

    testWidgets('and any other date is not', (tester) async {
      await pump(
        tester,
        WorkflowDateField(
          label: 'Date',
          value: DateTime(2026, 3, 4),
          onChanged: (_) {},
        ),
      );

      expect(find.text(en.actionToday), findsNothing);
    });

    testWidgets('an unset date says so rather than showing an empty field', (
      tester,
    ) async {
      await pump(
        tester,
        WorkflowDateField(label: 'Date', value: null, onChanged: (_) {}),
      );

      expect(find.text(en.labelUnknown), findsOneWidget);
      expect(find.text(en.actionToday), findsNothing);
    });

    testWidgets('the label can be suppressed where a step header names it', (
      tester,
    ) async {
      await pump(
        tester,
        WorkflowDateField(
          label: 'Date',
          value: DateTime(2026, 3, 4),
          showLabel: false,
          onChanged: (_) {},
        ),
      );

      expect(find.text('DATE'), findsNothing);
    });
  });

  group('ReturnPhotoStrip', () {
    testWidgets('an empty strip offers only the add tile', (tester) async {
      await pump(
        tester,
        ReturnPhotoStrip(
          paths: const <String>[],
          canAdd: true,
          onAdd: () {},
          onRemove: (_) {},
        ),
      );

      expect(find.byType(PhotoAddTile), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('the add tile disappears at the cap rather than failing after '
        'the tap', (tester) async {
      await pump(
        tester,
        ReturnPhotoStrip(
          paths: const <String>['a.jpg', 'b.jpg'],
          canAdd: false,
          onAdd: () {},
          onRemove: (_) {},
        ),
      );

      expect(find.byType(PhotoAddTile), findsNothing);
    });

    testWidgets('a file the OS has cleaned up shows a placeholder, not a red '
        'box', (tester) async {
      // The user is still filling in the form; a rendering error here would
      // replace a thumbnail with a crash report.
      await pump(
        tester,
        ReturnPhotoStrip(
          paths: const <String>['/no/such/file.jpg'],
          canAdd: true,
          onAdd: () {},
          onRemove: (_) {},
        ),
      );
      // Reading the file is real I/O, which the fake clock a widget test runs
      // on will never advance to.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      // Twice: one frame to deliver the failure, one to rebuild on it.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('removing hands back the path that was removed', (
      tester,
    ) async {
      final removed = <String>[];
      await pump(
        tester,
        ReturnPhotoStrip(
          paths: const <String>['/a.jpg', '/b.jpg'],
          canAdd: false,
          onAdd: () {},
          onRemove: removed.add,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pump();
      expect(removed, <String>['/b.jpg']);
    });

    testWidgets('adding is reachable past a strip full of photos', (
      tester,
    ) async {
      // The strip scrolls; the add tile is the last item, and a Row would
      // have put it off the edge.
      await pump(
        tester,
        ReturnPhotoStrip(
          paths: const <String>['/a.jpg', '/b.jpg', '/c.jpg', '/d.jpg'],
          canAdd: true,
          onAdd: () {},
          onRemove: (_) {},
        ),
        size: TestSizes.smallPhone,
      );
      await tester.pump();

      expectNoOverflow(tester);
      await tester.drag(find.byType(ListView), const Offset(-400, 0));
      await tester.pump();
      expect(find.byType(PhotoAddTile), findsOneWidget);
    });

    testWidgets('both controls are named for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ReturnPhotoStrip(
          paths: const <String>['/a.jpg'],
          canAdd: true,
          onAdd: () {},
          onRemove: (_) {},
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(en.actionAdd)), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(en.actionRemove)), findsWidgets);
      handle.dispose();
    });
  });

  group('PhotoAddTile', () {
    testWidgets('it is a square the size of a thumbnail', (tester) async {
      // So the add target lines up with the photos it sits beside.
      await pump(
        tester,
        Align(
          child: SizedBox.square(
            dimension: AppDimens.photoThumb,
            child: PhotoAddTile(onTap: () {}),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(PhotoAddTile)),
        const Size(AppDimens.photoThumb, AppDimens.photoThumb),
      );
    });
  });

  group('ScannerViewfinder', () {
    testWidgets('it draws four brackets around a square', (tester) async {
      await pump(tester, const Center(child: ScannerViewfinder()));

      final side = tester.getSize(find.byType(ScannerViewfinder));
      expect(side.width, side.height);
      expect(side.width, AppDimens.scannerFinder);
    });

    testWidgets('it shrinks rather than overflowing a landscape phone', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          height: 180,
          width: 200,
          child: Center(child: ScannerViewfinder()),
        ),
      );

      expectNoOverflow(tester);
      expect(
        tester.getSize(find.byType(ScannerViewfinder)).width,
        lessThan(AppDimens.scannerFinder),
      );
    });

    testWidgets('and draws nothing at all when there is no room', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(height: 8, width: 8, child: ScannerViewfinder()),
      );

      // Not a clipped bracket and not an overflow bar: a finder that cannot
      // be aimed is worse than no finder.
      expect(
        find.descendant(
          of: find.byType(ScannerViewfinder),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      expectNoOverflow(tester);
    });

    testWidgets('the scan line sweeps rather than sitting still', (
      tester,
    ) async {
      await pump(tester, const Center(child: ScannerViewfinder()));

      final start = tester.getTopLeft(
        find.descendant(
          of: find.byType(ScannerViewfinder),
          matching: find.byType(Container),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(ScannerViewfinder),
                matching: find.byType(Container),
              ),
            )
            .dy,
        isNot(start.dy),
      );
    });
  });

  group('ScannerScrim', () {
    testWidgets('it darkens the frame without eating the pointer', (
      tester,
    ) async {
      // The torch and mode controls sit under it.
      var taps = 0;
      await pump(
        tester,
        SizedBox(
          height: 200,
          child: Stack(
            children: <Widget>[
              Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('torch'),
                ),
              ),
              const ScannerScrim(),
            ],
          ),
        ),
      );

      await tester.tap(find.text('torch'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the scrim is a veil, not a blackout', (tester) async {
      await pump(tester, const SizedBox(height: 100, child: ScannerScrim()));

      final painted = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScannerScrim),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(painted.color.a, greaterThan(0));
      expect(
        painted.color.a,
        lessThan(1),
        reason: 'the camera has to stay visible through it',
      );
    });
  });

  group('ScanResultSheet', () {
    late FakeOdooData data;

    setUp(() async {
      data = FakeOdooData.seeded();
      await configureTestDependencies(data: data);
      await signInForTest(data);
    });

    tearDown(() async => sl.reset());

    Future<void> pumpSheet(WidgetTester tester, ScannerState state) async {
      await tester.pumpWidget(
        BlocProvider<ScannerCubit>(
          create: (_) => sl<ScannerCubit>(),
          child: TestApp(
            size: TestSizes.phone,
            child: Scaffold(body: ScanResultSheet(state: state)),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a lookup in flight says so instead of showing a stale match', (
      tester,
    ) async {
      await pumpSheet(tester, const ScannerState(isResolving: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(en.loadingLabel), findsOneWidget);
    });

    testWidgets('a match names the asset and offers to open it', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        ScannerState(
          lastCode: 'sijil://101',
          match: assetWith(assetTag: 'DH-LAP-0027'),
        ),
      );

      expect(find.text('MacBook Pro M4'), findsOneWidget);
      expect(find.text('DH-LAP-0027'), findsOneWidget);
      expect(find.text(en.scanMatched('sijil://101')), findsOneWidget);
      expect(find.text(en.actionOpen), findsOneWidget);
    });

    testWidgets('an unregistered code is not an error, it is an invitation', (
      tester,
    ) async {
      await pumpSheet(tester, const ScannerState(unmatchedCode: 'ABC-123'));

      expect(find.text(en.scanNoMatchTitle), findsOneWidget);
      expect(find.text(en.scanNoMatchBody('ABC-123')), findsOneWidget);
      expect(find.text(en.scanCreateAsset), findsOneWidget);
      expect(find.text(en.scanAgain), findsOneWidget);
    });

    testWidgets('a failed lookup is explained in the words of the failure', (
      tester,
    ) async {
      const failure = Failure(kind: FailureKind.serverUnreachable);
      await pumpSheet(
        tester,
        const ScannerState(status: ViewStatus.failure, failure: failure),
      );

      final presented = FailurePresenter.present(en, failure);
      expect(find.text(presented.title), findsOneWidget);
      expect(find.text(presented.fix), findsOneWidget);
      expect(find.text(en.scanAgain), findsOneWidget);
    });

    testWidgets('and a failure outranks a stale match still in the state', (
      tester,
    ) async {
      // The camera keeps running while a lookup fails; the card must not go
      // on offering the asset the *previous* code resolved to.
      await pumpSheet(
        tester,
        ScannerState(
          status: ViewStatus.failure,
          failure: const Failure(kind: FailureKind.serverUnreachable),
          match: assetWith(),
        ),
      );

      expect(find.text(en.actionOpen), findsNothing);
    });

    testWidgets('scanning again clears the result', (tester) async {
      await pumpSheet(tester, const ScannerState(unmatchedCode: 'ABC-123'));

      await tester.tap(find.text(en.scanAgain));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card fits a small phone in Arabic at the text ceiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider<ScannerCubit>(
          create: (_) => sl<ScannerCubit>(),
          child: TestApp(
            locale: const Locale('ar'),
            size: TestSizes.smallPhone,
            textScale: AppTextScale.max,
            child: Scaffold(
              body: ScanResultSheet(
                state: ScannerState(
                  lastCode: 'sijil://101',
                  match: assetWith(
                    name: 'حاسوب ماك بوك برو الجيل الرابع عشر بوصة',
                    assetTag: 'DH-LAP-0027',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expectNoOverflow(tester);
      expect(find.text(ar.actionOpen), findsOneWidget);
    });
  });

  group('AssetPickerSheet', () {
    late FakeOdooData data;
    late HandoverCubit cubit;

    setUp(() async {
      data = FakeOdooData.seeded();
      await configureTestDependencies(data: data);
      await signInForTest(data);
      cubit = sl<HandoverCubit>();
    });

    tearDown(() async {
      await cubit.close();
      await sl.reset();
    });

    /// Pumps the sheet and lets the debounced first page land.
    ///
    /// `pumpAndSettle` alone is not enough: the search is debounced, and a
    /// pending timer is not a scheduled frame — the sheet would still be
    /// showing its skeleton when the assertion ran.
    Future<void> pumpPicker(
      WidgetTester tester, {
      Set<int> alreadyChosen = const <int>{},
      Locale locale = const Locale('en'),
      Size size = TestSizes.phone,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(
        BlocProvider<HandoverCubit>.value(
          value: cubit,
          child: TestApp(
            locale: locale,
            size: size,
            textScale: textScale,
            child: Scaffold(
              body: AssetPickerSheet(alreadyChosen: alreadyChosen),
            ),
          ),
        ),
      );
      cubit.start();
      await settleSearch(tester);
    }

    testWidgets('it offers the assignable assets, and says what it is for', (
      tester,
    ) async {
      await pumpPicker(tester);

      expect(find.text(en.handoverPickAssets), findsOneWidget);
      expect(find.byType(AppSelectableTile), findsWidgets);
    });

    testWidgets('an asset already in the bundle is not offered again', (
      tester,
    ) async {
      await pumpPicker(tester);
      final offered = tester.widgetList<AppSelectableTile>(
        find.byType(AppSelectableTile),
      );
      final first = offered.first.title;

      final id = cubit.state.available.firstWhere((a) => a.name == first).id;
      await pumpPicker(tester, alreadyChosen: <int>{id});

      expect(find.text(first), findsNothing);
    });

    testWidgets('the confirm button counts what has been picked', (
      tester,
    ) async {
      await pumpPicker(tester);

      // Nothing picked: the only thing the button can do is close, so it is
      // the quiet one.
      expect(find.text(en.actionCancel), findsOneWidget);

      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pump();

      expect(find.text(en.handoverAddCount(1)), findsOneWidget);
      expect(find.text(en.actionCancel), findsNothing);
    });

    testWidgets('tapping a picked row un-picks it', (tester) async {
      // A multi-select sheet where a second tap does nothing is a trap.
      await pumpPicker(tester);

      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pump();
      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pump();

      expect(find.text(en.actionCancel), findsOneWidget);
    });

    testWidgets('a search with no matches says so rather than showing '
        'nothing', (tester) async {
      await pumpPicker(tester);

      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await settleSearch(tester);

      expect(find.text(en.handoverNoAssignableAssets), findsOneWidget);
    });

    testWidgets('it cannot hand back more than the bundle has room for', (
      tester,
    ) async {
      // The bundle is already at the cap. The handover screen disables the
      // button that opens this sheet in that state, so this is the second
      // line of defence — and the one that matters if the first ever moves:
      // a thirteenth asset picked here would be dropped without a word on
      // the screen after.
      await pumpPicker(
        tester,
        alreadyChosen: <int>{
          for (var i = 0; i < HandoverBundle.maxAssets; i++) 9000 + i,
        },
      );

      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pump();

      expect(find.text(en.actionCancel), findsOneWidget);
      expect(find.text(en.handoverAddCount(1)), findsNothing);
    });

    testWidgets('the sheet survives Arabic at the text ceiling', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(find.text(ar.handoverPickAssets), findsOneWidget);
    });
  });
}
