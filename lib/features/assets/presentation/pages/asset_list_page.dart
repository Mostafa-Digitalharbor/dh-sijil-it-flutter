import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/paginated_list_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_query.dart';
import '../cubit/asset_list_cubit.dart';
import '../widgets/asset_filter_sheet.dart';
import '../widgets/asset_row.dart';

/// Paginated, searchable and filterable list of every IT asset (spec §§5, 11,
/// 20).
class AssetListPage extends StatelessWidget {
  const AssetListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssetListCubit>(
      create: (_) => sl<AssetListCubit>()..load(),
      child: const _AssetListView(),
    );
  }
}

class _AssetListView extends StatefulWidget {
  const _AssetListView();

  @override
  State<_AssetListView> createState() => _AssetListViewState();
}

class _AssetListViewState extends State<_AssetListView> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters(AssetListCubit cubit) async {
    final state = cubit.state;
    final applied = await AssetFilterSheet.show(
      context,
      filters: state.filters,
      sort: state.query.sort,
      categories: state.categories,
      manufacturers: state.manufacturers,
      departments: state.departments,
    );
    if (applied == null) return;

    cubit
      ..applyFilters(applied.filters)
      ..setSort(applied.sort);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetListCubit>();

    return BlocBuilder<AssetListCubit, AssetListState>(
      builder: (context, state) {
        return AppScaffold(
          title: l10n.assetsTitle,
          subtitle: state.isSuccess
              ? l10n.assetsShowingOf(state.assets.length, state.page.totalCount)
              : null,
          actions: <Widget>[
            AppIconButton(
              icon: Icons.swap_vert_rounded,
              tooltip: l10n.sortLabel,
              onPressed: () => _openFilters(cubit),
            ),
          ],
          aboveBody: _SearchAndFilters(
            controller: _search,
            state: state,
            onSearch: cubit.search,
            onOpenFilters: () => _openFilters(cubit),
            onClearFilters: cubit.clearFilters,
          ),
          floatingAction: state.permissions.canCreate
              ? FloatingActionButton(
                  onPressed: () => context.go(
                    '${AppRoutes.assets}/${AppRoutes.assetCreate}',
                  ),
                  backgroundColor: AppColors.mint,
                  foregroundColor: AppColors.navy,
                  tooltip: l10n.assetNewTitle,
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          body: PaginatedListView<Asset>(
            items: state.assets,
            status: state.status,
            failure: state.failure,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onRefresh: () => cubit.load(refresh: true),
            onLoadMore: cubit.loadMore,
            onRetry: cubit.load,
            emptyView: state.isFilteredEmpty
                ? EmptyStateView(
                    icon: Icons.search_off_rounded,
                    title: l10n.emptySearchTitle,
                    message: l10n.emptySearchBody,
                    actionLabel: l10n.filterClearAll,
                    onAction: () {
                      _search.clear();
                      cubit
                        ..search('')
                        ..clearFilters();
                    },
                  )
                : EmptyStateView(
                    icon: Icons.devices_other_rounded,
                    title: l10n.emptyAssetsTitle,
                    message: l10n.emptyAssetsBody,
                  ),
            itemBuilder: (context, asset, _) => AssetRow(
              asset: asset,
              onTap: () => context.go(AppRoutes.assetDetailPath(asset.id)),
            ),
          ),
        );
      },
    );
  }
}

/// The search field and the active-filter chip row.
///
/// Pinned under the app bar rather than scrolling with the list: a filter the
/// user cannot see is a filter they forget they applied, and then the empty
/// list looks like a bug.
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.state,
    required this.onSearch,
    required this.onOpenFilters,
    required this.onClearFilters,
  });

  final TextEditingController controller;
  final AssetListState state;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final activeCount = state.filters.activeCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: context.pagePadding,
          child: AppSearchField(
            controller: controller,
            hint: l10n.assetsSearchHint,
            onChanged: onSearch,
            onClear: () => onSearch(''),
            trailing: AppIconButton(
              icon: Icons.qr_code_scanner_rounded,
              tooltip: l10n.scanTitle,
              bordered: false,
              size: AppDimens.appBarActionSize,
              onPressed: () => context.go(AppRoutes.scan),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppChipBar(
          children: <Widget>[
            AppChip(
              label: activeCount == 0
                  ? l10n.filtersLabel
                  : l10n.filtersLabelActive(activeCount),
              icon: Icons.tune_rounded,
              selected: activeCount > 0,
              onTap: onOpenFilters,
            ),
            if (activeCount > 0)
              AppChip(
                label: l10n.filterClearAll,
                icon: Icons.close_rounded,
                onTap: onClearFilters,
              ),
            AppChip(
              label: _sortLabel(l10n, state.query.sort),
              icon: Icons.swap_vert_rounded,
              onTap: onOpenFilters,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  static String _sortLabel(AppL10n l10n, AssetSort sort) => switch (sort) {
    AssetSort.recentlyUpdated => l10n.sortRecent,
    AssetSort.nameAsc => l10n.sortNameAsc,
    AssetSort.nameDesc => l10n.sortNameDesc,
  };
}
