import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_colors.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/shared/cubit/view_state.dart';
import 'package:sijil_it/shared/widgets/app_data_views.dart';
import 'package:sijil_it/shared/widgets/event_timeline.dart';
import 'package:sijil_it/shared/widgets/paginated_list_view.dart';
import 'package:sijil_it/shared/widgets/skeletons.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The list machinery three screens share, and the bars that sit above it.
///
/// `PaginatedListView` decides six things — skeleton, failure, empty, rows,
/// footer, and when to ask for the next page. Each of those was written three
/// times before it was written once, and the paging trigger is the one that
/// silently does nothing when it is wrong.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = TestSizes.phone,
  }) async {
    await tester.pumpWidget(
      TestApp(
        size: size,
        child: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  /// A list of [count] numbered rows with the callbacks spied on.
  Widget listOf({
    required int count,
    ViewStatus status = ViewStatus.success,
    bool hasMore = false,
    bool isLoadingMore = false,
    Failure? failure,
    Widget? header,
    VoidCallback? onLoadMore,
    Future<void> Function()? onRefresh,
    bool skeletonHasChips = true,
  }) {
    return PaginatedListView<int>(
      items: <int>[for (var i = 0; i < count; i++) i],
      status: status,
      failure: failure,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      header: header,
      skeletonHasChips: skeletonHasChips,
      onRefresh: onRefresh ?? () async {},
      onLoadMore: onLoadMore ?? () {},
      emptyView: const EmptyStateView(
        icon: Icons.inbox_rounded,
        title: 'Nothing here',
        message: 'No assets have been registered yet.',
      ),
      itemBuilder: (_, item, __) =>
          SizedBox(height: 84, child: Text('row $item')),
    );
  }

  group('PaginatedListView', () {
    testWidgets('a first load shows rows shaped like the real ones', (
      tester,
    ) async {
      await pump(tester, listOf(count: 0, status: ViewStatus.loading));

      expect(find.byType(SkeletonRowList), findsOneWidget);
      expect(find.byType(EmptyStateView), findsNothing);
    });

    testWidgets('and so does the frame before the request is even made', (
      tester,
    ) async {
      // `initial` with no items is not "loaded, and there is nothing" — it is
      // "we have not asked yet". Read the other way it flashes an empty state
      // and then replaces it with a skeleton.
      await pump(tester, listOf(count: 0, status: ViewStatus.initial));

      expect(find.byType(SkeletonRowList), findsOneWidget);
      expect(find.byType(EmptyStateView), findsNothing);
    });

    testWidgets('the placeholder matches the row the caller will build', (
      tester,
    ) async {
      // Employees have no status chip and their row is a line shorter.
      // Guessing wrong is the shove this widget exists to avoid.
      await pump(
        tester,
        listOf(count: 0, status: ViewStatus.loading, skeletonHasChips: true),
      );
      final withChips = tester
          .getSize(find.byType(SkeletonListRow).first)
          .height;

      await pump(
        tester,
        listOf(count: 0, status: ViewStatus.loading, skeletonHasChips: false),
      );
      final without = tester.getSize(find.byType(SkeletonListRow).first).height;

      expect(without, lessThan(withChips));
    });

    testWidgets('a failure with nothing on screen takes the screen', (
      tester,
    ) async {
      await pump(
        tester,
        listOf(
          count: 0,
          status: ViewStatus.failure,
          failure: const Failure(kind: FailureKind.timeout),
        ),
      );

      expect(find.byType(FailureView), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the rows that already arrived', (
      tester,
    ) async {
      // Replacing a working list with an error page because a *refresh* failed
      // throws away what the user was reading.
      await pump(
        tester,
        listOf(
          count: 3,
          status: ViewStatus.failure,
          failure: const Failure(kind: FailureKind.timeout),
        ),
      );

      expect(find.byType(FailureView), findsNothing);
      expect(find.text('row 0'), findsOneWidget);
    });

    testWidgets(
      'an empty result is the caller\'s sentence, not a generic one',
      (tester) async {
        // "No assets yet" and "no matches for that search" need different words
        // and different actions.
        await pump(tester, listOf(count: 0));

        expect(find.text('Nothing here'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(
          find.byType(SkeletonRowList),
          findsNothing,
          reason: 'loaded-and-empty is an answer, not a wait',
        );
      },
    );

    testWidgets('the footer spinner shows only while a page is in flight', (
      tester,
    ) async {
      await pump(tester, listOf(count: 3, hasMore: true));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await pump(tester, listOf(count: 3, hasMore: true, isLoadingMore: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the header scrolls with the rows rather than pinning', (
      tester,
    ) async {
      await pump(
        tester,
        listOf(count: 20, header: const Text('Showing 20 of 40')),
      );

      expect(find.text('Showing 20 of 40'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Showing 20 of 40')).dy,
        lessThan(tester.getTopLeft(find.text('row 0')).dy),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(find.text('Showing 20 of 40'), findsNothing);
    });

    group('asking for the next page', () {
      testWidgets('happens before the user reaches the bottom', (tester) async {
        // At the bottom exactly, the user watches a spinner. The prefetch
        // window is what makes the next page look like it was already there.
        var requested = 0;
        await pump(
          tester,
          listOf(count: 20, hasMore: true, onLoadMore: () => requested++),
        );

        // Short of the very bottom on purpose: the prefetch window is what
        // makes the next page look like it was already there, and a trigger
        // that only fires at maxScrollExtent shows the user a spinner instead.
        // Measured rather than guessed — a fixed drag that once stopped short
        // of the end reached it the moment the test screen grew.
        final list = find.byType(ListView);
        final extent = tester
            .widget<ListView>(list)
            .controller!
            .position
            .maxScrollExtent;
        await tester.drag(list, Offset(0, -extent * 0.9));
        await tester.pump();

        final position = tester
            .widget<ListView>(find.byType(ListView))
            .controller!
            .position;
        expect(
          position.pixels,
          lessThan(position.maxScrollExtent),
          reason: 'the point is that this fires before the end',
        );
        expect(requested, greaterThan(0));
      });

      testWidgets('does not happen when there is nothing more to ask for', (
        tester,
      ) async {
        var requested = 0;
        await pump(tester, listOf(count: 20, onLoadMore: () => requested++));

        await tester.drag(find.byType(ListView), const Offset(0, -1400));
        await tester.pump();

        expect(requested, 0);
      });

      testWidgets('does not stack a second request on the first', (
        tester,
      ) async {
        // The scroll listener fires per frame. Without the guard, one flick to
        // the bottom asks for the same offset a dozen times.
        var requested = 0;
        await pump(
          tester,
          listOf(
            count: 20,
            hasMore: true,
            isLoadingMore: true,
            onLoadMore: () => requested++,
          ),
        );

        await tester.drag(find.byType(ListView), const Offset(0, -1400));
        await tester.pump();

        expect(requested, 0);
      });

      testWidgets('a short list that fits does not ask on its own', (
        tester,
      ) async {
        var requested = 0;
        await pump(
          tester,
          listOf(count: 2, hasMore: true, onLoadMore: () => requested++),
        );

        expect(requested, 0);
      });
    });

    testWidgets('rows do not stretch to the full width of a tablet', (
      tester,
    ) async {
      await pump(tester, listOf(count: 5), size: TestSizes.tablet);

      final row = tester.getSize(find.text('row 0')).width;
      expect(row, lessThan(TestSizes.tablet.width));
    });

    testWidgets('the last row is not parked under the floating button', (
      tester,
    ) async {
      await pump(tester, listOf(count: 3));

      final list = tester.widget<ListView>(find.byType(ListView));
      final padding = list.padding!.resolve(TextDirection.ltr);
      expect(padding.bottom, greaterThan(padding.top));
    });
  });

  group('DistributionBar', () {
    testWidgets('an all-zero split draws a neutral track, not nothing', (
      tester,
    ) async {
      await pump(
        tester,
        const DistributionBar(
          segments: <BarSegment>[
            BarSegment(value: 0, color: AppColors.statusAssigned),
            BarSegment(value: 0, color: AppColors.statusAvailable),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DistributionBar), findsOneWidget);
    });

    testWidgets('zero segments are dropped rather than drawn at no width', (
      tester,
    ) async {
      // A 0-px child still contributes a gap, which shows as a stray notch.
      await pump(
        tester,
        const DistributionBar(
          segments: <BarSegment>[
            BarSegment(value: 12, color: AppColors.statusAssigned),
            BarSegment(value: 0, color: AppColors.statusLost),
            BarSegment(value: 7, color: AppColors.statusAvailable),
          ],
        ),
      );

      expect(find.byType(Expanded), findsNWidgets(2));
    });

    testWidgets('one asset in a hundred still draws', (tester) async {
      // "One asset is lost" is exactly the thing that needs seeing, and it is
      // also the thing integer rounding erases.
      await pump(
        tester,
        const DistributionBar(
          segments: <BarSegment>[
            BarSegment(value: 9999, color: AppColors.statusAssigned),
            BarSegment(value: 1, color: AppColors.statusLost),
          ],
        ),
      );

      final flexes = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .map((e) => e.flex)
          .toList();
      expect(flexes, hasLength(2));
      expect(flexes.every((f) => f >= 1), isTrue);
    });

    testWidgets('a single segment fills the bar', (tester) async {
      await pump(
        tester,
        const DistributionBar(
          segments: <BarSegment>[
            BarSegment(value: 22, color: AppColors.statusAssigned),
          ],
        ),
      );

      expect(
        tester.widgetList<Expanded>(find.byType(Expanded)).single.flex,
        1000,
      );
    });
  });

  group('EventTimeline', () {
    List<TimelineEvent> events(int count) => <TimelineEvent>[
      for (var i = 0; i < count; i++)
        TimelineEvent(
          icon: Icons.arrow_forward_rounded,
          tone: AppColors.statusAssigned,
          title: 'Assigned to person $i',
          meta: '24 Aug 2026',
        ),
    ];

    testWidgets('every event gets its own row', (tester) async {
      await pump(tester, EventTimeline(events: events(3)));

      expect(find.text('Assigned to person 0'), findsOneWidget);
      expect(find.text('Assigned to person 2'), findsOneWidget);
    });

    testWidgets('an empty history renders nothing rather than a bare rail', (
      tester,
    ) async {
      await pump(tester, const EventTimeline(events: <TimelineEvent>[]));

      expect(tester.getSize(find.byType(EventTimeline)).height, 0);
    });

    testWidgets('a single event has no rail to nowhere', (tester) async {
      // The rail is per-row so the last one can omit it — which is what makes
      // the timeline visibly end instead of trailing off.
      await pump(tester, EventTimeline(events: events(1)));

      final single = tester.getSize(find.byType(EventTimeline)).height;
      await pump(tester, EventTimeline(events: events(2)));
      final double_ = tester.getSize(find.byType(EventTimeline)).height;

      expect(single, lessThan(double_));
    });

    testWidgets('a wrapping subtitle does not detach the rail', (tester) async {
      await pump(
        tester,
        EventTimeline(
          events: <TimelineEvent>[
            const TimelineEvent(
              icon: Icons.arrow_forward_rounded,
              tone: AppColors.statusAssigned,
              title:
                  'Assigned to Youssef Tarek on 20 July 2025 — part of the '
                  'onboarding kit for the new development team',
              subtitle: 'Administrator',
              meta: '20 Jul 2025',
            ),
            ...events(1),
          ],
        ),
      );

      expectNoOverflow(tester);
    });
  });
}
