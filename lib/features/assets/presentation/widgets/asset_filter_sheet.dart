import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../domain/entities/asset_query.dart';
import '../../domain/entities/asset_status.dart';
import '../../domain/entities/warranty.dart';

/// What the filter sheet returns when the user applies it.
class AssetFilterSelection {
  const AssetFilterSelection({required this.filters, required this.sort});

  final AssetFilters filters;
  final AssetSort sort;
}

/// The filter and sort sheet for the assets screen (spec §11).
///
/// Edits a local copy and returns it only on Apply, so dismissing the sheet
/// leaves the list exactly as it was — a filter sheet that mutates live is one
/// where a stray tap costs the user their place in a long list.
class AssetFilterSheet extends StatefulWidget {
  const AssetFilterSheet({
    required this.initialFilters,
    required this.initialSort,
    required this.categories,
    required this.manufacturers,
    required this.departments,
    super.key,
  });

  final AssetFilters initialFilters;
  final AssetSort initialSort;
  final List<OdooNameRef> categories;
  final List<String> manufacturers;

  /// Empty on an Odoo without the Employees app, which hides the group.
  final List<OdooNameRef> departments;

  /// Opens the sheet and resolves to the selection, or null if dismissed.
  static Future<AssetFilterSelection?> show(
    BuildContext context, {
    required AssetFilters filters,
    required AssetSort sort,
    required List<OdooNameRef> categories,
    required List<String> manufacturers,
    required List<OdooNameRef> departments,
  }) {
    return showModalBottomSheet<AssetFilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AssetFilterSheet(
        initialFilters: filters,
        initialSort: sort,
        categories: categories,
        manufacturers: manufacturers,
        departments: departments,
      ),
    );
  }

  @override
  State<AssetFilterSheet> createState() => _AssetFilterSheetState();
}

class _AssetFilterSheetState extends State<AssetFilterSheet> {
  late AssetFilters _filters = widget.initialFilters;
  late AssetSort _sort = widget.initialSort;

  /// Statuses offered, in the order the dashboard shows them.
  static const List<AssetStatus> _statuses = <AssetStatus>[
    AssetStatus.assigned,
    AssetStatus.available,
    AssetStatus.reserved,
    AssetStatus.underMaintenance,
    AssetStatus.damaged,
    AssetStatus.lost,
    AssetStatus.retired,
  ];

  static const List<WarrantyState> _warrantyStates = <WarrantyState>[
    WarrantyState.expired,
    WarrantyState.expiringCritical,
    WarrantyState.expiringSoon,
    WarrantyState.valid,
  ];

  void _toggleStatus(AssetStatus status) {
    setState(() {
      final next = Set<AssetStatus>.from(_filters.statuses);
      next.contains(status) ? next.remove(status) : next.add(status);
      _filters = _filters.copyWith(statuses: next);
    });
  }

  void _toggleCategory(int id) {
    setState(() {
      final next = Set<int>.from(_filters.categoryIds);
      next.contains(id) ? next.remove(id) : next.add(id);
      _filters = _filters.copyWith(categoryIds: next);
    });
  }

  void _toggleWarranty(WarrantyState state) {
    setState(() {
      final next = Set<WarrantyState>.from(_filters.warrantyStates);
      next.contains(state) ? next.remove(state) : next.add(state);
      _filters = _filters.copyWith(warrantyStates: next);
    });
  }

  void _toggleDepartment(int id) {
    setState(() {
      _filters = _filters.departmentId == id
          ? _filters.copyWith(clearDepartment: true)
          : _filters.copyWith(departmentId: id);
    });
  }

