import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/core/error/exceptions.dart';
import 'package:sijil_it/core/export/file_share.dart';
import 'package:sijil_it/core/network/connectivity/network_info.dart';
import 'package:sijil_it/core/network/odoo/odoo_name_ref.dart';
import 'package:sijil_it/core/sync/offline_reads.dart';
import 'package:sijil_it/core/sync/outbox_entry.dart';
import 'package:sijil_it/core/sync/outbox_store.dart';
import 'package:sijil_it/core/sync/sync_service.dart';
import 'package:sijil_it/features/assets/domain/entities/return_due.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assets/presentation/cubit/asset_list_cubit.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_selection_bar.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/auth/presentation/pages/splash_page.dart';
import 'package:sijil_it/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:sijil_it/features/maintenance/presentation/pages/maintenance_list_page.dart';
import 'package:sijil_it/features/settings/presentation/widgets/reminders_card.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/cubit/sync_cubit.dart';
import 'package:sijil_it/shared/widgets/app_chip.dart';
import 'package:sijil_it/shared/widgets/app_segmented.dart';
import 'package:sijil_it/shared/widgets/export_action.dart';
import 'package:sijil_it/shared/widgets/status_chip.dart';
import 'package:sijil_it/shared/widgets/sync_banner.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The widgets no test had ever built.
///
/// A sweep of every public widget in `lib` against every identifier named in
/// `test/` turned up nine that nothing mounted. Most are reachable only from a
/// state the broader screen tests never reproduce — a selection bar that needs
/// rows picked, a banner that needs a queue, a button mid-export — which is
/// exactly the shape of thing that breaks quietly and is found by a user
/// rather than by a build.
void main() {
  late AppL10n en;

  setUpAll(() async => en = await loadL10n());

  setUp(() async => configureTestDependencies(data: FakeOdooData.seeded()));

  tearDown(() async => sl.reset());

  /// A queued write, in the only shape the banner cares about: that it exists.
  OutboxEntry anOutboxEntry({int attempts = 0}) => OutboxEntry(
    id: 'entry-$attempts',
    kind: OutboxKind.assignAsset,
    subjectId: 101,
    subjectName: 'MacBook Pro',
    payload: const <String, dynamic>{},
    queuedAt: DateTime(2026, 8, 29),
    attempts: attempts,
  );

  MaintenanceRequest aRequest({
    String name = 'Screen flicker',
    MaintenancePriority priority = MaintenancePriority.low,
    DateTime? scheduledFor,
    bool isDone = false,
  }) => MaintenanceRequest(
    id: 501,
    name: name,
    priority: priority,
    equipment: const OdooNameRef(101, 'MacBook Pro'),
    stage: const OdooNameRef(1, 'New Request'),
    type: MaintenanceType.corrective,
    requestedOn: DateTime(2026, 8, 20),
    scheduledFor: scheduledFor,
    isDone: isDone,
  );

  // ── AssetSelectionBar ────────────────────────────────────────────────────
  //
  // Bulk actions are the one place a wrong enablement is expensive: the point
  // of the bar is that it acts on many rows at once.
  group('AssetSelectionBar', () {
    Future<void> pump(
      WidgetTester tester,
      AssetListState state, {
      VoidCallback? onMove,
      VoidCallback? onLabels,
      Size size = TestSizes.phone,
      Locale locale = const Locale('en'),
      double textScale = 1,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        TestApp(
          size: size,
          locale: locale,
          textScale: textScale,
          child: Scaffold(
            body: AssetSelectionBar(
              state: state,
              onMove: onMove ?? () {},
              onLabels: onLabels ?? () {},
            ),
          ),
        ),
      );
      // A busy button spins, and a spinner never settles.
      settle ? await tester.pumpAndSettle() : await tester.pump();
    }

    testWidgets('both actions are dead with nothing selected', (tester) async {
      var moved = 0;
      var labelled = 0;

      await pump(
        tester,
        const AssetListState(),
        onMove: () => moved++,
        onLabels: () => labelled++,
      );

      await tester.tap(find.text(en.bulkPrintLabels));
      await tester.tap(find.text(en.bulkMoveDepartment));
      await tester.pumpAndSettle();

      expect(moved, 0, reason: 'a bulk move with no rows can only apologise');
      expect(labelled, 0, reason: 'a label sheet of nothing is a blank page');
    });

    testWidgets('a selection lights both up', (tester) async {
      var moved = 0;
      var labelled = 0;

      await pump(
        tester,
        const AssetListState(selectedIds: {101, 102}),
        onMove: () => moved++,
        onLabels: () => labelled++,
      );

      await tester.tap(find.text(en.bulkPrintLabels));
      await tester.tap(find.text(en.bulkMoveDepartment));
      await tester.pumpAndSettle();

      expect(labelled, 1);
      expect(moved, 1);
    });

    testWidgets('a read-only user may print but not move', (tester) async {
      var moved = 0;
      var labelled = 0;

      await pump(
        tester,
        const AssetListState(
          selectedIds: {101},
          permissions: AssetPermissions.readOnly(),
        ),
        onMove: () => moved++,
        onLabels: () => labelled++,
      );

      await tester.tap(find.text(en.bulkMoveDepartment));
      await tester.tap(find.text(en.bulkPrintLabels));
      await tester.pumpAndSettle();

      expect(
        moved,
        0,
        reason: 'moving a department is a write and Odoo would refuse it',
      );
      expect(
        labelled,
        1,
        reason: 'a label sheet is a local print and needs no write',
      );
    });

    testWidgets('a write in flight disables both', (tester) async {
      var moved = 0;

      await pump(
        tester,
        const AssetListState(selectedIds: {101}, isBulkWorking: true),
        onMove: () => moved++,
        settle: false,
      );

      await tester.tap(find.byType(AssetSelectionBar), warnIfMissed: false);
      await tester.pump();

      expect(moved, 0, reason: 'a second tap would send the same write twice');
    });

    testWidgets('it survives the worst case the app can reach', (tester) async {
      await pump(
        tester,
        const AssetListState(selectedIds: {101}),
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  // ── DueChip ──────────────────────────────────────────────────────────────
  group('DueChip', () {
    Future<void> pump(WidgetTester tester, ReturnDue due) async {
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: Center(child: DueChip(due: due)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ReturnDue dueIn(int days) => ReturnDue.evaluate(
      date: DateTime.now().add(Duration(days: days)),
      isAssigned: true,
    );

    testWidgets('an asset with no date shows nothing at all', (tester) async {
      await pump(tester, ReturnDue.none);

      expect(
        find.byType(AppChip),
        findsNothing,
        reason: 'most assets are not on loan; a chip on each is noise',
      );
    });

    testWidgets('a date far out is not worth a chip either', (tester) async {
      final due = dueIn(90);

      expect(due.state, ReturnDueState.scheduled);
      await pump(tester, due);

      expect(find.byType(AppChip), findsNothing);
    });

    testWidgets('a date coming up says so', (tester) async {
      final due = dueIn(1);

      expect(due.state, ReturnDueState.dueSoon);
      await pump(tester, due);

      expect(find.text(en.dueChipSoon), findsOneWidget);
    });

    testWidgets('a date gone by says so more loudly', (tester) async {
      final due = dueIn(-4);

      expect(due.state, ReturnDueState.overdue);
      await pump(tester, due);

      expect(find.text(en.dueChipOverdue), findsOneWidget);
    });

    testWidgets('a returned asset is never late', (tester) async {
      // The note recording the due date stays in the chatter after the asset
      // comes back; reading it alone would keep a returned laptop overdue for
      // ever.
      final due = ReturnDue.evaluate(
        date: DateTime.now().subtract(const Duration(days: 30)),
        isAssigned: false,
      );

      expect(due.state, ReturnDueState.none);
      await pump(tester, due);

      expect(find.byType(AppChip), findsNothing);
    });

    test('the list form omits the number the detail form carries', () {
      final due = dueIn(-4);

      expect(
        DueChip.labelFor(en, due),
        isNot(contains('4')),
        reason: 'on a row it would compete with the warranty chip',
      );
      expect(DueChip.detailFor(en, due), contains('4'));
    });
  });

  // ── SyncBanner ───────────────────────────────────────────────────────────
  //
  // The app's only channel for "what you did is not in Odoo yet". Its priority
  // order is the contract worth pinning.
  group('SyncBanner', () {
    Future<void> pump(
      WidgetTester tester,
      SyncViewState state, {
      Size size = TestSizes.phone,
      Locale locale = const Locale('en'),
      double textScale = 1,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        RoutedTestApp(
          size: size,
          locale: locale,
          textScale: textScale,
          child: BlocProvider<SyncCubit>.value(
            value: _StubSyncCubit(state),
            child: const Scaffold(body: SyncBanner()),
          ),
        ),
      );
      settle ? await tester.pumpAndSettle() : await tester.pump();
    }

    testWidgets('live and empty shows nothing', (tester) async {
      await pump(tester, const SyncViewState());

      expect(
        find.byType(InkWell),
        findsNothing,
        reason: 'a banner that is always there is a banner nobody reads',
      );
    });

    testWidgets('offline explains why nothing is updating', (tester) async {
      await pump(tester, const SyncViewState(isOffline: true));

      expect(find.text(en.syncOfflineBanner), findsOneWidget);
    });

    testWidgets('waiting writes outrank being offline', (tester) async {
      await pump(
        tester,
        SyncViewState(isOffline: true, pending: [anOutboxEntry()]),
      );

      expect(
        find.text(en.syncPendingBanner(1)),
        findsOneWidget,
        reason:
            'a queued write is the only one of the three states that can be '
            'lost, so it is the one to report',
      );
      expect(find.text(en.syncOfflineBanner), findsNothing);
    });

    testWidgets('stale is reported when nothing louder applies', (
      tester,
    ) async {
      await pump(tester, SyncViewState(servingFrom: DateTime.now()));

      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text(en.syncOfflineBanner), findsNothing);
    });

    testWidgets('a sync in flight swaps the chevron for a spinner', (
      tester,
    ) async {
      await pump(
        tester,
        SyncViewState(isSyncing: true, pending: [anOutboxEntry()]),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('it is a route to the sync screen, not decoration', (
      tester,
    ) async {
      await pump(tester, const SyncViewState(isOffline: true));

      expect(
        find.byType(InkWell),
        findsOneWidget,
        reason:
            'telling a user something is wrong with no way to look at it is '
            'half an answer',
      );
    });

    testWidgets('a long queue message still fits the worst case', (
      tester,
    ) async {
      await pump(
        tester,
        SyncViewState(
          pending: List.generate(99, (i) => anOutboxEntry(attempts: i)),
        ),
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  // ── MaintenanceRow ───────────────────────────────────────────────────────
  group('MaintenanceRow', () {
    Future<void> pump(
      WidgetTester tester,
      MaintenanceRequest request, {
      Size size = TestSizes.phone,
      Locale locale = const Locale('en'),
      double textScale = 1,
    }) async {
      await tester.pumpWidget(
        RoutedTestApp(
          size: size,
          locale: locale,
          textScale: textScale,
          child: Scaffold(body: MaintenanceRow(request: request)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it names the request and the equipment it is about', (
      tester,
    ) async {
      await pump(tester, aRequest(name: 'Screen flicker'));

      expect(find.text('Screen flicker'), findsOneWidget);
      expect(find.textContaining('MacBook Pro'), findsOneWidget);
    });

    testWidgets('a routine request carries no urgency chip', (tester) async {
      await pump(tester, aRequest(priority: MaintenancePriority.low));

      expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
    });

    testWidgets('an urgent one is marked', (tester) async {
      await pump(tester, aRequest(priority: MaintenancePriority.high));

      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
    });

    testWidgets('a request past its date is called overdue', (tester) async {
      await pump(
        tester,
        aRequest(
          scheduledFor: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      expect(find.text(en.maintenanceOverdue), findsOneWidget);
    });

    testWidgets('a closed request is never overdue, however old', (
      tester,
    ) async {
      await pump(
        tester,
        aRequest(
          scheduledFor: DateTime.now().subtract(const Duration(days: 300)),
          isDone: true,
        ),
      );

      expect(
        find.text(en.maintenanceOverdue),
        findsNothing,
        reason: 'work that is finished cannot be late',
      );
    });

    testWidgets('a long Arabic name at the text ceiling still fits', (
      tester,
    ) async {
      await pump(
        tester,
        aRequest(
          name: 'طلب صيانة عاجل لجهاز حاسوب محمول في الطابق الثالث',
          priority: MaintenancePriority.high,
          scheduledFor: DateTime.now().subtract(const Duration(days: 3)),
        ),
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  // ── ExportButton ─────────────────────────────────────────────────────────
  //
  // Building a two-hundred-row PDF is not instant on a mid-range phone, and a
  // button that looks idle while it works gets tapped again.
  group('ExportButton', () {
    testWidgets('it shows it is working and refuses a second tap', (
      tester,
    ) async {
      var runs = 0;
      final gate = Completer<void>();

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: ExportButton(
              label: 'Export',
              onExport: () async {
                runs++;
                await gate.future;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ExportButton));
      await tester.pump();

      expect(runs, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(ExportButton), warnIfMissed: false);
      await tester.pump();
      expect(runs, 1, reason: 'a second PDF is a second wait for nothing');

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a share sheet that will not open is reported, not thrown', (
      tester,
    ) async {
      // The production failure path. `ExportAction.share` is the only caller
      // that matters, and its contract is that a file the OS refuses to hand
      // over costs the user a snackbar rather than the list they came for.
      sl.unregister<FileShare>();
      sl.registerSingleton<FileShare>(_RefusingFileShare());

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: Builder(
              builder: (context) => ExportButton(
                label: 'Export',
                onExport: () => ExportAction.share(
                  context: context,
                  filename: 'assets.pdf',
                  subject: 'Assets',
                  mimeType: 'application/pdf',
                  build: () async => Uint8List(0),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ExportButton));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'an export is a side errand; it must not take down the screen '
            'the user still wants',
      );
      expect(find.text(en.exportFailed), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a button stuck spinning after a failure can never be retried',
      );
    });
  });

  // ── SplashPage ───────────────────────────────────────────────────────────
  group('SplashPage', () {
    Widget splash() => BlocProvider<AuthCubit>.value(
      value: sl<AuthCubit>(),
      child: const SplashPage(),
    );

    testWidgets('it resolves the session, so the router can redirect', (
      tester,
    ) async {
      final auth = sl<AuthCubit>();

      await tester.pumpWidget(TestApp(size: TestSizes.phone, child: splash()));
      // Two pumps rather than `pumpAndSettle`: the progress ring spins for
      // ever, so settling would time out instead of telling us anything.
      await tester.pump();
      await tester.pump();

      expect(
        auth.state.status,
        isNot(AuthStatus.unknown),
        reason: 'the router waits on this; unknown never redirects anywhere',
      );
    });

    testWidgets('it shows the brand and says what it is doing', (tester) async {
      await tester.pumpWidget(TestApp(size: TestSizes.phone, child: splash()));
      await tester.pump();

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(en.splashRestoring), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('it fits every size, in Arabic, at the text ceiling', (
      tester,
    ) async {
      for (final (name, size) in TestSizes.all) {
        await tester.pumpWidget(
          TestApp(
            size: size,
            locale: const Locale('ar', 'EG'),
            textScale: AppTextScale.max,
            child: splash(),
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'splash overflowed on a $name',
        );
      }
    });
  });

  // ── RemindersCard ────────────────────────────────────────────────────────
  group('RemindersCard', () {
    testWidgets('it starts off, because notifications are opt-in', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestApp(
          size: TestSizes.phone,
          child: Scaffold(body: RemindersCard()),
        ),
      );
      await tester.pump();

      final row = tester.widget<AppCheckRow>(find.byType(AppCheckRow).first);
      expect(
        row.value,
        isFalse,
        reason:
            'a notification nobody asked for is the fastest way to be turned '
            'off entirely',
      );
    });

    testWidgets('it fits the worst case', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          size: TestSizes.smallPhone,
          locale: Locale('ar', 'EG'),
          textScale: AppTextScale.max,
          child: Scaffold(body: RemindersCard()),
        ),
      );
      await tester.pump();

      expectNoOverflow(tester);
    });
  });
}

/// A [SyncCubit] pinned to one state.
///
/// The real one derives its state from the outbox, the network and a running
/// sync, and reaching "offline, with two writes queued, mid-replay" through
/// those would be a test about the cubit rather than about the banner. The
/// banner's own contract is a pure function of the state it is handed, so the
/// state is handed to it.
class _StubSyncCubit extends SyncCubit {
  _StubSyncCubit(this._pinned)
    : super(
        outbox: sl<OutboxStore>(),
        service: sl<SyncService>(),
        trail: sl<SyncTrail>(),
        network: sl<NetworkInfo>(),
      );

  final SyncViewState _pinned;

  @override
  SyncViewState get state => _pinned;
}

/// A [FileShare] that refuses, the way the OS does when it will not hand the
/// app a temporary file — a full disk, or a locked-down work profile.
class _RefusingFileShare implements FileShare {
  @override
  Future<bool> shareBytes({
    required Uint8List bytes,
    required String filename,
    required String subject,
    String? mimeType,
  }) async => throw const FileAccessException('no temporary directory');

  @override
  Future<bool> shareText({
    required String content,
    required String filename,
    required String subject,
    String? mimeType,
  }) => shareBytes(
    bytes: Uint8List.fromList(content.codeUnits),
    filename: filename,
    subject: subject,
    mimeType: mimeType,
  );
}
