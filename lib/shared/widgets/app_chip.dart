import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';

/// The one pill in the product: status, warranty, filter, capability, tag.
///
/// Takes a single [tone] colour and derives fill, border and label ink from
/// it, so a new chip cannot drift out of the system. The label is never
/// dropped in favour of colour alone — that is what keeps the states readable
/// in greyscale and for colour-blind users.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.tone,
    this.icon,
    this.leadingDot = false,
    this.trailingIcon,
    this.onTap,
    this.onRemove,
    this.selected = false,
    this.bordered = false,
    this.dense = false,
    this.semanticSuffix,
    super.key,
  });

  /// Neutral chip on the muted surface — capability "off", accessory "not
  /// returned", secondary metadata.
  const AppChip.neutral({
    required this.label,
    this.icon,
    this.onTap,
    this.onRemove,
    this.dense = false,
    this.semanticSuffix,
    super.key,
  }) : tone = null,
       leadingDot = false,
       trailingIcon = null,
       selected = false,
       bordered = false;

  final String label;

  /// Null renders the neutral variant.
  final Color? tone;

  final IconData? icon;

  /// Draws the small status dot that pairs with [tone].
  final bool leadingDot;

  final IconData? trailingIcon;
  final VoidCallback? onTap;

  /// Renders a dismiss affordance — used by active filter chips.
  final VoidCallback? onRemove;

  /// Inverted treatment: solid brand fill, used for an applied filter.
  final bool selected;

  final bool bordered;
  final bool dense;

  /// Appended to the accessible label, e.g. "kept on this device".
  final String? semanticSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color background;
    final Color ink;
    final Color? borderColor;

    if (selected) {
      background = isDark ? AppColors.mint : AppColors.navy;
      ink = isDark ? AppColors.navy : Colors.white;
      borderColor = null;
    } else if (tone == null) {
      background = isDark ? AppColors.borderDark : AppColors.surfaceLight;
      ink = scheme.onSurfaceVariant;
      borderColor = bordered ? scheme.outlineVariant : null;
    } else {
      background = tone!.withValues(alpha: AppOpacities.chipFill);
      ink = inkFor(context, tone!);
      borderColor = bordered
          ? tone!.withValues(alpha: AppOpacities.chipBorder)
          : null;
    }

    final textStyle =
        (dense ? theme.textTheme.bodySmall : theme.textTheme.labelSmall)
            ?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              letterSpacing: dense ? 0 : null,
            );

    final chip = Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDot && tone != null) ...[
            _Dot(color: tone!),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (icon != null) ...[
            Icon(icon, size: AppDimens.iconChip, color: ink),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(trailingIcon, size: AppDimens.iconControl, color: ink),
          ],
          if (onRemove != null) ...[
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Icon(
                Icons.close_rounded,
                size: AppDimens.iconSm,
                color: ink.withValues(alpha: AppOpacities.secondaryIcon),
              ),
            ),
          ],
        ],
      ),
    );

    final semantic = Semantics(
      label: semanticSuffix == null ? label : '$label — $semanticSuffix',
      button: onTap != null,
      child: ExcludeSemantics(child: chip),
    );

    if (onTap == null) return semantic;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: semantic,
    );
  }

  /// Label ink for a chip of the given [tone].
  ///
  /// The raw status hues are tuned for fills and dots. At a 12% tint several
  /// of them — mint, amber, the greys — miss 4.5:1 for text in light mode, so
  /// light mode uses a darkened variant and dark mode uses the hue itself.
  static Color inkFor(BuildContext context, Color tone) {
    if (Theme.of(context).brightness == Brightness.dark) return tone;
    return AppColors.inkFor(tone);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: AppDimens.dotSize,
    height: AppDimens.dotSize,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A horizontally scrolling row of chips that never overflows.
///
/// Filter rows are the classic overflow bug: three chips fit in English and
/// the fourth clips in Arabic. Scrolling sidesteps it entirely.
class AppChipBar extends StatelessWidget {
  const AppChipBar({
    required this.children,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.pageGutter,
    ),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    // A horizontally-scrolling list needs a bounded height, and a chip's height
    // is driven by its label — so the bound has to follow the text scaler.
    // Fixed at 40 px this clipped by exactly the few pixels the label grew,
    // which is how a 3-pixel overflow stripe ends up on the assets screen at a
    // large accessibility text size.
    final height =
        MediaQuery.textScalerOf(context).scale(AppDimens.chipHeight) +
        AppSpacing.sm;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) => Center(child: children[index]),
      ),
    );
  }
}

/// Chips that wrap onto multiple lines — capability lists, accessories.
class AppChipWrap extends StatelessWidget {
  const AppChipWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: children,
  );
}
