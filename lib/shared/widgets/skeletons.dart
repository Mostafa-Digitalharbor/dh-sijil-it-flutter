import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/responsive/responsive.dart';
import 'app_card.dart';
import 'app_media_row.dart';

/// Placeholders shaped like the content they stand in for.
///
/// ## Why these are not grey rectangles
///
/// A loading state has one job beyond saying "wait": it has to reserve the
/// space the real content will take. Get that wrong and the first frame of
/// data shoves the layout — the row the user was already reaching for moves
/// under their thumb, and on a slow connection they tap the wrong asset.
///
/// The old placeholder was a stack of 84-pt boxes for every screen in the app.
/// It was honest about *something* arriving and wrong about its shape, so the
/// dashboard jumped by most of a screen when its donut and trend card landed,
/// and a detail screen jumped by all of it.
///
/// So each skeleton here mirrors one real widget, and mirrors it by reusing
/// the same tokens rather than by eye: [SkeletonListRow] is built from the
/// same `AppCard.row` padding, the same `AppSpacing.md` gutter and the same
/// `AppDimens.tileMd` leading square as `AppListTile`. When the row changes,
/// the placeholder moves with it.
///
/// ## One shimmer, not many
///
/// Every leaf reads its colours from the theme and animates on its own. Nested
/// `Shimmer`s would each run their own gradient, and the seams show. The
/// primitives below therefore paint a plain box, and [SkeletonPage] wraps a
/// whole screen in the single sweep.
abstract final class _SkeletonPalette {
  static Color base(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? AppColors.borderLight
      : AppColors.borderDark;

  static Color highlight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? AppColors.surfaceLight
      : AppColors.cardDark;
}

/// Wraps a subtree in one shimmer sweep.
///
/// Callers that already sit inside a [SkeletonPage] must not add another.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _SkeletonPalette.base(context),
      highlightColor: _SkeletonPalette.highlight(context),
      child: child,
    );
  }
}

/// A stand-in for one line of text.
///
/// [widthFactor] is a fraction of the available width rather than a fixed
/// length: a title placeholder that is always 180 pt looks pasted on a tablet
/// and overflows a 320-pt phone.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({this.widthFactor = 1, this.height, super.key})
    : _role = _LineRole.plain;

  /// A title line, as tall as the `titleSmall` line it stands in for.
  const SkeletonLine.title({this.widthFactor = 0.55, super.key})
    : height = null,
      _role = _LineRole.title;

  /// A subtitle or caption line, as tall as `bodySmall`.
  const SkeletonLine.caption({this.widthFactor = 0.8, super.key})
    : height = null,
      _role = _LineRole.caption;

  final double widthFactor;

  /// An explicit height. Null lets the role decide.
  final double? height;

  final _LineRole _role;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height ?? _lineHeight(context),
          decoration: BoxDecoration(
            color: _SkeletonPalette.base(context),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
        ),
      ),
    );
  }

  /// One line of the text this bar is standing in for.
  ///
  /// The title bar used to be a flat 12 px and the caption 8 — roughly half
  /// of what the text actually occupies. Six of those stacked made the asset
  /// list's placeholder 43 px shorter *per row* than the list that replaced
  /// it, so the moment the data landed the page jumped under the reader's
  /// thumb. Deriving the height from the style also means the placeholder
  /// grows when the user turns text up, which the fixed bars never did.
  double _lineHeight(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = switch (_role) {
      _LineRole.title => text.titleSmall,
      _LineRole.caption => text.bodySmall,
      _LineRole.plain => null,
    };

    final size = style?.fontSize;
    if (size == null) return AppSpacing.md;

    // `height` is unset on the styles that inherit the font's own leading;
    // 1.4 is what the rest of the type scale uses.
    return MediaQuery.textScalerOf(
      context,
    ).scale(size * (style?.height ?? 1.4));
  }
}

/// Which piece of type a [SkeletonLine] is standing in for.
enum _LineRole { plain, title, caption }

