import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/storage_keys.dart';
import 'package:sijil_it/core/network/odoo/odoo_connection.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/auth/presentation/pages/login_page.dart';
import 'package:sijil_it/features/connection/presentation/pages/connection_page.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// The two first-run screens, driven the way a person drives them, against a
/// real XML-RPC server.
///
/// Everything below the widget is production code: the Cubits, the repository,
/// the Odoo services, the Dio client and the socket. Only the keychain, Hive
/// and connectivity are doubles.
///
/// The screens are pumped one at a time rather than through the router,
/// because the router is not what moves between them — `AuthCubit` is, and
/// asserting on its state is asserting on the thing that actually decides.
void main() {
  late FakeOdooData data;
  late InProcessOdooClient client;
  late AppL10n l10n;

  /// Any URL works: the in-process client routes by endpoint path, not host.
  const serverUrl = 'https://company.odoo.com';

  setUp(() async {
    data = FakeOdooData.seeded();
    client = await configureTestDependencies(data: data);
    l10n = await loadL10n();
  });

  tearDown(() async => sl.reset());

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale ?? const Locale('en'),
        size: TestSizes.phone,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: sl<AuthCubit>()),
            BlocProvider<AppSettingsCubit>(
              create: (_) => AppSettingsCubit(sl<AppPreferences>()),
            ),
          ],
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps a button that triggers a network call, then settles the UI.
  Future<void> tapButton(
    WidgetTester tester,
    String label, {
    Duration settle = const Duration(milliseconds: 600),
  }) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pump();
    await actAndSettle(tester, () => tester.tap(finder), settle: settle);
  }

  // ── Screen one: which server ───────────────────────────────────────────

  group('the server screen', () {
    Future<void> pumpConnection(WidgetTester tester, {Locale? locale}) =>
        pumpScreen(tester, const ConnectionPage(), locale: locale);

    Future<void> fillForm(
      WidgetTester tester, {
      String? url,
      String? database,
    }) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), url ?? serverUrl);
      await tester.enterText(fields.at(1), database ?? data.database);
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the server and the database, and nothing else', (
      tester,
    ) async {
      // The split itself. A credential field here would put a password on the
      // first screen a user ever sees, before anything has established which
      // server is about to receive it.
      await pumpConnection(tester);

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text(l10n.fieldServerUrl.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.fieldDatabase.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.fieldCredential.toUpperCase()), findsNothing);
      expect(find.text(l10n.fieldUsername.toUpperCase()), findsNothing);
    });

    testWidgets('Test connection reports the version it found', (tester) async {
      await pumpConnection(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.connectionReachable('18.0')), findsOneWidget);
      expect(client.calls.first.method, 'version');
    });

    testWidgets('Continue hands the details on without signing in', (
      tester,
    ) async {
      await pumpConnection(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionContinue);

      final auth = sl<AuthCubit>();
      expect(auth.state.status, AuthStatus.signedOut);
      expect(auth.state.connection?.database, data.database);
      expect(auth.state.connection?.baseUrl.host, 'company.odoo.com');

      // It is a step in a form, not a commitment: nothing was authenticated
      // and nothing was written, because neither is knowable yet.
      expect(client.calls, isEmpty);
      expect(auth.state.isSignedIn, isFalse);
    });

    testWidgets('Continue stays disabled until both fields can succeed', (
      tester,
    ) async {
      await pumpConnection(tester);

      AppButton button(String label) =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, label));

      expect(button(l10n.actionContinue).onPressed, isNull);
      expect(button(l10n.actionTestConnection).onPressed, isNull);

      // A URL alone is not enough — Odoo needs to be told which database.
      await fillForm(tester, database: '');
      expect(button(l10n.actionContinue).onPressed, isNull);

      await fillForm(tester);
      expect(button(l10n.actionContinue).onPressed, isNotNull);
    });

    testWidgets('a malformed URL is caught before a request is made', (
      tester,
    ) async {
      await pumpConnection(tester);
      await fillForm(tester, url: 'ht!tp:// not a url');

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.validationInvalidUrl), findsOneWidget);
      expect(client.calls, isEmpty);
    });

    testWidgets('http names the scheme rather than blaming the address', (
      tester,
    ) async {
      await pumpConnection(tester);
      await fillForm(tester, url: 'http://company.odoo.com');

      await tapButton(tester, l10n.actionContinue);

      expect(find.text(l10n.validationHttpsRequired), findsOneWidget);
      expect(find.text(l10n.validationInvalidUrl), findsNothing);
      expect(sl<AuthCubit>().state.status, isNot(AuthStatus.signedOut));
    });

    testWidgets('unreachable server explains the URL', (tester) async {
      client.unreachable = true;

      await pumpConnection(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.errorServerUnreachableTitle), findsOneWidget);
      expect(find.text(l10n.errorServerUnreachableFix), findsOneWidget);
    });

    testWidgets('offline is reported before any request is attempted', (
      tester,
    ) async {
      client = await configureTestDependencies(
        data: data,
        network: FakeNetworkInfo(connected: false),
      );

      await pumpConnection(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.errorNoInternetTitle), findsOneWidget);
      expect(find.text(l10n.errorNoInternetFix), findsOneWidget);
      // Nothing was sent — the app did not wait out a socket timeout first.
      expect(client.calls, isEmpty);
    });

    testWidgets('renders in Arabic, right to left', (tester) async {
      final ar = await loadL10n('ar');

      await pumpConnection(tester, locale: const Locale('ar', 'EG'));

      expect(find.text(ar.connectTitle), findsOneWidget);
      expect(find.text(ar.fieldServerUrl.toUpperCase()), findsOneWidget);

      expect(
        Directionality.of(tester.element(find.text(ar.connectTitle))),
        TextDirection.rtl,
      );
    });

    group('header controls', () {
      testWidgets('the language toggle offers the other language', (
        tester,
      ) async {
        await pumpConnection(tester);

        // In English it offers Arabic, spelled in Arabic.
        expect(find.text('ع'), findsOneWidget);
        expect(find.text('EN'), findsNothing);

        await pumpConnection(tester, locale: const Locale('ar', 'EG'));
        expect(find.text('EN'), findsOneWidget);
      });

      testWidgets('the theme toggle offers the other mode', (tester) async {
        await pumpConnection(tester);

        // Light mode offers dark, and shows the icon for what it switches to.
        expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
        expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
      });

      testWidgets('both controls are reachable before sign-in', (tester) async {
        await pumpConnection(tester);

        expect(
          find.byTooltip(l10n.tooltipToggleLanguage),
          findsOneWidget,
          reason: 'Settings is behind a sign-in, so language must be here.',
        );
        expect(find.byTooltip(l10n.tooltipToggleTheme), findsOneWidget);
      });
    });

    group('detect databases', () {
      testWidgets('is disabled until a server URL is entered', (tester) async {
        await pumpConnection(tester);

        final button = tester.widget<AppButton>(
          find.widgetWithText(AppButton, l10n.actionDetectDatabases),
        );
        expect(button.onPressed, isNull);
        expect(client.calls, isEmpty);
      });

      testWidgets('explains that most servers keep the list private', (
        tester,
      ) async {
        // The seeded instance has listing disabled, like a real production one.
        await pumpConnection(tester);
        await fillForm(tester);

        await tapButton(tester, l10n.actionDetectDatabases);

        expect(find.text(l10n.detectUnsupportedTitle), findsOneWidget);
        expect(find.text(l10n.detectUnsupportedBody), findsOneWidget);
        // Framed as information, not as a failure.
        expect(find.text(l10n.errorServerUnreachableTitle), findsNothing);
      });

      testWidgets('offers a picker when the server does publish a list', (
        tester,
      ) async {
        final listing = FakeOdooData(
          serverVersion: '18.0',
          database: 'company-production',
          login: 'admin@company.com',
          secret: 'test-api-key',
          userId: 2,
          installedModels: const {},
          records: const {},
          allowDatabaseListing: true,
          databases: const ['company-production', 'company-staging'],
        );
        client = await configureTestDependencies(data: listing);

        await pumpConnection(tester);
        await fillForm(tester, database: '');

        await tapButton(tester, l10n.actionDetectDatabases);

        expect(find.text(l10n.detectPickTitle), findsOneWidget);
        expect(find.text('company-staging'), findsOneWidget);

        await tester.tap(find.text('company-staging'));
        await tester.pumpAndSettle();

        // The chosen name lands in the field and in the form state.
        expect(
          find.widgetWithText(TextField, 'company-staging'),
          findsOneWidget,
        );
      });

      testWidgets('sits above the database field it fills in', (tester) async {
        await pumpConnection(tester);

        final buttonY = tester
            .getTopLeft(
              find.widgetWithText(AppButton, l10n.actionDetectDatabases),
            )
            .dy;
        final fieldY = tester
            .getTopLeft(find.text(l10n.fieldDatabase.toUpperCase()))
            .dy;

        expect(
          buttonY,
          lessThan(fieldY),
          reason: 'The action comes before the field, matching the task order.',
        );
      });
    });
  });

  // ── Screen two: who you are ────────────────────────────────────────────

  group('the sign-in screen', () {
    /// Arrives the way the user does: through Continue on the server screen.
    Future<void> pumpLogin(
      WidgetTester tester, {
      Locale? locale,
      String? database,
      String? username,
    }) async {
      sl<AuthCubit>().useConnection(
        OdooConnection(
          baseUrl: Uri.parse(serverUrl),
          database: database ?? data.database,
          username: username ?? '',
        ),
      );
      await pumpScreen(tester, const LoginPage(), locale: locale);
    }

    Future<void> fillForm(
      WidgetTester tester, {
      String? username,
      String? secret,
    }) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), username ?? data.login);
      await tester.enterText(fields.at(1), secret ?? data.secret);
      await tester.pumpAndSettle();
    }

    testWidgets('shows which server it is about to sign into', (tester) async {
      await pumpLogin(tester);

      expect(find.text('company.odoo.com'), findsOneWidget);
      expect(find.text(data.database), findsOneWidget);
    });

    testWidgets('Sign in authenticates and stores the connection', (
      tester,
    ) async {
      await pumpLogin(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionSignIn);

      final auth = sl<AuthCubit>();
      expect(auth.state.status, AuthStatus.signedIn);
      expect(auth.state.user?.displayName, 'Mostafa Bader');
      expect(auth.state.connection?.username, data.login);

      // Capabilities were probed during sign-in, so the shell already knows
      // which tabs to show.
      expect(auth.state.capabilities.hasMaintenance, isTrue);
      expect(auth.state.capabilities.hasHrEmployees, isTrue);

      // The credential went through common.authenticate, never a URL.
      expect(client.calls.any((c) => c.method == 'authenticate'), isTrue);
      for (final call in client.calls) {
        expect(call.path, isNot(contains(data.secret)));
      }
    });

    testWidgets('the username comes back filled in after a sign-out', (
      tester,
    ) async {
      // Signing out keeps the connection, and the connection knows who was
      // using it. Making them retype it is the kind of small friction that
      // reads as the app having forgotten them.
      await pumpLogin(tester, username: data.login);

      expect(find.widgetWithText(TextField, data.login), findsOneWidget);
    });

    testWidgets('back returns to the server screen with the URL kept', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.byTooltip(l10n.loginBackToServer));
      await tester.pumpAndSettle();

      final auth = sl<AuthCubit>();
      expect(auth.state.status, AuthStatus.configuring);
      expect(
        auth.state.connection?.database,
        data.database,
        reason:
            'Going back to fix one character in the URL must not empty the '
            'form — the old "forget the connection" behaviour did exactly '
            'that.',
      );
    });

    testWidgets('the system back gesture does the same thing', (tester) async {
      // Nothing is on the navigator below this screen, so an unhandled pop
      // closes the app — a back button that works beside a back swipe that
      // quits is worse than neither.
      await pumpLogin(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(sl<AuthCubit>().state.status, AuthStatus.configuring);
    });

    group('every failure explains itself', () {
      testWidgets('wrong credential: cause and fix, no stack trace', (
        tester,
      ) async {
        await pumpLogin(tester);
        await fillForm(tester, secret: 'definitely-wrong');

        await tapButton(tester, l10n.actionSignIn);

        expect(find.text(l10n.errorInvalidCredentialsTitle), findsOneWidget);
        expect(find.text(l10n.errorInvalidCredentialsBody), findsOneWidget);
        expect(find.text(l10n.errorInvalidCredentialsFix), findsOneWidget);

        // Nothing technical leaks into the UI.
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('odoo.exceptions'), findsNothing);
        expect(find.textContaining('#0'), findsNothing);

        expect(sl<AuthCubit>().state.status, AuthStatus.signedOut);
      });

      testWidgets('wrong database points at the database, not the admin', (
        tester,
      ) async {
        await pumpLogin(tester, database: 'typo-database');
        await fillForm(tester);

        await tapButton(tester, l10n.actionSignIn);

        expect(find.text(l10n.errorDatabaseUnavailableTitle), findsOneWidget);
        expect(find.text(l10n.errorDatabaseUnavailableFix), findsOneWidget);
        // Not misreported as a permissions problem.
        expect(find.text(l10n.errorAccessDeniedTitle), findsNothing);
      });

      testWidgets('an Arabic failure is fully translated', (tester) async {
        final ar = await loadL10n('ar');

        await pumpLogin(tester, locale: const Locale('ar', 'EG'));
        await fillForm(tester, secret: 'wrong');
        await tapButton(tester, ar.actionSignIn);

        expect(find.text(ar.errorInvalidCredentialsTitle), findsOneWidget);
        expect(find.text(ar.errorInvalidCredentialsFix), findsOneWidget);
      });
    });

    group('client-side validation', () {
      testWidgets('a missing credential is reported on its own field', (
        tester,
      ) async {
        await pumpLogin(tester);
        await fillForm(tester, secret: '');

        await tapButton(tester, l10n.actionSignIn);

        expect(find.text(l10n.validationEnterCredential), findsOneWidget);
        // Client-side validation must not cost a round trip.
        expect(client.calls.any((c) => c.method == 'authenticate'), isFalse);
      });

      testWidgets('a missing username is reported on its own field', (
        tester,
      ) async {
        await pumpLogin(tester);
        await fillForm(tester, username: '');

        await tapButton(tester, l10n.actionSignIn);

        expect(find.text(l10n.validationEnterUsername), findsOneWidget);
        expect(client.calls.any((c) => c.method == 'authenticate'), isFalse);
      });

      testWidgets('the message clears as soon as the field is corrected', (
        tester,
      ) async {
        await pumpLogin(tester);
        await fillForm(tester, secret: '');
        await tapButton(tester, l10n.actionSignIn);
        expect(find.text(l10n.validationEnterCredential), findsOneWidget);

        await tester.enterText(find.byType(TextField).at(1), data.secret);
        await tester.pumpAndSettle();

        expect(find.text(l10n.validationEnterCredential), findsNothing);
      });
    });

    group('security', () {
      testWidgets('the credential is never written to preferences', (
        tester,
      ) async {
        await pumpLogin(tester);
        await fillForm(tester);
        await tapButton(tester, l10n.actionSignIn);

        // The connection is saved; the secret is not part of it.
        final saved = sl<AuthCubit>().state.connection;
        expect(saved, isNotNull);
        expect('$saved', isNot(contains(data.secret)));

        // And the keys that exist in preferences are the non-secret ones.
        expect(PrefKeys.odooBaseUrl, isNot(SecureKeys.odooPassword));
      });

      testWidgets('the credential field is obscured by default', (
        tester,
      ) async {
        await pumpLogin(tester);

        final field = tester.widget<TextField>(find.byType(TextField).at(1));
        expect(field.obscureText, isTrue);
      });
    });
  });
}
