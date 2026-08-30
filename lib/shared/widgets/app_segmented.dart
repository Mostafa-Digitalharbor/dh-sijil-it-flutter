import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';

/// One choice in an [AppSegmented].
class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A small inline segmented control: theme mode, language, auth mode, scan
/// mode.
///
/// Segments share the available width equally and their labels shrink to fit
/// rather than clipping, which is what keeps "System / Light / Dark" and
/// "النظام / فاتح / داكن" both working in the same box.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.semanticLabel,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Pill-sized variant used inline in a label row.
  final bool compact;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final trackColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppDimens.segmentInset),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(
            compact ? AppRadii.pill : AppRadii.thumb,
          ),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            for (final option in options)
              // Flexible, not bare: a compact control sizes to its labels,
              // and two of those at a raised text size are wider than the
              // phone. Loose fit keeps the pill snug at ordinary sizes and
              // hands the segments a ceiling when there is not room — which
              // is what lets the [FittedBox] inside each one do its job
              // instead of the row painting a yellow bar.
              compact
                  ? Flexible(
                      child: _Segment<T>(
                        option: option,
                        selected: option.value == value,
                        compact: true,
                        onTap: () => onChanged(option.value),
                      ),
                    )
                  : Expanded(
                      child: _Segment<T>(
                        option: option,
                        selected: option.value == value,
                        compact: false,
                        onTap: () => onChanged(option.value),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(
      compact ? AppRadii.pill : AppRadii.control,
    );

    return Semantics(
      selected: selected,
      button: true,
      label: option.label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              height: AppDimens.segmentHeight,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: compact ? AppSpacing.md : AppSpacing.sm,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (option.icon != null) ...[
                    Icon(
                      option.icon,
                      size: AppDimens.iconSegment,
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.snug),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        option.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled checkbox row, used for "Keep me signed in" and the accessories
/// checklist.
class AppCheckRow extends StatelessWidget {
  const AppCheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;

  /// Null disables the row.
  ///
  /// Nullable rather than always-callable so a control the app cannot honour
  /// — a device unlock on a phone with no screen lock — reads as unavailable
  /// instead of accepting a tap and silently doing nothing.
  final ValueChanged<bool>? onChanged;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      checked: value,
      enabled: _enabled,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: AppDimens.checkboxSize,
                  height: AppDimens.checkboxSize,
                  decoration: BoxDecoration(
                    color: value && _enabled
                        ? (isDark ? AppColors.mint : AppColors.navy)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                    border: value && _enabled
                        ? null
                        : Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: value && _enabled
                      ? Icon(
                          Icons.check_rounded,
                          size: AppDimens.iconControl,
                          color: isDark ? AppColors.navy : Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.dense),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
