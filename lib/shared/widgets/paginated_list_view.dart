import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/error/failures.dart';
import '../../core/responsive/responsive.dart';
import '../cubit/view_state.dart';
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
    this.skeletonRowHeight = AppDimens.skeletonRowHeight,
    super.key,
  });

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

  final double skeletonRowHeight;

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
    // First load with nothing to show yet: a skeleton, so the layout does not
    // jump when the rows arrive.
    if (widget.status.isInitialLoad && widget.items.isEmpty) {
      return SkeletonList(itemHeight: widget.skeletonRowHeight);
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
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 1),
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
