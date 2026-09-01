import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/error/failure_presenter.dart';
import '../../../../core/error/failures.dart';
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

    return BlocConsumer<SyncCubit, SyncViewState>(
      // Only when a replay finishes, and only when it actually sent something.
      // Without this the screen answered "Sync now" by quietly emptying: the
      // queue vanished, the empty state appeared, and nothing said whether
      // that was because Odoo took the writes or because they were discarded.
      listenWhen: (previous, current) =>
          previous.isSyncing && !current.isSyncing,
      listener: (context, state) {
        final sent = state.lastReport?.sent ?? 0;
        if (sent > 0) AppSnack.success(context, l10n.syncSentCount(sent));
      },
      builder: (context, state) {
        final cubit = context.read<SyncCubit>();

        final hasAnything = state.hasPending || state.hasQuarantined;

        return AppScaffold(
          title: l10n.syncTitle,
          // The failures lead, because they are the half of the screen that
          // will not resolve itself.
          subtitle: switch (state) {
            _ when state.hasQuarantined => l10n.syncFailedCount(
              state.quarantined.length,
            ),
            _ when state.hasPending => l10n.syncPendingBanner(
              state.pending.length,
            ),
            _ => null,
          },
          showBack: true,
          body: hasAnything ? _Queue(state: state) : _Empty(state: state),
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
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<SyncCubit>();

    return AppPageBody(
      children: <Widget>[
        // Failures first. A write that will never go out on its own is the
        // one thing on this screen that needs a decision, and burying it under
        // a list that empties itself is how it goes unnoticed.
        if (state.hasQuarantined) ...<Widget>[
          _SectionHeader(
            label: l10n.syncFailedSection,
            tone: AppColors.danger,
            trailing: AppTextAction(
              label: l10n.syncDiscardFailedAll,
              icon: Icons.delete_sweep_outlined,
              onPressed: () => _confirmDiscardAll(context, cubit),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.syncFailedBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in state.quarantined)
            _QueuedRow(entry: entry, cubit: cubit),
        ],
        if (state.hasQuarantined && state.hasPending)
          _SectionHeader(
            label: l10n.syncPendingBanner(state.pending.length),
            tone: AppColors.warning,
          ),
        for (final entry in state.pending) _QueuedRow(entry: entry),
      ],
    );
  }

  Future<void> _confirmDiscardAll(BuildContext context, SyncCubit cubit) async {
    final l10n = AppL10n.of(context);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.syncDiscardFailedAllConfirm,
      message: l10n.syncDiscardFailedAllBody,
      confirmLabel: l10n.syncDiscardFailedAll,
      isDestructive: true,
    );

    if (confirmed) await cubit.discardAllQuarantined();
  }
}

/// A labelled divider between the two halves of the queue.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.tone,
    this.trailing,
  });

  final String label;
  final Color tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: tone),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _QueuedRow extends StatelessWidget {
  const _QueuedRow({required this.entry, this.cubit});

  final OutboxEntry entry;

  /// Present only for a quarantined entry, which is the only kind with
  /// controls of its own.
  final SyncCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final tone = entry.isQuarantined ? AppColors.danger : AppColors.warning;

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

    final owner = cubit;
    if (!entry.isQuarantined || owner == null) return card;

    // Why it stopped, and the two things that can be done about it. Said under
    // the row rather than inside it, and with controls rather than only a
    // sentence: the reason on its own was a badge that never cleared, because
    // the only way to act on it was to discard the entire queue.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        card,
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            end: AppSpacing.md,
            top: AppSpacing.xs,
          ),
          child: Text(
            _reason(l10n, entry),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              AppTextAction(
                label: l10n.syncRetryOne,
                icon: Icons.refresh_rounded,
                onPressed: () => owner.retryQuarantined(entry.id),
              ),
              const SizedBox(width: AppSpacing.md),
              AppTextAction(
                label: l10n.syncDiscardOne,
                icon: Icons.delete_outline_rounded,
                onPressed: () => _confirmDiscard(context, owner),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDiscard(BuildContext context, SyncCubit owner) async {
    final l10n = AppL10n.of(context);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.syncDiscardOneConfirm,
      message: l10n.syncDiscardOneBody(entry.subjectName),
      confirmLabel: l10n.syncDiscardOne,
      isDestructive: true,
    );

    if (confirmed) await owner.discardQuarantined(entry.id);
  }

  /// Odoo's reason, in the user's language.
  ///
  /// The stored value is a [FailureKind] name — the same vocabulary the error
  /// screens use — so it resolves through the presenter rather than being
  /// shown as the raw enum a technician has no way to read.
  static String _reason(AppL10n l10n, OutboxEntry entry) {
    final kind = FailureKind.values
        .where((k) => k.name == entry.lastError)
        .firstOrNull;
    if (kind == null) return l10n.syncBlocked;

    return l10n.syncFailedReason(
      FailurePresenter.shortMessage(l10n, Failure(kind: kind)),
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
