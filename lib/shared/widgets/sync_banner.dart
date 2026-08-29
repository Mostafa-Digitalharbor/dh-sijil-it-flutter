import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/generated/app_localizations.dart';
import '../cubit/sync_cubit.dart';
import '../utils/app_date_format.dart';

/// The strip that says the app is not currently speaking to Odoo.
///
/// One line, above the tab bar and below every screen, because the fact it
/// reports is about the app rather than about a screen — and a technician
/// walking out of a server room changes tabs on the way.
///
/// It says three different things and the order is deliberate:
///
/// 1. **Waiting writes** outrank everything. A queued handover is work the
///    user did that Odoo has not seen, and it is the only one of the three
///    that can be lost.
/// 2. **Offline** is next: it explains why nothing is updating.
/// 3. **Stale** is last — the screen is readable, it is simply not live.
///
/// Nothing is shown when the app is live and the queue is empty. A banner that
/// is always there is a banner nobody reads.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    return BlocBuilder<SyncCubit, SyncViewState>(
      builder: (context, state) {
        if (!state.shouldWarn) return const SizedBox.shrink();

        final (message, tone, icon) = _describe(context, l10n, state);

        return Material(
          color: tone.withValues(alpha: AppOpacities.overlay),
          child: InkWell(
            onTap: () => context.push(AppRoutes.syncPath),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: screen.gutter,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: AppDimens.iconMd,
                      color: AppColors.inkFor(tone),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkFor(tone),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.isSyncing)
                      const SizedBox(
                        width: AppDimens.iconMd,
                        height: AppDimens.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: AppDimens.progressStroke,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: AppDimens.iconLg,
                        color: AppColors.inkFor(tone),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// What to say, in the order that matters most to least.
  (String, Color, IconData) _describe(
    BuildContext context,
    AppL10n l10n,
    SyncViewState state,
  ) {
    if (state.hasPending) {
      return (
        l10n.syncPendingBanner(state.pending.length),
        AppColors.warning,
        Icons.cloud_upload_outlined,
      );
    }

    if (state.isOffline) {
      return (
        l10n.syncOfflineBanner,
        AppColors.statusRetired,
        Icons.cloud_off_rounded,
      );
    }

    return (
      l10n.syncStaleBanner(context.dates.relative(state.servingFrom)),
      AppColors.statusRetired,
      Icons.history_rounded,
    );
  }
}
