import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/paginated_list_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_query.dart';
import '../../domain/entities/asset_status.dart';
import '../cubit/asset_list_cubit.dart';
import '../widgets/asset_row.dart';

/// Every asset past the date somebody promised it back.
///
/// ## Why this screen exists
///
/// The app has always recorded when a handover *started* — "assigned 12 days
/// ago" — and never when it was supposed to end. So an asset issued for a
/// week and an asset issued for a career looked identical, and nothing in the
/// product ever said a device was late. This is the screen that gets a laptop
/// back from somebody who has already left the company.
///
/// ## Why it is the asset list underneath
///
/// It is the same question with one filter on it, so it is the same ViewModel,
/// the same row and the same pagination. A second list screen would be a
/// second place for the status palette, the offline behaviour and the empty
/// state to drift.
///
/// The filter pairs "assigned" — which Odoo can narrow on, so the server does
/// most of the work — with "overdue", which it cannot: the date lives in a
/// chatter note, and the comparison against today happens on the device.
class OverdueAssetsPage extends StatelessWidget {
  const OverdueAssetsPage({super.key});

  /// The one filter this screen is.
  static const AssetFilters filters = AssetFilters(
    statuses: <AssetStatus>{AssetStatus.assigned},
    overdueOnly: true,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssetListCubit>(
      create: (_) => sl<AssetListCubit>()..load(filters: filters),
      child: const _OverdueView(),
    );
  }
}

class _OverdueView extends StatelessWidget {
  const _OverdueView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<AssetListCubit, AssetListState>(
      builder: (context, state) {
        final cubit = context.read<AssetListCubit>();

        return AppScaffold(
          title: l10n.overdueTitle,
          // The count is of what is *loaded*, and says so by counting the rows
          // rather than the server's total: the narrowing happens here, so the
          // server's total is the number of assigned assets, not late ones.
          subtitle: state.isSuccess
              ? l10n.overdueCount(state.assets.length)
              : null,
          showBack: true,
          onBack: () => context.go(AppRoutes.more),
          body: PaginatedListView<Asset>(
            items: state.assets,
            status: state.status,
            failure: state.failure,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onRefresh: () => cubit.load(refresh: true),
            onLoadMore: cubit.loadMore,
            onRetry: () => cubit.load(filters: OverdueAssetsPage.filters),
            emptyView: EmptyStateView(
              icon: Icons.event_available_rounded,
              title: l10n.overdueEmptyTitle,
              message: l10n.overdueEmptyBody,
            ),
            itemBuilder: (context, asset, _) => AssetRow(
              asset: asset,
              // The warranty chip is turned off and the holder left on: this
              // screen is about who has it and how late they are, and a
              // warranty date would be a third number competing for the row.
              showWarranty: false,
              onTap: () => context.go(AppRoutes.assetDetailPath(asset.id)),
            ),
          ),
        );
      },
    );
  }
}
