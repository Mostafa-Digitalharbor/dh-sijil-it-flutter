import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';

/// The one card in the product.
///
/// Every panel, tile and row container is this widget. Nothing else may draw
/// a rounded, bordered surface — that is what keeps radius, border and
/// padding identical across nine features without a style guide anyone has
/// to remember.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.radius = AppRadii.lg,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.backgroundColor,
    this.selected = false,
    this.semanticLabel,
    super.key,
  });

  /// A card with no inner padding, for lists of rows that pad themselves.
  const AppCard.flush({
    required this.child,
    this.radius = AppRadii.lg,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.backgroundColor,
    this.selected = false,
    this.semanticLabel,
    super.key,
  }) : padding = EdgeInsets.zero;

  /// Compact variant used for list rows.
  const AppCard.row({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.backgroundColor,
    this.selected = false,
    this.semanticLabel,
    super.key,
  }) : padding = const EdgeInsetsDirectional.symmetric(
         horizontal: AppSpacing.md,
         vertical: AppSpacing.md,
       ),
       radius = AppRadii.lg;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// The long-press gesture, for a row that can start a multi-selection.
  ///
  /// Given its own `InkWell` arm rather than being folded into [onTap],
  /// because a card with only a long-press must still show ink and still be
  /// reachable — and because `InkWell` treats a null `onTap` as "not
  /// interactive" and swallows the press.
  final VoidCallback? onLongPress;

  final Color? borderColor;
  final Color? backgroundColor;

  /// Draws the accent selection border instead of the neutral one.
  final bool selected;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final border = selected
        ? BorderSide(color: scheme.secondary, width: AppDimens.selectedBorder)
        : BorderSide(
            color: borderColor ?? scheme.outlineVariant,
            width: AppDimens.hairline,
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border,
    );

    final surface = Material(
      color: backgroundColor ?? scheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: (onTap == null && onLongPress == null)
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(padding: padding, child: child),
            ),
    );

    if (semanticLabel == null) return surface;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected ? true : null,
      child: surface,
    );
  }
}

/// The brand-coloured hero card: the dashboard total, the asset detail header.
///
/// Used sparingly on purpose — it is the loudest surface in the app, so more
/// than one per screen turns the hierarchy to mush.
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: isDark
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.onAccent,
        ),
        child: child,
      ),
    );
  }

  /// Secondary text colour to use inside a hero card.
  static Color subduedText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.textSecondaryDark
      : AppColors.heroSubdued;

  /// Primary text colour to use inside a hero card.
  static Color primaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.textPrimaryDark
      : AppColors.onAccent;
}

/// A card with a small uppercase heading, optional trailing action, and a
/// body — the shape of nearly every block on the detail and settings screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.only(
      start: AppSpacing.lg,
      end: AppSpacing.lg,
      top: AppSpacing.md,
      bottom: AppSpacing.md,
    ),
    super.key,
  });

  final String title;
  final Widget child;

  /// Usually a text button ("See all", "New request").
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// A card that collapses to a single header row.
///
/// Used for the detail sections that are context rather than headline —
/// purchase, vendor, notes. Collapsed by default so the screen opens on the
/// facts a user came for, with the rest one tap away instead of three screens
/// of scrolling down.
class AppExpansionCard extends StatefulWidget {
  const AppExpansionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<AppExpansionCard> createState() => _AppExpansionCardState();
}

class _AppExpansionCardState extends State<AppExpansionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: widget.title,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppDimens.minTapTarget,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: AppDimens.iconLg,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: AppDimens.iconXl,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: AppSpacing.md,
                top: AppSpacing.xs,
              ),
              child: SizedBox(width: double.infinity, child: widget.child),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppDurations.fast,
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}
