import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_data_views.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';
import 'package:sijil_it/shared/widgets/status_legend.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The dashboard, against a real XML-RPC server.
///
/// The assertions are mostly arithmetic: six status tiles that partition the
/// asset table, and a hero total that agrees with them. A dashboard whose
/// tiles sum to more than its headline is a dashboard nobody trusts again.
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: TestSizes.phone,
        child: signedInScreen(const DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The count beside [label] in the distribution ring's legend.
  ///
  /// The ring itself is arcs on a canvas, so the legend is where the numbers
  /// are actually assertable — and where a screen reader finds them too.
  int legendValue(WidgetTester tester, String label) {
    final row = tester
        .widgetList<StatusLegendRow>(find.byType(StatusLegendRow))
        .firstWhere((r) => r.label == label);
    return row.count;
  }

  int totalEquipment() => data.tableOf('maintenance.equipment').length;

  group('counts', () {
    testWidgets('the hero total matches the asset table', (tester) async {
      await pump(tester);
      expect(find.text('${totalEquipment()}'), findsWidgets);
    });

    testWidgets('the legend partitions the total', (tester) async {
      await pump(tester);

      // Four named rows plus the row that groups reserved, damaged and lost.
      // Together they must account for every asset exactly once: if the
      // status domains overlapped, the legend would sum past the figure in
      // the middle of the ring and the card would contradict itself.
      final sum = <String>[
        l10n.statusAssigned,
        l10n.statusAvailable,
        l10n.statusRetired,
        l10n.statusMaintenance,
        l10n.dashboardRareStatuses,
      ].map((label) => legendValue(tester, label)).reduce((a, b) => a + b);

      expect(
        sum,
        totalEquipment(),
        reason: 'the legend must add up to the ring centre, not overlap',
      );
    });

    testWidgets('a scrapped asset counts as retired, not as maintenance', (
      tester,
    ) async {
      // The fixture's scrapped printer also carries no open request; the point
      // is that scrap wins over every other derivation.
      await pump(tester);

      final retired = data
          .tableOf('maintenance.equipment')
          .where((row) => row['scrap_date'] != false)
          .length;

      expect(legendValue(tester, l10n.statusRetired), retired);
    });

    testWidgets('an open request outranks the assignment it carries', (
      tester,
    ) async {
      await pump(tester);

      final inMaintenance = data
          .tableOf('maintenance.equipment')
          .where(
            (row) =>
                row['scrap_date'] == false &&
                (row['maintenance_open_count'] as int) > 0,
          )
          .length;

      expect(legendValue(tester, l10n.statusMaintenance), inMaintenance);
    });
  });

  group('sections', () {
    testWidgets('renders a bar for each category in use', (tester) async {
      await pump(tester);

      final categories = data
          .tableOf('maintenance.equipment')
          .map((row) => (row['category_id'] as List<Object?>?)?[1])
          .whereType<Object>()
          .toSet();

      expect(find.byType(LabeledBar), findsNWidgets(categories.length));
    });

    testWidgets('shows an empty-activity line when the chatter is silent', (
      tester,
    ) async {
      await pump(tester);

      // The feed is the last card and the body builds lazily, so it has to be
      // scrolled into view before it exists to find.
      await tester.scrollUntilVisible(
        find.text(l10n.emptyActivityBody),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.emptyActivityBody), findsOneWidget);
    });
  });

  group('degraded instances', () {
    testWidgets('an Odoo without Maintenance explains itself', (tester) async {
      final bare = FakeOdooData.seeded()
        ..installedModels.remove('maintenance.equipment');
      await configureTestDependencies(data: bare);
      await signInForTest(bare);

      await pump(tester);

      expect(find.byType(FailureView), findsOneWidget);
      expect(find.text(l10n.errorModelUnavailableTitle), findsOneWidget);
      // It names the app to install, rather than blaming the user.
      expect(find.text(l10n.errorModelUnavailableFix), findsOneWidget);
    });

    testWidgets('an empty Odoo offers the empty state, not an error', (
      tester,
    ) async {
      final bare = FakeOdooData.seeded();
      bare.tableOf('maintenance.equipment').clear();
      await configureTestDependencies(data: bare);
      await signInForTest(bare);

      await pump(tester);

      expect(find.text(l10n.emptyAssetsTitle), findsOneWidget);
      expect(find.byType(FailureView), findsNothing);
    });
  });

  testWidgets('renders right to left in Arabic without overflow', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('ar', 'EG'));
    expectNoOverflow(tester);
  });
}
