import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../domain/entities/assignment.dart';
import '../cubit/return_asset_cubit.dart';
import '../widgets/condition_picker.dart';
import '../widgets/return_photo_strip.dart';
import '../widgets/workflow_asset_strip.dart';

/// Takes an asset back from an employee (spec §8).
class ReturnAssetPage extends StatelessWidget {
  const ReturnAssetPage({required this.assetId, super.key});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReturnAssetCubit>(
      create: (_) => sl<ReturnAssetCubit>()..start(assetId),
      child: _ReturnAssetView(assetId: assetId),
    );
  }
}

class _ReturnAssetView extends StatefulWidget {
  const _ReturnAssetView({required this.assetId});

  final int assetId;

  @override
  State<_ReturnAssetView> createState() => _ReturnAssetViewState();
}

class _ReturnAssetViewState extends State<_ReturnAssetView> {
  final TextEditingController _notes = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _close() => context.go(AppRoutes.assetDetailPath(widget.assetId));

  Future<void> _addPhoto(ReturnAssetCubit cubit) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        // Return photos are evidence of a scratch, not print artwork. Capping
        // them keeps one XML-RPC payload with up to five attachments from
        // timing out on a phone connection.
        maxWidth: AppConstants.photoMaxWidth.toDouble(),
        imageQuality: AppConstants.photoQuality,
      );
      if (file != null) cubit.addPhoto(file.path);
    } on Object catch (error) {
      // A cancelled picker and a missing camera both land here; neither is
      // worth an error screen over an optional attachment.
      AppLogger.warn('Photo capture unavailable — $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocConsumer<ReturnAssetCubit, ReturnAssetState>(
      listenWhen: (previous, current) =>
          previous.returned != current.returned ||
          previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null && state.asset != null) {
          AppSnack.failure(context, failure);
          context.read<ReturnAssetCubit>().acknowledgeFailure();
          return;
        }

        final returned = state.returned;
        if (returned != null) {
          AppSnack.success(context, l10n.returnSuccess(returned.name));
          _close();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ReturnAssetCubit>();

        return AppScaffold(
          title: l10n.returnTitle,
          compactTitle: true,
          leading: AppIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.actionClose,
            bordered: false,
            onPressed: _close,
          ),
          bottomBar: state.asset == null
              ? null
              : AppButton(
                  label: l10n.returnConfirm,
                  icon: Icons.assignment_return_rounded,
                  isBusy: state.isSubmitting,
                  onPressed: state.canSubmit ? cubit.submit : null,
                ),
          body: switch (state) {
            _ when state.isLoading && state.asset == null =>
              const SkeletonList(),
            _ when state.hasFailed && state.asset == null => FailureView(
              failure: state.failure!,
              onRetry: () => cubit.start(widget.assetId),
            ),
            _ when state.asset == null => const SizedBox.shrink(),
            _ => _ReturnForm(
              state: state,
              notes: _notes,
              onAddPhoto: () => _addPhoto(cubit),
            ),
          },
        );
      },
    );
  }
}

class _ReturnForm extends StatelessWidget {
  const _ReturnForm({
    required this.state,
    required this.notes,
    required this.onAddPhoto,
  });

  final ReturnAssetState state;
  final TextEditingController notes;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<ReturnAssetCubit>();

    return AppPageBody(
      gap: AppSpacing.sm,
      children: <Widget>[
        WorkflowAssetStrip(asset: state.asset!, showHolder: true),
        const SizedBox(height: AppSpacing.sm),

        _Label(text: l10n.returnDate),
        WorkflowDateField(
          label: l10n.returnDate,
          showLabel: false,
          value: state.returnedOn,
          onChanged: cubit.setDate,
        ),

        const SizedBox(height: AppSpacing.sm),
        _Label(text: l10n.returnCondition),
        ConditionPicker(
          selected: state.condition,
          onChanged: cubit.setCondition,
        ),

        const SizedBox(height: AppSpacing.sm),
        _Label(text: l10n.labelNotes),
        AppTextField(
          label: l10n.labelNotes,
          showLabel: false,
          controller: notes,
          hint: l10n.returnNotesHint,
          maxLines: 3,
          onChanged: cubit.setNotes,
        ),

        const SizedBox(height: AppSpacing.sm),
        _PhotosHeader(count: state.photoPaths.length),
        ReturnPhotoStrip(
          paths: state.photoPaths,
          canAdd: state.canAddPhoto,
          onAdd: onAddPhoto,
          onRemove: cubit.removePhoto,
        ),

        const SizedBox(height: AppSpacing.sm),
        _OutcomeHint(status: state.resultingStatus),
      ],
    );
  }
}

/// A small uppercase section label — the return screen's headings are plain
/// labels rather than cards, matching the design.
class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

class _PhotosHeader extends StatelessWidget {
  const _PhotosHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(child: _Label(text: l10n.returnPhotos)),
        Text(
          l10n.photoCount(count, ReturnRequest.maxPhotos),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Says what confirming will do, before the user commits.
///
/// The four conditions land the asset in three different states, and "Damaged"
/// in particular is stored only on this device — a user should not discover
/// that afterwards.
class _OutcomeHint extends StatelessWidget {
  const _OutcomeHint({required this.status});

  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.info_outline_rounded,
          size: AppDimens.iconMd,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: screen.isLargeText ? AppSpacing.sm : AppSpacing.md),
        Expanded(
          child: Text(
            l10n.returnOutcome(StatusChip.labelFor(l10n, status)),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
