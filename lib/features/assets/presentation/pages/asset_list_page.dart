import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/export/export_documents.dart';
import '../../../../core/export/file_share.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/export_action.dart';
import '../../../../shared/widgets/paginated_list_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/voice_search_button.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_query.dart';
import '../cubit/asset_list_cubit.dart';
import '../widgets/asset_filter_sheet.dart';
import '../widgets/asset_row.dart';
import '../widgets/asset_selection_bar.dart';

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

  /// Hands the list, exactly as filtered, to the OS share sheet.
  ///
  /// CSV rather than a PDF: this is the export somebody opens in a
  /// spreadsheet to sort and pivot, and a PDF of two hundred rows is a worse
  /// version of the screen they are already looking at.
  ///
  /// Only what is loaded is exported — the count in the subject line says so,
  /// rather than a file quietly claiming to be the whole fleet.
  Future<void> _shareList(BuildContext context, List<Asset> assets) {
    final l10n = AppL10n.of(context);

    final copy = ExportAction.copyFor(
      context,
      title: l10n.exportAssetsTitle,
      subtitle: l10n.exportAssetsSubtitle(assets.length),
      columns: <String>[
        l10n.exportColumnTag,
        l10n.exportColumnName,
        l10n.exportColumnCategory,
        l10n.exportColumnManufacturer,
        l10n.exportColumnModel,
        l10n.exportColumnSerial,
        l10n.exportColumnStatus,
        l10n.exportColumnHolder,
        l10n.exportColumnDepartment,
        l10n.exportColumnAssignedOn,
        l10n.exportColumnDueBack,
        l10n.exportColumnWarrantyEnd,
      ],
    );

    return ExportAction.share(
      context: context,
      filename: FileShare.safeName(l10n.exportAssetsTitle, 'csv'),
      subject: '${l10n.exportAssetsTitle} — ${copy.subtitle}',
      mimeType: 'text/csv',
      build: () async =>
          Uint8List.fromList(utf8.encode(AssetListExport.csv(assets, copy))),
    );
  }

  /// Hands the selected rows to the OS share sheet as a printable label page.
  ///
  /// A PDF and not a CSV, unlike the list export above: this one is not data
  /// somebody pivots, it is paper somebody sticks on a laptop, and the layout
  /// *is* the deliverable.
  Future<void> _shareLabels(BuildContext context, List<Asset> assets) async {
    final l10n = AppL10n.of(context);

    final copy = ExportAction.copyFor(
      context,
      title: l10n.labelSheetTitle,
      subtitle: l10n.labelSheetSubtitle(assets.length),
      columns: const <String>[],
    );
    final theme = await ExportAction.themeFor(context);
    if (!context.mounted) return;

    await ExportAction.share(
      context: context,
      filename: FileShare.safeName(l10n.labelSheetTitle, 'pdf'),
      subject: '${l10n.labelSheetTitle} — ${copy.subtitle}',
      mimeType: 'application/pdf',
      build: () =>
          AssetLabelSheetExport.build(assets: assets, copy: copy, theme: theme),
    );
  }

  /// Asks which department, then moves the selection there.
  ///
  /// A confirmation step and not a straight apply: this is the one control in
  /// the product that writes to forty records at once, and the sheet is where
  /// the user sees how many that is before it happens.
  Future<void> _moveSelection(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetListCubit>();
    final departments = cubit.state.departments;

    if (departments.isEmpty) {
      AppSnack.info(context, l10n.bulkMoveNoDepartments);
      return;
    }

    final chosen = await AppOptionSheet.show<OdooNameRef>(
      context,
      title: l10n.bulkMoveTitle,
      subtitle: l10n.selectionCount(cubit.state.selectedIds.length),
      options: <AppSheetOption<OdooNameRef>>[
        for (final department in departments)
          AppSheetOption<OdooNameRef>(
            value: department,
            label: department.name,
            icon: Icons.apartment_rounded,
          ),
      ],
    );
    if (chosen == null) return;

    await cubit.moveSelectionToDepartment(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetListCubit>();

    return BlocConsumer<AssetListCubit, AssetListState>(
      listenWhen: (previous, current) =>
          previous.bulkMoved != current.bulkMoved ||
          previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        // Only while selecting: the list's *own* load failure belongs to the
        // failure view inside the list, which has room for the fix. A bulk
        // write is an action the user just took, so it answers in a line.
        if (failure != null && state.isSelecting) {
          AppSnack.failure(context, failure);
          context.read<AssetListCubit>().acknowledgeFailure();
          return;
        }

        final moved = state.bulkMoved;
        if (moved != null) {
          AppSnack.success(
            context,
            l10n.bulkMoveDone(moved.count, moved.department),
          );
          context.read<AssetListCubit>().acknowledgeBulkMove();
        }
      },
      builder: (context, state) {
        // Selection replaces the screen's chrome rather than adding to it: the
        // title becomes a count, the actions become the actions for that
        // count, and the create button gets out of the way. A screen that is
        // in two modes at once is one where the user cannot tell what a tap
        // will do.
        if (state.isSelecting) {
          return _SelectionScaffold(
            state: state,
            onMove: () => _moveSelection(context),
            onLabels: () => _shareLabels(context, state.selectedAssets),
          );
        }

        return AppScaffold(
          title: l10n.assetsTitle,
          subtitle: state.isSuccess
              ? l10n.assetsShowingOf(state.assets.length, state.page.totalCount)
              : null,
          actions: <Widget>[
            // The list the user has already narrowed is the export they want.
            // Anything else would be a second, unfiltered answer to a question
            // they spent three taps refining.
            AppIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: l10n.exportShare,
              onPressed: state.assets.isEmpty
                  ? null
                  : () => _shareList(context, state.assets),
            ),
            AppIconButton(
              icon: Icons.checklist_rounded,
              tooltip: l10n.selectionStart,
              onPressed: state.assets.isEmpty ? null : cubit.selectAllLoaded,
            ),
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
              // Long-press, the platform gesture for "I mean these ones".
              // Reached from a row rather than from a mode switch, so the
              // press that starts selecting is also the first thing selected.
              onLongPress: () => cubit.startSelection(asset.id),
            ),
          ),
        );
      },
    );
  }
}

