import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/error/failure_presenter.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_media_row.dart';
import '../../../assets/presentation/widgets/asset_icons.dart';
import '../cubit/scanner_cubit.dart';

/// The white card over the camera showing what the last scan resolved to.
///
/// Three outcomes, all handled here so the camera screen itself stays about
/// aiming: a match, a code nothing matches, and a lookup that failed.
class ScanResultSheet extends StatelessWidget {
  const ScanResultSheet({required this.state, super.key});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: context.screen.gutter,
      ),
      child: AppCard(
        radius: AppRadii.sheetCard,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: switch (state) {
          _ when state.isResolving => const _Resolving(),
          _ when state.hasFailed && state.failure != null => _LookupFailed(
            state: state,
          ),
          _ when state.match != null => _MatchFound(state: state),
          _ => _NoMatch(state: state),
        },
      ),
    );
  }
}

class _Resolving extends StatelessWidget {
  const _Resolving();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        const SizedBox(
          width: AppDimens.iconXl,
          height: AppDimens.iconXl,
          child: CircularProgressIndicator(
            strokeWidth: AppDimens.progressStroke,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(l10n.loadingLabel, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}

class _MatchFound extends StatelessWidget {
  const _MatchFound({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final asset = state.match!;

    return AppMediaRow(
      leading: AppLeadingTile(
        icon: AssetIcons.forCategory(asset.category?.name),
        tone: AppColors.statusAvailable,
      ),
      gap: AppSpacing.sm,
      trailing: AppButton(
        label: l10n.actionOpen,
        expand: false,
        isCompact: true,
        onPressed: () {
          context.read<ScannerCubit>().reset();
          context.go(AppRoutes.assetDetailPath(asset.id));
        },
      ),
      children: <Widget>[
        Text(
          l10n.scanMatched(state.lastCode ?? ''),
          style: theme.textTheme.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          asset.name,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          asset.subtitle ?? '',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A code that resolved to nothing.
///
/// Not an error: an unregistered barcode is a normal thing to point a phone
/// at, so the card offers the action that follows — create the asset.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppMediaRow(
          leading: const AppLeadingTile(
            icon: Icons.search_off_rounded,
            tone: AppColors.warning,
          ),
          children: <Widget>[
            Text(
              l10n.scanNoMatchTitle,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l10n.scanNoMatchBody(state.unmatchedCode ?? ''),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton.outlined(
                label: l10n.scanAgain,
                isCompact: true,
                onPressed: context.read<ScannerCubit>().reset,
              ),
            ),
            const SizedBox(width: AppSpacing.gridGap),
            Expanded(
              child: AppButton(
                label: l10n.scanCreateAsset,
                isCompact: true,
                onPressed: () {
                  context.read<ScannerCubit>().reset();
                  context.go('${AppRoutes.assets}/${AppRoutes.assetCreate}');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The lookup itself failed — offline, a timeout, an ACL.
class _LookupFailed extends StatelessWidget {
  const _LookupFailed({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final presented = FailurePresenter.present(l10n, state.failure!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppMediaRow(
          leading: AppLeadingTile(icon: presented.icon, tone: AppColors.danger),
          children: <Widget>[
            Text(
              presented.title,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              presented.fix,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.outlined(
          label: l10n.scanAgain,
          isCompact: true,
          onPressed: context.read<ScannerCubit>().reset,
        ),
      ],
    );
  }
}
