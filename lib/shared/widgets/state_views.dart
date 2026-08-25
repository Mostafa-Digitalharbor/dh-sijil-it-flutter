import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/error/failure_presenter.dart';
import '../../core/error/failures.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Resolves accent ink for both themes.
///
/// Light mode darkens saturated hues so they clear 4.5:1 as text on their own
/// 12% tint; dark mode uses the hue itself.
abstract final class AppInk {
  static Color of(BuildContext context, Color tone) =>
      Theme.of(context).brightness == Brightness.dark
      ? tone
      : AppColors.inkFor(tone);

  const AppInk._();
}

/// Shimmering placeholder used while first-page data loads (spec §26).
///
/// Skeletons rather than spinners: the layout does not jump when the real
/// content arrives.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = AppSpacing.lg,
    this.radius = AppRadii.sm,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final base = isLight ? AppColors.borderLight : AppColors.borderDark;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: isLight ? AppColors.surfaceLight : AppColors.cardDark,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A list of skeleton rows shaped like the real asset and employee rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.itemCount = 6,
    this.itemHeight = AppDimens.skeletonRowHeight,
    super.key,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsetsDirectional.all(context.screen.gutter),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) =>
          SkeletonBox(height: itemHeight, radius: AppRadii.lg),
    );
  }
}

/// Shared frame for the empty and failure treatments: centred, scrollable so
/// it survives a short viewport or a large text scale, and width-capped so
/// the copy stays readable on a tablet.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.fix,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String? fix;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = context.screen;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Always scrollable so a RefreshIndicator can drive this directly.
        // Callers must not wrap it in a second scroll view: the inner one
        // would be laid out unbounded and `minHeight: constraints.maxHeight`
        // below would become `minHeight: Infinity`.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: screen.gutter,
          vertical: AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.dialogMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppDimens.emptyStateIconBox,
                    height: AppDimens.emptyStateIconBox,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: AppOpacities.tileFill),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(
                      icon,
                      size: AppDimens.iconHuge,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (fix != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _FixHint(fix: fix!),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "what to do" block.
///
/// Visually separated from the cause on purpose: a user who already knows
/// what broke can skip straight to the step that fixes it.
class _FixHint extends StatelessWidget {
  const _FixHint({required this.fix});

  final String fix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final accent = theme.colorScheme.secondary;
    final ink = AppInk.of(context, accent);

    return AppCard(
      backgroundColor: accent.withValues(alpha: AppOpacities.overlay),
      borderColor: accent.withValues(alpha: AppOpacities.chipBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: AppDimens.iconMd,
            color: ink,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.errorHowToFix.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(fix, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a query legitimately returns nothing (spec §26).
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.secondary,
      title: title,
      body: message,
      action: (actionLabel != null && onAction != null)
          ? AppButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
              isCompact: true,
            )
          : null,
    );
  }
}

/// Renders a [Failure] as cause plus fix, with the one action that helps.
///
/// The user never sees a stack trace or an Odoo fault string; the technical
/// detail goes to Settings → Diagnostics instead (spec §22).
class FailureView extends StatelessWidget {
  const FailureView({
    required this.failure,
    this.onRetry,
    this.onEditConnection,
    this.onSignIn,
    super.key,
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final VoidCallback? onEditConnection;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final presented = FailurePresenter.present(AppL10n.of(context), failure);
    final handler = _handlerFor(presented.action);

    return _CenteredMessage(
      icon: presented.icon,
      iconColor: AppColors.danger,
      title: presented.title,
      body: presented.body,
      fix: presented.fix,
      action: (presented.hasAction && handler != null)
          ? AppButton.outlined(
              label: presented.actionLabel,
              onPressed: handler,
              icon: _iconFor(presented.action),
              expand: false,
              isCompact: true,
            )
          : null,
    );
  }

  VoidCallback? _handlerFor(FailureAction action) => switch (action) {
    FailureAction.retry => onRetry,
    FailureAction.editConnection => onEditConnection,
    FailureAction.signIn => onSignIn,
    FailureAction.none => null,
  };

  IconData? _iconFor(FailureAction action) => switch (action) {
    FailureAction.retry => Icons.refresh_rounded,
    FailureAction.editConnection => Icons.settings_ethernet_rounded,
    FailureAction.signIn => Icons.login_rounded,
    FailureAction.none => null,
  };
}

/// Centred spinner, for the rare case where a skeleton cannot fit the layout
/// (a full-screen modal mid-submit).
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: AppDimens.progressStrokeThick,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
