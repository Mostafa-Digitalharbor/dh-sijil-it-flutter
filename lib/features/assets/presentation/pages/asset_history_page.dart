import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_data_view.dart';
import '../../../../shared/widgets/event_timeline.dart';
import '../../../../shared/widgets/skeleton_screens.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/asset_history.dart';
import '../cubit/asset_history_cubit.dart';

/// An asset's whole service life, newest first.
///
/// ## Where the data comes from
///
/// Nowhere new. Every assignment, return and status change this app has ever
/// performed posted a note to the asset's chatter, and that log has been
/// sitting in the customer's database unread since the first release — visible
/// only to someone who opened the record in Odoo's web client. This screen is
/// one `mail.message` search, which means it works retroactively on history
/// the customer already has.
class AssetHistoryPage extends StatelessWidget {
  const AssetHistoryPage({required this.assetId, this.assetName, super.key});

  final int assetId;

  /// Shown as the subtitle. Passed in rather than re-read, because the caller
  /// is the detail screen and already has it.
  final String? assetName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssetHistoryCubit>(
      create: (_) => sl<AssetHistoryCubit>()..load(assetId),
      child: _HistoryView(assetId: assetId, assetName: assetName),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.assetId, this.assetName});

  final int assetId;
  final String? assetName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<AssetHistoryCubit, SimpleViewState<AssetHistory>>(
      builder: (context, state) {
        final cubit = context.read<AssetHistoryCubit>();
        final history = state.data;

        return AppScaffold(
          title: l10n.historyTitle,
          subtitle: assetName,
          compactTitle: true,
          showBack: true,
          body: AsyncDataView<AssetHistory>(
            status: state.status,
            // An empty list is data, not absence: it means Odoo answered and
            // this asset genuinely has no history yet, which is the empty
            // state below rather than the "record is gone" failure.
            data: history,
            failure: state.failure,
            onRetry: () => cubit.load(assetId),
            loadingView: const SkeletonTimeline(),
            emptyView: EmptyStateView(
              icon: Icons.history_rounded,
              title: l10n.historyEmptyTitle,
              message: l10n.historyEmptyBody,
            ),
            builder: (_, history) => history.isEmpty
                ? EmptyStateView(
                    icon: Icons.history_rounded,
                    title: l10n.historyEmptyTitle,
                    message: l10n.historyEmptyBody,
                  )
                : _Timeline(history: history, assetId: assetId),
          ),
        );
      },
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.history, required this.assetId});

  final AssetHistory history;
  final int assetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetHistoryCubit>();

    final events = <TimelineEvent>[
      for (final entry in history.entries)
        TimelineEvent(
          icon: _iconFor(entry.kind),
          tone: _toneFor(entry.kind),
          title: entry.summary,
          subtitle: entry.author?.name,
          meta: context.dates.dateAndTime(entry.occurredAt),
        ),
      if (history.registeredOn != null)
        TimelineEvent(
          icon: Icons.add_rounded,
          tone: AppColors.statusRetired,
          title: l10n.historyRegistered,
          meta: context.dates.day(history.registeredOn),
        ),
    ];

    return AppPageBody(
      onRefresh: () => cubit.load(assetId, refresh: true),
      children: <Widget>[
        EventTimeline(
          events: events,
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
        ),
        // Older entries, on request rather than on scroll.
        //
        // A button and not an infinite scroll: the summary line below closes
        // the timeline, and a list that silently grew underneath it would keep
        // pushing the conclusion out of reach. The reader asked a question —
        // "who had this before" — and gets to decide when to keep going.
        if (history.hasMore)
          Center(
            child: cubit.isLoadingMore
                ? const Padding(
                    padding: EdgeInsetsDirectional.all(AppSpacing.md),
                    child: SizedBox(
                      width: AppDimens.iconXl,
                      height: AppDimens.iconXl,
                      child: CircularProgressIndicator(
                        strokeWidth: AppDimens.progressStroke,
                      ),
                    ),
                  )
                : AppButton.outlined(
                    label: l10n.historyLoadOlder,
                    icon: Icons.history_toggle_off_rounded,
                    expand: false,
                    isCompact: true,
                    onPressed: cubit.loadMore,
                  ),
          ),
        _SummaryLine(history: history),
      ],
    );
  }

  /// A handover is blue on this screen because a handover is blue on the asset
  /// list. The reader learns the status palette once and it holds everywhere.
  static Color _toneFor(AssetEventKind kind) => switch (kind) {
    AssetEventKind.assigned => AppColors.statusAssigned,
    AssetEventKind.returned => AppColors.statusAvailable,
    AssetEventKind.statusChanged => AppColors.statusReserved,
    AssetEventKind.audited => AppColors.statusAvailable,
    AssetEventKind.maintenance => AppColors.statusMaintenance,
    AssetEventKind.registered => AppColors.statusRetired,
    AssetEventKind.note => AppColors.statusRetired,
  };

  static IconData _iconFor(AssetEventKind kind) => switch (kind) {
    AssetEventKind.assigned => Icons.arrow_forward_rounded,
    AssetEventKind.returned => Icons.check_rounded,
    AssetEventKind.statusChanged => Icons.swap_horiz_rounded,
    AssetEventKind.audited => Icons.qr_code_scanner_rounded,
    AssetEventKind.maintenance => Icons.build_rounded,
    AssetEventKind.registered => Icons.add_rounded,
    AssetEventKind.note => Icons.chat_bubble_outline_rounded,
  };
}

/// How long the asset has been in service, and how many people have held it.
///
/// The two together answer the question the timeline raises but does not
/// state: a device on its fourth holder in two years is being passed around,
/// not settled, and that is a replacement decision rather than a repair one.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.history});

  final AssetHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final since = history.registeredOn;

    return AppCard(
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            size: AppDimens.iconSm,
            color: palette.faint,
          ),
          const SizedBox(width: AppSpacing.dense),
          Expanded(
            child: Text(
              since == null
                  ? l10n.historyTitle
                  : l10n.historySince(context.dates.day(since)),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.dim),
            ),
          ),
          // Zero is not shown, because zero is not a fact about the asset.
          //
          // The count comes from assignment notes in the chatter, and only
          // this app writes those. An asset assigned in the Odoo web client,
          // or imported with the rest of a customer's inventory, has a holder
          // and no note — and "No holders yet" then sits one screen away from
          // a detail page naming that holder, contradicting it. Real data
          // makes this the *common* case on day one, not an edge case.
          //
          // The number earns its place once there is one: "fourth holder in
          // two years" is the replacement signal this line exists for.
          if (history.holderCount > 0)
            Text(
              l10n.historyHolders(history.holderCount),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: AppTextSize.label,
                color: palette.mint,
              ),
            ),
        ],
      ),
    );
  }
}
