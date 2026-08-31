import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import '../utils/app_number.dart';
import '../utils/decoded_image.dart';

/// Photographs attached to a record, with the controls to add and remove them.
///
/// ## Why this exists
///
/// The app already uploaded photos — the return flow has posted them to
/// `ir.attachment` since day one. Nothing ever displayed them. They went to
/// Odoo and disappeared from the app that took them, which meant the evidence
/// was only visible to whoever opened the record in the web client.
///
/// Removal is an explicit × badge rather than a long-press. A long-press is a
/// gesture people discover by accident or never; deleting evidence should be
/// deliberate and reachable, which is the same argument in both directions.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    required this.photos,
    this.onAdd,
    this.onRemove,
    this.onOpen,
    this.featured = false,
    this.addLabel,
    this.maxTiles = 4,
    super.key,
  });

  final List<ImageProvider> photos;

  /// Omitted when the user lacks write access, which hides the add tile
  /// entirely rather than showing a control that fails on tap.
  final VoidCallback? onAdd;
  final void Function(int index)? onRemove;
  final void Function(int index)? onOpen;

  /// Gives the first photo double width, for a detail header where one image
  /// is the subject and the rest are context.
  final bool featured;

  final String? addLabel;

  /// Tiles shown before the strip stops adding more. The add tile counts.
  final int maxTiles;

  @override
  Widget build(BuildContext context) {
    if (featured) return _Featured(strip: this);

    final slots = math.max(0, maxTiles - (onAdd == null ? 0 : 1));
    final shown = photos.take(slots).toList(growable: false);

    return SizedBox(
      height: AppDimens.photoThumb,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < shown.length; i++) ...<Widget>[
            Expanded(
              child: PhotoTile(
                image: shown[i],
                extra: photos.length > slots && i == shown.length - 1
                    ? photos.length - slots
                    : null,
                onTap: onOpen == null ? null : () => onOpen!(i),
                onRemove: onRemove == null ? null : () => onRemove!(i),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (onAdd != null)
            Expanded(
              child: PhotoAddTile(onTap: onAdd!, label: addLabel),
            ),
        ],
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.strip});

  final PhotoStrip strip;

  @override
  Widget build(BuildContext context) {
    final photos = strip.photos;

    return SizedBox(
      height: AppDimens.photoStrip,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: photos.isEmpty
                ? PhotoAddTile(onTap: strip.onAdd, label: strip.addLabel)
                : PhotoTile(
                    image: photos.first,
                    counter: photos.length > 1
                        ? AppL10n.of(context).photosPosition(1, photos.length)
                        : null,
                    onTap: strip.onOpen == null ? null : () => strip.onOpen!(0),
                  ),
          ),
          if (photos.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: photos.length > 1
                        ? PhotoTile(
                            image: photos[1],
                            onTap: strip.onOpen == null
                                ? null
                                : () => strip.onOpen!(1),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (strip.onAdd != null) ...<Widget>[
                    if (photos.length > 1)
                      const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: PhotoAddTile(
                        onTap: strip.onAdd,
                        label: strip.addLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One photograph, framed.
///
/// Public because the return flow draws the same tile over a local file that
/// has not been uploaded yet. Two implementations of "a photo with an × on
/// it" drifted apart once already: one grew a dashed add target and a "+N"
/// overlay, the other kept a solid border and a plain icon, and the two
/// screens stopped looking like the same app.
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.image,
    this.onTap,
    this.onRemove,
    this.counter,
    this.extra,
    super.key,
  });

  final ImageProvider image;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  /// "1/4" badge on a featured lead image.
  final String? counter;

  /// "+3" badge when more photos exist than tiles.
  final int? extra;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = BorderRadius.circular(AppRadii.photo);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Material(
          color: palette.sunken,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Measured rather than passed in: the tile is sized by its
              // parent (an Expanded in a Row, a square in a scroller), and a
              // caller that has to remember to declare its own size is a
              // caller that will eventually forget and put a 48 MB decode
              // behind a 64-pt thumbnail.
              LayoutBuilder(
                builder: (context, constraints) => Image(
                  image: DecodedImage.thumbnail(
                    context,
                    image,
                    side: constraints.biggest.shortestSide,
                  ),
                  fit: BoxFit.cover,
                  // A camera-intent temp file Android has since reclaimed, or
                  // an `ir.attachment` that came back corrupt. Neither is
                  // worth a red error box in a form somebody is still
                  // filling in.
                  errorBuilder: (context, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: AppDimens.iconXl,
                      color: palette.faint,
                    ),
                  ),
                ),
              ),
              // Transparent so the ripple lands on top of the photograph
              // rather than behind it.
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: palette.line),
            ),
          ),
        ),
        if (extra != null)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                color: palette.sunken.withValues(
                  alpha: AppOpacities.photoOverlay,
                ),
              ),
              child: Center(
                child: Text(
                  AppNumber.plusCount(context, extra!),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppPalette.dark.ink),
                ),
              ),
            ),
          ),
        if (counter != null)
          PositionedDirectional(
            bottom: AppSpacing.snug,
            start: AppSpacing.sm,
            child: _Badge(text: counter!),
          ),
        if (onRemove != null)
          PositionedDirectional(
            top: AppSpacing.xs,
            end: AppSpacing.xs,
            child: _RemoveButton(onTap: onRemove!),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.sunken.withValues(
          alpha: AppOpacities.photoBadge,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.snug,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: AppTextSize.caption,
            letterSpacing: AppTypography.noTracking,
            color: AppPalette.dark.dim,
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppL10n.of(context).actionRemove,
      child: Material(
        color: context.palette.sunken.withValues(
          alpha: AppOpacities.photoControl,
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: AppDimens.photoRemoveButton,
            height: AppDimens.photoRemoveButton,
            child: Icon(
              Icons.close_rounded,
              size: AppDimens.iconXs,
              color: AppPalette.dark.dim,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "add a photo" target: a dashed slot rather than a filled button.
///
/// The dash says "this is empty and you can fill it", which a solid border
/// does not.
class PhotoAddTile extends StatelessWidget {
  const PhotoAddTile({required this.onTap, this.label, super.key});

  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = BorderRadius.circular(AppRadii.photo);

    return Semantics(
      button: true,
      // The icon alone announces nothing, and this is how a screen-reader
      // user reaches the camera at all.
      label: label ?? AppL10n.of(context).actionAdd,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: palette.line,
          radius: shape.topLeft.x,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.add_rounded,
                    size: AppDimens.iconSm,
                    color: palette.faint,
                  ),
                  if (label != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: AppSpacing.xxs,
                      ),
                      child: Text(
                        label!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: AppTextSize.badge,
                          letterSpacing: AppTypography.noTracking,
                          color: palette.faint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded rectangle.
///
/// Flutter has no dashed border, and the dash is doing real work here: it says
/// "this slot is empty and you can fill it", which a solid border does not.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
