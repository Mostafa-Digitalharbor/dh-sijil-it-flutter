import 'package:equatable/equatable.dart';

import '../../../assets/domain/entities/asset_status.dart';

/// One row of the "assets by category" chart.
class CategoryCount extends Equatable {
  const CategoryCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  List<Object?> get props => [label, count];
}

/// One entry in the recent-activity feed (spec §4).
class ActivityEntry extends Equatable {
  const ActivityEntry({
    required this.id,
    required this.title,
    required this.occurredAt,
    this.detail,
    this.assetId,
    this.kind = ActivityKind.note,
  });

  final int id;
  final String title;
  final DateTime occurredAt;
  final String? detail;

  /// The asset this entry is about, so a tap can open it.
  final int? assetId;

  final ActivityKind kind;

  @override
  List<Object?> get props => [id, title, occurredAt, detail, assetId, kind];
}

/// What an activity entry was about, which decides its icon and tint.
///
/// Inferred from the chatter text rather than from a field: Odoo records a
/// note as a note, and the app's own notes are the ones worth colouring.
enum ActivityKind { assigned, returned, maintenance, created, note }

/// Everything the dashboard renders, in one immutable snapshot (spec §4).
///
/// Assembled from counts rather than records: the whole screen is a handful of
/// `search_count` calls and one `read_group`, never a download of the asset
/// table (spec §20).
class DashboardSummary extends Equatable {
  const DashboardSummary({
    this.countsByStatus = const <AssetStatus, int>{},
    this.categories = const <CategoryCount>[],
    this.activity = const <ActivityEntry>[],
    this.inServiceTrend = const <int>[],
    this.warrantyExpiringCount = 0,
    this.openMaintenanceCount = 0,
    this.syncedAt,
  });

  final Map<AssetStatus, int> countsByStatus;
  final List<CategoryCount> categories;
  final List<ActivityEntry> activity;

  /// Assets in service at the end of each of the last twelve months, oldest
  /// first.
  ///
  /// Empty when the instance has too few dated records to draw an honest
  /// shape — the dashboard then hides the chart rather than drawing a line
  /// through three points and implying a trend that is not there.
  final List<int> inServiceTrend;

  /// Assets whose warranty ends inside the warning window (spec §15).
  final int warrantyExpiringCount;

  final int openMaintenanceCount;

  /// When these numbers were read, for the "synced 2 min ago" line.
  final DateTime? syncedAt;

  int countOf(AssetStatus status) => countsByStatus[status] ?? 0;

  /// Every asset the instance holds, including retired ones — the hero figure.
  int get totalCount =>
      countsByStatus.values.fold(0, (sum, value) => sum + value);

  /// Assets not retired or lost, which is what "112 in service" means.
  int get inServiceCount => countsByStatus.entries
      .where((entry) => entry.key.isActive)
      .fold(0, (sum, entry) => sum + entry.value);

  bool get isEmpty => totalCount == 0;

  /// The largest single category, used to scale the bar chart. Never zero, so
  /// the caller can divide by it without guarding.
  int get largestCategoryCount => categories.isEmpty
      ? 1
      : categories
            .map((c) => c.count)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 1 << 31);

  @override
  List<Object?> get props => [
    countsByStatus,
    categories,
    activity,
    inServiceTrend,
    warrantyExpiringCount,
    openMaintenanceCount,
    syncedAt,
  ];
}
