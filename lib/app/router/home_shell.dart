import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/app_nav_bar.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/sync_banner.dart';
import '../../shared/widgets/tool_tile.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_routes.dart';

/// The persistent chrome around the five main tabs (spec §26).
///
/// On a phone this is a bottom [NavigationBar]; from the tablet breakpoint up
/// it becomes a side [NavigationRail], which is what makes the layout
/// genuinely responsive rather than just a stretched phone UI (spec §1).
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// The tabs, in branch order.
  ///
  /// The order is load-bearing: `StatefulShellRoute.indexedStack` addresses
  /// branches by index, so a tab can never be *removed* from this list without
  /// silently re-pointing every one after it. Features that an instance lacks
  /// are handled inside their own screen — the repositories return a
  /// `modelUnavailable` failure, which renders as an explanation of which Odoo
  /// app is missing rather than an empty tab.
  static List<NavItem> _tabsFor(AppL10n l10n) => <NavItem>[
    NavItem(
      label: l10n.navDashboard,
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    NavItem(
      label: l10n.navAssets,
      icon: Icons.devices_other_outlined,
      selectedIcon: Icons.devices_other_rounded,
    ),
    // Raised out of the bar: scanning is how a technician finds the asset
    // they are standing in front of, and it is the most-performed action in
    // the product by a wide margin.
    NavItem(
      label: l10n.navScan,
      icon: Icons.qr_code_scanner_rounded,
      isPrimary: true,
    ),
    NavItem(
      label: l10n.navEmployees,
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
    ),
    // A grid of tiles, not an ellipsis: the screen behind this is a board of
    // tools, and "..." means a menu.
    NavItem(
      label: l10n.navMore,
      icon: Icons.grid_view_rounded,
      glyph: const GridGlyph(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tabs = _tabsFor(l10n);

    // Above the tab bar and below every screen: what it reports is a fact
    // about the app, and a technician walking out of a server room changes
    // tabs on the way back into signal.
    if (context.screen.usesNavigationRail) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              labelType: NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                for (final tab in tabs)
                  NavigationRailDestination(
                    icon: tab.glyph ?? Icon(tab.icon),
                    selectedIcon:
                        tab.glyph ?? Icon(tab.selectedIcon ?? tab.icon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(width: AppSpacing.xs / 4),
            Expanded(
              child: Column(
                children: <Widget>[
                  const SyncBanner(),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SyncBanner(),
          AppNavBar(
            items: tabs,
            currentIndex: navigationShell.currentIndex,
            onSelected: _onTap,
          ),
        ],
      ),
    );
  }

  /// Tapping the active tab pops it back to its root, matching platform
  /// convention.
  void _onTap(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
}

/// The "More" tab: an index into everything that does not warrant its own tab.
///
/// Unlike the tab bar, this list *is* capability-gated — a row here is just a
/// row, so hiding Maintenance on an instance without the app costs nothing and
/// spares the user a screen that can only apologise (docs/ARCHITECTURE.md §5).
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final capabilities = context.watch<AuthCubit>().state.capabilities;

    return AppScaffold(
      title: l10n.moreTitle,
      body: AppPageBody(
        children: <Widget>[
          Text(l10n.moreToolsLabel, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          AppToolGrid(
            children: <Widget>[
              if (capabilities.hasMaintenanceRequests)
                AppToolTile(
                  icon: Icons.build_rounded,
                  tone: AppColors.statusMaintenance,
                  title: l10n.maintenanceTitle,
                  subtitle: l10n.moreMaintenanceSubtitle,
                  onTap: () => context.go(AppRoutes.maintenancePath),
                ),
              AppToolTile(
                icon: Icons.how_to_reg_rounded,
                tone: AppColors.statusAssigned,
                title: l10n.handoverTitle,
                subtitle: l10n.moreHandoverSubtitle,
                onTap: () => context.go(AppRoutes.handoverPath),
              ),
              AppToolTile(
                icon: Icons.qr_code_scanner_rounded,
                tone: AppColors.statusAvailable,
                title: l10n.auditTitle,
                subtitle: l10n.moreAuditSubtitle,
                onTap: () => context.go(AppRoutes.auditPath),
              ),
              // Always listed, empty queue or not: somebody handing a phone in
              // at the end of a shift needs a place to check that nothing is
              // still sitting on it.
              AppToolTile(
                icon: Icons.cloud_sync_rounded,
                tone: AppColors.warning,
                title: l10n.syncTitle,
                subtitle: l10n.syncSubtitle,
                onTap: () => context.go(AppRoutes.syncPath),
              ),
              AppToolTile(
                icon: Icons.settings_rounded,
                tone: AppColors.statusRetired,
                title: l10n.settingsTitle,
                subtitle: l10n.moreSettingsSubtitle,
                onTap: () => context.go(AppRoutes.settingsPath),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              '${AppConstants.appName} — ${AppConstants.appTagline}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
