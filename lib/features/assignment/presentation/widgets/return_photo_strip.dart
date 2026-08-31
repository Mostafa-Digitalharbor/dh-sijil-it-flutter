import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/photo_strip.dart';

/// The photo row on the return screen (spec §8).
///
/// Thumbnails of what the user just captured, plus an add tile that disappears
/// at the cap rather than failing after the tap.
///
/// The tiles themselves come from [PhotoStrip]'s vocabulary. This screen shows
/// files that have not been uploaded yet and the detail screens show
/// `ir.attachment` records that have, but a photograph with an × on it is one
/// idea, and it was previously two — which is how the return screen ended up
/// with a solid-bordered add target and a plain icon while every other photo
/// surface had a dashed one and a ripple.
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
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.gridGap),
        itemBuilder: (context, index) => SizedBox.square(
          dimension: AppDimens.photoThumb,
          child: index >= paths.length
              ? PhotoAddTile(onTap: onAdd)
              : PhotoTile(
                  // Keyed by path so removing the middle photo does not leave
                  // the tiles after it showing the image of their old
                  // neighbour until the next frame decodes.
                  key: ValueKey<String>(paths[index]),
                  image: FileImage(File(paths[index])),
                  onRemove: () => onRemove(paths[index]),
                ),
        ),
      ),
    );
  }
}
