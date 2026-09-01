import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/sync/outbox_store.dart';
import 'package:sijil_it/features/assignment/presentation/pages/assign_asset_page.dart';
import 'package:sijil_it/features/assignment/presentation/pages/return_asset_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';
import 'package:sijil_it/shared/widgets/app_sheets.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// What the app says when a write went into the queue instead of into Odoo.
///
/// ## The bug this file exists for
///
/// A handover made with no signal is parked in the outbox, and the repository
/// answers with the asset as it *will* read once the queue drains — which is
/// correct for the screen, and was being used as though it were correct for
/// the sentence underneath it. So a technician standing in a basement saw a
/// green tick and "MacBook Pro assigned to Ahmed", exactly what they would
/// have seen if Odoo had accepted the handover.
///
/// That is the one lie in the product worth going out of the way to prevent.
/// Somebody told the handover is recorded has no reason to keep the app open
/// or to check anything later, and the queue on their phone is the only copy
/// that exists. The `syncQueuedNotice` string had been written and translated
/// into both languages, and then never wired to anything.
void main() {
  late FakeOdooData data;
  late FakeNetworkInfo network;
  late AppL10n en;

  /// From the fixture: unassigned, and assigned-to-Ahmed respectively.
  const availableAssetId = 104;
  const assignedAssetId = 101;

  setUp(() async {
    data = FakeOdooData.seeded();
    network = FakeNetworkInfo();
    await configureTestDependencies(data: data, network: network);
    en = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// Pumps a screen and lets its debounced employee lookup run.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      RoutedTestApp(
        size: TestSizes.phone,
        locale: locale ?? const Locale('en'),
        child: signedInScreen(screen),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> confirmAssign(WidgetTester tester) async {
    await tester.tap(find.byType(AppSelectableTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, en.assignConfirm));
    await tester.pumpAndSettle();
  }

  group('an assignment made online', () {
    testWidgets('is confirmed plainly, with no caveat', (tester) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      await confirmAssign(tester);

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        find.textContaining(en.syncQueuedNotice),
        findsNothing,
        reason: 'Odoo has it; saying otherwise would be noise',
      );
    });
  });

  group('an assignment made with no signal', () {
    testWidgets('says where the handover actually is', (tester) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      network.connected = false;

      await confirmAssign(tester);

      expect(
        find.textContaining(en.syncQueuedNotice),
        findsOneWidget,
        reason:
            'the queue on this phone is the only copy, and the user has to '
            'know that to behave accordingly',
      );
    });

    testWidgets('does not wear the tick that means Odoo accepted it', (
      tester,
    ) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      network.connected = false;

      await confirmAssign(tester);

      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('the write really is queued, not merely reported as such', (
      tester,
    ) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      network.connected = false;

      await confirmAssign(tester);

      expect(await sl<OutboxStore>().pending(), hasLength(1));
    });

    testWidgets('and Odoo has genuinely not been told', (tester) async {
      await pump(tester, const AssignAssetPage(assetId: availableAssetId));
      network.connected = false;

      await confirmAssign(tester);

      final row = data
          .tableOf('maintenance.equipment')
          .firstWhere((r) => r['id'] == availableAssetId);
      expect(
        row['employee_id'],
        false,
        reason: 'if this were written, the caveat would be the wrong message',
      );
    });

    testWidgets('says it in Arabic too', (tester) async {
      final ar = await loadL10n('ar');
      await pump(
        tester,
        const AssignAssetPage(assetId: availableAssetId),
        locale: const Locale('ar', 'EG'),
      );
      network.connected = false;

      await tester.tap(find.byType(AppSelectableTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, ar.assignConfirm));
      await tester.pumpAndSettle();

      expect(find.textContaining(ar.syncQueuedNotice), findsOneWidget);
    });
  });

  group('a return made with no signal', () {
    testWidgets('carries the same caveat', (tester) async {
      await pump(tester, const ReturnAssetPage(assetId: assignedAssetId));
      network.connected = false;

      await tester.tap(find.widgetWithText(AppButton, en.returnConfirm));
      await tester.pumpAndSettle();

      expect(find.textContaining(en.syncQueuedNotice), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('and is confirmed plainly when there is a connection', (
      tester,
    ) async {
      await pump(tester, const ReturnAssetPage(assetId: assignedAssetId));

      await tester.tap(find.widgetWithText(AppButton, en.returnConfirm));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.textContaining(en.syncQueuedNotice), findsNothing);
    });
  });

  group('the notice fits where it is shown', () {
    testWidgets('two sentences survive the text ceiling in Arabic', (
      tester,
    ) async {
      final ar = await loadL10n('ar');

      await tester.pumpWidget(
        RoutedTestApp(
          size: TestSizes.smallPhone,
          locale: const Locale('ar', 'EG'),
          textScale: AppTextScale.max,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => AppSnack.written(
                    context,
                    ar.assignSuccess('ماك بوك برو ١٦ بوصة', 'أحمد عبد الله'),
                    queued: true,
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expectNoOverflow(tester);
      expect(
        find.textContaining(ar.syncQueuedNotice),
        findsOneWidget,
        reason:
            'the line that would be dropped first is the one saying it is not '
            'in Odoo yet',
      );
    });
  });
}
