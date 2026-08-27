import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/responsive/responsive.dart';
import '../utils/app_number.dart';
import '../utils/app_text.dart';
import 'app_card.dart';

/// One segment of a proportional bar.
class BarSegment {
  const BarSegment({required this.value, required this.color, this.label});

  final num value;
  final Color color;
  final String? label;
}

/// A single stacked bar showing how a total splits — the dashboard's status
/// distribution.
///
/// Zero-value segments are dropped rather than rendered at 0 px, which would
/// otherwise leave stray gap artefacts between the visible ones.
class DistributionBar extends StatelessWidget {
  /// `Expanded.flex` is an int, so the proportions have to be quantised. A
  /// thousand steps puts the rounding error below a tenth of a percent, which
  /// is finer than the bar can render on any screen the app runs on.
  ///
  /// Doubles as the clamp ceiling: a segment is never given more than the
  /// whole bar, and — via the floor of 1 — a segment that rounds to nothing
  /// still draws, because a status with one asset in it disappearing from the
  /// distribution is worse than a hairline that is technically too wide.
  static const int _flexResolution = 1000;

  const DistributionBar({
    required this.segments,
    this.height = AppDimens.statusStripHeight,
    super.key,
  });

  final List<BarSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.value > 0).toList();
    final total = visible.fold<num>(0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          height: height,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(width: AppDimens.statusStripGap),
              Expanded(
                flex: (visible[i].value / total * _flexResolution)
                    .round()
                    .clamp(1, _flexResolution),
                child: ColoredBox(color: visible[i].color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labelled horizontal bar — "Laptop ████████ 43".
///
/// The label column is width-capped rather than fixed so a long Arabic
/// category name truncates instead of squeezing the bar to nothing.
class LabeledBar extends StatelessWidget {
  const LabeledBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    super.key,
  });

  final String label;
  final num value;
  final num max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();

    return Semantics(
      // Through AppNumber, not interpolated: `'$value'` is always Latin, so a
      // screen reader on an Arabic device announced "١٢ laptops" as
      // "12 laptops" — the digit rule applies to what is spoken too.
      label: AppText.labelled(label, AppNumber.count(context, value)),
      child: ExcludeSemantics(
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.barLabelMaxWidth,
                minWidth: AppDimens.barLabelMinWidth,
              ),
              child: Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Stack(
                  children: [
                    Container(
                      height: AppDimens.progressBarHeight,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: AppOpacities.divider,
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: AppDimens.progressBarHeight,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: AppDimens.barValueWidth,
              child: Text(
                AppNumber.count(context, value),
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A count tile — the six status tiles on the dashboard.
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    required this.value,
    required this.label,
    this.tone,
    this.onTap,
    this.icon,
    super.key,
  });

  final String value;
  final String label;

  /// Draws the status dot and tints the number.
  final Color? tone;

  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = tone == null
        ? theme.colorScheme.onSurface
        : (theme.brightness == Brightness.dark
              ? tone!
              : AppColors.inkFor(tone!));

    return AppCard(
      onTap: onTap,
      radius: AppRadii.card,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.dense,
      ),
      semanticLabel: AppText.labelled(label, value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tone != null)
            Container(
              width: AppDimens.dotSize,
              height: AppDimens.dotSize,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            )
          else if (icon != null)
            Icon(icon, size: AppDimens.iconMd, color: ink),
          const SizedBox(height: AppSpacing.tight),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: ink,
                fontFeatures: AppTypography.tabular,
                height: AppTypography.solidLineHeight,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A responsive grid of stat tiles.
///
/// Column count follows the size class, and drops to two when text is scaled
/// up — three 110-px tiles with a scaled label is where the dashboard used to
/// overflow.
class AppStatGrid extends StatelessWidget {
  const AppStatGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final screen = context.screen;
    // Not re-derived here: `statTileColumns` is the same rule the rest of the
    // app asks for by name, and this grid had quietly grown its own copy of
    // it — with the breakpoints spelled out a second time.
    final columns = screen.statTileColumns;

    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final slice = tiles.sublist(i, (i + columns).clamp(0, tiles.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  child: c < slice.length ? slice[c] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.gridGap),
          rows[i],
        ],
      ],
    );
  }
}

/// A tinted "needs attention" card — warranty expiring, maintenance open.
class AppAttentionTile extends StatelessWidget {
  const AppAttentionTile({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color tone;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.brightness == Brightness.dark
        ? tone
        : AppColors.inkFor(tone);

    return AppCard(
      onTap: onTap,
      radius: AppRadii.card,
      backgroundColor: tone.withValues(alpha: AppOpacities.overlay),
      borderColor: tone.withValues(alpha: AppOpacities.chipBorder),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.dense,
      ),
      semanticLabel: AppText.labelled(label, value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: AppDimens.iconMd, color: ink),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: ink,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.fine),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A numbered step heading in a multi-step form.
class AppStepHeader extends StatelessWidget {
  const AppStepHeader({
    required this.step,
    required this.title,
    this.trailing,
    this.isActive = true,
    super.key,
  });

  final int step;
  final String title;
  final String? trailing;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badgeBackground = isActive
        ? (isDark ? AppColors.mint : AppColors.navy)
        : theme.colorScheme.outlineVariant;
    final badgeInk = isActive
        ? (isDark ? AppColors.navy : Colors.white)
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Container(
          width: AppDimens.stepBadgeSize,
          height: AppDimens.stepBadgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeBackground,
            shape: BoxShape.circle,
          ),
          child: Text(
            // Through AppNumber: `'$step'` is Latin whatever the locale, which
            // put "1" in the badge above an Arabic heading counting "١".
            AppNumber.count(context, step),
            style: theme.textTheme.labelSmall?.copyWith(
              color: badgeInk,
              letterSpacing: AppTypography.noTracking,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) Text(trailing!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
