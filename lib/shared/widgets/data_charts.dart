import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// One band of a [StatusDonut].
@immutable
class DonutSlice {
  const DonutSlice({required this.value, required this.color});

  final int value;
  final Color color;
}

/// The dashboard's distribution ring.
///
/// ## Why a chart replaced the counters
///
/// The previous dashboard was six tiles holding six numbers. "68" answers
/// *how many are assigned*; it does not answer *is the fleet healthy*, which
/// is the only question anyone opens the app to ask. A ring answers it in one
/// glance because the reader compares arc lengths, not digits.
///
/// The total sits in the middle rather than in a seventh tile: it is the sum
/// of everything drawn around it, and putting it anywhere else makes the
/// reader do the arithmetic to check.
///
/// [centerValue] arrives already formatted — a **count** follows the language,
/// so the caller localises it and this widget never touches digits.
class StatusDonut extends StatelessWidget {
  const StatusDonut({
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.size = 120,
    this.semanticLabel,
    super.key,
  });

  final List<DonutSlice> slices;
  final String centerValue;
  final String centerLabel;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScale = MediaQuery.textScalerOf(context);

    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            slices: slices.where((s) => s.value > 0).toList(growable: false),
            track: palette.track,
            stroke: size * 0.108,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  centerValue,
                  style: AppTypography.numeric(
                    size: textScale.scale(size * 0.25).clamp(16, size * 0.3),
                    color: palette.ink,
                  ),
                ),
                Text(
                  centerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: AppTextSize.axis,
                    letterSpacing: AppTypography.noTracking,
                    color: palette.faint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.slices,
    required this.track,
    required this.stroke,
  });

  final List<DonutSlice> slices;
  final Color track;
  final double stroke;

  /// Blank arc between bands, in radians. Without it two adjacent hues of
  /// similar lightness read as one band.
  static const double _gap = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(rect.center, radius, paint..color = track);

    final total = slices.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) return;

    // A single band would draw a full circle with a gap bitten out of it,
    // which reads as an error rather than as "everything is one status".
    if (slices.length == 1) {
      canvas.drawCircle(rect.center, radius, paint..color = slices.first.color);
      return;
    }

    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * 2 * math.pi;
      // Never let the gap eat a band whole: a 1-of-124 slice still has to be
      // visible, because "one asset is lost" is exactly what needs seeing.
      final drawn = math.max(sweep - _gap, 0.012);
      canvas.drawArc(rect, start, drawn, false, paint..color = slice.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.track != track ||
      old.stroke != stroke ||
      old.slices.length != slices.length ||
      Object.hashAll(old.slices.map((s) => Object.hash(s.value, s.color))) !=
          Object.hashAll(slices.map((s) => Object.hash(s.value, s.color)));
}

/// A filled trend line with an emphasised endpoint.
///
/// Answers "which way is this going", which the ring cannot: a distribution is
/// a snapshot, and a fleet that lost twenty assets this quarter looks identical
/// to one that gained twenty. The endpoint gets a dot because the latest
/// reading is the one the reader is actually looking for.
///
/// Always drawn LTR, even in Arabic. Time on a chart axis runs left to right
/// in both locales — mirroring it would be a novel convention, not a
/// translation.
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({
    required this.values,
    this.height = 72,
    this.tone,
    this.semanticLabel,
    super.key,
  });

  final List<double> values;
  final double height;
  final Color? tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: semanticLabel,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(
              values: values,
              tone: tone ?? palette.mint,
              grid: palette.lineSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.tone,
    required this.grid,
  });

  final List<double> values;
  final Color tone;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.22 + i * 0.32);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) return;

    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    // A flat series has no range to normalise against; centre it rather than
    // dividing by zero and painting the line along the top edge.
    final span = (hi - lo).abs() < 0.0001 ? 1.0 : hi - lo;
    final top = size.height * 0.14;
    final bottom = size.height * 0.86;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * (i / (values.length - 1)),
          (hi - lo).abs() < 0.0001
              ? (top + bottom) / 2
              : bottom - ((values[i] - lo) / span) * (bottom - top),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            tone.withValues(alpha: AppOpacities.sparklineArea),
            tone.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppDimens.sparklineStroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = tone,
    );

    canvas.drawCircle(
      points.last,
      AppDimens.sparklineHaloRadius,
      Paint()..color = tone.withValues(alpha: AppOpacities.sparklineHalo),
    );
    canvas.drawCircle(
      points.last,
      AppDimens.sparklinePoint,
      Paint()..color = tone,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.tone != tone || old.grid != grid || !listEquals(old.values, values);

  static bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A ring that shows how far through a count the user is.
///
/// Used by the audit screen, where "31 of 43" is the difference between
/// knowing you are nearly done and having no idea when to stop.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.progress,
    required this.primary,
    required this.secondary,
    this.size = 104,
    this.tone,
    super.key,
  });

  /// 0..1. Values outside are clamped rather than drawn as an over-full ring.
  final double progress;

  /// Big centred value — a percentage, already localised.
  final String primary;

  /// Small line beneath it — "٣١ من ٤٣", already localised.
  final String secondary;
  final double size;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScale = MediaQuery.textScalerOf(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          tone: tone ?? palette.mint,
          track: palette.track,
          stroke: size * 0.106,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                primary,
                style: AppTypography.numeric(
                  size: textScale.scale(size * 0.25).clamp(16, size * 0.3),
                  color: palette.ink,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                child: Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: AppTextSize.nav,
                    letterSpacing: AppTypography.noTracking,
                    color: palette.faint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.tone,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color tone;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = track);
    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      paint..color = tone,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.tone != tone || old.track != track;
}
