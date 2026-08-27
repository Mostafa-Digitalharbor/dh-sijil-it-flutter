import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/skeletons.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// The assets screen, driven against a real XML-RPC server.
///
/// Everything below the widget is production code — Cubit, use case,
/// repository, mapper, status resolver, Odoo service, Dio, socket. Only the
/// keychain, Hive and connectivity are doubles.
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

  Future<void> pump(
    WidgetTester tester, {
    Size size = TestSizes.phone,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: size,
        textScale: textScale,
        child: signedInScreen(const AssetListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('loading and content', () {
    testWidgets('shows a skeleton before the first page arrives', (
      tester,
    ) async {
      // Slow the server enough that the loading state lasts more than the
      // microtask it otherwise would.
      client.delay = const Duration(milliseconds: 200);

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const AssetListPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonRowList), findsOneWidget);
      expect(find.byType(AssetRow), findsNothing);

      client.delay = Duration.zero;
      await tester.pumpAndSettle();
      expect(find.byType(AssetRow), findsWidgets);
    });

    testWidgets('renders a row for every asset the server returns', (
      tester,
    ) async {
      await pump(tester);

      final expected = data
          .tableOf('maintenance.equipment')
          .where((row) => row['scrap_date'] == false)
          .length;

      expect(find.byType(AssetRow), findsNWidgets(expected));
    });

    testWidgets('the counter reports what is shown out of the total', (
      tester,
    ) async {
      await pump(tester);

      final shown = tester.widgetList<AssetRow>(find.byType(AssetRow)).length;
      expect(find.text(l10n.assetsShowingOf(shown, shown)), findsOneWidget);
    });

    testWidgets('retired assets are hidden until asked for', (tester) async {
      await pump(tester);

      final retired = data
          .tableOf('maintenance.equipment')
          .where((row) => row['scrap_date'] != false)
          .map((row) => row['name'] as String);

      expect(retired, isNotEmpty, reason: 'the fixture must contain one');
      for (final name in retired) {
        expect(find.text(name), findsNothing);
      }
    });
  });

  group('search', () {
    testWidgets('narrows the list to matching assets', (tester) async {
      await pump(tester);

      final target =
          data.tableOf('maintenance.equipment').first['name'] as String;

      await tester.enterText(find.byType(TextField).first, target);
      // Past the 350 ms debounce, then let the request resolve.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(AssetRow), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AssetRow), matching: find.text(target)),
        findsOneWidget,
      );
    });

    testWidgets('a term with no matches offers to clear the filters', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'nothing-matches-this',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(AssetRow), findsNothing);
      expect(find.text(l10n.emptySearchTitle), findsOneWidget);
      expect(find.text(l10n.filterClearAll), findsWidgets);
    });

    testWidgets('debounces so typing a word is one request', (tester) async {
      await pump(tester);

      final before = _searchCalls(client);

      for (final term in <String>['M', 'Ma', 'Mac', 'MacB']) {
        await tester.enterText(find.byType(TextField).first, term);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // One search_read plus its search_count, not four of each.
      expect(_searchCalls(client) - before, lessThanOrEqualTo(2));
    });
  });

  group('failure', () {
    testWidgets('an Odoo error explains itself and offers a retry', (
      tester,
    ) async {
      data.deniedOperations.add('maintenance.equipment.search_read');
      await pump(tester);

      expect(find.byType(FailureView), findsOneWidget);
      expect(find.text(l10n.errorAccessDeniedTitle), findsOneWidget);
      // The fix, not a stack trace.
      expect(find.text(l10n.errorAccessDeniedFix), findsOneWidget);
    });

    testWidgets('no Odoo fault text ever reaches the screen', (tester) async {
      data.deniedOperations.add('maintenance.equipment.search_read');
      await pump(tester);

      expect(find.textContaining('odoo.exceptions'), findsNothing);
      expect(find.textContaining('Traceback'), findsNothing);
      expect(find.textContaining('AccessError'), findsNothing);
    });
  });

  group('permissions', () {
    testWidgets('the create button is hidden when Odoo forbids create', (
      tester,
    ) async {
      data.deniedOperations.add('maintenance.equipment.create');
      await pump(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('the create button is offered when Odoo allows it', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (name, size) in TestSizes.all) {
      testWidgets('lays out without overflow on a $name', (tester) async {
        await pump(tester, size: size);
        expectNoOverflow(tester);
      });
    }

    testWidgets('survives a large text scale', (tester) async {
      await pump(tester, size: TestSizes.smallPhone, textScale: 1.6);
      expectNoOverflow(tester);
    });

    testWidgets('renders right to left in Arabic', (tester) async {
      await pump(tester, locale: const Locale('ar', 'EG'));

      expect(find.text(l10n.assetsTitle), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(AssetRow).first)),
        TextDirection.rtl,
      );
      expectNoOverflow(tester);
    });
  });
}

/// How many equipment reads the app has issued.
///
/// Counts `search_read` and `search_count` on the asset model only, so an
/// unrelated capability probe cannot make a debounce assertion pass or fail.
int _searchCalls(InProcessOdooClient client) => client.calls.where((call) {
  if (call.method != 'execute_kw' || call.params.length < 5) return false;
  final model = call.params[3];
  final method = call.params[4];
  return model == 'maintenance.equipment' &&
      (method == 'search_read' || method == 'search_count');
}).length;
