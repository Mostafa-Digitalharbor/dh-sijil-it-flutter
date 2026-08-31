import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';

/// Which corner a bracket is drawn in, named by *direction* rather than by
/// side so the set mirrors correctly under an Arabic locale.
enum ViewfinderCorner {
  topStart,
  topEnd,
  bottomStart,
  bottomEnd;

  bool get isTop =>
      this == ViewfinderCorner.topStart || this == ViewfinderCorner.topEnd;

  bool get isStart =>
      this == ViewfinderCorner.topStart || this == ViewfinderCorner.bottomStart;
}

/// Four corner brackets, drawn to the edges of whatever box contains them.
///
/// ## Why corners and not a box
///
/// A full outline reads as a frame you must fit the code *inside*, so people
/// back away until the whole sticker is in it — and by then the code is too
/// small to decode. Corners read as an aim point, which is what they are: the
/// detector reads the entire frame either way.
///
/// ## Why this is shared
///
/// The scanner and the audit counter both draw this, and they used to draw it
/// twice. The copies had already diverged: the audit's was built from
/// `Border(left:)` and `BorderRadius.only(topLeft:)`, which are absolute
/// sides, so under Arabic its brackets stayed put while every other element
/// on the screen mirrored — the one asymmetry a reviewer never notices
/// because both versions look like brackets.
class ViewfinderBrackets extends StatelessWidget {
  const ViewfinderBrackets({
    this.size,
    this.armLength = AppDimens.viewfinderCorner,
    this.weight = AppDimens.viewfinderCornerWeight,
    this.radius = AppRadii.md,
    this.color = AppColors.mint,
    super.key,
  });

  /// The scanner's larger set: longer arms, a heavier stroke, a rounder turn.
  const ViewfinderBrackets.scanner({Key? key})
    : this(
        armLength: AppDimens.scannerCorner,
        weight: AppDimens.scannerCornerWidth,
        radius: AppRadii.viewfinder,
        key: key,
      );

  /// Side of the square the brackets span. Null fills the parent, which is
  /// what a [Stack] child wants.
  final double? size;

  /// How far each arm runs from its corner.
  final double armLength;

  final double weight;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    final brackets = Stack(
      children: <Widget>[
        for (final corner in ViewfinderCorner.values)
          Positioned.directional(
            textDirection: textDirection,
            top: corner.isTop ? 0 : null,
            bottom: corner.isTop ? null : 0,
            start: corner.isStart ? 0 : null,
            end: corner.isStart ? null : 0,
            child: _Bracket(
              corner: corner,
              armLength: armLength,
              weight: weight,
              radius: radius,
              color: color,
            ),
          ),
      ],
    );

    final side = size;
    if (side == null) return brackets;
    return SizedBox(width: side, height: side, child: brackets);
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({
    required this.corner,
    required this.armLength,
    required this.weight,
    required this.radius,
    required this.color,
  });

  final ViewfinderCorner corner;
  final double armLength;
  final double weight;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: color, width: weight);
    final turn = Radius.circular(radius);

    return SizedBox(
      width: armLength,
      height: armLength,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: corner.isTop ? side : BorderSide.none,
            bottom: corner.isTop ? BorderSide.none : side,
            start: corner.isStart ? side : BorderSide.none,
            end: corner.isStart ? BorderSide.none : side,
          ),
          // Only the outer turn is rounded: the two open ends stay square, so
          // the bracket reads as a corner of a frame rather than as a tick.
          borderRadius: BorderRadiusDirectional.only(
            topStart: corner == ViewfinderCorner.topStart ? turn : Radius.zero,
            topEnd: corner == ViewfinderCorner.topEnd ? turn : Radius.zero,
            bottomStart: corner == ViewfinderCorner.bottomStart
                ? turn
                : Radius.zero,
            bottomEnd: corner == ViewfinderCorner.bottomEnd
                ? turn
                : Radius.zero,
          ).resolve(Directionality.of(context)),
        ),
      ),
    );
  }
}
