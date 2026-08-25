import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';

/// One tool on the More grid.
///
/// A grid of tiles rather than a list of rows, because More is not a menu of
/// settings — it is the drawer the app keeps its other *tools* in, and each
/// one carries its own state ("9 open", "7 in use"). A row can show a name and
/// a chevron; a tile can show what you would open it to find out.
class AppToolTile extends StatelessWidget {
  const AppToolTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;

  /// Status hue. Tinted for the icon plate, read at the theme's own weight.
  final Color tone;

  final String title;

  /// The live line — what this tool holds right now. Omitted rather than
  /// faked when the count is not known yet.
  final String? subtitle;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.raised,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: palette.lineSoft),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: AppDimens.statusTileSmall,
                  height: AppDimens.statusTileSmall,
                  decoration: BoxDecoration(
                    color: context.tint(tone),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    icon,
                    size: AppDimens.iconLg,
                    color: context.ink(tone),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 1),
                Text(
                  title,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(color: palette.faint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays tools out two-up, growing to fit whatever the text scale needs.
///
/// A [GridView] with a fixed aspect ratio would clip the subtitle the moment
/// the user raises their text size, so the row height is driven by the tallest
/// tile in it instead.
class AppToolGrid extends StatelessWidget {
  const AppToolGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: left),
              const SizedBox(width: AppSpacing.sm + 2),
              // An odd tile keeps its column width instead of stretching to
              // fill the row, so the grid stays a grid.
              Expanded(child: right ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) {
        rows.add(const SizedBox(height: AppSpacing.sm + 2));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
