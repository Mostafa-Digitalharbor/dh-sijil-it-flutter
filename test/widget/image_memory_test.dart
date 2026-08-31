import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/shared/utils/decoded_image.dart';
import 'package:sijil_it/shared/widgets/app_logo.dart';
import 'package:sijil_it/shared/widgets/photo_strip.dart';

import '../fake_odoo/test_app_harness.dart';

/// How much memory the app is willing to spend showing a picture.
///
/// ## Why this is a test and not a code-review note
///
/// Flutter decodes an image at its intrinsic resolution unless told otherwise,
/// and caches the result uncompressed at four bytes per pixel. A phone-camera
/// photograph is routinely 4000x3000 — **48 MB** — and drawing it into a
/// 64-point thumbnail does not change that by one byte.
///
/// The return screen shows four of those. Unbounded, that is roughly 190 MB of
/// image cache for four thumbnails: an out-of-memory kill on a 2 GB handset,
/// and on a better one a permanent thrash of the 100 MB cache where every
/// scroll re-decodes what the last one evicted.
///
/// It is invisible in a screenshot, invisible in a review, and it comes back
/// the moment somebody adds a photo surface and reaches for the obvious
/// `Image.memory(bytes)`. So it is asserted.
///
/// These assert on the *provider*, not on decoded pixels. A decode needs a
/// real raster pass, which a headless widget test does not have — and the
/// provider is where the decision actually lives.
void main() {
  /// A 1x1 PNG. Never decoded here; it only has to be a plausible payload.
  final pixel = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  /// Resolves [build] against a real [MediaQuery], which is what supplies the
  /// device pixel ratio the bound is computed from.
  Future<T> underMediaQuery<T>(
    WidgetTester tester,
    T Function(BuildContext context) build,
  ) async {
    late T result;
    await tester.pumpWidget(
      TestApp(
        child: Builder(
          builder: (context) {
            result = build(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  group('DecodedImage.thumbnail', () {
    testWidgets('bounds the decode to the box, not the camera', (tester) async {
      final bounded = await underMediaQuery(
        tester,
        (context) => DecodedImage.thumbnail(
          context,
          MemoryImage(pixel),
          side: AppDimens.photoThumb,
        ),
      );

      final resize = bounded as ResizeImage;
      final ratio = tester.view.devicePixelRatio;

      // The headroom is deliberate: a `BoxFit.cover` draw needs the *shorter*
      // side to reach the box, and `fit` sizes the longer one.
      expect(resize.width, (AppDimens.photoThumb * 1.5 * ratio).round());
      expect(resize.height, resize.width);
      expect(resize.policy, ResizeImagePolicy.fit);

      // Even with the headroom, a 4000-px photo lands well under a megabyte.
      final pixels = resize.width! * resize.height!;
      expect(pixels * 4, lessThan(1024 * 1024));
    });

    testWidgets('never upscales a photo that is already small', (tester) async {
      // Upscaling at decode time spends memory to gain what the GPU does free.
      final bounded = await underMediaQuery(
        tester,
        (context) => DecodedImage.thumbnail(
          context,
          MemoryImage(pixel),
          side: AppDimens.photoThumb,
        ),
      );

      expect((bounded as ResizeImage).allowUpscaling, isFalse);
    });

    testWidgets('a zero-sized box asks for no resize rather than a zero one', (
      tester,
    ) async {
      // The frame a rotation passes through, and the frame before a
      // LayoutBuilder has constraints. `ResizeImage(width: 0)` asserts.
      final bounded = await underMediaQuery(
        tester,
        (context) =>
            DecodedImage.thumbnail(context, MemoryImage(pixel), side: 0),
      );

      expect(bounded, isA<MemoryImage>());
    });
  });

  group('every photo surface', () {
    /// The `Image` widgets a subtree actually builds.
    List<Image> imagesIn(WidgetTester tester, Finder root) => tester
        .widgetList<Image>(
          find.descendant(of: root, matching: find.byType(Image)),
        )
        .toList();

    testWidgets('the strip bounds its tiles without being asked to', (
      tester,
    ) async {
      // Bounding lives inside PhotoTile rather than at the call site, so a
      // new photo surface cannot forget it.
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: PhotoStrip(
              photos: <ImageProvider>[
                for (var i = 0; i < 4; i++) MemoryImage(pixel),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final images = imagesIn(tester, find.byType(PhotoStrip));
      expect(images, hasLength(4));

      for (final image in images) {
        expect(
          image.image,
          isA<ResizeImage>(),
          reason: 'A tile decoded its photo at full resolution.',
        );
      }
    });

    testWidgets('and the featured layout bounds its lead image too', (
      tester,
    ) async {
      // The lead tile is twice the width of the others and took a separate
      // code path, which is exactly where a bound gets missed.
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: PhotoStrip(
              featured: true,
              photos: <ImageProvider>[
                for (var i = 0; i < 3; i++) MemoryImage(pixel),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final images = imagesIn(tester, find.byType(PhotoStrip));
      expect(images, isNotEmpty);
      for (final image in images) {
        expect(image.image, isA<ResizeImage>());
      }
    });
  });

  group('the brand mark', () {
    testWidgets('the monogram is not decoded at its print resolution', (
      tester,
    ) async {
      // The file is 1024 square — 4 MB decoded — and every screen that shows
      // it draws it at forty-odd points. The splash pays for three of these
      // on its first frame.
      await tester.pumpWidget(
        const TestApp(
          child: Center(
            child: AppLogo.monogram(size: AppDimens.logoMonogramSm),
          ),
        ),
      );

      final image = tester.widget<Image>(
        find.descendant(of: find.byType(AppLogo), matching: find.byType(Image)),
      );

      expect(image.width, AppDimens.logoMonogramSm);
      expect(image.image, isA<ResizeImage>());
      // The exact bound follows the device pixel ratio, so assert the
      // relationship rather than a number.
      expect((image.image as ResizeImage).width, lessThan(1024));
    });

    testWidgets('a mark left at its natural size is not forced to one', (
      tester,
    ) async {
      // With no width the caller wants the artwork's own size, and there is
      // nothing to bound it by. Inventing a bound would silently shrink it.
      await tester.pumpWidget(
        const TestApp(child: Center(child: AppLogo(BrandMark.wordmark))),
      );

      final image = tester.widget<Image>(
        find.descendant(of: find.byType(AppLogo), matching: find.byType(Image)),
      );

      expect(image.image, isA<AssetImage>());
    });
  });
}
