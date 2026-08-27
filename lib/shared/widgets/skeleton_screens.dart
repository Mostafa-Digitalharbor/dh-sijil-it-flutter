import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/responsive/responsive.dart';
import 'app_card.dart';
import 'skeletons.dart';

/// Whole-screen placeholders, each shaped like the screen it stands in for.
///
/// The primitives live in `skeletons.dart`; these assemble them into the five
/// layouts the product actually has. Keeping them apart matters because the
/// primitives are reused inside real widgets — a list row that is still
/// loading its photo — while these are only ever a first frame.
///
/// Every one is measured from the real screen rather than drawn by eye. The
/// point of a skeleton is that the content lands *where the placeholder was*;
/// a placeholder of the wrong height is a layout jump with extra steps.

/// A page-shaped skeleton laid out on the same gutter as `AppPageBody`.
///
/// Not `AppPageBody` itself: that one scrolls and carries a refresh
/// indicator, neither of which a placeholder wants. It reuses the padding and
/// the gap so the cards land where the real ones will.
class SkeletonBody extends StatelessWidget {
  const SkeletonBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final screen = context.screen;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          children[i],
        ],
      ],
    );

    return SkeletonPage(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(
          start: screen.gutter,
          end: screen.gutter,
          top: AppSpacing.xs,
          bottom: AppSpacing.xxxl,
        ),
        child: screen.size.isExpanded
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppDimens.contentMaxWidth,
                  ),
                  child: column,
                ),
              )
            : column,
      ),
    );
  }
}

/// The dashboard, before its cards arrive.
///
/// This is the screen the old uniform placeholder mis-sized worst. A ring, a
/// sparkline and a bar chart are nothing like an 84-pt row, so the page used
/// to jump by most of its own length when the summary landed.
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonBody(
      children: <Widget>[
        // The status ring, with its five legend rows beside it.
        AppCard(
          child: Row(
            children: <Widget>[
              SkeletonTile.circle(size: AppDimens.donutSkeleton),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SkeletonLine.caption(widthFactor: 0.9),
                    SizedBox(height: AppSpacing.md),
                    SkeletonLine.caption(widthFactor: 0.9),
                    SizedBox(height: AppSpacing.md),
                    SkeletonLine.caption(widthFactor: 0.9),
                    SizedBox(height: AppSpacing.md),
                    SkeletonLine.caption(widthFactor: 0.9),
                    SizedBox(height: AppSpacing.md),
                    SkeletonLine.caption(widthFactor: 0.9),
                  ],
                ),
              ),
            ],
          ),
        ),
        SkeletonCard(height: AppDimens.trendSkeleton),
        Row(
          children: <Widget>[
            Expanded(child: SkeletonCard(lines: 1)),
            SizedBox(width: AppSpacing.gridGap),
            Expanded(child: SkeletonCard(lines: 1)),
          ],
        ),
        SkeletonCard(lines: 4),
      ],
    );
  }
}

/// A detail screen: a hero card, a row of actions, then blocks of facts.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({this.hasActions = true, super.key});

  final bool hasActions;

  @override
  Widget build(BuildContext context) {
    return SkeletonBody(
      children: <Widget>[
        const AppCard(
          child: Row(
            children: <Widget>[
              SkeletonTile(size: AppDimens.tileLg),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SkeletonLine(widthFactor: 0.7),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonLine.caption(widthFactor: 0.9),
                    SizedBox(height: AppSpacing.md),
                    SkeletonChip(),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasActions)
          const Row(
            children: <Widget>[
              Expanded(child: SkeletonButton()),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(child: SkeletonButton()),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(child: SkeletonButton()),
            ],
          ),
        const SkeletonKeyValues(),
        const SkeletonKeyValues(rows: 1),
      ],
    );
  }
}

/// A form: a stack of labelled fields.
class SkeletonForm extends StatelessWidget {
  const SkeletonForm({this.fields = 5, super.key});

  final int fields;

  @override
  Widget build(BuildContext context) {
    return SkeletonBody(
      children: <Widget>[
        for (var i = 0; i < fields; i++)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SkeletonLine.caption(widthFactor: 0.3),
              SizedBox(height: AppSpacing.sm),
              SkeletonField(),
            ],
          ),
      ],
    );
  }
}

/// A vertical timeline: a rail of dots, an entry beside each.
class SkeletonTimeline extends StatelessWidget {
  const SkeletonTimeline({this.entries = 5, super.key});

  final int entries;

  @override
  Widget build(BuildContext context) {
    return SkeletonBody(
      children: <Widget>[
        for (var i = 0; i < entries; i++)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: AppDimens.timelineRail,
                child: SkeletonTile.circle(size: AppDimens.dotSize),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SkeletonLine.title(widthFactor: 0.6),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonLine.caption(widthFactor: 0.4),
                    SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
