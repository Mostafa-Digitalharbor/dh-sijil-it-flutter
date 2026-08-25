import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/utils/app_number.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_views.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/data_charts.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/greeting_header.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/status_legend.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../cubit/dashboard_cubit.dart';

/// The landing screen: totals, status split, categories and recent activity
/// (spec §4).
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>(
      create: (_) => sl<DashboardCubit>()..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<DashboardCubit, SimpleViewState<DashboardSummary>>(
      builder: (context, state) {
        final cubit = context.read<DashboardCubit>();
        final summary = state.data;

        final user = context.watch<AuthCubit>().state.user;

        return AppScaffold(
          // Still the screen's accessible name; the visible header is a
          // person rather than a string.
          title: l10n.dashboardTitle,
          titleWidget: GreetingHeader(
            name: user?.displayName ?? l10n.dashboardTitle,
            photo: user?.avatar,
          ),
          actions: <Widget>[
            AppIconButton(
              icon: Icons.refresh_rounded,
              tooltip: l10n.actionRefresh,
              onPressed: () => cubit.load(refresh: true),
            ),
          ],
          body: switch (state) {
            _ when state.isLoading && summary == null => const SkeletonList(),
            _ when state.hasFailed && summary == null => FailureView(
              failure: state.failure!,
              onRetry: cubit.load,
            ),
            _ when summary == null => const SizedBox.shrink(),
            _ => _DashboardBody(summary: summary),
          },
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<DashboardCubit>();

    if (summary.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => cubit.load(refresh: true),
        child: EmptyStateView(
          icon: Icons.devices_other_rounded,
          title: l10n.emptyAssetsTitle,
          message: l10n.emptyAssetsBody,
        ),
      );
    }

    return AppPageBody(
      onRefresh: () => cubit.load(refresh: true),
      children: <Widget>[
        _DistributionCard(summary: summary),
        if (summary.inServiceTrend.length > 1) _TrendCard(summary: summary),
        if (summary.warrantyExpiringCount > 0 ||
            summary.openMaintenanceCount > 0)
          _AttentionRow(summary: summary),
        if (summary.categories.isNotEmpty) _CategoryBreakdown(summary: summary),
        _ActivityFeed(summary: summary),
      ],
    );
  }
}

/// The status split, as a ring with the total in the middle.
///
/// ## Why this replaced six tiles
///
/// The old dashboard was six counters. "68" answers *how many are assigned*;
/// it does not answer *is the fleet healthy*, which is the only question
/// anyone opens the app to ask. A ring answers it at a glance, because the
/// reader compares arc lengths instead of reading and subtracting digits.
///
/// The three rare statuses share one legend row. Reserved, damaged and lost
/// are usually single digits, and giving each a full row made the eye weight
/// them like the four that matter daily.
class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.summary});

  final DashboardSummary summary;

  /// Ring order: the ordinary statuses first, so they form one continuous
  /// sweep and the exceptions cluster together at the end.
  static const List<AssetStatus> _ringOrder = <AssetStatus>[
    AssetStatus.assigned,
    AssetStatus.available,
    AssetStatus.retired,
    AssetStatus.underMaintenance,
    AssetStatus.reserved,
    AssetStatus.damaged,
    AssetStatus.lost,
  ];

  /// The four that get their own legend row.
  static const List<AssetStatus> _named = <AssetStatus>[
    AssetStatus.assigned,
    AssetStatus.available,
    AssetStatus.retired,
    AssetStatus.underMaintenance,
  ];

  static const List<AssetStatus> _rare = <AssetStatus>[
    AssetStatus.reserved,
    AssetStatus.damaged,
    AssetStatus.lost,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final rareCount = _rare.fold(0, (sum, s) => sum + summary.countOf(s));

    return GlassCard(
      onTap: () => context.go(AppRoutes.assets),
      child: Row(
        children: <Widget>[
          StatusDonut(
            slices: <DonutSlice>[
              for (final status in _ringOrder)
                DonutSlice(
                  value: summary.countOf(status),
                  color: StatusChip.colorFor(status),
                ),
            ],
            centerValue: AppNumber.count(context, summary.totalCount),
            centerLabel: l10n.dashboardAssetsUnit,
            semanticLabel: l10n.dashboardInService(summary.inServiceCount),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final status in _named) ...<Widget>[
                  StatusLegendRow(
                    tone: StatusChip.colorFor(status),
                    label: StatusChip.labelFor(l10n, status),
                    count: summary.countOf(status),
                  ),
                  const SizedBox(height: AppSpacing.sm - 1),
                ],
                StatusLegendRow(
                  tone: StatusChip.colorFor(AssetStatus.reserved),
                  label: l10n.dashboardRareStatuses,
                  count: rareCount,
                  muted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Twelve months of assets in service.
///
/// Answers the question the ring cannot: a distribution is a snapshot, and a
/// fleet that shed twenty assets this quarter looks identical to one that
/// gained twenty. Hidden entirely when the instance has too few dated records
/// to draw an honest shape - see `DashboardRepositoryImpl._inServiceTrend`.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final trend = summary.inServiceTrend;
    final growth = trend.first == 0
        ? null
        : (trend.last - trend.first) / trend.first;

    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.dashboardTrendTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: AppTypography.noTracking,
                    color: palette.faint,
                  ),
                ),
              ),
              if (growth != null)
                Text(
                  AppNumber.signedPercent(context, growth),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: AppTextSize.label,
                    color: growth >= 0
                        ? context.ink(AppColors.statusAvailable)
                        : context.ink(AppColors.statusDamaged),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendSparkline(
            values: trend.map((v) => v.toDouble()).toList(growable: false),
            tone: context.ink(AppColors.statusAvailable),
          ),
        ],
      ),
    );
  }
}

