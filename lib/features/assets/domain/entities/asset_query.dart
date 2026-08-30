import 'package:equatable/equatable.dart';

import '../../../../core/pagination/page_request.dart';
import 'asset_status.dart';
import 'warranty.dart';

/// How an asset list is ordered (spec §11).
///
/// The Odoo `order` clause lives here rather than at the call site so a
/// widget never writes a field name, and so the default is decided once.
enum AssetSort {
  recentlyUpdated,
  nameAsc,
  nameDesc;

  static const AssetSort defaultSort = AssetSort.recentlyUpdated;
}

/// The filter set the assets screen can apply (spec §11).
///
/// A value object: two identical filter sets are equal, which is what lets the
/// Cubit skip a redundant round trip when a filter sheet is dismissed
/// unchanged.
///
/// Every filter is an *optional narrowing*. An empty [AssetFilters] means "no
/// restriction", never "match nothing" — which is why the counts on the
/// dashboard and the unfiltered list agree.
class AssetFilters extends Equatable {
  const AssetFilters({
    this.query,
    this.statuses = const <AssetStatus>{},
    this.categoryIds = const <int>{},
    this.employeeId,
    this.departmentId,
    this.manufacturer,
    this.warrantyStates = const <WarrantyState>{},
    this.includeRetired = false,
    this.overdueOnly = false,
  });

  /// Free-text, matched across name, tag, serial, model and manufacturer.
  final String? query;

  final Set<AssetStatus> statuses;
  final Set<int> categoryIds;

  /// Restricts to one employee's holdings — how the employee detail screen
  /// reuses the asset list.
  final int? employeeId;

  final int? departmentId;
  final String? manufacturer;

  /// Warranty buckets. Evaluated in Dart against `warranty_date`, because
  /// Odoo stores only the raw date (spec §15).
  final Set<WarrantyState> warrantyStates;

  /// Retired assets are hidden by default: an IT manager looking at "our
  /// laptops" does not mean the scrapped ones.
  final bool includeRetired;

  /// Only assets past the date they were promised back.
  ///
  /// Evaluated in Dart for the same reason the warranty buckets are: the date
  /// lives in a chatter note, not a field Odoo can compare against today.
  final bool overdueOnly;

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      statuses.isEmpty &&
      categoryIds.isEmpty &&
      employeeId == null &&
      departmentId == null &&
      manufacturer == null &&
      warrantyStates.isEmpty &&
      !includeRetired &&
      !overdueOnly;

  bool get isNotEmpty => !isEmpty;

  /// Number of active narrowings, for the "Filters (3)" badge. The free-text
  /// query is excluded: it has its own visible field.
  int get activeCount =>
      (statuses.isEmpty ? 0 : 1) +
      (categoryIds.isEmpty ? 0 : 1) +
      (employeeId == null ? 0 : 1) +
      (departmentId == null ? 0 : 1) +
      (manufacturer == null ? 0 : 1) +
      (warrantyStates.isEmpty ? 0 : 1) +
      (overdueOnly ? 1 : 0);

  /// True when any active filter can only be evaluated on the device.
  ///
  /// Warranty buckets and the three local-overlay statuses have no Odoo field
  /// to filter on, so the repository must widen the query and narrow the
  /// result in Dart. Knowing this up front is what keeps the "showing N of M"
  /// counter honest.
  bool get needsClientSideNarrowing =>
      warrantyStates.isNotEmpty ||
      overdueOnly ||
      statuses.any((s) => s.isLocalOnly);

  AssetFilters copyWith({
    String? query,
    Set<AssetStatus>? statuses,
    Set<int>? categoryIds,
    int? employeeId,
    int? departmentId,
    String? manufacturer,
    Set<WarrantyState>? warrantyStates,
    bool? includeRetired,
    bool? overdueOnly,
    bool clearQuery = false,
    bool clearEmployee = false,
    bool clearDepartment = false,
    bool clearManufacturer = false,
  }) => AssetFilters(
    query: clearQuery ? null : (query ?? this.query),
    statuses: statuses ?? this.statuses,
    categoryIds: categoryIds ?? this.categoryIds,
    employeeId: clearEmployee ? null : (employeeId ?? this.employeeId),
    departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
    manufacturer: clearManufacturer
        ? null
        : (manufacturer ?? this.manufacturer),
    warrantyStates: warrantyStates ?? this.warrantyStates,
    includeRetired: includeRetired ?? this.includeRetired,
    overdueOnly: overdueOnly ?? this.overdueOnly,
  );

  /// Drops every narrowing but keeps the typed search term, which is what the
  /// "Clear all" control in the filter sheet means.
  AssetFilters cleared() => AssetFilters(query: query);

  @override
  List<Object?> get props => [
    query,
    statuses,
    categoryIds,
    employeeId,
    departmentId,
    manufacturer,
    warrantyStates,
    includeRetired,
    overdueOnly,
  ];
}

/// One request for a page of assets: what to match, how to order, which page.
class AssetQuery extends Equatable {
  const AssetQuery({
    this.filters = const AssetFilters(),
    this.sort = AssetSort.defaultSort,
    this.page = const PageRequest(),
  });

  final AssetFilters filters;
  final AssetSort sort;
  final PageRequest page;

  AssetQuery next() =>
      AssetQuery(filters: filters, sort: sort, page: page.next());

  AssetQuery first() =>
      AssetQuery(filters: filters, sort: sort, page: page.first());

  /// A stable identity for this exact question, used to file the offline copy.
  ///
  /// Derived from [props] rather than written by hand, so a filter cannot be
  /// added without changing the key. A hand-written key that forgets one is
  /// how a filtered list gets answered from an unfiltered copy.
  ///
  /// Two logically-equal filter sets built in a different order produce
  /// different keys. That costs a cache miss and nothing else.
  String get cacheKey => props.map((p) => '$p').join('|');

  AssetQuery copyWith({
    AssetFilters? filters,
    AssetSort? sort,
    PageRequest? page,
  }) => AssetQuery(
    filters: filters ?? this.filters,
    sort: sort ?? this.sort,
    page: page ?? this.page,
  );

  @override
  List<Object?> get props => [filters, sort, page];
}
