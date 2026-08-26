import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/photo_picker.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_number.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/photo_strip.dart';
import '../../domain/entities/record_photo.dart';
import '../cubit/photo_cubit.dart';
import '../pages/photo_viewer_page.dart';

/// The photo block on a detail screen.
///
/// One widget for both the asset and the maintenance request: the only thing
/// that differs is the model the enclosing [PhotoCubit] was built with, and
/// [featured], which gives the asset's lead photo double width because there
/// the image *is* the subject, while on a repair the photos are evidence and
/// weigh the same.
class PhotoSection extends StatelessWidget {
  const PhotoSection({this.featured = false, this.hint, super.key});

  final bool featured;

  /// Shown when the record has no photos yet — the section explains what the
  /// photos are for rather than leaving an unexplained empty tile.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return BlocConsumer<PhotoCubit, PhotoState>(
      listenWhen: (previous, current) =>
          (current.failure != null && previous.failure != current.failure) ||
          (current.outcome != null && previous.outcome != current.outcome),
      listener: (context, state) {
        final cubit = context.read<PhotoCubit>();

        if (state.failure != null) {
          AppSnack.failure(context, state.failure!);
          cubit.acknowledgeFailure();
          return;
        }

        // Uploading a photo is a write to Odoo that leaves no visible trace
        // beyond one more thumbnail in a strip the user may not be looking at.
        // Saying so is the difference between "it worked" and "did that go?".
        switch (state.outcome!) {
          case PhotoOutcome.added:
            AppSnack.success(context, l10n.photosAdded);
          case PhotoOutcome.removed:
            AppSnack.success(context, l10n.photosRemoved);
        }
        cubit.acknowledgeOutcome();
      },
      builder: (context, state) {
        final cubit = context.read<PhotoCubit>();

        return GlassCard(
          borderColor: state.isEmpty
              ? null
              : palette.mint.withValues(alpha: AppOpacities.chipBorder),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(count: state.count, isBusy: state.isUploading),
              const SizedBox(height: AppSpacing.md),

              if (state.isEmpty && !state.isLoading && hint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    hint!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.dim),
                  ),
                ),

              PhotoStrip(
                featured: featured,
                addLabel: featured ? l10n.photosAdd : null,
                photos: <ImageProvider>[
                  for (final photo in state.photos)
                    if (photo.bytes case final bytes?) MemoryImage(bytes),
                ],
                onAdd: cubit.canEdit ? () => _pick(context) : null,
                onRemove: cubit.canEdit
                    ? (index) => _confirmRemove(context, state.photos, index)
                    : null,
                onOpen: (index) => PhotoViewerPage.open(
                  context,
                  photos: state.photos.where((p) => p.isLoaded).toList(),
                  initialIndex: index,
                ),
              ),

              if (cubit.canEdit && !featured) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _SourceButtons(onPick: cubit.add),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<PhotoCubit>();
    if (featured) {
      // The featured layout has no room for two buttons, so the add tile asks
      // which source instead of silently picking one.
      final l10n = AppL10n.of(context);
      final source = await AppOptionSheet.show<PhotoSource>(
        context,
        title: l10n.photosTitle,
        options: <AppSheetOption<PhotoSource>>[
          AppSheetOption<PhotoSource>(
            value: PhotoSource.camera,
            label: l10n.photosCamera,
            icon: Icons.photo_camera_outlined,
          ),
          AppSheetOption<PhotoSource>(
            value: PhotoSource.gallery,
            label: l10n.photosGallery,
            icon: Icons.photo_library_outlined,
          ),
        ],
      );
      if (source == null) return;
      await cubit.add(source);
      return;
    }
    await cubit.add(PhotoSource.camera);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    List<RecordPhoto> photos,
    int index,
  ) async {
    final loaded = photos.where((p) => p.isLoaded).toList(growable: false);
    if (index >= loaded.length) return;

    final l10n = AppL10n.of(context);
    final cubit = context.read<PhotoCubit>();
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.photosRemoveTitle,
      message: l10n.photosRemoveBody,
      confirmLabel: l10n.photosRemoveAction,
      isDestructive: true,
    );
    if (!confirmed) return;
    await cubit.remove(loaded[index].id);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.isBusy});

  final int count;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Icon(
          Icons.photo_camera_outlined,
          size: AppDimens.iconSm,
          color: palette.mint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          l10n.photosTitle,
          style: text.titleSmall?.copyWith(color: palette.mint),
        ),
        if (count > 0) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          _CountBadge(count: count),
        ],
        const Spacer(),
        if (isBusy)
          SizedBox(
            width: AppDimens.iconSm,
            height: AppDimens.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: AppDimens.progressStroke,
              color: palette.mint,
            ),
          )
        else if (count > 0)
          // Says the bytes left the phone. Without it people re-upload the
          // same photo because nothing on screen confirmed it stuck.
          Text(
            l10n.photosSavedToOdoo,
            style: text.bodySmall?.copyWith(
              fontSize: AppTextSize.nav,
              color: palette.faint,
            ),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.mint.withValues(alpha: AppOpacities.chipFill),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm - 1,
          vertical: 1,
        ),
        child: Text(
          AppNumber.count(context, count),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: AppTextSize.nav,
            letterSpacing: AppTypography.noTracking,
            color: palette.mint,
          ),
        ),
      ),
    );
  }
}

class _SourceButtons extends StatelessWidget {
  const _SourceButtons({required this.onPick});

  final void Function(PhotoSource source) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onPick(PhotoSource.camera),
            icon: const Icon(
              Icons.photo_camera_outlined,
              size: AppDimens.iconSm,
            ),
            label: Text(l10n.photosCamera),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppDimens.buttonHeightSmall),
              foregroundColor: palette.mint,
              side: BorderSide(
                color: palette.mint.withValues(alpha: AppOpacities.chipBorder),
              ),
              backgroundColor: palette.mint.withValues(
                alpha: AppOpacities.overlaySoft,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onPick(PhotoSource.gallery),
            icon: const Icon(
              Icons.photo_library_outlined,
              size: AppDimens.iconSm,
            ),
            label: Text(l10n.photosGallery),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppDimens.buttonHeightSmall),
            ),
          ),
        ),
      ],
    );
  }
}
