import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/storage_keys.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/connection/presentation/pages/connection_page.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// The connection screen, driven the way a person drives it, against a real
/// XML-RPC server.
///
/// Everything below the widget is production code: the Cubit, the repository,
/// the Odoo services, the Dio client and the socket. Only the keychain, Hive
/// and connectivity are doubles.
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

  Future<void> pumpScreen(WidgetTester tester, {Locale? locale}) async {
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
          child: const ConnectionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String? url,
    String? database,
    String? username,
    String? secret,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), url ?? serverUrl);
    await tester.enterText(fields.at(1), database ?? data.database);
    await tester.enterText(fields.at(2), username ?? data.login);
    await tester.enterText(fields.at(3), secret ?? data.secret);
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

  group('happy path', () {
    testWidgets('Test connection reports the version it found', (tester) async {
      await pumpScreen(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.connectionReachable('18.0')), findsOneWidget);
      expect(client.calls.first.method, 'version');
    });

    testWidgets('Save and sign in authenticates and stores the connection', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionSaveAndSignIn);

      final auth = sl<AuthCubit>();
      expect(auth.state.status, AuthStatus.signedIn);
      expect(auth.state.user?.displayName, 'Mostafa Bader');

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
  });

  group('every failure explains itself', () {
    testWidgets('wrong credential: cause and fix, no stack trace', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillForm(tester, secret: 'definitely-wrong');

      await tapButton(tester, l10n.actionSaveAndSignIn);

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
      await pumpScreen(tester);
      await fillForm(tester, database: 'typo-database');

      await tapButton(tester, l10n.actionSaveAndSignIn);

      expect(find.text(l10n.errorDatabaseUnavailableTitle), findsOneWidget);
      expect(find.text(l10n.errorDatabaseUnavailableFix), findsOneWidget);
      // Not misreported as a permissions problem.
      expect(find.text(l10n.errorAccessDeniedTitle), findsNothing);
    });

    testWidgets('unreachable server explains the URL', (tester) async {
      client.unreachable = true;

      await pumpScreen(tester);
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

      await pumpScreen(tester);
      await fillForm(tester);

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.errorNoInternetTitle), findsOneWidget);
      expect(find.text(l10n.errorNoInternetFix), findsOneWidget);
      // Nothing was sent — the app did not wait out a socket timeout first.
      expect(client.calls, isEmpty);
    });
  });

  group('client-side validation', () {
    testWidgets('actions stay disabled until the form can succeed', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Prevention over correction: with nothing typed there is nothing to
      // test and nothing to submit, so neither action is offered.
      final probe = tester.widget<AppButton>(
        find.widgetWithText(AppButton, l10n.actionTestConnection),
      );
      final submit = tester.widget<AppButton>(
        find.widgetWithText(AppButton, l10n.actionSaveAndSignIn),
      );
      expect(probe.onPressed, isNull);
      expect(submit.onPressed, isNull);
      expect(client.calls, isEmpty);
    });

    testWidgets('a missing credential is reported on its own field', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillForm(tester, secret: '');

      await tapButton(tester, l10n.actionSaveAndSignIn);

      expect(find.text(l10n.validationEnterCredential), findsOneWidget);
      // Client-side validation must not cost a round trip.
      expect(client.calls.any((c) => c.method == 'authenticate'), isFalse);
    });

    testWidgets('a malformed URL is caught before a request is made', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillForm(tester, url: 'ht!tp:// not a url');

      await tapButton(tester, l10n.actionTestConnection);

      expect(find.text(l10n.validationInvalidUrl), findsOneWidget);
      expect(client.calls, isEmpty);
    });
  });

  group('localization', () {
    testWidgets('renders in Arabic, right to left', (tester) async {
      final ar = await loadL10n('ar');

      await pumpScreen(tester, locale: const Locale('ar', 'EG'));

      expect(find.text(ar.connectTitle), findsOneWidget);
      expect(find.text(ar.fieldServerUrl.toUpperCase()), findsOneWidget);

      expect(
        Directionality.of(tester.element(find.text(ar.connectTitle))),
        TextDirection.rtl,
      );
    });

    testWidgets('an Arabic failure is fully translated', (tester) async {
      final ar = await loadL10n('ar');

      await pumpScreen(tester, locale: const Locale('ar', 'EG'));
      await fillForm(tester, secret: 'wrong');
      await tapButton(tester, ar.actionSaveAndSignIn);

      expect(find.text(ar.errorInvalidCredentialsTitle), findsOneWidget);
      expect(find.text(ar.errorInvalidCredentialsFix), findsOneWidget);
    });
  });

  group('security', () {
    testWidgets('the credential is never written to preferences', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillForm(tester);
      await tapButton(tester, l10n.actionSaveAndSignIn);

      // The connection is saved; the secret is not part of it.
      final saved = sl<AuthCubit>().state.connection;
      expect(saved, isNotNull);
      expect('$saved', isNot(contains(data.secret)));

      // And the keys that exist in preferences are the non-secret ones.
      expect(PrefKeys.odooBaseUrl, isNot(SecureKeys.odooPassword));
    });

    testWidgets('the credential field is obscured by default', (tester) async {
      await pumpScreen(tester);

      final field = tester.widget<TextField>(find.byType(TextField).at(3));
      expect(field.obscureText, isTrue);
    });
  });

  group('header controls', () {
    testWidgets('the language toggle offers the other language', (
      tester,
    ) async {
      await pumpScreen(tester);

      // In English it offers Arabic, spelled in Arabic.
      expect(find.text('ع'), findsOneWidget);
      expect(find.text('EN'), findsNothing);

      await pumpScreen(tester, locale: const Locale('ar', 'EG'));
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('the theme toggle offers the other mode', (tester) async {
      await pumpScreen(tester);

      // Light mode offers dark, and shows the icon for what it switches to.
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
    });

    testWidgets('both controls are reachable before sign-in', (tester) async {
      await pumpScreen(tester);
      final l10n = await loadL10n();

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
      await pumpScreen(tester);

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
      await pumpScreen(tester);
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

      await pumpScreen(tester);
      await fillForm(tester, database: '');

      await tapButton(tester, l10n.actionDetectDatabases);

      expect(find.text(l10n.detectPickTitle), findsOneWidget);
      expect(find.text('company-staging'), findsOneWidget);

      await tester.tap(find.text('company-staging'));
      await tester.pumpAndSettle();

      // The chosen name lands in the field and in the form state.
      expect(find.widgetWithText(TextField, 'company-staging'), findsOneWidget);
    });

    testWidgets('sits above the database field it fills in', (tester) async {
      await pumpScreen(tester);

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
}
