import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/paginated_list_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/entities/asset_query.dart';
import '../../../assets/presentation/cubit/asset_list_cubit.dart';
import '../../../assets/presentation/widgets/asset_row.dart';

/// Every asset one employee holds (spec §9).
///
/// Reuses [AssetListCubit] with the employee filter pre-applied rather than
/// owning a parallel way to read assets — so paging, status resolution and the
/// row layout are identical to the main list by construction.
class EmployeeAssetsPage extends StatelessWidget {
  const EmployeeAssetsPage({required this.employeeId, super.key});

  final int employeeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssetListCubit>(
      create: (_) => sl<AssetListCubit>()
        ..applyFilters(
          AssetFilters(employeeId: employeeId, includeRetired: true),
        ),
      child: _EmployeeAssetsView(employeeId: employeeId),
    );
  }
}

class _EmployeeAssetsView extends StatelessWidget {
  const _EmployeeAssetsView({required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<AssetListCubit, AssetListState>(
      builder: (context, state) {
        final cubit = context.read<AssetListCubit>();

        return AppScaffold(
          title: l10n.employeeAssignedAssets,
          compactTitle: true,
          subtitle: state.isSuccess
              ? l10n.employeeItemCount(state.page.totalCount)
              : null,
          showBack: true,
          onBack: () => context.go(AppRoutes.employeeDetailPath(employeeId)),
          body: PaginatedListView<Asset>(
            items: state.assets,
            status: state.status,
            failure: state.failure,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onRefresh: () => cubit.load(refresh: true),
            onLoadMore: cubit.loadMore,
            onRetry: cubit.load,
            emptyView: EmptyStateView(
              icon: Icons.inbox_rounded,
              title: l10n.emptyEmployeeAssetsTitle,
              message: l10n.emptyEmployeeAssetsBody,
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
