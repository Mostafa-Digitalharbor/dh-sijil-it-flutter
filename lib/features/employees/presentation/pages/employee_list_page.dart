import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/paginated_list_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/employee.dart';
import '../cubit/employee_list_cubit.dart';

/// The employee directory (spec §9).
class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EmployeeListCubit>(
      create: (_) => sl<EmployeeListCubit>()..load(),
      child: const _EmployeeListView(),
    );
  }
}

class _EmployeeListView extends StatefulWidget {
  const _EmployeeListView();

  @override
  State<_EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends State<_EmployeeListView> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<EmployeeListCubit, EmployeeListState>(
      builder: (context, state) {
        final cubit = context.read<EmployeeListCubit>();

        return AppScaffold(
          title: l10n.employeesTitle,
          subtitle: state.isSuccess
              ? l10n.employeeItemCount(state.page.totalCount)
              : null,
          aboveBody: _SearchAndDepartments(
            controller: _search,
            state: state,
            onSearch: cubit.search,
            onPickDepartment: cubit.filterByDepartment,
          ),
          body: PaginatedListView<Employee>(
            items: state.employees,
            status: state.status,
            failure: state.failure,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            skeletonHasChips: false,
            onRefresh: () => cubit.load(refresh: true),
            onLoadMore: cubit.loadMore,
            onRetry: cubit.load,
            emptyView: state.isFilteredEmpty
                ? EmptyStateView(
                    icon: Icons.search_off_rounded,
                    title: l10n.emptySearchTitle,
                    message: l10n.emptySearchBody,
                  )
                : EmptyStateView(
                    icon: Icons.people_outline_rounded,
                    title: l10n.emptyEmployeesTitle,
                    message: l10n.emptyEmployeesBody,
                  ),
            itemBuilder: (context, employee, _) => AppListTile(
              leading: AppAvatar(name: employee.name),
              title: employee.name,
              subtitle: employee.summary,
              onTap: () =>
                  context.go(AppRoutes.employeeDetailPath(employee.id)),
            ),
          ),
        );
      },
    );
  }
}

class _SearchAndDepartments extends StatelessWidget {
  const _SearchAndDepartments({
    required this.controller,
    required this.state,
    required this.onSearch,
    required this.onPickDepartment,
  });

  final TextEditingController controller;
  final EmployeeListState state;
  final ValueChanged<String> onSearch;
  final ValueChanged<int?> onPickDepartment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selected = state.filters.departmentId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: context.pagePadding,
          child: AppSearchField(
            controller: controller,
            hint: l10n.employeeSearchHint,
            onChanged: onSearch,
            onClear: () => onSearch(''),
          ),
        ),
        if (state.departments.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppChipBar(
            children: <Widget>[
              AppChip(
                label: l10n.assignAllDepartments,
                selected: selected == null,
                onTap: () => onPickDepartment(null),
              ),
              for (final department in state.departments)
                AppChip(
                  label: department.name,
                  selected: selected == department.id,
                  onTap: () => onPickDepartment(
                    selected == department.id ? null : department.id,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
