import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';

/// Visual weight of a button, in descending order of emphasis.
enum AppButtonVariant {
  /// The one primary action on a screen.
  filled,

  /// A workflow confirmation — mint, used for Assign / Return / Confirm.
  accent,

  /// Secondary actions that sit beside a primary one.
  outlined,

  /// Destructive: sign out, delete.
  danger,
}

/// The one button in the product.
///
/// Wraps Material's buttons so that height, radius, label style, the busy
/// state and the disabled state are decided once. A feature never reaches for
/// `FilledButton` directly, which is what stops a 44-px button appearing on
/// one screen and a 52-px one on the next.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.isBusy = false,
    this.isCompact = false,
    this.expand = true,
    super.key,
  });

  const AppButton.accent({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.isCompact = false,
    this.expand = true,
    super.key,
  }) : variant = AppButtonVariant.accent;

  const AppButton.outlined({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.isCompact = false,
    this.expand = true,
    super.key,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.danger({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.isCompact = false,
    this.expand = true,
    super.key,
  }) : variant = AppButtonVariant.danger;

  final String label;

  /// Null disables the button. A busy button is also non-interactive.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final IconData? icon;

  /// Swaps the icon for a spinner and blocks input, without changing width —
  /// so the layout does not jump while a request is in flight.
  final bool isBusy;

  final bool isCompact;

  /// False makes the button hug its label instead of filling its parent.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = isCompact
        ? AppDimens.buttonHeightCompact
        : AppDimens.buttonHeight;

    final (background, foreground, border) = _palette(theme, isDark);
    final enabled = onPressed != null && !isBusy;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isBusy)
          SizedBox(
            width: AppDimens.iconMd,
            height: AppDimens.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: AppDimens.progressStroke,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        else if (icon != null)
          Icon(icon, size: AppDimens.iconLg, color: foreground),
        if (isBusy || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : AppOpacities.disabled,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            height: height,
            width: expand ? double.infinity : null,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: border,
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  (Color, Color, Border?) _palette(ThemeData theme, bool isDark) {
    final scheme = theme.colorScheme;

    return switch (variant) {
      // In dark mode the primary surface is mint on navy, so the filled
      // button inverts rather than becoming an invisible navy-on-navy slab.
      AppButtonVariant.filled =>
        isDark
            ? (AppColors.mint, AppColors.navy, null)
            : (AppColors.navy, Colors.white, null),
      AppButtonVariant.accent => (AppColors.mint, AppColors.navy, null),
      AppButtonVariant.outlined => (
        scheme.surface,
        scheme.onSurface,
        Border.all(color: scheme.outlineVariant),
      ),
      AppButtonVariant.danger => (
        scheme.surface,
        AppColors.danger,
        Border.all(
          color: AppColors.danger.withValues(alpha: AppOpacities.dangerBorder),
        ),
      ),
    };
  }
}

/// A square icon-only button — app bar actions, the torch toggle, the photo
/// remove control.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.bordered = true,
    this.color,
    this.backgroundColor,
    this.size = AppDimens.appBarActionSize,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Required, not optional: an icon with no label needs an accessible name.
  final String tooltip;

  final bool bordered;
  final Color? color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          // The visual box may be smaller than the tap target; this keeps the
          // touchable area at the platform minimum regardless.
          width: size < AppDimens.minTapTarget ? AppDimens.minTapTarget : size,
          height: size < AppDimens.minTapTarget ? AppDimens.minTapTarget : size,
          child: Center(
            child: Material(
              color:
                  backgroundColor ??
                  (bordered ? scheme.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: bordered
                        ? Border.all(color: scheme.outlineVariant)
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: AppDimens.iconLg,
                    color: color ?? scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A low-emphasis inline action: "See all", "Detect", "Change".
class AppTextAction extends StatelessWidget {
  const AppTextAction({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The palette already resolves mint per brightness — raw mint on dark,
    // the darkened partner on light. This used to read `colorScheme.secondary`
    // and re-derive the light variant by hand, which silently turned every
    // "See all" blue the moment `secondary` stopped being mint.
    //
    // A null callback has to *look* inert. Until this, "Clear" beside an empty
    // signature pad rendered in full accent and swallowed the tap in silence,
    // which reads as the app having missed the press.
    final isEnabled = onPressed != null;
    final accent = isEnabled ? context.palette.mint : context.palette.faint;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppDimens.iconSm, color: accent),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                letterSpacing: AppTypography.noTracking,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The × that dismisses a modal form.
///
/// Four screens — the asset form, assign, return and handover — each spelled
/// out the same five lines: the rounded close glyph, the "Close" tooltip, and
/// `bordered: false` so it reads as chrome rather than as an action. The only
/// thing that differed between them was the callback.
///
/// It is a widget rather than a named constructor on [AppIconButton] because
/// the tooltip has to be translated, and that needs a `BuildContext` the
/// constructor does not have.
///
/// Deliberately *not* used by the scanner, whose close button is drawn white
/// on a live camera feed and carries its own colours.
class AppCloseButton extends StatelessWidget {
  const AppCloseButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.close_rounded,
      tooltip: AppL10n.of(context).actionClose,
      bordered: false,
      onPressed: onPressed,
    );
  }
}
