import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_theme.dart';
import 'package:sijil_it/core/network/connectivity/network_info.dart';
import 'package:sijil_it/core/network/odoo/odoo_connection.dart';
import 'package:sijil_it/core/network/xmlrpc/xml_rpc_client.dart';
import 'package:sijil_it/core/security/credential_vault.dart';
import 'package:sijil_it/core/storage/cache/cache_store.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import 'fake_odoo_data.dart';
import 'test_doubles.dart';

/// Builds the same object graph the app uses, with the three platform-bound
/// pieces swapped for in-memory doubles.
///
/// This is the payoff of registering everything against an interface: a widget
/// test gets the *real* repositories, the *real* Odoo services and the *real*
/// Dio client over a *real* socket, while the keychain, Hive and connectivity
/// — the only parts that need a device — become plain Dart objects.
Future<InProcessOdooClient> configureTestDependencies({
  FakeOdooData? data,
  FakeNetworkInfo? network,
  Map<String, Object> preferences = const {},
}) async {
  await sl.reset();

  SharedPreferences.setMockInitialValues(preferences);

  sl.registerLazySingleton<CredentialVault>(InMemoryVault.new);
  sl.registerLazySingleton<CacheStore>(InMemoryCache.new);
  sl.registerSingleton<AppPreferences>(await AppPreferences.create());
  sl.registerLazySingleton<NetworkInfo>(() => network ?? FakeNetworkInfo());

  final client = InProcessOdooClient(data ?? FakeOdooData.seeded());
  sl.registerSingleton<XmlRpcClient>(client);

  // The real graph, on top of the doubles above. Nothing about repositories,
  // use cases or Cubits is re-declared here, so a widget test cannot drift from
  // what the app actually wires.
  registerAppGraph();

  return client;
}

/// Wraps a widget in the same theme, localization and providers the real app
/// gives it — so a widget test sees the production `TextStyle`s and the
/// production `AppL10n`, not defaults.
class TestApp extends StatelessWidget {
  const TestApp({
    required this.child,
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.light,
    this.size,
    this.textScale = 1.0,
    super.key,
  });

  final Widget child;
  final Locale locale;
  final ThemeMode themeMode;

  /// Simulates a device size, for responsive and overflow assertions.
  final Size? size;

  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppSettingsCubit.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              size: size ?? media.size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// [TestApp] with a router behind it.
///
/// Screens that finish by navigating — the assign and return workflows call
/// `context.go` on success — assert `No GoRouter found in context` inside a
/// plain [TestApp]. This gives them one: the screen under test lives at `/`,
/// and any other destination resolves to a blank page, because these tests are
/// about what reached Odoo rather than about where the user landed.
class RoutedTestApp extends StatelessWidget {
  RoutedTestApp({
    required this.child,
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.light,
    this.size,
    this.textScale = 1.0,
    super.key,
  });

  final Widget child;
  final Locale locale;
  final ThemeMode themeMode;
  final Size? size;
  final double textScale;

  late final GoRouter _router = GoRouter(
    routes: <RouteBase>[GoRoute(path: '/', builder: (_, __) => child)],
    errorBuilder: (_, __) => const Scaffold(body: SizedBox.shrink()),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppSettingsCubit.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      builder: (context, routed) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            size: size ?? media.size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: routed ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Loads the generated localizations outside a widget, for asserting on the
/// exact strings a screen should show.
Future<AppL10n> loadL10n([String languageCode = 'en']) =>
    AppL10n.delegate.load(Locale(languageCode));

/// Common phone and tablet sizes to run a layout assertion across.
abstract final class TestSizes {
  static const Size phone = Size(390, 844);
  static const Size smallPhone = Size(320, 568);
  static const Size tablet = Size(834, 1194);
  static const Size landscape = Size(844, 390);

  static const List<(String, Size)> all = [
    ('small phone', smallPhone),
    ('phone', phone),
    ('tablet', tablet),
    ('landscape phone', landscape),
  ];

  const TestSizes._();
}

/// Fails the test if any render box overflowed.
///
/// Flutter reports overflow as a non-fatal console error, which a test would
/// otherwise sail straight past — this turns "a yellow-and-black bar appeared"
/// into a red build.
void expectNoOverflow(WidgetTester tester) {
  final errors = tester.takeException();
  expect(errors, isNull, reason: 'A widget overflowed or threw during layout.');
}

/// Performs an interaction and lets the resulting async work settle.
Future<void> actAndSettle(
  WidgetTester tester,
  Future<void> Function() action, {
  Duration settle = const Duration(milliseconds: 400),
}) async {
  await action();
  await tester.pumpAndSettle();
}

/// Signs in against the fake server, so a page test starts where a real user
/// would: with a live session and probed capabilities.
///
/// Goes through the real [AuthCubit] rather than hand-building a session — the
/// capability probe runs, the credential lands in the vault, and the state the
/// screens read is the state the app produces.
Future<void> signInForTest(FakeOdooData data) async {
  await sl<AuthCubit>().signIn(
    connection: OdooConnection(
      // Any host works: the in-process client routes by endpoint path.
      baseUrl: Uri.parse('https://company.odoo.com'),
      database: data.database,
      username: data.login,
    ),
    secret: data.secret,
  );
}

/// Wraps a screen with the providers the router normally supplies, plus a
/// signed-in session.
Widget signedInScreen(Widget child) => MultiBlocProvider(
  providers: [
    BlocProvider<AuthCubit>.value(value: sl<AuthCubit>()),
    BlocProvider<AppSettingsCubit>(
      create: (_) => AppSettingsCubit(sl<AppPreferences>()),
    ),
  ],
  child: child,
);
