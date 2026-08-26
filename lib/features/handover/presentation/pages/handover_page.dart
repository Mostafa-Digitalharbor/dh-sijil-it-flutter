import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_number.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_views.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/app_title_block.dart';
import '../../../../shared/widgets/mono_text.dart';
import '../../../../shared/widgets/signature_pad.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_icons.dart';
import '../../../assignment/presentation/widgets/workflow_asset_strip.dart';
import '../../domain/entities/handover.dart';
import '../cubit/handover_cubit.dart';
import '../widgets/asset_picker_sheet.dart';

/// Hands a set of assets to one person, against their signature.
///
/// One screen rather than a wizard. The four things it asks for — who, what,
/// when, signed — are all true at the same moment, and a technician standing
/// at a new hire's desk is adding a forgotten monitor to the bundle while the
/// person is already reaching for the phone. A wizard would make going back a
/// navigation instead of a scroll.
class HandoverPage extends StatelessWidget {
  const HandoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HandoverCubit>(
      create: (_) => sl<HandoverCubit>()..start(),
      child: const _HandoverView(),
    );
  }
}

class _HandoverView extends StatefulWidget {
  const _HandoverView();

  @override
  State<_HandoverView> createState() => _HandoverViewState();
}

class _HandoverViewState extends State<_HandoverView> {
  final SignaturePadController _signature = SignaturePadController();
  final TextEditingController _people = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  /// The pad's laid-out size, captured when it is painted.
  ///
  /// The export renders in the pad's own coordinate space, so the image has to
  /// be produced at the size the strokes were drawn at — otherwise a signature
  /// written on a tablet exports cropped.
  Size _padSize = const Size(320, AppDimens.signaturePadHeight);

  @override
  void initState() {
    super.initState();
    _signature.addListener(_onStroke);
  }

  @override
  void dispose() {
    _signature
      ..removeListener(_onStroke)
      ..dispose();
    _people.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onStroke() =>
      context.read<HandoverCubit>().setSigned(isSigned: _signature.isNotEmpty);

  void _close() => context.go(AppRoutes.more);

  Future<void> _submit() async {
    final bytes = await _signature.toPng(size: _padSize);
    if (!mounted) return;
    await context.read<HandoverCubit>().submit(bytes);
  }

  Future<void> _addAssets() async {
    final cubit = context.read<HandoverCubit>();
    final picked = await AssetPickerSheet.show(context, cubit: cubit);
    if (picked == null) return;
    for (final asset in picked) {
      cubit.addToBundle(asset);
    }
  }

  void _startOver() {
    _signature.clear();
    _notes.clear();
    context.read<HandoverCubit>().retryFailed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocConsumer<HandoverCubit, HandoverState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure ||
          previous.receipt != current.receipt,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null) {
          AppSnack.failure(context, failure);
          context.read<HandoverCubit>().acknowledgeFailure();
        }
      },
      builder: (context, state) {
        final cubit = context.read<HandoverCubit>();
        final receipt = state.receipt;

        return AppScaffold(
          title: l10n.handoverTitle,
          subtitle: receipt == null ? l10n.handoverSubtitle : null,
          compactTitle: true,
          leading: AppIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.actionClose,
            bordered: false,
            onPressed: _close,
          ),
          bottomBar: receipt != null
              ? null
              : StickyActionBar(
                  hint: _BlockerHint(blocker: state.blocker),
                  child: AppButton(
                    label: l10n.handoverConfirm,
                    icon: Icons.how_to_reg_rounded,
                    isBusy: state.isSubmitting,
                    onPressed: state.canSubmit ? _submit : null,
                  ),
                ),
          body: receipt != null
              ? _ReceiptView(
                  receipt: receipt,
                  recipient: state.recipient?.name ?? '',
                  onRetry: _startOver,
                  onDone: _close,
                )
              : _HandoverForm(
                  state: state,
                  cubit: cubit,
                  people: _people,
                  notes: _notes,
                  signature: _signature,
                  onAddAssets: _addAssets,
                  onPadSized: (size) => _padSize = size,
                ),
        );
      },
    );
  }
}

// ── The form ───────────────────────────────────────────────────────────────

class _HandoverForm extends StatelessWidget {
  const _HandoverForm({
    required this.state,
    required this.cubit,
    required this.people,
    required this.notes,
    required this.signature,
    required this.onAddAssets,
    required this.onPadSized,
  });

