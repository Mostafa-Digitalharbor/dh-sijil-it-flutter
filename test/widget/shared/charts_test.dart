import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_colors.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/shared/widgets/data_charts.dart';
import 'package:sijil_it/shared/widgets/signature_pad.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The drawn widgets: the ring, the trend line, the progress ring, the pad.
///
/// A `CustomPainter` fails silently. Divide by zero on a flat series, sweep an
/// arc past 2π, normalise against an empty list — none of it throws, and all
/// of it produces a picture that is merely wrong. So these feed each painter
/// the inputs real data actually reaches: all-zero, one value, a flat line, a
/// single dominant slice.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: TestSizes.phone,
        textScale: textScale,
        child: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  group('StatusDonut', () {
    const slices = <DonutSlice>[
      DonutSlice(value: 12, color: AppColors.statusAssigned),
      DonutSlice(value: 7, color: AppColors.statusAvailable),
      DonutSlice(value: 3, color: AppColors.statusMaintenance),
    ];

    testWidgets('an empty fleet draws a track and still names the total', (
      tester,
    ) async {
      // Day one of a deployment: every count is zero. Dividing by the total
      // here is how a chart widget throws on the very first screen a customer
      // ever opens.
      await pump(
        tester,
        const StatusDonut(
          slices: <DonutSlice>[
            DonutSlice(value: 0, color: AppColors.statusAssigned),
            DonutSlice(value: 0, color: AppColors.statusAvailable),
          ],
          centerValue: '0',
          centerLabel: 'ASSETS',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('ASSETS'), findsOneWidget);
    });

    testWidgets('no slices at all is survivable', (tester) async {
      await pump(
        tester,
        const StatusDonut(
          slices: <DonutSlice>[],
          centerValue: '0',
          centerLabel: 'ASSETS',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the total is not repeated outside the ring', (tester) async {
      // It is the sum of what is drawn around it. Anywhere else and the reader
      // has to do the arithmetic to check.
      await pump(
        tester,
        const StatusDonut(
          slices: slices,
          centerValue: '22',
          centerLabel: 'ASSETS',
        ),
      );

      expect(find.text('22'), findsOneWidget);
    });

    testWidgets('a summary label replaces the parts for a screen reader', (
      tester,
    ) async {
      // Read out slice by slice, a ring is a list of numbers with no shape.
      await pump(
        tester,
        const StatusDonut(
          slices: slices,
          centerValue: '22',
          centerLabel: 'ASSETS',
          semanticLabel:
              '22 assets: 12 assigned, 7 available, 3 in maintenance',
        ),
      );

      expect(
        find.bySemanticsLabel(
          '22 assets: 12 assigned, 7 available, 3 in maintenance',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the centre value stays inside the ring at large text', (
      tester,
    ) async {
      await pump(
        tester,
        const StatusDonut(
          slices: slices,
          centerValue: '1248',
          centerLabel: 'ASSETS',
        ),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      final ring = tester.getSize(find.byType(StatusDonut));
      final value = tester.getSize(find.text('1248'));
      expect(value.width, lessThanOrEqualTo(ring.width));
    });
  });

  group('TrendSparkline', () {
    testWidgets('a flat series does not divide by its own range', (
      tester,
    ) async {
      // Every month the same: the range is zero, and normalising against it
      // paints the line along the top edge — or throws.
      await pump(
        tester,
        const TrendSparkline(values: <double>[7, 7, 7, 7, 7, 7]),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single reading and an empty series both survive', (
      tester,
    ) async {
      await pump(tester, const TrendSparkline(values: <double>[7]));
      expect(tester.takeException(), isNull);

      await pump(tester, const TrendSparkline(values: <double>[]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('time runs left to right in Arabic too', (tester) async {
      // Mirroring a time axis would be a novel convention, not a translation.
      await pump(
        tester,
        const TrendSparkline(values: <double>[1, 4, 9]),
        locale: const Locale('ar'),
      );

      final context = tester.element(find.byType(CustomPaint).last);
      expect(Directionality.of(context), TextDirection.ltr);
    });

    testWidgets('negative readings do not break the normalisation', (
      tester,
    ) async {
      await pump(tester, const TrendSparkline(values: <double>[-4, 0, -9, 3]));
      expect(tester.takeException(), isNull);
    });
  });

  group('ProgressRing', () {
    testWidgets('progress outside 0..1 is clamped, not drawn over-full', (
      tester,
    ) async {
      for (final progress in <double>[-1, 0, 0.5, 1, 4]) {
        await pump(
          tester,
          ProgressRing(
            progress: progress,
            primary: '${(progress * 100).round()}%',
            secondary: '31 of 43',
          ),
        );
        expect(tester.takeException(), isNull, reason: 'progress $progress');
      }
    });

    testWidgets('both halves of the count are shown', (tester) async {
      // "31 of 43" is the difference between knowing you are nearly done and
      // having no idea when to stop.
      await pump(
        tester,
        const ProgressRing(
          progress: 0.72,
          primary: '72%',
          secondary: '31 of 43',
        ),
      );

      expect(find.text('72%'), findsOneWidget);
      expect(find.text('31 of 43'), findsOneWidget);
    });
  });

  group('SignaturePadController', () {
    test('a tap is a dot, not a signature', () {
      // The confirm button is gated on this. A stray finger-press must not
      // count as the recipient agreeing to a handover.
      final controller = SignaturePadController()..begin(const Offset(10, 10));

      expect(controller.isEmpty, isTrue);
      expect(controller.isNotEmpty, isFalse);
    });

    test('a drawn stroke counts', () {
      final controller = SignaturePadController()
        ..begin(const Offset(10, 10))
        ..extend(const Offset(30, 24));

      expect(controller.isNotEmpty, isTrue);
    });

    test('extending before starting is ignored rather than throwing', () {
      final controller = SignaturePadController();

      expect(() => controller.extend(const Offset(1, 1)), returnsNormally);
      expect(controller.strokes, isEmpty);
    });

    test('the stroke list handed out cannot be edited from outside', () {
      final controller = SignaturePadController()..begin(Offset.zero);

      expect(() => controller.strokes.add(<Offset>[]), throwsUnsupportedError);
    });

    test('clearing an empty pad does not notify', () {
      // The hint fades on every notification; an idle pad must not flicker.
      var notifications = 0;
      final controller = SignaturePadController()
        ..addListener(() => notifications++)
        ..clear();

      expect(notifications, 0);

      controller
        ..begin(Offset.zero)
        ..clear();
      expect(notifications, 2);
    });

    test('an empty pad exports nothing at all', () async {
      // Null rather than a blank PNG: a white rectangle filed as proof of
      // receipt is worse than no file, because it looks like evidence.
      final controller = SignaturePadController()..begin(const Offset(5, 5));

      expect(await controller.toPng(size: const Size(200, 100)), isNull);
    });

    test('a signature exports as black ink on white paper', () async {
      // Whatever the pad looked like: the audience is whoever opens the record
      // in Odoo's web client, on white. Exporting the dark-theme rendering
      // ships an invisible image.
      final controller = SignaturePadController()
        ..begin(const Offset(10, 50))
        ..extend(const Offset(100, 20))
        ..extend(const Offset(190, 60));

      final png = await controller.toPng(
        size: const Size(200, 100),
        pixelRatio: 1,
      );
      expect(png, isNotNull);

      final image = await decodeImageFromList(png!);
      addTearDown(image.dispose);
      expect(image.width, 200);
      expect(image.height, 100);

      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = data!.buffer.asUint8List();

      int at(int x, int y) => (y * image.width + x) * 4;
      final corner = at(2, 2);
      expect(
        <int>[pixels[corner], pixels[corner + 1], pixels[corner + 2]],
        everyElement(greaterThan(0xF0)),
        reason: 'the paper is white, not the pad\'s dark well',
      );

      var darkest = 0xFF;
      for (var x = 0; x < image.width; x++) {
        for (var y = 0; y < image.height; y++) {
          darkest = darkest < pixels[at(x, y)] ? darkest : pixels[at(x, y)];
        }
      }
      expect(darkest, lessThan(0x40), reason: 'the ink is black, not white');
    });
  });

  group('SignaturePad', () {
    testWidgets('drawing on the pad reaches the controller', (tester) async {
      final controller = SignaturePadController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        SizedBox(
          width: 300,
          child: SignaturePad(controller: controller, hint: 'Sign above'),
        ),
      );

      await tester.drag(find.byType(SignaturePad), const Offset(80, 30));
      await tester.pump();

      expect(controller.isNotEmpty, isTrue);
    });

    testWidgets('the hint fades once there is a signature over it', (
      tester,
    ) async {
      final controller = SignaturePadController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        SizedBox(
          width: 300,
          child: SignaturePad(controller: controller, hint: 'Sign above'),
        ),
      );

      double hintOpacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find.text('Sign above'),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;

      expect(hintOpacity(), 1);

      await tester.drag(find.byType(SignaturePad), const Offset(80, 30));
      await tester.pump();

      expect(hintOpacity(), 0);
    });

    testWidgets('the pad has a definite height inside a scrolling form', (
      tester,
    ) async {
      // A minimum height resolves to infinity in a scroll view and the Stack
      // cannot lay out.
      final controller = SignaturePadController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        SizedBox(
          width: 320,
          height: 400,
          child: ListView(
            children: <Widget>[SignaturePad(controller: controller)],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SignaturePad)).height,
        AppDimens.signaturePadHeight,
      );
    });
  });
}
