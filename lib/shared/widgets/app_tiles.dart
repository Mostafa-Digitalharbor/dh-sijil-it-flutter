import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/responsive/responsive.dart';
import '../utils/app_text.dart';
import 'app_avatar.dart';
import 'app_card.dart';

/// The list row used across assets, employees and maintenance.
///
/// One widget rather than three near-identical ones: they differ only in what
/// goes in the leading slot and the chip row, and keeping them unified is
/// what makes a spacing change land everywhere at once.
class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.chips = const [],
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.subtitleIsLatin = false,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Status, warranty and metadata chips under the subtitle.
  final List<Widget> chips;

  /// Replaces the chevron — usually a single status chip.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;

  /// Forces LTR on the subtitle, for rows whose subtitle is a tag and serial.
  final bool subtitleIsLatin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = context.screen;

    // At a large text scale a trailing chip beside two lines of title no
    // longer fits on one row, so the chip moves below instead of clipping.
    final stackTrailing = screen.isLargeText && trailing != null;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          _Subtitle(text: subtitle!, forceLatin: subtitleIsLatin),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.snug,
            runSpacing: AppSpacing.xs,
            children: chips,
          ),
        ],
        if (stackTrailing) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(alignment: AlignmentDirectional.centerStart, child: trailing!),
        ],
      ],
    );

    return AppCard.row(
      onTap: onTap,
      semanticLabel: AppText.announced(title, subtitle ?? ''),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(child: text),
          if (!stackTrailing && trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ] else if (!stackTrailing && showChevron && onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconXl,
              color: theme.colorScheme.outlineVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text, required this.forceLatin});

  final String text;
  final bool forceLatin;

  @override
  Widget build(BuildContext context) {
    final widget = Text(
      text,
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (!forceLatin) return widget;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: AlignmentDirectional.centerStart, child: widget),
    );
  }
}

/// A selectable row — the employee picker in the assignment flow.
class AppSelectableTile extends StatelessWidget {
  const AppSelectableTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.caption,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard.row(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$title, $subtitle',
      child: Row(
        children: [
          AppAvatar(name: title, emphasised: selected),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SelectionMark(selected: selected),
        ],
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: AppDurations.fast,
      width: AppDimens.radioSize,
      height: AppDimens.radioSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.mint : Colors.transparent,
        border: selected
            ? null
            : Border.all(
                color: theme.colorScheme.outlineVariant,
                width: AppDimens.focusedBorder,
              ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: AppDimens.iconSm,
              color: AppColors.navy,
            )
          : null,
    );
  }
}

/// A settings row: icon, title, supporting line, chevron.
class AppSettingTile extends StatelessWidget {
  const AppSettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
    this.tone,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? tone;

  /// Whether to show the trailing chevron.
  ///
  /// A chevron is a promise that tapping opens something. Turn it off when the
  /// row is a *choice* — a radio option that stays on this screen — or the
  /// control lies about what it does.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone ?? theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppDimens.minTapTarget),
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.md,
          ),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: AppOpacities.dividerSoft,
                      ),
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(icon, size: AppDimens.iconXl, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(color: tone),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onTap != null && showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppDimens.iconXl,
                  color: theme.colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashboard or asset-detail activity entry.
class AppActivityTile extends StatelessWidget {
  const AppActivityTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.timestamp,
    this.showDivider = false,
    super.key,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String timestamp;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: AppOpacities.dividerSoft,
                  ),
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          AppLeadingTile.small(icon: icon, tone: tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(timestamp, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