  final HandoverState state;
  final HandoverCubit cubit;
  final TextEditingController people;
  final TextEditingController notes;
  final SignaturePadController signature;
  final VoidCallback onAddAssets;
  final ValueChanged<Size> onPadSized;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppPageBody(
      gap: AppSpacing.sm,
      children: <Widget>[
        AppStepHeader(step: 1, title: l10n.handoverStepRecipient),
        _RecipientSection(state: state, cubit: cubit, search: people),

        const SizedBox(height: AppSpacing.sm),
        AppStepHeader(
          step: 2,
          title: l10n.handoverStepBundle,
          trailing: state.bundle.isEmpty
              ? null
              : AppNumber.count(context, state.bundle.length),
        ),
        _BundleSection(state: state, cubit: cubit, onAdd: onAddAssets),

        const SizedBox(height: AppSpacing.sm),
        AppStepHeader(step: 3, title: l10n.handoverStepDate),
        WorkflowDateField(
          label: l10n.handoverStepDate,
          showLabel: false,
          value: state.handedOverOn,
          onChanged: cubit.setDate,
        ),

        const SizedBox(height: AppSpacing.sm),
        AppStepHeader(step: 4, title: l10n.handoverStepSignature),
        _SignatureSection(
          state: state,
          controller: signature,
          onSized: onPadSized,
        ),

        const SizedBox(height: AppSpacing.sm),
        AppStepHeader(
          step: 5,
          title: l10n.handoverStepNotes,
          trailing: l10n.labelOptional,
          isActive: false,
        ),
        AppTextField(
          label: l10n.handoverStepNotes,
          showLabel: false,
          controller: notes,
          hint: l10n.handoverNotesHint,
          maxLines: 3,
          onChanged: cubit.setNotes,
        ),
      ],
    );
  }
}

/// Step 1 — collapses to a card once somebody is chosen.
///
/// The search field is the whole step until it is answered, then it stops
/// being useful and starts being four rows of people the user has already
/// decided against.
class _RecipientSection extends StatelessWidget {
  const _RecipientSection({
    required this.state,
    required this.cubit,
    required this.search,
  });

  final HandoverState state;
  final HandoverCubit cubit;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final recipient = state.recipient;

    if (recipient != null) {
      return AppCard.row(
        child: Row(
          children: <Widget>[
            AppAvatar(name: recipient.name, size: AppDimens.avatarMd),
            const SizedBox(width: AppSpacing.md),
            AppTitleBlock(title: recipient.name, subtitle: recipient.summary),
            const SizedBox(width: AppSpacing.sm),
            AppTextAction(
              label: l10n.actionChange,
              onPressed: () {
                search.clear();
                cubit
                  ..clearRecipient()
                  ..searchPeople('');
              },
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppSearchField(
          controller: search,
          hint: l10n.handoverSearchPeople,
          onChanged: cubit.searchPeople,
          onClear: () => cubit.searchPeople(''),
        ),
        if (state.isSearchingPeople && state.candidates.isEmpty)
          const Padding(
            padding: EdgeInsetsDirectional.only(top: AppSpacing.md),
            child: SkeletonBox(height: AppDimens.skeletonRowHeight),
          )
        else if (state.candidates.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
            child: Text(
              l10n.emptyEmployeesTitle,
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          for (final employee in state.candidates)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: AppSelectableTile(
                title: employee.name,
                subtitle: employee.summary,
                caption: employee.workEmail,
                selected: false,
                onTap: () => cubit.chooseRecipient(employee),
              ),
            ),
      ],
    );
  }
}

/// Step 2 — the bundle itself.
class _BundleSection extends StatelessWidget {
  const _BundleSection({
    required this.state,
    required this.cubit,
    required this.onAdd,
  });

  final HandoverState state;
  final HandoverCubit cubit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final asset in state.bundle)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: _BundleRow(
              asset: asset,
              onRemove: () => cubit.removeFromBundle(asset.id),
            ),
          ),
        if (state.bundle.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.handoverBundleEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        AppButton.outlined(
          label: state.isFull
              ? l10n.handoverBundleFull(HandoverBundle.maxAssets)
              : l10n.handoverAddAssets,
          icon: Icons.add_rounded,
          isCompact: true,
          onPressed: state.isFull ? null : onAdd,
        ),
      ],
    );
  }
}

class _BundleRow extends StatelessWidget {
  const _BundleRow({required this.asset, required this.onRemove});

  final Asset asset;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tag = asset.assetTag ?? asset.serialNumber;