  void _toggleManufacturer(String name) {
    setState(() {
      _filters = _filters.manufacturer == name
          ? _filters.copyWith(clearManufacturer: true)
          : _filters.copyWith(manufacturer: name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: screen.gutter),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.filtersTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                AppTextAction(
                  label: l10n.filterClearAll,
                  onPressed: () =>
                      setState(() => _filters = _filters.cleared()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: screen.gutter,
                vertical: AppSpacing.sm,
              ),
              children: <Widget>[
                _Group(
                  title: l10n.sortLabel,
                  child: AppChipWrap(
                    children: <Widget>[
                      for (final sort in AssetSort.values)
                        AppChip(
                          label: _sortLabel(l10n, sort),
                          selected: _sort == sort,
                          onTap: () => setState(() => _sort = sort),
                        ),
                    ],
                  ),
                ),
                _Group(
                  title: l10n.filterStatus,
                  child: AppChipWrap(
                    children: <Widget>[
                      for (final status in _statuses)
                        AppChip(
                          label: _statusLabel(l10n, status),
                          selected: _filters.statuses.contains(status),
                          onTap: () => _toggleStatus(status),
                        ),
                    ],
                  ),
                ),
                if (widget.categories.isNotEmpty)
                  _Group(
                    title: l10n.filterCategory,
                    child: AppChipWrap(
                      children: <Widget>[
                        for (final category in widget.categories)
                          AppChip(
                            label: category.name,
                            selected: _filters.categoryIds.contains(
                              category.id,
                            ),
                            onTap: () => _toggleCategory(category.id),
                          ),
                      ],
                    ),
                  ),
                _Group(
                  title: l10n.filterWarranty,
                  child: AppChipWrap(
                    children: <Widget>[
                      for (final state in _warrantyStates)
                        AppChip(
                          label: _warrantyLabel(l10n, state),
                          selected: _filters.warrantyStates.contains(state),
                          onTap: () => _toggleWarranty(state),
                        ),
                    ],
                  ),
                ),
                if (widget.departments.isNotEmpty)
                  _Group(
                    title: l10n.filterDepartment,
                    child: AppChipWrap(
                      children: <Widget>[
                        for (final department in widget.departments)
                          AppChip(
                            label: department.name,
                            selected: _filters.departmentId == department.id,
                            onTap: () => _toggleDepartment(department.id),
                          ),
                      ],
                    ),
                  ),
                if (widget.manufacturers.isNotEmpty)
                  _Group(
                    title: l10n.filterManufacturer,
                    child: AppChipWrap(
                      children: <Widget>[
                        for (final name in widget.manufacturers)
                          AppChip(
                            label: name,
                            selected: _filters.manufacturer == name,
                            onTap: () => _toggleManufacturer(name),
                          ),
                      ],
                    ),
                  ),
                _Group(
                  title: l10n.statusRetired,
                  child: AppChipWrap(
                    children: <Widget>[
                      AppChip(
                        label: l10n.filterIncludeRetired,
                        selected: _filters.includeRetired,
                        onTap: () => setState(() {
                          _filters = _filters.copyWith(
                            includeRetired: !_filters.includeRetired,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: screen.gutter,
              end: screen.gutter,
              top: AppSpacing.sm,
              bottom: AppSpacing.md,
            ),
            child: AppButton(
              label: l10n.actionApply,
              onPressed: () => Navigator.of(
                context,
              ).pop(AssetFilterSelection(filters: _filters, sort: _sort)),
            ),
          ),
        ],
      ),
    );
  }

  static String _sortLabel(AppL10n l10n, AssetSort sort) => switch (sort) {
    AssetSort.recentlyUpdated => l10n.sortRecent,
    AssetSort.nameAsc => l10n.sortNameAsc,
    AssetSort.nameDesc => l10n.sortNameDesc,
  };

  static String _statusLabel(AppL10n l10n, AssetStatus status) =>
      switch (status) {
        AssetStatus.available => l10n.statusAvailable,
        AssetStatus.assigned => l10n.statusAssigned,
        AssetStatus.reserved => l10n.statusReserved,
        AssetStatus.underMaintenance => l10n.statusMaintenance,
        AssetStatus.damaged => l10n.statusDamaged,
        AssetStatus.lost => l10n.statusLost,
        AssetStatus.retired => l10n.statusRetired,
      };

  static String _warrantyLabel(AppL10n l10n, WarrantyState state) =>
      switch (state) {
        WarrantyState.unknown => l10n.warrantyUnknown,
        WarrantyState.valid => l10n.warrantyFilterValid,
        WarrantyState.expiringSoon => l10n.warrantyFilterSoon,
        WarrantyState.expiringCritical => l10n.warrantyFilterCritical,
        WarrantyState.expired => l10n.warrantyFilterExpired,
      };
}

/// A labelled block inside the sheet.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm + 1),
          child,
        ],
      ),
    );
  }
}
