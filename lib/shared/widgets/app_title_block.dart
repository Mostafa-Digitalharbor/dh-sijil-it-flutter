import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

/// A name with a line under it, filling whatever width is left in a row.
///
/// ## Why this is a widget
///
/// Twenty-one call sites had written out the same eight lines: an [Expanded]
/// wrapping a start-aligned, min-height [Column] of two [Text]s with
/// `maxLines` and `TextOverflow.ellipsis` on each. It is the shape of every
/// row in the product — an asset row, an employee tile, the recipient card, a
/// scan result, a settings entry.
///
/// Repetition is not the real cost. The overflow rules are: a copy that
/// forgets `overflow: TextOverflow.ellipsis` does not fail a test and does not
/// look wrong in English, and then an Arabic asset name with a long
/// manufacturer runs off the row and paints a yellow-and-black bar across it.
/// Written once, every row in the app clips the same way.
class AppTitleBlock extends StatelessWidget {
  const AppTitleBlock({
    required this.title,
    this.subtitle,
    this.caption,
    this.below,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.expand = true,
    super.key,
  });

  final String title;

  /// The second line. Omitted rather than rendered blank when absent, so the
  /// row's height follows its content.
  final String? subtitle;

  /// A third, quieter line — an email under a name, a serial under a model.
  final String? caption;

  /// A second line that is a widget rather than prose.
  ///
  /// The asset rows put a [MonoText] identifier here: a tag is Latin and
  /// monospaced in every locale, so it cannot go through [subtitle], which
  /// follows the language. Rendered after [subtitle] and [caption], so a row
  /// can carry both a description and a tag.
  final Widget? below;

  /// Defaults to `titleSmall`, the row heading weight used across the product.
  final TextStyle? titleStyle;

  /// Defaults to `bodySmall`.
  final TextStyle? subtitleStyle;

  final int titleMaxLines;
  final int subtitleMaxLines;

  /// Whether to take the remaining width of its [Row].
  ///
  /// False where the block sits in a [Column] or a sheet, which have no free
  /// horizontal space to claim and where an [Expanded] would throw.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: titleStyle ?? theme.textTheme.titleSmall,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            style: subtitleStyle ?? theme.textTheme.bodySmall,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (caption != null && caption!.isNotEmpty)
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.faint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (below != null) below!,
      ],
    );

    return expand ? Expanded(child: column) : column;
  }
}
