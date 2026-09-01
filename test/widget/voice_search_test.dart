import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/employees/presentation/pages/employee_list_page.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/voice_search_button.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// Dictating a search instead of typing it.
///
/// The technician this is for is holding a laptop in one hand and a phone in
/// the other, standing at a desk that is not theirs. Typing "MacBook Pro"
/// needs both hands and a flat surface; saying it needs neither — and the
/// search field is the way into every list in the product.
///
/// The recogniser itself belongs to the plugin. What is asserted here is
/// everything around it: that the button is absent where it cannot work, that
/// what was heard reaches the same code path a typed query does, and that the
/// microphone is not left open.
void main() {
  late FakeOdooData data;
  late FakeVoiceInput voice;
  late AppL10n en;

  setUp(() async {
    data = FakeOdooData.seeded();
    voice = FakeVoiceInput(available: true);
    await configureTestDependencies(data: data, voice: voice);
    en = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('en'),
    Size size = TestSizes.phone,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      RoutedTestApp(
        size: size,
        locale: locale,
        textScale: textScale,
        child: signedInScreen(screen),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('whether the button is offered at all', () {
    testWidgets('it appears on a device that can dictate', (tester) async {
      await pump(tester, const AssetListPage());

      expect(find.byType(VoiceSearchButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('and is absent on one that cannot', (tester) async {
      voice.available = false;
      await pump(tester, const AssetListPage());

      expect(
        find.byIcon(Icons.mic_none_rounded),
        findsNothing,
        reason:
            'a control that can never work is worse than no control — the '
            'keyboard beside it does the same job',
      );
    });

    testWidgets('the scan button is untouched either way', (tester) async {
      voice.available = false;
      await pump(tester, const AssetListPage());

      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });

    testWidgets('employees get it too, where a name is hardest to type', (
      tester,
    ) async {
      await pump(tester, const EmployeeListPage());

      expect(find.byType(VoiceSearchButton), findsOneWidget);
    });
  });

  group('offering the button asks the user for nothing', () {
    // Found on a device, not here. The button used to decide whether to draw
    // itself by calling `isAvailable`, which initialises the recogniser — and
    // on Android that raises "Allow Sijil IT to record audio?". It appeared
    // over a screen nobody had touched, seconds after launch.
    //
    // The cost of answering "Don't allow" to a question with no context is
    // permanent: Android stops showing the dialog, and the microphone button
    // never returns for that install.

    testWidgets('drawing it never initialises the recogniser', (tester) async {
      await pump(tester, const AssetListPage());

      expect(find.byType(VoiceSearchButton), findsOneWidget);
      expect(
        voice.canOfferCount,
        greaterThan(0),
        reason: 'it still has to ask whether to draw itself',
      );
      expect(
        voice.isAvailableCount,
        0,
        reason: 'this is the call that prompts, and no one has pressed it',
      );
    });

    testWidgets('a device that has not been asked yet is still offered it', (
      tester,
    ) async {
      // The state every fresh install is in: the permission is undecided, so
      // nothing is known about the recogniser and nothing may be asked. The
      // button has to appear regardless, because pressing it is the only path
      // to granting the permission at all.
      voice
        ..available = false
        ..offered = true;

      await pump(tester, const AssetListPage());

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(voice.isAvailableCount, 0);
    });

    testWidgets('and the press is what asks', (tester) async {
      voice
        ..available = true
        ..offered = true;

      await pump(tester, const AssetListPage());
      expect(voice.isAvailableCount, 0);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(
        voice.isAvailableCount,
        greaterThan(0),
        reason: 'the prompt belongs to the moment the user asked for it',
      );
    });

    testWidgets('a device that turns out not to support it loses the button', (
      tester,
    ) async {
      // The trade this makes: one wasted tap on a device that was offered the
      // button optimistically and cannot honour it, against no unexplained
      // prompt on every device that can.
      voice
        ..available = false
        ..offered = true;

      await pump(tester, const AssetListPage());
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });
  });

  group('what is heard reaches the search', () {
    testWidgets('a final transcript becomes the query', (tester) async {
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      voice.speak('MacBook');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'MacBook'),
        findsOneWidget,
        reason: 'it goes into the same field the keyboard writes to',
      );
    });

    testWidgets('a partial one narrows the list while you are still talking', (
      tester,
    ) async {
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      voice.speak('Mac', isFinal: false);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Mac'),
        findsOneWidget,
        reason:
            'a search that appears only at the end looks like nothing '
            'happened for four seconds',
      );
    });

    testWidgets('the same query a typed one would produce', (tester) async {
      // Not a second lookup path. Whatever resolves from the keyboard has to
      // resolve from the microphone, and neither can drift from the other.
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      voice.speak('MacBook');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final spoken = find.byType(AssetListPage).evaluate().length;
      expect(spoken, 1);
      expect(find.textContaining('MacBook'), findsWidgets);
    });
  });

  group('the microphone state is visible and does not leak', () {
    testWidgets('the icon fills while listening', (tester) async {
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('and empties again when the recogniser commits', (
      tester,
    ) async {
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      voice.speak('MacBook');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('a second tap stops it', (tester) async {
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      expect(voice.stopCount, 1);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('leaving the screen closes the microphone', (tester) async {
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(
        voice.stopCount,
        1,
        reason:
            'a microphone left open by a screen the user has left is the '
            'thing people uninstall an app over',
      );
    });

    testWidgets('a refused permission takes the button away', (tester) async {
      voice.refuseToStart = true;
      await pump(tester, const AssetListPage());

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.mic_none_rounded),
        findsNothing,
        reason:
            'on Android the system prompt never reappears once "Don\'t allow" '
            'has been chosen, so offering the button again is a dead end',
      );
    });
  });

  group('it asks the recogniser for the right language', () {
    testWidgets('English', (tester) async {
      await pump(tester, const AssetListPage());
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(voice.lastLocaleId, 'en_US');
    });

    testWidgets('Arabic', (tester) async {
      // Getting this wrong is not subtle: an Arabic recogniser handed English
      // audio returns confident nonsense.
      await pump(
        tester,
        const AssetListPage(),
        locale: const Locale('ar', 'EG'),
      );
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(voice.lastLocaleId, 'ar_EG');
    });
  });

  group('it fits beside everything already in the field', () {
    testWidgets('the worst case the app can reach', (tester) async {
      await pump(
        tester,
        const AssetListPage(),
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(find.byType(VoiceSearchButton), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });

    testWidgets('and the button is named for a screen reader', (tester) async {
      await pump(tester, const AssetListPage());

      expect(find.byTooltip(en.voiceSearchStart), findsOneWidget);
    });
  });
}