/// A stand-in for a square leading tile or an avatar.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({
    this.size = AppDimens.tileMd,
    this.radius = AppRadii.md,
    super.key,
  });

  const SkeletonTile.circle({this.size = AppDimens.avatarMd, super.key})
    : radius = AppRadii.pill;

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _SkeletonPalette.base(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A stand-in for a status or warranty chip.
class SkeletonChip extends StatelessWidget {
  const SkeletonChip({this.width = AppDimens.barLabelMaxWidth, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: AppDimens.chipHeight,
      decoration: BoxDecoration(
        color: _SkeletonPalette.base(context),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }
}

/// A stand-in for one `AppListTile` — an asset, an employee, a request.
///
/// Built from the same tokens as the real row, so the two occupy identical
/// space and the list does not move when the data lands.
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({this.showChips = true, super.key});

  /// Whether to stand in for an asset row rather than an employee one.
  ///
  /// The two differ in more than the chips: an asset's subtitle is a tag, a
  /// manufacturer and a holder, which wraps to a second line on a phone,
  /// while an employee's is a department and a title on one. Both are drawn
  /// here, because getting only the chips right still left the placeholder a
  /// line short of what replaced it.
  final bool showChips;

  @override
  Widget build(BuildContext context) {
    return AppCard.row(
      child: AppMediaRow(
        leading: const SkeletonTile(),
        children: <Widget>[
          const SkeletonLine.title(),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonLine.caption(),
          if (showChips) ...<Widget>[
            // No gap: this is the second line of one wrapped subtitle,
            // not a second field.
            const SkeletonLine.caption(widthFactor: 0.5),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: <Widget>[
                SkeletonChip(width: AppDimens.barLabelMinWidth),
                SizedBox(width: AppSpacing.snug),
                SkeletonChip(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A list of [SkeletonListRow]s, laid out on the gutter the real list uses.
class SkeletonRowList extends StatelessWidget {
  const SkeletonRowList({this.itemCount = 6, this.showChips = true, super.key});

  final int itemCount;
  final bool showChips;

  @override
  Widget build(BuildContext context) {
    return SkeletonPage(
      child: ListView.separated(
        padding: EdgeInsetsDirectional.all(context.screen.gutter),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.gridGap),
        itemBuilder: (_, __) => SkeletonListRow(showChips: showChips),
      ),
    );
  }
}

/// A stand-in for a card with a heading and a body of lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    this.lines = 3,
    this.height,
    this.hasHeading = true,
    super.key,
  });

  final int lines;

  /// Fixes the card's height, for a chart whose body is not made of lines.
  final double? height;

  final bool hasHeading;

  @override
  Widget build(BuildContext context) {
    if (height != null) {
      return AppCard(
        child: SizedBox(height: height, width: double.infinity),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasHeading) ...<Widget>[
            const SkeletonLine(widthFactor: 0.4),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (var i = 0; i < lines; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            SkeletonLine.caption(widthFactor: i.isEven ? 0.9 : 0.7),
          ],
        ],
      ),
    );
  }
}

/// A stand-in for a two-column key/value block on a detail screen.
class SkeletonKeyValues extends StatelessWidget {
  const SkeletonKeyValues({this.rows = 2, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final columns = context.screen.detailColumns;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SkeletonLine(widthFactor: 0.35),
          const SizedBox(height: AppSpacing.lg),
          for (var row = 0; row < rows; row++) ...<Widget>[
            if (row > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var column = 0; column < columns; column++) ...<Widget>[
                  if (column > 0) const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SkeletonLine.caption(widthFactor: 0.5),
                        SizedBox(height: AppSpacing.sm),
                        SkeletonLine.title(widthFactor: 0.8),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A stand-in for a compact action button.
class SkeletonButton extends StatelessWidget {
  const SkeletonButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.buttonHeightCompact,
      decoration: BoxDecoration(
        color: _SkeletonPalette.base(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }
}

/// A stand-in for a text field.
class SkeletonField extends StatelessWidget {
  const SkeletonField({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.fieldHeight,
      decoration: BoxDecoration(
        color: _SkeletonPalette.base(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }
}
