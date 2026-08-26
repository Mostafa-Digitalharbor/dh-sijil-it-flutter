import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// Every failure that claims to offer a way out must actually offer one.
///
/// `FailurePresenter` decides the wording *and* the action for each
/// [FailureKind]: an expired session is told to sign in again, a bad server
/// URL is told to fix the connection. Those sentences are promises. Rendering
/// them above nothing is worse than saying nothing, because the user reads an
/// instruction and then hunts the screen for the control it names.
///
/// That is precisely what shipped: twelve screens construct a [FailureView],
/// all of them passed `onRetry`, none passed the other two, and the widget
/// quietly rendered no button when a handler was null. The tests below pin the
/// promise rather than the plumbing — they assert that a *user* can act, not
/// that a particular callback was wired.
void main() {
  late AppL10n l10n;
  late FakeOdooData data;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
  });

  tearDown(() async => sl.reset());

  /// Renders one failure inside the providers the real app supplies.
  Future<void> pump(WidgetTester tester, Failure failure) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: BlocProvider<AuthCubit>.value(
          value: sl<AuthCubit>(),
          child: Scaffold(body: FailureView(failure: failure)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a failure that names an action offers it', () {
    // One entry per FailureKind whose presenter promises something. Retry is
    // excluded on purpose: only the calling screen knows what to re-run, so it
    // stays the caller's job and has always been passed.
    final promised = <FailureKind, String>{
      FailureKind.sessionExpired: 'session expiry',
      FailureKind.invalidCredentials: 'wrong credentials',
      FailureKind.serverUnreachable: 'unreachable server',
      FailureKind.notAnOdooServer: 'not an Odoo server',
      FailureKind.databaseUnavailable: 'wrong database',
    };

    for (final entry in promised.entries) {
      testWidgets('${entry.value} — the button the copy names exists', (
        tester,
      ) async {
        await pump(tester, Failure(kind: entry.key));

        final button = find.byType(AppButton);
        expect(
          button,
          findsOneWidget,
          reason:
              'The copy for ${entry.value} tells the user to act, and the '
              'screen gave them nothing to act with.',
        );
        expect(
          tester.widget<AppButton>(button).onPressed,
          isNotNull,
          reason: 'The button rendered but does nothing when pressed.',
        );
      });
    }
  });

  group('the action actually does something', () {
    testWidgets('an expired session signs out, so the router can route', (
      tester,
    ) async {
      await signInForTest(data);
      expect(sl<AuthCubit>().state.isSignedIn, isTrue);

      await pump(tester, const Failure(kind: FailureKind.sessionExpired));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      // Not asserting on navigation: this widget deliberately does not know
      // where the user lands. It drops the session, and the router — which is
      // already listening to AuthCubit — decides. Asserting on the route here
      // would couple a shared widget to the app's routing table.
      expect(
        sl<AuthCubit>().state.isSignedIn,
        isFalse,
        reason: 'The session survived, so the user is still stuck.',
      );
    });

    testWidgets('a bad server URL returns to first-run, not just sign-out', (
      tester,
    ) async {
      await signInForTest(data);

      await pump(tester, const Failure(kind: FailureKind.notAnOdooServer));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      // The distinction matters: signing out keeps the stored server, which is
      // the one thing known to be wrong here. Only forgetting the connection
      // gets the user back to the screen that can fix it.
      expect(
        sl<AuthCubit>().state.status,
        AuthStatus.unconfigured,
        reason:
            'Signing out alone would send the user back to a login screen for '
            'the very server that could not be reached.',
      );
    });
  });

  group('the defaults are overridable and safe', () {
    testWidgets('an explicit handler wins over the default', (tester) async {
      var called = false;

      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: BlocProvider<AuthCubit>.value(
            value: sl<AuthCubit>(),
            child: Scaffold(
              body: FailureView(
                failure: const Failure(kind: FailureKind.sessionExpired),
                onSignIn: () => called = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(
        sl<AuthCubit>().state.isSignedIn,
        isFalse,
        reason: 'Never signed in; the default must not have run as well.',
      );
    });

    testWidgets('no AuthCubit in scope costs the button, not the frame', (
      tester,
    ) async {
      // A screen pumped in isolation, as a dozen tests in this suite do. The
      // fallback must degrade rather than throw: losing a button is a missing
      // affordance, and throwing is a blank red screen where the error message
      // was supposed to be.
      await tester.pumpWidget(
        const TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: FailureView(
              failure: Failure(kind: FailureKind.sessionExpired),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.errorSessionExpiredTitle), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });
  });
}
