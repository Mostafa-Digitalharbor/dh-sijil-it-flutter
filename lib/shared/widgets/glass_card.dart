import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';

/// A raised surface with a lit top edge.
///
/// This is the one piece of decoration Obsidian allows, and it earns its place
/// on a dark ground: a flat `#101A38` panel on a `#0B1226` page is a 4%
/// luminance step, which reads as a smudge rather than as a card. The vertical
/// gradient plus a 1px highlight along the top edge give it a direction of
/// light, so the card reads as *above* the page instead of painted onto it.
///
/// In light mode both are pointless — a translucent white fill over a white
/// ground is invisible — so [AppPalette.light] flattens the gradient to two
/// near-identical whites and drops the highlight to a faint hairline. The
/// widget does not branch; the palette does.
///
/// Use [AppCard] for ordinary rows and panels. Reach for this only where the
/// design calls out a hero surface: the dashboard donut, the trend chart, the
/// audit counters, the signature pad.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
    this.radius = AppRadii.xl,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Overrides the border, for a card that carries a status tone.
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = BorderRadius.circular(radius);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: borderColor ?? palette.lineSoft),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.glassTop, palette.glassBottom],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // The lit rim. Fades out at both ends so it reads as a highlight
          // catching the top of a surface, not as a drawn border.
          PositionedDirectional(
            top: 0,
            start: radius,
            end: radius,
            child: SizedBox(
              height: AppDimens.hairline,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      palette.edge.withValues(alpha: 0),
                      palette.edge,
                      palette.edge.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (onTap == null) return ClipRRect(borderRadius: shape, child: surface);

    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: surface),
    );
  }
}

/// The soft coloured light behind the top of a screen.
///
/// Sits under the app bar and the first card and bleeds downward. Purely
/// atmospheric — it never carries meaning, so it is excluded from semantics
/// and drawn at an alpha low enough that text over it keeps its contrast
/// ratio in both themes.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    this.tones,
    this.height = 320,
    this.intensity = 0.16,
    super.key,
  });

  /// Two hues, drawn as overlapping radial washes. Defaults to the accent and
  /// the "assigned" blue, which is the palette's resting mood.
  final (Color, Color)? tones;
  final double height;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (a, b) =
        tones ?? (palette.mint, Theme.of(context).colorScheme.secondary);

    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              _Wash(
                tone: a,
                alignment: const Alignment(-0.65, -0.9),
                intensity: intensity,
              ),
              _Wash(
                tone: b,
                alignment: const Alignment(0.75, -1),
                intensity: intensity * 1.2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wash extends StatelessWidget {
  const _Wash({
    required this.tone,
    required this.alignment,
    required this.intensity,
  });

  final Color tone;
  final Alignment alignment;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: AppDimens.glowSpread,
          colors: <Color>[
            tone.withValues(alpha: intensity),
            tone.withValues(alpha: 0),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
