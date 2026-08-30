import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_history.dart';
import 'package:sijil_it/features/assets/domain/usecases/asset_usecases.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_history_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// What colleagues did in the Odoo web client, on the app's own timeline.
///
/// ## The bug this closes
///
/// An asset's history was reconstructed from `mail.message`, and a message
/// Odoo posts for a *field change* carries no body at all — the sentence is
/// rendered in the browser from `mail.tracking.value` rows the app did not
/// read. So it read those messages, found them blank, and dropped them.
///
/// The visible result was an asset handed over in Odoo whose history said the
/// handover never happened, next to a detail screen naming the holder.
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  /// From the fixture: the Dell monitor, whose `employee_id` was set in the
  /// web client rather than by this app.
  const trackedAssetId = 102;

  /// The MacBook, whose chatter this app wrote.
  const notedAssetId = 101;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Future<AssetHistory> historyOf(int id) async {
    final result = await sl<GetAssetHistory>()(id);
    return result.getOrElse(() => throw StateError('history $id did not read'));
  }

  test('a field change made in Odoo becomes a timeline entry', () async {
    final history = await historyOf(trackedAssetId);

    expect(history.entries, hasLength(1));
    // The sentence is built from the tracking rows, the same way the web
    // client builds it: what changed, to what, and what it was before.
    expect(history.entries.single.summary, contains('Used By'));
    expect(history.entries.single.summary, contains('Ahmed Mohamed'));
  });

  test('it is classified as a handover, not as an anonymous note', () async {
    final history = await historyOf(trackedAssetId);

    // Matched on `employee_id`, never on the label: "Used By" arrives in
    // whatever language the person making the change had Odoo set to, so a
    // rule written against the label would work in one office and stop at the
    // border.
    expect(history.entries.single.kind, AssetEventKind.assigned);
  });

  test('the person who received it counts as a holder', () async {
    final history = await historyOf(trackedAssetId);

    expect(history.holderCount, 1);
  });

  test('the same person, recorded twice, is still one holder', () async {
    // The double-counting this guards against is the ordinary case: the app
    // writes a note when *it* performs a handover, Odoo writes a tracking row
    // for the same field change, and counting sentences made one person into
    // two.
    data.tableOf(OdooModels.mailMessage).add(<String, dynamic>{
      'id': 6002,
      'body': '<p>Assigned to Ahmed Mohamed on 2025-10-15.</p>',
      'subject': false,
      'date': '2025-10-15 08:12:30',
      'author_id': <Object?>[data.userId, data.login],
      'model': OdooModels.maintenanceEquipment,
      'res_id': trackedAssetId,
      'message_type': 'comment',
      'tracking_value_ids': <Object?>[],
    });

    final history = await historyOf(trackedAssetId);

    expect(history.entries, hasLength(2));
    expect(history.holderCount, 1);
  });

  test('a note this app wrote is still read the way it always was', () async {
    // The tracking read is an addition, not a replacement. Everything the app
    // has been writing since the first release has to keep classifying.
    data.tableOf(OdooModels.mailMessage).add(<String, dynamic>{
      'id': 6003,
      'body': '<p>Status set to Damaged by the Sijil IT mobile app.</p>',
      'subject': false,
      'date': '2026-08-24 10:00:00',
      'author_id': <Object?>[data.userId, data.login],
      'model': OdooModels.maintenanceEquipment,
      'res_id': notedAssetId,
      'message_type': 'comment',
      'tracking_value_ids': <Object?>[],
    });

    final history = await historyOf(notedAssetId);

    expect(history.entries.single.kind, AssetEventKind.statusChanged);
    expect(history.entries.single.holder, isNull);
  });

  test(
    'an instance that refuses the tracking read still has a history',
    () async {
      // Hardened ACLs are a real deployment. The notes are the bulk of the
      // timeline and are already in hand, so losing the refinement must not lose
      // the screen.
      data.deniedOperations.add('${OdooModels.mailTrackingValue}.read');

      final history = await historyOf(trackedAssetId);

      // The tracking-only entry has nothing left to say, so it drops out — but
      // the read resolved and the screen renders.
      expect(history.entries, isEmpty);
      expect(history.registeredOn, isNotNull);
    },
  );

  testWidgets('the screen draws it as a handover', (tester) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: signedInScreen(const AssetHistoryPage(assetId: trackedAssetId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ahmed Mohamed'), findsWidgets);
    expect(find.text(l10n.historyHolders(1)), findsOneWidget);
    expect(find.text(l10n.historyEmptyTitle), findsNothing);
  });
}