/// The assets screen while the user is choosing rows.
///
/// A separate scaffold rather than a pile of conditionals inside the normal
/// one: the two modes share the list and nothing else — different title,
/// different actions, no search, no create button, and a bar of bulk actions
/// pinned to the bottom where a thumb is.
class _SelectionScaffold extends StatelessWidget {
  const _SelectionScaffold({
    required this.state,
    required this.onMove,
    required this.onLabels,
  });

  final AssetListState state;
  final VoidCallback onMove;
  final VoidCallback onLabels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetListCubit>();

    return AppScaffold(
      title: l10n.selectionCount(state.selectedIds.length),
      compactTitle: true,
      leading: AppCloseButton(
        onPressed: state.isBulkWorking ? null : cubit.endSelection,
      ),
      actions: <Widget>[
        AppIconButton(
          icon: Icons.select_all_rounded,
          tooltip: l10n.selectionAll,
          onPressed: state.isBulkWorking ? null : cubit.selectAllLoaded,
        ),
        AppIconButton(
          icon: Icons.deselect_rounded,
          tooltip: l10n.selectionNone,
          onPressed: state.isBulkWorking || !state.hasSelection
              ? null
              : cubit.clearSelection,
        ),
      ],
      bottomBar: AssetSelectionBar(
        state: state,
        onMove: onMove,
        onLabels: onLabels,
      ),
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
          icon: Icons.devices_other_rounded,
          title: l10n.emptyAssetsTitle,
          message: l10n.emptyAssetsBody,
        ),
        itemBuilder: (context, asset, _) => AssetRow(
          asset: asset,
          selectable: true,
          selected: state.selectedIds.contains(asset.id),
          // Blocked at the ceiling rather than silently ignored: a tap that
          // does nothing reads as a broken row, and the number is the only
          // thing that explains it.
          onTap: () {
            if (!state.selectedIds.contains(asset.id) && !state.canSelectMore) {
              AppSnack.info(
                context,
                l10n.selectionLimitReached(AppConstants.bulkSelectionLimit),
              );
              return;
            }
            cubit.toggleSelection(asset.id);
          },
        ),
      ),
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
            // Both hands-free ways in, beside each other: the camera for an
            // asset you are standing in front of, the microphone for one you
            // are looking for. The microphone is absent on a device that
            // cannot dictate, so this is one button on most tablets.
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                VoiceSearchButton(
                  onTranscript: (text) {
                    controller.text = text;
                    onSearch(text);
                  },
                ),
                AppIconButton(
                  icon: Icons.qr_code_scanner_rounded,
                  tooltip: l10n.scanTitle,
                  bordered: false,
                  size: AppDimens.appBarActionSize,
                  onPressed: () => context.go(AppRoutes.scan),
                ),
              ],
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
