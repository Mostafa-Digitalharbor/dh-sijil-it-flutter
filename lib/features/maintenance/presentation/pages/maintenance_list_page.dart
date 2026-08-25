import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/utils/app_text.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/paginated_list_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/maintenance_request.dart';
import '../cubit/maintenance_cubit.dart';
import '../widgets/maintenance_labels.dart';

/// Maintenance requests for the connected instance (spec §16).
class MaintenanceListPage extends StatelessWidget {
  const MaintenanceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MaintenanceListCubit>(
      create: (_) => sl<MaintenanceListCubit>()..load(),
      child: const _MaintenanceListView(),
    );
  }
}

class _MaintenanceListView extends StatefulWidget {
  const _MaintenanceListView();

  @override
  State<_MaintenanceListView> createState() => _MaintenanceListViewState();
}

class _MaintenanceListViewState extends State<_MaintenanceListView> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<MaintenanceListCubit, MaintenanceListState>(
      builder: (context, state) {
        final cubit = context.read<MaintenanceListCubit>();

        return AppScaffold(
          title: l10n.maintenanceTitle,
          showBack: true,
          onBack: () => context.go(AppRoutes.more),
          subtitle: state.isSuccess
              ? l10n.employeeItemCount(state.page.totalCount)
              : null,
          aboveBody: _SearchAndFilters(
            controller: _search,
            state: state,
            onSearch: cubit.search,
            onToggleOpen: (value) => cubit.showOnlyOpen(value: value),
            onPickType: cubit.filterByType,
          ),
          body: PaginatedListView<MaintenanceRequest>(
            items: state.requests,
            status: state.status,
            failure: state.failure,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onRefresh: () => cubit.load(refresh: true),
            onLoadMore: cubit.loadMore,
            onRetry: cubit.load,
            emptyView: EmptyStateView(
              icon: Icons.build_circle_outlined,
              title: l10n.emptyMaintenanceTitle,
              message: l10n.emptyMaintenanceBody,
            ),
            itemBuilder: (context, request, _) =>
                MaintenanceRow(request: request),
          ),
        );
      },
    );
  }
}

/// One maintenance request in a list.
class MaintenanceRow extends StatelessWidget {
  const MaintenanceRow({required this.request, super.key});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final overdue = request.isOverdue();

    return AppListTile(
      leading: AppLeadingTile(
        icon: MaintenanceLabels.typeIcon(request.type),
        tone: MaintenanceLabels.stageTone(request),
      ),
      title: request.name,
      subtitle: AppText.joined(<String?>[
        request.equipment?.name,
        context.dates.relative(request.requestedOn),
      ]),
      onTap: () => context.go(AppRoutes.maintenanceDetailPath(request.id)),
      chips: <Widget>[
        if (request.stage != null)
          AppChip(
            label: request.stage!.name,
            tone: MaintenanceLabels.stageTone(request),
            leadingDot: true,
            bordered: true,
            dense: true,
          ),
        if (request.priority.isUrgent)
          AppChip(
            label: MaintenanceLabels.priority(l10n, request.priority),
            tone: MaintenanceLabels.priorityTone(request.priority),
            icon: Icons.priority_high_rounded,
            dense: true,
          ),
        if (overdue)
          AppChip(
            label: l10n.maintenanceOverdue,
            tone: MaintenanceLabels.priorityTone(MaintenancePriority.high),
            icon: Icons.schedule_rounded,
            dense: true,
          ),
      ],
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.state,
    required this.onSearch,
    required this.onToggleOpen,
    required this.onPickType,
  });

  final TextEditingController controller;
  final MaintenanceListState state;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onToggleOpen;
  final ValueChanged<MaintenanceType?> onPickType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selectedType = state.query.filters.type;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: context.pagePadding,
          child: AppSearchField(
            controller: controller,
            hint: l10n.maintenanceSearchHint,
            onChanged: onSearch,
            onClear: () => onSearch(''),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppChipBar(
          children: <Widget>[
            AppChip(
              label: l10n.maintenanceOnlyOpen,
              icon: Icons.pending_actions_rounded,
              selected: state.onlyOpen,
              onTap: () => onToggleOpen(!state.onlyOpen),
            ),
            AppChip(
              label: l10n.labelAll,
              selected: selectedType == null,
              onTap: () => onPickType(null),
            ),
            for (final type in MaintenanceType.values)
              AppChip(
                label: MaintenanceLabels.type(l10n, type),
                selected: selectedType == type,
                onTap: () => onPickType(selectedType == type ? null : type),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
