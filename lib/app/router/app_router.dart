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
import '../../features/sync/presentation/pages/sync_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/state_views.dart';
import 'app_routes.dart';
import 'app_transitions.dart';
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
        // Splash and the server screen are *arrivals*: the app resolved where
        // the user belongs and put them there. Animating them would animate a
        // navigation the user never performed, and `NoTransitionPage` also
        // stops the outgoing screen lingering offstage, where it swallows taps
        // aimed at the screen that replaced it.
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
        // Sign-in is the exception, and the only auth screen the user reaches
        // by pressing something: "Continue" on the server screen. It is one
        // step deeper in a two-step form and it has a back button, so it gets
        // the same movement as any other forward navigation — and the back
        // button plays it in reverse, which is what makes the pair read as a
        // form rather than as two unrelated screens.
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (_, state) => AppTransitions.forward(
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
                      pageBuilder: (_, state) => AppTransitions.modal(
                        key: state.pageKey,
                        child: const AssetFormPage(assetId: null),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.assetDetail,
                      pageBuilder: (_, state) => AppTransitions.forward(
                        key: state.pageKey,
                        child: AssetDetailPage(
                          assetId: _intParam(state, 'assetId'),
                        ),
                      ),
                      routes: [
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'edit',
                          pageBuilder: (_, state) => AppTransitions.modal(
                            key: state.pageKey,
                            child: AssetFormPage(
                              assetId: _intParam(state, 'assetId'),
                            ),
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'history',
                          pageBuilder: (_, state) => AppTransitions.forward(
                            key: state.pageKey,
                            child: AssetHistoryPage(
                              assetId: _intParam(state, 'assetId'),
                              assetName: state.uri.queryParameters['name'],
                            ),
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'qr',
                          pageBuilder: (_, state) => AppTransitions.forward(
                            key: state.pageKey,
                            child: AssetQrPage(
                              assetId: _intParam(state, 'assetId'),
                            ),
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'assign',
                          pageBuilder: (_, state) => AppTransitions.modal(
                            key: state.pageKey,
                            child: AssignAssetPage(
                              assetId: _intParam(state, 'assetId'),
                            ),
                          ),
                        ),
                        GoRoute(
                          parentNavigatorKey: rootNavigatorKey,
                          path: 'return',
                          pageBuilder: (_, state) => AppTransitions.modal(
                            key: state.pageKey,
                            child: ReturnAssetPage(
                              assetId: _intParam(state, 'assetId'),
                            ),
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
                      pageBuilder: (_, state) => AppTransitions.forward(
                        key: state.pageKey,
                        child: EmployeeDetailPage(
                          employeeId: _intParam(state, 'employeeId'),
                        ),
                      ),
                      routes: [
                        GoRoute(
                          path: 'assets',
                          pageBuilder: (_, state) => AppTransitions.forward(
                            key: state.pageKey,
                            child: EmployeeAssetsPage(
                              employeeId: _intParam(state, 'employeeId'),
                            ),
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
                      pageBuilder: (_, state) => AppTransitions.forward(
                        key: state.pageKey,
                        child: const MaintenanceListPage(),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.maintenanceDetail,
                      pageBuilder: (_, state) => AppTransitions.forward(
                        key: state.pageKey,
                        child: MaintenanceDetailPage(
                          requestId: _intParam(state, 'requestId'),
                        ),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.audit,
                      // Full-screen: an audit owns the camera and the tab bar
                      // would be a one-tap way to lose a half-finished count.
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (_, state) => AppTransitions.modal(
                        key: state.pageKey,
                        child: const AuditPage(),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.handover,
                      // Full-screen for the same reason as the audit: a
                      // half-filled bundle with a signature on the pad is not
                      // something a mis-tapped tab should discard.
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (_, state) => AppTransitions.modal(
                        key: state.pageKey,
                        child: const HandoverPage(),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.sync,
                      pageBuilder: (_, state) => AppTransitions.forward(
                        key: state.pageKey,
                        child: const SyncPage(),
                      ),
                    ),
                    GoRoute(
                      path: AppRoutes.settings,
                      pageBuilder: (_, state) => AppTransitions.forward(
                        key: state.pageKey,
                        child: const SettingsPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'diagnostics',
                          pageBuilder: (_, state) => AppTransitions.forward(
                            key: state.pageKey,
                            child: const DebugLogPage(),
                          ),
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
  /// its own behalf: still resolving → Splash; choosing a server → Connection;
  /// server chosen but signed out → Login; signed in → the requested page.
  ///
  /// This is also what "Continue" and the login screen's back button do. They
  /// move `AuthCubit` between `configuring` and `signedOut` and let the
  /// redirect place the user, so neither screen holds a route name and the
  /// two-step form cannot disagree with the auth gate about where the user is.
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

      case AuthStatus.configuring:
        return location == AppRoutes.connection ? null : AppRoutes.connection;

      // Pinned to the login screen, not "any auth screen".
      //
      // The looser test was harmless while the connection screen did the
      // signing in — a rejected credential emitted `signedOut` and the user
      // was already where the message belonged. Now that Continue emits it
      // from the server screen, treating that screen as an acceptable resting
      // place means the redirect declines to move and the button does nothing.
      case AuthStatus.signedOut:
        return location == AppRoutes.login ? null : AppRoutes.login;

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
