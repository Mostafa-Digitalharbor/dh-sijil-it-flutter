import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// A leading element, a gap, and a column of text that takes the rest of the
/// row.
///
/// ## Why this is a widget and not a copied Row
///
/// It is the most-repeated shape in the product: an avatar or an icon beside
/// a name and a subtitle. Eighteen screens built it by hand, and each one had
/// to remember the same four things —
///
/// * the text column is wrapped in [Expanded], or a long asset name overflows
///   the row instead of ellipsing;
/// * `mainAxisSize: MainAxisSize.min`, or the column claims the full height of
///   whatever bounded box it lands in;
/// * `crossAxisAlignment: CrossAxisAlignment.start`, or the text centres
///   itself against the avatar and stops lining up with the rows above it;
/// * a spacing token for the gap rather than a number.
///
/// Three of those are invisible when they are wrong on a wide screen and only
/// show up on a 320-pt phone in Arabic at the text-size ceiling — which is to
/// say, in the place a reviewer is least likely to look. Writing them once
/// means the responsive sweep proves them once.
///
/// The row is deliberately *not* tappable: the call sites wrap it in whatever
/// they already use — `AppCard.row`, an `InkWell`, a `ListTile` — and folding
/// that in here would mean this widget owning ink, semantics and selection
/// state it has no opinion about.
class AppMediaRow extends StatelessWidget {
  const AppMediaRow({
    required this.leading,
    required this.children,
    this.trailing,
    this.gap = AppSpacing.md,
    this.alignment = CrossAxisAlignment.center,
    super.key,
  });

  /// Drawn at the start edge — an avatar, an icon plate, a thumbnail.
  final Widget leading;

  /// The text column. Stacked in the order given, start-aligned.
  final List<Widget> children;

  /// Drawn at the end edge, at its natural size — a chevron, a chip, a menu.
  final Widget? trailing;

  /// Space between [leading] and the text, and between the text and
  /// [trailing]. A token, never a raw number.
  final double gap;

  /// How [leading] and [trailing] sit against the text column.
  ///
  /// Centre by default, which is right when the text is one or two lines.
  /// A block that can wrap to several passes [CrossAxisAlignment.start] so the
  /// icon stays level with the first line rather than drifting to the middle
  /// of a paragraph.
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: alignment,
      children: <Widget>[
        leading,
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
        if (trailing case final Widget trailing) ...<Widget>[
          SizedBox(width: gap),
          trailing,
        ],
      ],
    );
  }
}
