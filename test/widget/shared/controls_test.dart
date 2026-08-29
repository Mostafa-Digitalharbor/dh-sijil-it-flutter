import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/app/theme/app_palette.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';
import 'package:sijil_it/shared/widgets/app_text_field.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The buttons and fields every screen is built from.
///
/// These are pumped in isolation on purpose. A regression in `AppButton`
/// reaches forty screens at once, and finding it through a screen test means
/// reading past that screen's own data, cubit and layout first.
void main() {
  late AppL10n l10n;

  setUpAll(() async => l10n = await loadL10n());

  Future<void> pump(WidgetTester tester, Widget child, {Locale? locale}) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale ?? const Locale('en'),
        size: TestSizes.phone,
        child: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('AppButton', () {
    testWidgets('a busy button does not fire, even with a callback', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        AppButton(label: 'Save', isBusy: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(taps, 0, reason: 'a second submit is exactly what busy prevents');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a disabled button neither fires nor looks live', (
      tester,
    ) async {
      await pump(tester, const AppButton(label: 'Save', onPressed: null));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Save'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, AppOpacities.disabled);
    });

    testWidgets('going busy does not change the width', (tester) async {
      // The promise the spinner makes: a button that resizes mid-request drags
      // whatever is beside it sideways under the user's thumb.
      await pump(
        tester,
        AppButton(
          label: 'Test connection',
          icon: Icons.refresh_rounded,
          expand: false,
          onPressed: () {},
        ),
      );
      final resting = tester.getSize(find.byType(AppButton)).width;

      await pump(
        tester,
        AppButton(
          label: 'Test connection',
          icon: Icons.refresh_rounded,
          expand: false,
          isBusy: true,
          onPressed: () {},
        ),
      );

      expect(tester.getSize(find.byType(AppButton)).width, resting);
    });

    testWidgets('expand fills its parent, and not expanding hugs the label', (
      tester,
    ) async {
      await pump(tester, AppButton(label: 'Go', onPressed: () {}));
      final wide = tester.getSize(find.byType(AppButton)).width;

      await pump(
        tester,
        AppButton(label: 'Go', expand: false, onPressed: () {}),
      );
      final narrow = tester.getSize(find.byType(AppButton)).width;

      expect(narrow, lessThan(wide));
    });

    testWidgets('compact is shorter, and the default clears the tap floor', (
      tester,
    ) async {
      await pump(tester, AppButton(label: 'Go', onPressed: () {}));
      final tall = tester.getSize(find.byType(AppButton)).height;

      await pump(
        tester,
        AppButton(label: 'Go', isCompact: true, onPressed: () {}),
      );
      final short = tester.getSize(find.byType(AppButton)).height;

      expect(short, lessThan(tall));
      expect(tall, greaterThanOrEqualTo(AppDimens.minTapTarget));
    });

    testWidgets('a long label ellipsises rather than overflowing', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(
          label: 'Confirm this handover and notify everyone involved by email',
          onPressed: () {},
        ),
      );

      expectNoOverflow(tester);
      final text = tester.widget<Text>(find.textContaining('Confirm this'));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });
  });

  group('AppIconButton', () {
    testWidgets('an icon-only control still has an accessible name', (
      tester,
    ) async {
      await pump(
        tester,
        AppIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () {},
        ),
      );

      expect(find.byTooltip('Refresh'), findsOneWidget);
      expect(find.bySemanticsLabel('Refresh'), findsWidgets);

      // Named *and* announced as a button: a label alone tells a screen-reader
      // user what it is, not that it can be pressed.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Refresh' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a visually small button keeps a full-size tap target', (
      tester,
    ) async {
      // The visual box and the touchable area are allowed to differ; what is
      // not allowed is a 24-px target on a device held one-handed.
      await pump(
        tester,
        AppIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          size: 24,
          onPressed: () {},
        ),
      );

      final box = tester.getSize(find.byType(AppIconButton));
      expect(box.width, AppDimens.minTapTarget);
      expect(box.height, AppDimens.minTapTarget);
    });
  });

  group('AppTextAction', () {
    testWidgets('an enabled action is drawn in the accent', (tester) async {
      await pump(tester, AppTextAction(label: 'See all', onPressed: () {}));

      final context = tester.element(find.text('See all'));
      final text = tester.widget<Text>(find.text('See all'));
      expect(text.style?.color, context.palette.mint);
    });

    testWidgets('a disabled action looks inert instead of silently ignoring', (
      tester,
    ) async {
      // "Clear" beside an empty signature pad used to render in full accent
      // and swallow the tap, which reads as the app having missed the press.
      await pump(tester, const AppTextAction(label: 'Clear', onPressed: null));

      final context = tester.element(find.text('Clear'));
      final text = tester.widget<Text>(find.text('Clear'));
      expect(text.style?.color, context.palette.faint);
      expect(text.style?.color, isNot(context.palette.mint));
    });
  });

  group('AppCloseButton', () {
    testWidgets('carries the translated name of what it does', (tester) async {
      await pump(tester, AppCloseButton(onPressed: () {}));
      expect(find.byTooltip(l10n.actionClose), findsOneWidget);

      final ar = await loadL10n('ar');
      await pump(
        tester,
        AppCloseButton(onPressed: () {}),
        locale: const Locale('ar'),
      );
      expect(find.byTooltip(ar.actionClose), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('an error renders below the field, not inside it', (
      tester,
    ) async {
      // Inside the box, a long Arabic sentence truncates; below it, it wraps.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppTextField(
          label: 'Server URL',
          controller: controller,
          errorText: 'That does not look like a valid server address.',
        ),
      );

      expect(
        find.text('That does not look like a valid server address.'),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.decoration?.errorText,
        isNull,
        reason: 'the decoration must not draw a second copy',
      );

      final fieldBottom = tester.getBottomLeft(find.byType(TextField)).dy;
      final messageTop = tester
          .getTopLeft(find.textContaining('valid server address'))
          .dy;
      expect(messageTop, greaterThanOrEqualTo(fieldBottom - 1));
    });

    testWidgets('the label is printed uppercase and turns red on error', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppTextField(label: 'Database', controller: controller),
      );
      expect(find.text('DATABASE'), findsOneWidget);
      final calm = tester.widget<Text>(find.text('DATABASE')).style?.color;

      await pump(
        tester,
        AppTextField(
          label: 'Database',
          controller: controller,
          errorText: 'Enter your Odoo database name.',
        ),
      );
      final alarmed = tester.widget<Text>(find.text('DATABASE')).style?.color;

      expect(alarmed, isNot(calm));
    });

    testWidgets('the obscure toggle shows what the next tap will do', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'secret');
      addTearDown(controller.dispose);
      var obscure = true;

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppTextField(
                label: 'Credential',
                controller: controller,
                obscure: obscure,
                onToggleObscure: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
    });

    testWidgets('no toggle is offered when there is nothing to reveal', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(tester, AppTextField(label: 'Name', controller: controller));

      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('hiding the label keeps it for a screen reader', (
      tester,
    ) async {
      // The assign and return forms already print the field name as a step
      // heading; printing it twice is noise, losing it is a blank box.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppTextField(label: 'Notes', controller: controller, showLabel: false),
      );

      expect(find.text('NOTES'), findsNothing);
      expect(
        find.bySemanticsLabel('Notes'),
        findsOneWidget,
        reason: 'a field nobody can name is a field nobody can fill in',
      );
    });

    testWidgets('a notes box grows instead of clipping its second line', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppTextField(label: 'Notes', controller: controller, maxLines: 4),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 4);
      expect(field.minLines, 4);
      expect(field.keyboardType, TextInputType.multiline);
    });

    testWidgets('an obscured field stays one line even when asked for more', (
      tester,
    ) async {
      // `obscureText` with maxLines > 1 is a framework assertion, and a
      // password field is never a paragraph.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppTextField(
          label: 'Credential',
          controller: controller,
          obscure: true,
          maxLines: 3,
          onToggleObscure: () {},
        ),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 1);
    });
  });

  group('AppSearchField', () {
    testWidgets('the clear button appears only once there is text to clear', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppSearchField(
          controller: controller,
          hint: 'Name, tag, serial…',
          onChanged: (_) {},
          onClear: controller.clear,
        ),
      );
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'thinkpad');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('no clear affordance is offered when there is no handler', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'thinkpad');
      addTearDown(controller.dispose);

      await pump(
        tester,
        AppSearchField(
          controller: controller,
          hint: 'Search',
          onChanged: (_) {},
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  group('AppPickerField', () {
    testWidgets('the whole field opens the picker, not just the hint', (
      tester,
    ) async {
      var opened = 0;
      await pump(
        tester,
        AppPickerField(
          label: 'Handover date',
          value: '29 August 2026',
          trailingLabel: 'Today',
          onTap: () => opened++,
        ),
      );

      await tester.tap(find.text('29 August 2026'));
      await tester.pump();
      expect(opened, 1);

      await tester.tap(find.text('Today'));
      await tester.pump();
      expect(opened, 2, reason: 'the hint is an affordance, not decoration');
    });

    testWidgets('a disabled picker does not open', (tester) async {
      var opened = 0;
      await pump(
        tester,
        AppPickerField(
          label: 'Handover date',
          value: '29 August 2026',
          enabled: false,
          onTap: () => opened++,
        ),
      );

      await tester.tap(find.text('29 August 2026'));
      await tester.pump();
      expect(opened, 0);
    });
  });
}
