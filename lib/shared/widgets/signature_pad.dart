import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Holds the strokes drawn on a [SignaturePad] and renders them to a PNG.
///
/// Kept outside the widget so a Cubit can ask "has this been signed yet" to
/// gate the confirm button, and can pull the bytes at submit time without the
/// widget having to push them up on every touch move.
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = <List<Offset>>[];

  List<List<Offset>> get strokes => List<List<Offset>>.unmodifiable(_strokes);

  /// A single tap leaves a one-point stroke. That is a dot, not a signature,
  /// so it does not count as signed.
  bool get isEmpty => !_strokes.any((s) => s.length > 1);

  bool get isNotEmpty => !isEmpty;

  void begin(Offset point) {
    _strokes.add(<Offset>[point]);
    notifyListeners();
  }

  void extend(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }

  /// Renders the signature as a PNG.
  ///
  /// **Black ink on white**, whatever the pad looked like on screen. The pad
  /// draws light strokes on a dark well because that is what the app's dark
  /// theme calls for, but the file's audience is whoever opens the record in
  /// Odoo's web client — on white. Exporting what the screen showed would ship
  /// a white-on-transparent image that is invisible exactly where it matters.
  Future<Uint8List?> toPng({required Size size, double pixelRatio = 2}) async {
    if (isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.signaturePaper,
    );
    _paintStrokes(canvas, _strokes, AppColors.signatureInk);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

void _paintStrokes(Canvas canvas, List<List<Offset>> strokes, Color ink) {
  final paint = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = AppDimens.signatureStroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  for (final stroke in strokes) {
    if (stroke.length < 2) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          AppDimens.signatureStroke / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      }
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      // Midpoint smoothing: raw touch samples are far enough apart that a
      // polyline shows every one of them as a corner, which makes a signature
      // look drawn by a machine instead of by a hand.
      final previous = stroke[i - 1];
      final current = stroke[i];
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
    }
    canvas.drawPath(path, paint);
  }
}

/// A pad the recipient signs with a finger.
///
/// The proof this produces is the point of the handover flow: a chatter note
/// records that IT *says* it handed over three assets, a signature records
/// that the recipient agreed. It is stored alongside the note on every asset
/// in the bundle, so the evidence survives on each record independently.
class SignaturePad extends StatelessWidget {
  const SignaturePad({
    required this.controller,
    this.hint,
    this.height = AppDimens.signaturePadHeight,
    super.key,
  });

  final SignaturePadController controller;
  final String? hint;

  /// Definite, because the pad is normally inside a scrolling form: a minimum
  /// height there resolves to infinity and the [Stack] cannot lay out. A
  /// caller with room to spare passes a larger value.
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ColoredBox(
          color: palette.sunken,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: palette.line),
                    ),
                  ),
                ),
              ),
              // The signature is captured in the pad's own coordinate space,
              // so it exports identically whatever size the pad was laid out
              // at — a tablet and a phone produce the same image.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => controller.begin(d.localPosition),
                  onPanUpdate: (d) => controller.extend(d.localPosition),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => CustomPaint(
                      painter: _SignaturePainter(
                        strokes: controller.strokes,
                        ink: palette.ink,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              if (hint != null)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => AnimatedOpacity(
                        opacity: controller.isEmpty ? 1 : 0,
                        duration: AppDurations.fast,
                        child: Text(
                          hint!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: AppTextSize.axis,
                                letterSpacing: AppTypography.noTracking,
                                color: palette.faint,
                              ),
                        ),
                      ),
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

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes, required this.ink});

  final List<List<Offset>> strokes;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, strokes, ink);

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
