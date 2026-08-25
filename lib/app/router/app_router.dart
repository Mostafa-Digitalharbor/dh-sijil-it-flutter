import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/assets/presentation/pages/asset_detail_page.dart';
import '../../features/assets/presentation/pages/asset_form_page.dart';
import '../../features/assets/presentation/pages/asset_history_page.dart';
import '../../features/assets/presentation/pages/asset_list_page.dart';
import '../../features/assets/presentation/pages/asset_qr_page.dart';
import '../../features/assignment/presentation/pages/assign_asset_page.dart';
import '../../features/assignment/presentation/pages/return_asset_page.dart';
import '../../features/audit/presentation/pages/audit_page.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/connection/presentation/pages/connection_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/employees/presentation/pages/employee_assets_page.dart';
import '../../features/employees/presentation/pages/employee_detail_page.dart';
import '../../features/employees/presentation/pages/employee_list_page.dart';
import '../../features/handover/presentation/pages/handover_page.dart';
import '../../features/maintenance/presentation/pages/maintenance_detail_page.dart';
import '../../features/maintenance/presentation/pages/maintenance_list_page.dart';
import '../../features/scanner/presentation/pages/scanner_page.dart';
import '../../features/settings/presentation/pages/debug_log_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/state_views.dart';
import 'app_routes.dart';
import 'home_shell.dart';

/// Builds the app's navigation graph.
///
/// The five main tabs live inside a [StatefulShellRoute] so each keeps its own
/// navigation stack — switching from a deep asset detail to Scan and back
/// returns you where you were, which is what a commercial product does
/// (spec §26).
///
/// Auth is enforced in one place, [_redirect], rather than by each screen
/// checking for itself.
abstract final class AppRouter {
  /// The navigator above the tab shell.
  ///
  /// The four workflow screens — create/edit, assign, return and the QR label —
  /// are modal in the design: they open with a close button and no tab bar,
  /// because each is a task you finish or abandon rather than a place you
  /// browse. Routing them through this key is what puts them over the shell
  /// instead of inside a tab.
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static GoRouter create({required AuthCubit auth}) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.splash,

      // Re-runs the redirect on every auth transition, so a sign-out from any
      // screen lands on the right destination without that screen navigating.
      refreshListenable: _StreamListenable(auth.stream),

      redirect: (context, state) => _redirect(state: state, auth: auth.state),

      routes: [
        // The three auth screens replace one another through the redirect
        // above rather than being pushed, so a zoom transition would animate a
        // navigation the user never performed. NoTransitionPage also stops the
        // outgoing screen lingering offstage, where it swallows taps aimed at
        // the screen that replaced it.
        GoRoute(
          path: AppRoutes.splash,
          pageBuilder: (_, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const SplashPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.connection,
          pageBuilder: (_, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const ConnectionPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (_, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const LoginPage(),
          ),
        ),

        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) =>
              HomeShell(navigationShell: navigationShell),
          branches: [
            // ── Dashboard ────────────────────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.dashboard,
                  builder: (_, __) => const DashboardPage(),
                ),
              ],
            ),