    return AppCard.row(
      child: Row(
        children: <Widget>[
          AppLeadingTile(
            icon: AssetIcons.forCategory(asset.category?.name),
            size: AppDimens.avatarMd,
          ),
          const SizedBox(width: AppSpacing.md),
          AppTitleBlock(
            title: asset.name,
            below: tag == null ? null : MonoText.tag(tag),
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.handoverRemoveFromBundle(asset.name),
            bordered: false,
            size: AppDimens.tileSm,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Step 4 — the pad, and the line that identifies what was signed.
class _SignatureSection extends StatelessWidget {
  const _SignatureSection({
    required this.state,
    required this.controller,
    required this.onSized,
  });

  final HandoverState state;
  final SignaturePadController controller;
  final ValueChanged<Size> onSized;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            onSized(Size(constraints.maxWidth, AppDimens.signaturePadHeight));
            return SignaturePad(
              controller: controller,
              hint: l10n.handoverSignHint,
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: state.isSigned
                  ? _ProofLine(state: state)
                  : Text(
                      l10n.handoverSignatureRequired,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.faint),
                    ),
            ),
            AppTextAction(
              label: l10n.actionClear,
              onPressed: state.isSigned ? controller.clear : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// "Nour Adel · 2026-08-25" under the pad.
///
/// The name is the point: it says *whose* signature the app is about to
/// record, on a screen where the pad is nowhere near the recipient's name.
///
/// The signature's fingerprint is deliberately not here. It is derived from
/// the exported PNG, so showing it live would mean re-rendering the image on
/// every touch move; it goes into the chatter note instead, which is where
/// somebody holding a printed receipt would look for it.
class _ProofLine extends StatelessWidget {
  const _ProofLine({required this.state});

  final HandoverState state;

  @override
  Widget build(BuildContext context) {
    final name = state.recipient?.name;
    final date = state.handedOverOn;

    return Row(
      children: <Widget>[
        if (name != null)
          Flexible(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (name != null && date != null)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
            child: Text('·'),
          ),
        // The date stays Latin and monospaced whatever the language: it is an
        // identifier on a receipt, matched against a record, not a quantity.
        if (date != null) MonoText.caption(_iso(date)),
      ],
    );
  }

  static String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// The one-line reason the confirm button is disabled.
class _BlockerHint extends StatelessWidget {
  const _BlockerHint({required this.blocker});

  final HandoverBlocker? blocker;

  @override
  Widget build(BuildContext context) {
    if (blocker == null) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);

    return Text(
      switch (blocker!) {
        HandoverBlocker.recipient => l10n.handoverNeedsRecipient,
        HandoverBlocker.assets => l10n.handoverNeedsAssets,
        HandoverBlocker.signature => l10n.handoverNeedsSignature,
      },
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

// ── The receipt ────────────────────────────────────────────────────────────

/// What happened, said plainly — including when Odoo took only part of it.
class _ReceiptView extends StatelessWidget {
  const _ReceiptView({
    required this.receipt,
    required this.recipient,
    required this.onRetry,
    required this.onDone,
  });

  final HandoverReceipt receipt;
  final String recipient;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    if (receipt.isTotalFailure) {
      return EmptyStateView(
        icon: Icons.error_outline_rounded,
        title: l10n.handoverNothingRecorded,
        message: l10n.handoverNothingRecordedBody,
        actionLabel: l10n.actionRetry,
        onAction: onRetry,
      );
    }

    return AppPageBody(
      gap: AppSpacing.sm,
      children: <Widget>[
        _Outcome(
          isComplete: receipt.isComplete,
          title: receipt.isComplete
              ? l10n.handoverDone(recipient)
              : l10n.handoverPartial(
                  receipt.handedOver.length,
                  receipt.handedOver.length + receipt.failed.length,
                ),
          message: receipt.isPartiallySigned
              ? l10n.handoverSignatureIncomplete
              : l10n.handoverProofSaved,
        ),

        if (receipt.failed.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.handoverRefused, style: theme.textTheme.labelMedium),
          for (final asset in receipt.failed)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: WorkflowAssetStrip(asset: asset),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.outlined(
            label: l10n.handoverRetryRefused,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],

        if (receipt.handedOver.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.handoverRecorded, style: theme.textTheme.labelMedium),
          for (final asset in receipt.handedOver)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: WorkflowAssetStrip(asset: asset),
            ),
        ],

        const SizedBox(height: AppSpacing.md),
        AppButton(label: l10n.actionDone, onPressed: onDone),
      ],
    );
  }
}

/// The banner at the top of the receipt.
///
/// Amber, not red, when Odoo took only part of the bundle: assets did change
/// hands, and colouring that as a failure would push someone to run the whole
/// thing again.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.isComplete,
    required this.title,
    required this.message,
  });

  final bool isComplete;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = isComplete
        ? AppColors.statusAvailable
        : AppColors.statusMaintenance;
    final ink = theme.brightness == Brightness.dark
        ? tone
        : AppColors.inkFor(tone);

    return AppCard(
      backgroundColor: tone.withValues(alpha: AppOpacities.overlay),
      borderColor: tone.withValues(alpha: AppOpacities.chipBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isComplete
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: AppDimens.iconMd,
            color: ink,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
