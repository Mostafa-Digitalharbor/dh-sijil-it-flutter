import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/features/scanner/presentation/pages/scanner_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The screen the product is named for, and the one no test had ever built.
///
/// Its logic was covered — `manual_code_entry_test.dart` drives `ScannerCubit`
/// directly, and every payload shape resolves there. What was never rendered
/// is the screen itself, which is the one place in the app exempt from the
/// responsive sweep: `responsive_sweep_test.dart` skips it because it mounts a
/// camera, so the chrome stacked on top of that camera — a top bar, an
/// instruction block, a mode switch, a manual-entry field and a result sheet,
/// all in one non-scrolling `Column` — had never been laid out at any size.
///
/// That column is exactly the shape that overflows. It has no `SingleChild
/// ScrollView` around it, by design: a viewfinder that scrolls away is not a
/// viewfinder. So every one of those children has to fit in the height the
/// device gives it, at whatever text size the user has chosen, in both
/// languages — and nothing was checking.
void main() {
  late AppL10n en;

  setUp(() async {
    await configureTestDependencies(data: FakeOdooData.seeded());
    en = await loadL10n();

    // `mobile_scanner` talks to a camera that a host VM does not have. Stubbed
    // rather than mocked out: the screen under test is the chrome *around* the
    // preview, and the preview's own texture is not what this file is about.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          (call) async => switch (call.method) {
            'state' => 1,
            'request' || 'start' => <String, Object?>{
              'textureId': 1,
              'size': <String, Object?>{'width': 1280.0, 'height': 720.0},
              'currentTorchState': 0,
            },
            _ => null,
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          null,
        );
    await sl.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = TestSizes.phone,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      RoutedTestApp(
        size: size,
        locale: locale,
        textScale: textScale,
        child: signedInScreen(const ScannerPage()),
      ),
    );
    // Not `pumpAndSettle`: the viewfinder's sweep line animates for ever, so
    // settling would time out rather than tell us anything.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the screen builds with a camera behind it', () {
    testWidgets('it names itself and offers the way out', (tester) async {
      await pump(tester);

      expect(find.text(en.scanTitle), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('it says what to point the camera at', (tester) async {
      await pump(tester);

      expect(find.text(en.scanInstruction), findsOneWidget);
    });

    testWidgets('the torch is offered, and starts off', (tester) async {
      await pump(tester);

      expect(
        find.byIcon(Icons.flashlight_off_rounded),
        findsOneWidget,
        reason: 'a torch that starts on blinds whoever opens the screen',
      );
      expect(find.byIcon(Icons.flashlight_on_rounded), findsNothing);
    });

    testWidgets('a keyboard is offered beside the camera', (tester) async {
      // The scanner used to have no alternative at all: a scuffed sticker or a
      // label on the underside of a desk was a dead end.
      await pump(tester);

      expect(find.text(en.scanEnterCode), findsOneWidget);
    });

    testWidgets('that keyboard opens a prompt that explains itself', (
      tester,
    ) async {
      // What resolving a typed code *does* is covered against the cubit in
      // `manual_code_entry_test.dart`, where it is faster and more precise.
      // What only this file can show is that the button on the camera screen
      // reaches that path at all.
      await pump(tester);

      await tester.tap(find.text(en.scanEnterCode));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(en.scanEnterCodeTitle), findsOneWidget);
      expect(find.text(en.scanEnterCodeBody), findsOneWidget);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'the point of the fallback is somewhere to type',
      );
      expect(find.text(en.actionOpen), findsOneWidget);
    });

    testWidgets('and the prompt fits the worst case too', (tester) async {
      await pump(
        tester,
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      final ar = await loadL10n('ar');
      await tester.tap(find.text(ar.scanEnterCode));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expectNoOverflow(tester);
    });
  });

  group('the chrome fits the device it is drawn on', () {
    for (final (name, size) in TestSizes.all) {
      testWidgets('a $name', (tester) async {
        await pump(tester, size: size);

        expectNoOverflow(tester);
      });
    }

    testWidgets('a small phone at the text ceiling', (tester) async {
      await pump(
        tester,
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });

    testWidgets('the worst case the app can actually reach', (tester) async {
      // The narrowest device, the longer language and the largest text the
      // clamp allows, all at once — the combination the rest of the product is
      // swept against and this screen never was.
      await pump(
        tester,
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });

    testWidgets('a landscape phone, where the height runs out first', (
      tester,
    ) async {
      await pump(
        tester,
        size: TestSizes.landscape,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });

    testWidgets('in Arabic, right to left', (tester) async {
      await pump(tester, locale: const Locale('ar', 'EG'));

      expectNoOverflow(tester);
      expect(find.byType(ScannerPage), findsOneWidget);
    });
  });
}
