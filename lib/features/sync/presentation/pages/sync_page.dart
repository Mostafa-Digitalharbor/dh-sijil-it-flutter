import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/sync/outbox_entry.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/cubit/sync_cubit.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_title_block.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../assets/domain/entities/asset_status.dart';

/// What is waiting to reach Odoo, and why.
///
/// The queue is the one place in the app holding data that exists nowhere
/// else, so it is a screen rather than a line in Settings: a technician who
/// hands in a phone at the end of a shift needs to be able to see whether
/// anything is still on it.
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<SyncCubit, SyncViewState>(
      builder: (context, state) {
        final cubit = context.read<SyncCubit>();

        return AppScaffold(
          title: l10n.syncTitle,
          subtitle: state.hasPending
              ? l10n.syncPendingBanner(state.pending.length)
              : null,
          showBack: true,
          body: state.hasPending ? _Queue(state: state) : _Empty(state: state),
          bottomBar: state.hasPending
              ? _Actions(state: state, cubit: cubit)
              : null,
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.state});

  final SyncViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return EmptyStateView(
      icon: state.isOffline
          ? Icons.cloud_off_rounded
          : Icons.cloud_done_outlined,
      title: l10n.syncQueueEmptyTitle,
      message: l10n.syncQueueEmptyBody,
    );
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.state});

  final SyncViewState state;

  @override
  Widget build(BuildContext context) {
    return AppPageBody(
      children: <Widget>[
        for (final entry in state.pending) _QueuedRow(entry: entry),
      ],
    );
  }
}

class _QueuedRow extends StatelessWidget {
  const _QueuedRow({required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final tone = entry.isBlocked ? AppColors.danger : AppColors.warning;

    final card = AppCard.row(
      child: Row(
        children: <Widget>[
          AppLeadingTile(icon: _iconFor(entry.kind), tone: tone),
          const SizedBox(width: AppSpacing.md),
          AppTitleBlock(
            title: entry.subjectName,
            subtitle: _describe(l10n, entry),
            below: Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.snug,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  AppChip(
                    label: context.dates.relative(entry.queuedAt),
                    icon: Icons.schedule_rounded,
                  ),
                  if (entry.attempts > 0)
                    AppChip(
                      label: l10n.syncAttempts(entry.attempts),
                      tone: tone,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!entry.isBlocked) return card;

    // Said under the row rather than inside it: this is why the entry stopped
    // trying, and a row that carries it silently is a badge that never clears.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        card,
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            top: AppSpacing.xs,
          ),
          child: Text(
            l10n.syncBlocked,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(OutboxKind kind) => switch (kind) {
    OutboxKind.assignAsset => Icons.person_add_alt_1_rounded,
    OutboxKind.returnAsset => Icons.assignment_return_rounded,
    OutboxKind.setAssetStatus => Icons.flag_rounded,
  };

  /// The queued write in the words the user chose it with.
  static String _describe(AppL10n l10n, OutboxEntry entry) =>
      switch (entry.kind) {
        OutboxKind.assignAsset => l10n.syncQueuedAssign(
          '${entry.payload['employeeName'] ?? ''}',
        ),
        OutboxKind.returnAsset => l10n.syncQueuedReturn,
        OutboxKind.setAssetStatus => l10n.syncQueuedStatus(
          StatusChip.labelFor(
            l10n,
            AssetStatus.values
                    .where((s) => s.name == entry.payload['status'])
                    .firstOrNull ??
                AssetStatus.available,
          ),
        ),
      };
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.cubit});

  final SyncViewState state;
  final SyncCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: AppButton.outlined(
            label: l10n.syncDiscard,
            icon: Icons.delete_outline_rounded,
            onPressed: state.isSyncing ? null : () => _confirmDiscard(context),
          ),
        ),
        const SizedBox(width: AppSpacing.gridGap),
        Expanded(
          child: AppButton(
            label: state.isSyncing ? l10n.syncSending : l10n.syncNow,
            icon: Icons.cloud_upload_outlined,
            isBusy: state.isSyncing,
            // Offline, "send now" can only fail. The queue already says the
            // writes will go by themselves.
            onPressed: state.isOffline ? null : cubit.syncNow,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final l10n = AppL10n.of(context);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.syncDiscardConfirm,
      message: l10n.syncDiscardBody,
      confirmLabel: l10n.syncDiscard,
      isDestructive: true,
    );

    if (confirmed) await cubit.discardQueue();
  }
}
