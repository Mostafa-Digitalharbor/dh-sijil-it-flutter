import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/error/failures.dart';
import '../../core/responsive/responsive.dart';
import '../cubit/view_state.dart';
import 'skeletons.dart';
import 'state_views.dart';

/// The one infinite-scrolling list in the product.
///
/// Assets, employees and maintenance requests are the same screen with
/// different rows: skeleton on first load, failure view, empty state,
/// pull-to-refresh, a footer spinner, and a trigger that asks for the next
/// page before the user reaches the bottom. Writing that three times is three
/// chances to get the paging trigger subtly wrong.
///
/// The caller supplies the rows and the four callbacks; everything else is
/// decided here.
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    required this.items,
    required this.status,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    required this.emptyView,
    this.failure,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.header,
    this.onRetry,
    this.skeletonHasChips = true,
    super.key,
  });

  /// The same list, wired from a [PaginatedViewState] instead of by hand.
  ///
  /// Every list screen in the app passed the same six values — items, status,
  /// failure, hasMore, isLoadingMore — pulled out of a state object that
  /// already held all of them together. This takes the state, which is both
  /// shorter at the call site and impossible to get half right: there is no
  /// longer a way to pass one screen's `items` beside another's `hasMore`.
  PaginatedListView.fromState({
    required PaginatedViewState<T> state,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    required this.emptyView,
    this.header,
    this.onRetry,
    this.skeletonHasChips = true,
    super.key,
  }) : items = state.items,
       status = state.status,
       failure = state.failure,
       hasMore = state.hasMore,
       isLoadingMore = state.isLoadingMore;

  final List<T> items;
  final ViewStatus status;
  final Failure? failure;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  /// Rendered when the list is genuinely empty. Supplied by the caller because
  /// "no assets yet" and "no matches for that search" are different sentences
  /// with different actions.
  final Widget emptyView;

  final bool hasMore;
  final bool isLoadingMore;

  /// Pinned as the first scrolling item — a summary card above a list.
  final Widget? header;

  final VoidCallback? onRetry;

  /// Whether the placeholder rows carry chips.
  ///
  /// Assets and maintenance requests show a status chip; employees do not, and
  /// their row is correspondingly shorter. Guessing wrong here is the layout
  /// jump this whole file exists to avoid.
  final bool skeletonHasChips;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    if (!_controller.hasClients) return;

    final position = _controller.position;
    if (position.pixels >=
        position.maxScrollExtent - AppDimens.listPrefetchExtent) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // First load with nothing to show yet: rows shaped like the real ones, so
    // the layout does not jump when they arrive. `showChips` is the caller's,
    // because a row with a status and a warranty chip is a line taller than
    // one without and the difference is visible as a shove.
    //
    // `initial` counts as a load, matching `AsyncDataView`. It is the state
    // before the first request has even been made, and with no items that read
    // as "loaded, and there is nothing" — so a screen that built one frame
    // ahead of its Cubit flashed "No assets yet" and then replaced it with a
    // skeleton. Two widgets answering the same question differently is how
    // that kind of thing survives a review.
    final isFirstLoad =
        widget.status == ViewStatus.initial || widget.status.isInitialLoad;
    if (isFirstLoad && widget.items.isEmpty) {
      return SkeletonRowList(showChips: widget.skeletonHasChips);
    }

    if (widget.status == ViewStatus.failure &&
        widget.items.isEmpty &&
        widget.failure != null) {
      return FailureView(failure: widget.failure!, onRetry: widget.onRetry);
    }

    if (widget.items.isEmpty) {
      // The empty and failure views are already scrollable and already fill the
      // viewport, so the RefreshIndicator drives them directly. Adding a scroll
      // view here would nest two, and the inner one would be measured against
      // an unbounded height.
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: widget.emptyView,
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: _ConstrainedList(child: _buildList(context)),
    );
  }

  Widget _buildList(BuildContext context) {
    final screen = context.screen;
    final headerCount = widget.header == null ? 0 : 1;
    final footerCount = widget.isLoadingMore ? 1 : 0;

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.only(
        start: screen.gutter,
        end: screen.gutter,
        top: AppSpacing.xs,
        // Clears the floating action button and the bottom navigation bar, so
        // the last row is never parked underneath either.
        bottom: AppDimens.fabSize + AppSpacing.xxxl,
      ),
      itemCount: headerCount + widget.items.length + footerCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.gridGap),
      itemBuilder: (context, index) {
        if (headerCount == 1 && index == 0) return widget.header!;

        final itemIndex = index - headerCount;
        if (itemIndex >= widget.items.length) return const _LoadMoreFooter();

        return widget.itemBuilder(context, widget.items[itemIndex], itemIndex);
      },
    );
  }
}

/// Caps the reading width on a tablet, so rows do not stretch to 1200 px.
class _ConstrainedList extends StatelessWidget {
  const _ConstrainedList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.screen.size.isExpanded) return child;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.contentMaxWidth),
        child: child,
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: AppDimens.iconXl,
          height: AppDimens.iconXl,
          child: CircularProgressIndicator(
            strokeWidth: AppDimens.progressStroke,
          ),
        ),
      ),
    );
  }
}
