import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';

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
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

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
                  color: Colors.white.withValues(
                    alpha: AppOpacities.viewfinderFill,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xl + 8),
                ),
                child: const SizedBox.expand(),
              ),
              for (final corner in _Corner.values)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: corner.isTop ? 0 : null,
                  bottom: corner.isTop ? null : 0,
                  start: corner.isStart ? 0 : null,
                  end: corner.isStart ? null : 0,
                  child: _CornerBracket(corner: corner),
                ),
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

/// Which corner a bracket is drawn in.
enum _Corner {
  topStart,
  topEnd,
  bottomStart,
  bottomEnd;

  bool get isTop => this == _Corner.topStart || this == _Corner.topEnd;

  bool get isStart => this == _Corner.topStart || this == _Corner.bottomStart;
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.corner});

  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(
      color: AppColors.mint,
      width: AppDimens.scannerCornerWidth,
    );
    const radius = Radius.circular(AppRadii.xl + 8);

    return SizedBox(
      width: AppDimens.scannerCorner,
      height: AppDimens.scannerCorner,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: corner.isTop ? side : BorderSide.none,
            bottom: corner.isTop ? BorderSide.none : side,
            start: corner.isStart ? side : BorderSide.none,
            end: corner.isStart ? BorderSide.none : side,
          ),
          borderRadius: BorderRadiusDirectional.only(
            topStart: corner == _Corner.topStart ? radius : Radius.zero,
            topEnd: corner == _Corner.topEnd ? radius : Radius.zero,
            bottomStart: corner == _Corner.bottomStart ? radius : Radius.zero,
            bottomEnd: corner == _Corner.bottomEnd ? radius : Radius.zero,
          ).resolve(Directionality.of(context)),
        ),
      ),
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
            blurRadius: AppDimens.sheetBlur + 4,
          ),
        ],
      ),
    );
  }
}
