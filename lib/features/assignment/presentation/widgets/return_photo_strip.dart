import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The photo row on the return screen (spec §8).
///
/// Thumbnails of what the user captured plus an add tile, which disappears at
/// the cap rather than failing after the tap.
class ReturnPhotoStrip extends StatelessWidget {
  const ReturnPhotoStrip({
    required this.paths,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<String> paths;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimens.photoThumb,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.gridGap),
        itemBuilder: (context, index) {
          if (index >= paths.length) return _AddTile(onTap: onAdd);
          return _PhotoTile(
            path: paths[index],
            onRemove: () => onRemove(paths[index]),
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.photo),
          child: Image.file(
            File(path),
            width: AppDimens.photoThumb,
            height: AppDimens.photoThumb,
            fit: BoxFit.cover,
            // A file the OS has since cleaned up is not worth a red error
            // box in a form the user is still filling in.
            errorBuilder: (context, _, __) => Container(
              width: AppDimens.photoThumb,
              height: AppDimens.photoThumb,
              color: theme.colorScheme.outlineVariant,
              child: Icon(
                Icons.broken_image_outlined,
                size: AppDimens.iconXl,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: Semantics(
            button: true,
            label: l10n.actionRemove,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: AppDimens.iconXxl,
                height: AppDimens.iconXxl,
                decoration: BoxDecoration(
                  color: theme.colorScheme.scrim.withValues(
                    alpha: AppOpacities.scrim,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: AppDimens.iconSm,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: l10n.actionAdd,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.photo),
        child: DottedBorderBox(
          child: Icon(
            Icons.add_a_photo_outlined,
            size: AppDimens.iconXl,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A dashed-looking add target.
///
/// Drawn as a solid hairline rather than a true dashed border: Flutter has no
/// dashed `BoxBorder`, and a custom painter for one 64-px tile is more code
/// than the visual difference is worth.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppDimens.photoThumb,
      height: AppDimens.photoThumb,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.photo),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: AppDimens.focusedBorder,
        ),
      ),
      child: child,
    );
  }
}
