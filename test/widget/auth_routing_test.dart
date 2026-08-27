import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/router/app_router.dart';
import 'package:sijil_it/app/theme/app_theme.dart';
import 'package:sijil_it/core/network/odoo/odoo_connection.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/auth/presentation/pages/login_page.dart';
import 'package:sijil_it/features/connection/presentation/pages/connection_page.dart';
import 'package:sijil_it/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// Where each auth state puts the user, through the real router.
///
/// The two first-run screens do not navigate. They move `AuthCubit` and let
/// `AppRouter`'s redirect place the user, which keeps the routing table in one
/// file — but it also means a screen can be correct, its Cubit can be correct,
/// and the button can still do nothing, because the two disagree about where
/// that state belongs.
///
/// That is not hypothetical: "Continue" emitted `signedOut` from the server
/// screen, and the redirect's `signedOut` arm accepted *either* auth screen as
/// a resting place — so it declined to move and the button was inert. Every
/// widget test passed, because none of them had a router in it.
void main() {
  late FakeOdooData data;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
  });

  tearDown(() async => sl.reset());

  OdooConnection connectionFor(FakeOdooData data, {String username = ''}) =>
      OdooConnection(
        baseUrl: Uri.parse('https://company.odoo.com'),
        database: data.database,
        username: username,
      );

  /// The whole app, on its real routing table.
  Future<void> pumpApp(WidgetTester tester) async {
    final auth = sl<AuthCubit>();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: auth),
          BlocProvider<AppSettingsCubit>(
            create: (_) => AppSettingsCubit(sl<AppPreferences>()),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          supportedLocales: AppSettingsCubit.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          theme: AppTheme.light,
          routerConfig: AppRouter.create(auth: auth),
          builder: (context, routed) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: TestSizes.phone),
            child: routed ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh install lands on the server screen', (tester) async {
    await sl<AuthCubit>().restore();
    await pumpApp(tester);

    expect(find.byType(ConnectionPage), findsOneWidget);
  });

  testWidgets('Continue moves the user to sign-in', (tester) async {
    await sl<AuthCubit>().restore();
    await pumpApp(tester);

    sl<AuthCubit>().useConnection(connectionFor(data));
    await tester.pumpAndSettle();

    expect(
      find.byType(LoginPage),
      findsOneWidget,
      reason: 'the redirect has to move — the screen does not navigate itself',
    );
    expect(find.byType(ConnectionPage), findsNothing);
  });

  testWidgets('back from sign-in returns to the server screen', (tester) async {
    await sl<AuthCubit>().restore();
    await pumpApp(tester);

    sl<AuthCubit>().useConnection(connectionFor(data));
    await tester.pumpAndSettle();

    await sl<AuthCubit>().editConnection();
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets(
    'the round trip is not one-way — forward still works after back',
    (tester) async {
      // A redirect that moves on the first transition and then wedges is the
      // shape this whole indirection is prone to.
      await sl<AuthCubit>().restore();
      await pumpApp(tester);

      for (var lap = 0; lap < 2; lap++) {
        sl<AuthCubit>().useConnection(connectionFor(data));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget, reason: 'lap $lap');

        await sl<AuthCubit>().editConnection();
        await tester.pumpAndSettle();
        expect(find.byType(ConnectionPage), findsOneWidget, reason: 'lap $lap');
      }
    },
  );

  testWidgets('a saved connection with no session opens sign-in directly', (
    tester,
  ) async {
    // The returning user: the server is on file, the session is not.
    await sl<AuthCubit>().signIn(
      connection: connectionFor(data, username: data.login),
      secret: data.secret,
    );
    await sl<AuthCubit>().signOut();

    await pumpApp(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      sl<AuthCubit>().state.connection?.username,
      data.login,
      reason: 'and it knows who they were, so the field comes back filled in',
    );
  });

  testWidgets('signing in leaves the auth screens for the dashboard', (
    tester,
  ) async {
    await sl<AuthCubit>().restore();
    await pumpApp(tester);

    sl<AuthCubit>().useConnection(connectionFor(data));
    await tester.pumpAndSettle();

    await sl<AuthCubit>().signIn(
      connection: connectionFor(data, username: data.login),
      secret: data.secret,
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(ConnectionPage), findsNothing);
  });

  testWidgets('a rejected credential keeps the user on the sign-in screen', (
    tester,
  ) async {
    // Not bounced back to the server screen: the server was fine, and losing
    // the typed username to prove it would be its own small insult.
    await sl<AuthCubit>().restore();
    await pumpApp(tester);

    sl<AuthCubit>().useConnection(connectionFor(data));
    await tester.pumpAndSettle();

    await sl<AuthCubit>().signIn(
      connection: connectionFor(data, username: data.login),
      secret: 'definitely-wrong',
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(sl<AuthCubit>().state.status, AuthStatus.signedOut);
  });

  testWidgets('sign-in is the only auth screen that animates', (tester) async {
    // Splash and the server screen are arrivals the user did not ask for.
    // Sign-in is one step deeper in a form they are filling in, so it moves
    // like every other forward navigation in the app.
    await sl<AuthCubit>().restore();
    await pumpApp(tester);

    // The server screen arrives without one, so a SlideTransition found later
    // came from the login route and not from something ambient.
    expect(
      find.ancestor(
        of: find.byType(ConnectionPage),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );

    sl<AuthCubit>().useConnection(connectionFor(data));
    // Two: the first delivers the Cubit's stream event to the redirect, the
    // second builds the frame the new route starts its transition on.
    await tester.pump();
    await tester.pump();

    // Mid-flight: the page is mounted and not yet where it will end up.
    await tester.pump(const Duration(milliseconds: 40));
    final slide = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.byType(LoginPage),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(
      slide.position.value.dx,
      isNot(0),
      reason: 'still at rest here means the transition was dropped',
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
