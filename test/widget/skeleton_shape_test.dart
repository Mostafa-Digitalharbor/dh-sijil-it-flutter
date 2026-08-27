import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:sijil_it/shared/widgets/skeleton_screens.dart';
import 'package:sijil_it/shared/widgets/skeletons.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// A skeleton's job is to hold the space the content will take.
///
/// It is easy to write one that shimmers convincingly and reserves the wrong
/// height, and the failure is invisible in a screenshot: it only shows as the
/// page shoving itself half a screen when the data lands. On a slow connection
/// that moves the row the user is already reaching for out from under their
/// thumb, and they open the wrong asset.
///
/// So these assert the thing that actually matters — that the placeholder and
/// the real content occupy comparable space — rather than that a shimmer
/// exists.
void main() {
  late FakeOdooData data;
  late InProcessOdooClient client;

  setUp(() async {
    data = FakeOdooData.seeded();
    client = await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// Height of the first widget of [T] on screen.
  double heightOf<T extends Widget>(WidgetTester tester) =>
      tester.getSize(find.byType(T).first).height;

  group('list rows', () {
    testWidgets('a placeholder row is close to a real one', (tester) async {
      client.delay = const Duration(seconds: 5);
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const AssetListPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonRowList), findsOneWidget);
      final placeholder = heightOf<SkeletonListRow>(tester);

      client.delay = Duration.zero;
      await tester.pumpAndSettle();

      expect(find.byType(AssetRow), findsWidgets);
      final real = heightOf<AssetRow>(tester);

      // Within a quarter of a row. Exactness is not the goal — the goal is
      // that six of these stacked do not add up to a visible shove.
      expect(
        (placeholder - real).abs(),
        lessThan(real * 0.25),
        reason: 'placeholder $placeholder vs real $real',
      );
    });
  });

  group('dashboard', () {
    testWidgets('shows the dashboard-shaped skeleton, not a row list', (
      tester,
    ) async {
      // The regression this exists for: every screen used to get the same
      // stack of 84-pt boxes, and the dashboard's ring, sparkline and bar
      // chart look nothing like a list row.
      client.delay = const Duration(seconds: 5);
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const DashboardPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonDashboard), findsOneWidget);
      expect(find.byType(SkeletonRowList), findsNothing);

      client.delay = Duration.zero;
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonDashboard), findsNothing);
    });

    testWidgets('the skeleton fills a comparable share of the page', (
      tester,
    ) async {
      client.delay = const Duration(seconds: 5);
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const DashboardPage()),
        ),
      );
      await tester.pump();

      // The placeholder must not be a thin strip on a tall page: that is the
      // shape that lets the real content arrive and push everything down.
      final skeleton = tester.getSize(find.byType(SkeletonBody).first);
      expect(skeleton.height, greaterThan(TestSizes.phone.height * 0.5));

      client.delay = Duration.zero;
      await tester.pumpAndSettle();
    });
  });

  group('every skeleton renders at the sizes the app supports', () {
    final skeletons = <String, Widget>{
      'dashboard': const SkeletonDashboard(),
      'detail': const SkeletonDetail(),
      'detail without actions': const SkeletonDetail(hasActions: false),
      'form': const SkeletonForm(),
      'timeline': const SkeletonTimeline(),
      'row list': const SkeletonRowList(),
      'row list without chips': const SkeletonRowList(showChips: false),
    };

    for (final entry in skeletons.entries) {
      for (final (sizeName, size) in TestSizes.all) {
        testWidgets('${entry.key} fits a $sizeName', (tester) async {
          await tester.pumpWidget(
            TestApp(
              size: size,
              child: Scaffold(body: entry.value),
            ),
          );
          await tester.pump();
          expectNoOverflow(tester);
        });
      }

      testWidgets('${entry.key} fits the worst case', (tester) async {
        await tester.pumpWidget(
          TestApp(
            size: TestSizes.smallPhone,
            locale: const Locale('ar'),
            textScale: AppTextScale.max,
            child: Scaffold(body: entry.value),
          ),
        );
        await tester.pump();
        expectNoOverflow(tester);
      });
    }
  });
}
