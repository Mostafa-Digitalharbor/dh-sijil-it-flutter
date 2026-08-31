import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/viewfinder_brackets.dart';

/// Darkens everything outside the viewfinder square.
///
/// Purely an aiming aid: the detector reads the whole frame, but a user who
/// can see where to point holds the phone still, and a still phone is what
/// actually makes a code resolve on the first try.
class ScannerScrim extends StatelessWidget {
  const ScannerScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: AppColors.surfaceDark.withValues(alpha: AppOpacities.scrim),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The mint corner brackets and the sweeping scan line.
class ScannerViewfinder extends StatefulWidget {
  const ScannerViewfinder({super.key});

  @override
  State<ScannerViewfinder> createState() => _ScannerViewfinderState();
}

class _ScannerViewfinderState extends State<ScannerViewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    // Built here rather than as a lazy field. On a screen with no room for a
    // finder — a landscape phone, or the zero-height frame a rotation passes
    // through — `build` returns before it ever touches the controller, and
    // `dispose` was then the first thing to read it. That *constructed* an
    // AnimationController against a deactivated element, which asserts, and
    // left a ticker running that nothing would ever stop.
    _sweep = AnimationController(
      vsync: this,
      duration: AppDurations.scannerSweep,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Shrinks on a small screen rather than overflowing: the finder is a
        // fixed 244 px in the design, but a phone in landscape has less than
        // that in height.
        final side = <double>[
          AppDimens.scannerFinder,
          constraints.maxWidth - AppSpacing.huge,
          constraints.maxHeight - AppSpacing.lg,
        ].reduce((a, b) => a < b ? a : b).clamp(0.0, AppDimens.scannerFinder);

        if (side <= 0) return const SizedBox.shrink();

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.onCamera.withValues(
                    alpha: AppOpacities.viewfinderFill,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.viewfinder),
                ),
                child: const SizedBox.expand(),
              ),
              const ViewfinderBrackets.scanner(),
              AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) => Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: _sweep.value * (side - AppSpacing.xxxl) + AppSpacing.lg,
                  child: const _ScanLine(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.scannerLine,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.mint.withValues(alpha: 0),
            AppColors.mint,
            AppColors.mint.withValues(alpha: 0),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.mint.withValues(alpha: AppOpacities.glow),
            blurRadius: AppDimens.glowBlur,
          ),
        ],
      ),
    );
  }
}