/// Warranty and maintenance attention cards (spec §15).
class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Row(
      children: <Widget>[
        if (summary.warrantyExpiringCount > 0)
          Expanded(
            child: AppAttentionTile(
              icon: Icons.shield_outlined,
              tone: AppColors.warning,
              value: AppNumber.count(context, summary.warrantyExpiringCount),
              label: l10n.dashboardWarrantyDue,
              onTap: () => context.go(AppRoutes.assets),
            ),
          ),
        if (summary.warrantyExpiringCount > 0 &&
            summary.openMaintenanceCount > 0)
          const SizedBox(width: AppSpacing.sm + 1),
        if (summary.openMaintenanceCount > 0)
          Expanded(
            child: AppAttentionTile(
              icon: Icons.build_rounded,
              tone: AppColors.statusMaintenance,
              value: AppNumber.count(context, summary.openMaintenanceCount),
              label: l10n.dashboardOpenMaintenance,
              onTap: () => context.go(AppRoutes.maintenancePath),
            ),
          ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});

  final DashboardSummary summary;

  /// The bar palette.
  ///
  /// These were navy shades, which vanished the moment the ground became navy
  /// too — the largest category drew a bar the same colour as the card behind
  /// it. The status hues are the only set in the palette already tuned to read
  /// on both grounds, and a category chart carries no status context for them
  /// to collide with: every bar is labelled with its category name.
  static const List<Color> _palette = <Color>[
    AppColors.statusAssigned,
    AppColors.statusAvailable,
    AppColors.statusReserved,
    AppColors.statusMaintenance,
    AppColors.statusLost,
    AppColors.statusRetired,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SectionCard(
      title: l10n.dashboardByCategory,
      trailing: AppTextAction(
        label: l10n.actionSeeAll,
        onPressed: () => context.go(AppRoutes.assets),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < summary.categories.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.sm - 1),
            LabeledBar(
              label: summary.categories[i].label,
              value: summary.categories[i].count,
              max: summary.largestCategoryCount,
              color: context.ink(_palette[i % _palette.length]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final entries = summary.activity;

    return SectionCard(
      title: l10n.dashboardRecentActivity,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.emptyActivityBody,
                style: theme.textTheme.bodySmall,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < entries.length; i++)
                  AppActivityTile(
                    icon: _iconFor(entries[i].kind),
                    tone: _toneFor(entries[i].kind),
                    title: entries[i].title,
                    timestamp: _timestamp(context, entries[i]),
                    showDivider: i < entries.length - 1,
                  ),
              ],
            ),
    );
  }

  static String _timestamp(BuildContext context, ActivityEntry entry) {
    final relative = context.dates.relative(entry.occurredAt);
    final detail = entry.detail;
    return detail == null ? relative : '$relative · $detail';
  }

  static IconData _iconFor(ActivityKind kind) => switch (kind) {
    ActivityKind.assigned => Icons.person_rounded,
    ActivityKind.returned => Icons.assignment_return_rounded,
    ActivityKind.maintenance => Icons.build_rounded,
    ActivityKind.created => Icons.add_circle_outline_rounded,
    ActivityKind.note => Icons.chat_bubble_outline_rounded,
  };

  static Color _toneFor(ActivityKind kind) => switch (kind) {
    ActivityKind.assigned => AppColors.statusAssigned,
    ActivityKind.returned => AppColors.statusAvailable,
    ActivityKind.maintenance => AppColors.statusMaintenance,
    ActivityKind.created => AppColors.statusReserved,
    ActivityKind.note => AppColors.navy300,
  };
}
