import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/features/assets/data/services/asset_note_vocabulary.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_history_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The summary line under an asset's timeline.
///
/// The timeline is reconstructed from `mail.message`, and only this app writes
/// the notes it reads. So a customer's first day — inventory imported, or
/// assignments made in the Odoo web client — produces an asset that has a
/// holder and no note saying so.
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  /// An asset in the fixture that is assigned to someone.
  const assignedAssetId = 101;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    await signInForTest(data);
    l10n = await loadL10n();
  });

  tearDown(() async => sl.reset());

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: signedInScreen(const AssetHistoryPage(assetId: assignedAssetId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Puts an assignment note in the asset's chatter, the way the app would.
  void postAssignmentNote(String holder) {
    data.tableOf(OdooModels.mailMessage).add(<String, dynamic>{
      'id': 90000 + holder.hashCode.abs() % 1000,
      'body': '<p>${AssetNoteVocabulary.assignedPrefix} $holder</p>',
      'subject': false,
      'date': '2026-08-24 10:00:00',
      'author_id': <Object?>[data.userId, data.login],
      'model': OdooModels.maintenanceEquipment,
      'res_id': assignedAssetId,
      'message_type': 'comment',
    });
  }

  testWidgets('an empty log does not claim the asset has never been held', (
    tester,
  ) async {
    // "No holders yet" is a statement about the asset, and the only thing the
    // screen actually knows is that its own log is empty. It used to sit one
    // tap away from a detail page naming the current holder, flatly
    // contradicting it.
    await pumpHistory(tester);

    expect(find.text(l10n.historyHolders(0)), findsNothing);
  });

  testWidgets('the count appears as soon as there is one to show', (
    tester,
  ) async {
    // Not suppressed in general — this line is why the screen exists. A device
    // on its fourth holder in two years is being passed around, and that is a
    // replacement decision rather than a repair one.
    postAssignmentNote('Youssef Tarek');
    await pumpHistory(tester);

    expect(find.text(l10n.historyHolders(1)), findsOneWidget);
  });

  testWidgets('distinct holders are counted, repeats are not', (tester) async {
    postAssignmentNote('Youssef Tarek');
    postAssignmentNote('Khaled Adel');
    postAssignmentNote('Youssef Tarek');

    await pumpHistory(tester);

    expect(find.text(l10n.historyHolders(2)), findsOneWidget);
  });

  testWidgets('the service date still shows with an empty log', (tester) async {
    // Suppressing the count must not take the rest of the line with it: the
    // creation date comes from the record, not the chatter, so it is known
    // even when nothing was ever logged.
    await pumpHistory(tester);

    expect(find.textContaining(RegExp('service|Service')), findsWidgets);
  });
}
