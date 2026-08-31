import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/shared/utils/decoded_image.dart';
import 'package:sijil_it/shared/widgets/photo_strip.dart';

import '../test/fake_odoo/test_app_harness.dart';

/// How many bytes a photograph actually costs, measured on a real engine.
///
/// ## Why this is an integration test and not a widget test
///
/// The widget suite asserts on the *provider* — that a `ResizeImage` is in
/// place with the right bounds — because a headless test has no rasteriser and
/// cannot decode anything. That proves the decision is wired up. It does not
/// prove the decision works.
///
/// This decodes. It renders the same photograph twice, once through the app's
/// bounding and once raw, and reads `ImageCache.currentSizeBytes` after each.
/// The comparison is the claim, made on the device rather than argued from
/// first principles.
///
/// ## What it does and does not transfer
///
/// A decoded bitmap is four bytes per pixel on every architecture, so the
/// **ratio** measured here is the ratio on a 2 GB ARM handset too. What does
/// not transfer is the consequence: on this emulator, backed by host memory,
/// the unbounded decode is merely wasteful. On a cheap phone it is the
/// difference between a photo strip and an out-of-memory kill.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A real PNG, [side] square. Needs a rasteriser, which is why this test
  /// lives here.
  Future<Uint8List> photograph(int side) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Noise rather than a flat fill: a solid colour compresses to almost
    // nothing, and the encoded size is half of what is being measured.
    for (var x = 0; x < side; x += 8) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 8, side.toDouble()),
        Paint()..color = Color(0xFF000000 | (x * 7919) & 0xFFFFFF),
      );
    }
    final image = await recorder.endRecording().toImage(side, side);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// Renders [provider] into a thumbnail-sized box and returns what the image
  /// cache grew by.
  Future<int> cacheCostOf(WidgetTester tester, ImageProvider provider) async {
    final cache = PaintingBinding.instance.imageCache;
    cache
      ..clear()
      ..clearLiveImages();

    await tester.pumpWidget(
      TestApp(
        child: Center(
          child: SizedBox(
            width: AppDimens.photoThumb,
            height: AppDimens.photoThumb,
            child: Image(image: provider, fit: BoxFit.cover),
          ),
        ),
      ),
    );

    // Real decoding, on a real clock.
    for (var i = 0; i < 20 && cache.currentSizeBytes == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    return cache.currentSizeBytes;
  }

  testWidgets('a camera-sized photo in a thumbnail costs a thumbnail', (
    tester,
  ) async {
    // 1200 square is a modest camera output — a real one is three times this
    // on each axis, and the relationship is quadratic.
    const side = 1200;
    final bytes = await photograph(side);

    final unbounded = await cacheCostOf(tester, MemoryImage(bytes));

    late ImageProvider boundedProvider;
    await tester.pumpWidget(
      TestApp(
        child: Builder(
          builder: (context) {
            boundedProvider = DecodedImage.thumbnail(
              context,
              MemoryImage(bytes),
              side: AppDimens.photoThumb,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final bounded = await cacheCostOf(tester, boundedProvider);

    // Printed so the number is in the CI log rather than only in an
    // assertion someone has to reverse-engineer.
    debugPrint(
      'IMAGE MEMORY: ${side}x$side photo in a '
      '${AppDimens.photoThumb.toInt()}pt box — '
      'unbounded ${unbounded ~/ 1024} KB, bounded ${bounded ~/ 1024} KB '
      '(${(unbounded / bounded).toStringAsFixed(1)}x)',
    );

    expect(unbounded, greaterThan(0), reason: 'Nothing decoded.');
    expect(bounded, greaterThan(0), reason: 'Nothing decoded.');

    // The unbounded decode is the full bitmap: 1200 * 1200 * 4 = 5.5 MB.
    expect(unbounded, greaterThan(4 * 1024 * 1024));

    // Bounded, it is the box plus the cover headroom — well under a tenth.
    expect(
      bounded * 10,
      lessThan(unbounded),
      reason:
          'Bounding saved less than 90%. unbounded=$unbounded bounded=$bounded',
    );
  });

  testWidgets('a strip of four is bounded without the caller asking', (
    tester,
  ) async {
    // The return screen's worst case, and the reason the bound lives inside
    // `PhotoTile` rather than at each call site.
    final bytes = await photograph(1200);
    final cache = PaintingBinding.instance.imageCache;
    cache
      ..clear()
      ..clearLiveImages();

    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: Scaffold(
          body: PhotoStrip(
            photos: <ImageProvider>[
              // Distinct providers, so the cache cannot collapse them into
              // one entry and flatter the result.
              for (var i = 0; i < 4; i++)
                MemoryImage(Uint8List.fromList(<int>[...bytes, i])),
            ],
          ),
        ),
      ),
    );

    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    final used = cache.currentSizeBytes;
    const unbounded = 1200 * 1200 * 4 * 4;

    debugPrint(
      'STRIP MEMORY: four 1200x1200 photos — ${used ~/ 1024} KB, '
      'against ${unbounded ~/ 1024} KB unbounded',
    );

    expect(used, greaterThan(0), reason: 'Nothing decoded.');
    expect(
      used * 10,
      lessThan(unbounded),
      reason: 'Four thumbnails took ${used ~/ 1024} KB.',
    );
  });
}