            // ── Assets ───────────────────────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.assets,
                  builder: (_, __) => const AssetListPage(),
                  routes: [
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: AppRoutes.assetCreate,
                      builder: (_, __) => const AssetFormPage(assetId: null),
                    ),
                    GoRoute(
                      path: AppRoutes.assetDetail,
                      builder: (_, state) =>
                          AssetDetailPage(assetId: _intParam(state, 'assetId')),
                      routes: [
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'edit',
                          builder: (_, state) => AssetFormPage(
                            assetId: _intParam(state, 'assetId'),
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'history',
                          builder: (_, state) => AssetHistoryPage(
                            assetId: _intParam(state, 'assetId'),
                            assetName: state.uri.queryParameters['name'],
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'qr',
                          builder: (_, state) =>
                              AssetQrPage(assetId: _intParam(state, 'assetId')),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'assign',
                          builder: (_, state) => AssignAssetPage(
                            assetId: _intParam(state, 'assetId'),
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'return',
                          builder: (_, state) => ReturnAssetPage(
                            assetId: _intParam(state, 'assetId'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // ── Scan ─────────────────────────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.scan,
                  builder: (_, __) => const ScannerPage(),
                ),
              ],
            ),

            // ── Employees ────────────────────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.employees,
                  builder: (_, __) => const EmployeeListPage(),
                  routes: [
                    GoRoute(
                      path: AppRoutes.employeeDetail,
                      builder: (_, state) => EmployeeDetailPage(
                        employeeId: _intParam(state, 'employeeId'),
                      ),
                      routes: [
                        GoRoute(
                          path: 'assets',
                          builder: (_, state) => EmployeeAssetsPage(
                            employeeId: _intParam(state, 'employeeId'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // ── More ─────────────────────────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.more,
                  builder: (_, __) => const MorePage(),
                  routes: [
                    GoRoute(
                      path: AppRoutes.maintenance,
                      builder: (_, __) => const MaintenanceListPage(),
                    ),
                    GoRoute(
                      path: AppRoutes.maintenanceDetail,
                      builder: (_, state) => MaintenanceDetailPage(
                        requestId: _intParam(state, 'requestId'),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.audit,
                      // Full-screen: an audit owns the camera and the tab bar
                      // would be a one-tap way to lose a half-finished count.
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, __) => const AuditPage(),
                    ),
                    GoRoute(
                      path: AppRoutes.handover,
                      // Full-screen for the same reason as the audit: a
                      // half-filled bundle with a signature on the pad is not
                      // something a mis-tapped tab should discard.
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, __) => const HandoverPage(),
                    ),
                    GoRoute(
                      path: AppRoutes.settings,
                      builder: (_, __) => const SettingsPage(),
                      routes: [
                        GoRoute(
                          path: 'diagnostics',
                          builder: (_, __) => const DebugLogPage(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],

      // A route that does not exist is a user-facing state like any other, so
      // it gets the same treatment: an explanation and a way out, translated.
      errorBuilder: (context, state) => _RouteNotFoundPage(uri: state.uri),
    );
  }

  /// Single auth gate for the whole app.
  ///
  /// Four destinations, decided in one place so no screen ever navigates on
  /// its own behalf: still resolving → Splash; never configured → Connection;
  /// configured but signed out → Login; signed in → the requested page.
  static String? _redirect({
    required GoRouterState state,
    required AuthState auth,
  }) {
    final location = state.matchedLocation;
    final isAuthScreen =
        location == AppRoutes.login || location == AppRoutes.connection;

    switch (auth.status) {
      // Hold on the splash until restore() resolves, so the user never sees
      // the login screen flash before an existing session is recovered.
      case AuthStatus.unknown:
        return location == AppRoutes.splash ? null : AppRoutes.splash;

      case AuthStatus.busy:
        // A sign-in in flight keeps whatever screen started it.
        return null;

      case AuthStatus.unconfigured:
        return location == AppRoutes.connection ? null : AppRoutes.connection;

      case AuthStatus.signedOut:
        return isAuthScreen ? null : AppRoutes.login;

      case AuthStatus.signedIn:
        // Signed in — never leave the user sitting on an auth screen.
        return (isAuthScreen || location == AppRoutes.splash)
            ? AppRoutes.dashboard
            : null;
    }
  }

  static int _intParam(GoRouterState state, String name) =>
      int.tryParse(state.pathParameters[name] ?? '') ?? 0;
}

/// Shown for a URI the graph has no route for.
class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: SafeArea(
        child: EmptyStateView(
          icon: Icons.explore_off_rounded,
          title: l10n.errorRouteNotFoundTitle,
          message: l10n.errorRouteNotFoundBody,
          actionLabel: l10n.actionGoToDashboard,
          onAction: () => context.go(AppRoutes.dashboard),
        ),
      ),
    );
  }
}

/// Bridges a [Stream] to the [Listenable] that GoRouter's `refreshListenable`
/// expects, so session changes re-run the redirect.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
