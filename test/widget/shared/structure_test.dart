import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_avatar.dart';
import 'package:sijil_it/shared/widgets/app_segmented.dart';
import 'package:sijil_it/shared/widgets/app_sheets.dart';
import 'package:sijil_it/shared/widgets/greeting_header.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../../fake_odoo/test_app_harness.dart';

/// Avatars, segmented controls, dialogs and the three whole-screen states.
void main() {
  late AppL10n en;
  late AppL10n ar;

  setUpAll(() async {
    en = await loadL10n();
    ar = await loadL10n('ar');
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: TestSizes.phone,
        child: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  group('AppAvatar initials', () {
    test('two words give the first letter of each', () {
      expect(AppAvatar.initialsOf('Mostafa Bader'), 'MB');
    });

    test('a middle name is skipped in favour of the family name', () {
      // "MK" for Mostafa Kamal and "MB" for Mostafa Bader is the distinction
      // a list of colleagues actually needs.
      expect(AppAvatar.initialsOf('Mostafa Ahmed Kamal'), 'MK');
    });

    test('one word gives its first two letters', () {
      expect(AppAvatar.initialsOf('Administrator'), 'AD');
    });

    test('a one-letter name does not overrun', () {
      expect(AppAvatar.initialsOf('A'), 'A');
    });

    test('Arabic names produce Arabic initials', () {
      // Not transliterated and not dropped: two letters in the script the
      // name is written in.
      expect(AppAvatar.initialsOf('مصطفى بدر'), 'مب');
      expect(AppAvatar.initialsOf('يوسف'), 'يو');
    });

    test(
      'nothing usable falls back to a marker rather than a blank circle',
      () {
        for (final name in <String>['', '   ', '\n\t']) {
          expect(AppAvatar.initialsOf(name), '?', reason: 'for ${name.length}');
        }
      },
    );

    test('extra spacing between words is ignored', () {
      expect(AppAvatar.initialsOf('  Mostafa   Bader  '), 'MB');
    });

    testWidgets('the name is announced, and the initials are not spelled', (
      tester,
    ) async {
      // Two letters read aloud are a puzzle, not a name — and read *after*
      // the name they are noise on every row of a list.
      final handle = tester.ensureSemantics();

      await pump(tester, const AppAvatar(name: 'Mostafa Bader'));

      expect(find.text('MB'), findsOneWidget);
      expect(find.bySemanticsLabel('Mostafa Bader'), findsOneWidget);
      expect(find.bySemanticsLabel('MB'), findsNothing);

      handle.dispose();
    });
  });

  group('AppSegmented', () {
    testWidgets('choosing a segment reports the value, not the index', (
      tester,
    ) async {
      ThemeMode? chosen;
      await pump(
        tester,
        AppSegmented<ThemeMode>(
          value: ThemeMode.system,
          onChanged: (mode) => chosen = mode,
          options: const <SegmentOption<ThemeMode>>[
            SegmentOption(value: ThemeMode.system, label: 'System'),
            SegmentOption(value: ThemeMode.light, label: 'Light'),
            SegmentOption(value: ThemeMode.dark, label: 'Dark'),
          ],
        ),
      );

      await tester.tap(find.text('Dark'));
      await tester.pump();

      expect(chosen, ThemeMode.dark);
    });

    testWidgets('tapping the current choice still reports it', (tester) async {
      // Silence here reads as a dead control to anyone re-confirming a choice.
      var reports = 0;
      await pump(
        tester,
        AppSegmented<int>(
          value: 1,
          onChanged: (_) => reports++,
          options: const <SegmentOption<int>>[
            SegmentOption(value: 1, label: 'One'),
            SegmentOption(value: 2, label: 'Two'),
          ],
        ),
      );

      await tester.tap(find.text('One'));
      await tester.pump();
      expect(reports, 1);
    });

    testWidgets('three long Arabic labels share the width without clipping', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(
          width: 280,
          child: AppSegmented<int>(
            value: 0,
            onChanged: (_) {},
            options: const <SegmentOption<int>>[
              SegmentOption(value: 0, label: 'النظام'),
              SegmentOption(value: 1, label: 'فاتح'),
              SegmentOption(value: 2, label: 'داكن'),
            ],
          ),
        ),
        locale: const Locale('ar'),
      );

      expectNoOverflow(tester);
      expect(find.text('النظام'), findsOneWidget);
      expect(find.text('داكن'), findsOneWidget);
    });

    testWidgets('the group carries a name for a screen reader', (tester) async {
      await pump(
        tester,
        AppSegmented<int>(
          value: 0,
          semanticLabel: 'Credential',
          onChanged: (_) {},
          options: const <SegmentOption<int>>[
            SegmentOption(value: 0, label: 'Password'),
            SegmentOption(value: 1, label: 'API key'),
          ],
        ),
      );

      expect(find.bySemanticsLabel('Credential'), findsOneWidget);
    });
  });

  group('AppCheckRow', () {
    testWidgets('the label is part of the target, not just the box', (
      tester,
    ) async {
      // A 20-px checkbox is a miss on a moving bus; the words beside it are
      // the affordance people actually aim at.
      bool? value;
      await pump(
        tester,
        AppCheckRow(
          label: 'Keep me signed in',
          value: false,
          onChanged: (next) => value = next,
        ),
      );

      await tester.tap(find.text('Keep me signed in'));
      await tester.pump();

      expect(value, isTrue);
    });

    testWidgets('it reports the flipped value, not the current one', (
      tester,
    ) async {
      bool? value;
      await pump(
        tester,
        AppCheckRow(
          label: 'Keep me signed in',
          value: true,
          onChanged: (next) => value = next,
        ),
      );

      await tester.tap(find.text('Keep me signed in'));
      await tester.pump();

      expect(value, isFalse);
    });
  });

  group('GreetingHeader', () {
    test('the greeting follows the clock', () {
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 6)),
        en.greetingMorning,
      );
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 13)),
        en.greetingAfternoon,
      );
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 21)),
        en.greetingEvening,
      );
    });

    test('the boundaries fall on the right side', () {
      // Noon is afternoon and 18:00 is evening — off by one here and the app
      // says "good morning" at lunchtime for exactly one hour a day.
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 11, 59)),
        en.greetingMorning,
      );
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 12)),
        en.greetingAfternoon,
      );
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 17, 59)),
        en.greetingAfternoon,
      );
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29, 18)),
        en.greetingEvening,
      );
    });

    test('midnight is morning, not left over from the day before', () {
      expect(
        GreetingHeader.greetingFor(en, DateTime(2026, 8, 29)),
        en.greetingMorning,
      );
    });

    test('Arabic collapses afternoon and evening on purpose', () {
      // مساء الخير covers both, so the two ARB entries resolving to the same
      // string is correct rather than a copy-paste slip.
      expect(
        GreetingHeader.greetingFor(ar, DateTime(2026, 8, 29, 13)),
        GreetingHeader.greetingFor(ar, DateTime(2026, 8, 29, 21)),
      );
      expect(
        GreetingHeader.greetingFor(ar, DateTime(2026, 8, 29, 6)),
        isNot(GreetingHeader.greetingFor(ar, DateTime(2026, 8, 29, 13))),
      );
    });

    testWidgets('the clock is injectable, so the header is testable at noon', (
      tester,
    ) async {
      await pump(
        tester,
        GreetingHeader(name: 'Administrator', now: DateTime(2026, 8, 29, 21)),
      );

      expect(find.text(en.greetingEvening), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
    });
  });

  group('EmptyStateView', () {
    testWidgets('an action is offered only when there is one to take', (
      tester,
    ) async {
      var acted = 0;
      await pump(
        tester,
        EmptyStateView(
          icon: Icons.inbox_rounded,
          title: 'No assets yet',
          message: 'Register the first one to get started.',
          actionLabel: 'Add asset',
          onAction: () => acted++,
        ),
      );

      await tester.tap(find.text('Add asset'));
      await tester.pump();
      expect(acted, 1);

      await pump(
        tester,
        const EmptyStateView(
          icon: Icons.inbox_rounded,
          title: 'No assets yet',
          message: 'Register the first one to get started.',
        ),
      );
      expect(find.text('Add asset'), findsNothing);
    });

    testWidgets('it scrolls, so pull-to-refresh works on an empty list', (
      tester,
    ) async {
      // A non-scrollable empty state makes the gesture inert exactly when the
      // user most wants to try again.
      await pump(
        tester,
        const EmptyStateView(
          icon: Icons.inbox_rounded,
          title: 'No assets yet',
          message: 'Register the first one to get started.',
        ),
      );

      expect(find.byType(Scrollable), findsWidgets);
    });
  });

  group('FailureView', () {
    testWidgets('every failure states the cause and what to do about it', (
      tester,
    ) async {
      await pump(
        tester,
        FailureView(
          failure: const Failure(kind: FailureKind.noInternet),
          onRetry: () {},
        ),
      );

      expect(find.text(en.errorNoInternetTitle), findsOneWidget);
      expect(find.text(en.errorNoInternetBody), findsOneWidget);
      expect(find.text(en.errorNoInternetFix), findsOneWidget);
    });

    testWidgets('nothing technical reaches the screen', (tester) async {
      await pump(
        tester,
        FailureView(
          failure: const Failure(
            kind: FailureKind.unknown,
            technicalDetails: 'XmlRpcFault(faultCode: 1, #0 main.dart:42)',
          ),
          onRetry: () {},
        ),
      );

      expect(find.textContaining('XmlRpcFault'), findsNothing);
      expect(find.textContaining('#0'), findsNothing);
      expect(find.textContaining('.dart'), findsNothing);
    });

    testWidgets('a retry button appears only when retrying could help', (
      tester,
    ) async {
      await pump(
        tester,
        const FailureView(failure: Failure(kind: FailureKind.timeout)),
      );

      // No handler bound, so no button: an action that does nothing is worse
      // than none.
      expect(find.text(en.actionRetry), findsNothing);
    });
  });

  group('LoadingView', () {
    testWidgets('a spinner alone, or a spinner with a reason', (tester) async {
      await pump(tester, const LoadingView());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pump(tester, const LoadingView(message: 'Checking the server…'));
      expect(find.text('Checking the server…'), findsOneWidget);
    });
  });

  group('AppConfirmDialog', () {
    testWidgets('confirming returns true and dismissing returns false', (
      tester,
    ) async {
      late bool result;

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    result = await AppConfirmDialog.show(
                      context,
                      title: 'Sign out of Sijil IT?',
                      message: 'Your stored credential is removed.',
                      confirmLabel: 'Sign out',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of Sijil IT?'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.actionCancel));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('a long Arabic message scrolls instead of clipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('ar'),
          size: TestSizes.smallPhone,
          textScale: AppTextScale.max,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => AppConfirmDialog.show(
                    context,
                    title: ar.assetDeleteConfirm,
                    message: ar.assetDeleteBody,
                    confirmLabel: ar.actionDelete,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expectNoOverflow(tester);
    });
  });
}
