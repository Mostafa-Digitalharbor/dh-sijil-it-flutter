import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/odoo_models.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_domain_builder.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/network/odoo/odoo_value.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assets/data/services/asset_state_store.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Builds the dashboard from counts, never from records (spec §4, §20).
///
/// The status figures mirror `AssetStatusResolver` exactly, including its
/// precedence: retired beats maintenance beats assigned beats available. Each
/// bucket's domain therefore excludes the ones above it, so the six numbers
/// partition the asset table instead of overlapping — otherwise the tiles
/// would sum to more than the hero total and the screen would contradict
/// itself.
class DashboardRepositoryImpl
    with RepositoryGuard
    implements DashboardRepository {
  @override
  String get guardLabel => 'dashboard repository';

  const DashboardRepositoryImpl({
    required OdooObjectService odoo,
    required OdooCapabilityService capabilities,
    required AssetStateStore states,
    DateTime Function()? clock,
  }) : _odoo = odoo,
       _capabilities = capabilities,
       _states = states,
       _clock = clock ?? DateTime.now;

  final OdooObjectService _odoo;
  final OdooCapabilityService _capabilities;
  final AssetStateStore _states;
  final DateTime Function() _clock;

  static const String _model = OdooModels.maintenanceEquipment;

  @override
  ResultFuture<DashboardSummary> getSummary() => guard(() async {
    await _capabilities.requireModel(_model);

    final counts = await _statusCounts();
    final overlaid = await _applyLocalOverlay(counts);

    return DashboardSummary(
      countsByStatus: overlaid,
      categories: await _categoryBreakdown(),
      activity: await _recentActivity(),
      inServiceTrend: await _inServiceTrend(),
      warrantyExpiringCount: await _warrantyExpiringCount(),
      openMaintenanceCount: overlaid[AssetStatus.underMaintenance] ?? 0,
      syncedAt: _clock(),
    );
  });

  // ── Status counts ────────────────────────────────────────────────────────

  /// The four server-derivable buckets, counted with mutually exclusive
  /// domains that mirror the resolver's precedence.
  Future<Map<AssetStatus, int>> _statusCounts() async {
    final available = await _capabilities.getFields(_model);
    final hasScrap = available.contains(EquipmentFields.scrapDate);
    final hasEmployee = available.contains(EquipmentFields.employeeId);
    final hasOpen = available.contains(EquipmentFields.maintenanceOpenCount);

    /// `scrap_date` unset — the precondition every non-retired bucket shares.
    List<Object?> notRetired() => hasScrap
        ? <Object?>[
            <Object?>[EquipmentFields.scrapDate, '=', false],
          ]
        : <Object?>[];

    /// No open maintenance request — shared by assigned and available.
    List<Object?> notInMaintenance() => hasOpen
        ? <Object?>[
            <Object?>[EquipmentFields.maintenanceOpenCount, '=', 0],
          ]
        : <Object?>[];

    final retired = hasScrap
        ? await _count(<Object?>[
            <Object?>[EquipmentFields.scrapDate, '!=', false],
          ])
        : 0;

    final maintenance = hasOpen
        ? await _count(<Object?>[
            ...notRetired(),
            <Object?>[EquipmentFields.maintenanceOpenCount, '>', 0],
          ])
        : 0;

    final assigned = hasEmployee
        ? await _count(<Object?>[
            ...notRetired(),
            ...notInMaintenance(),
            <Object?>[EquipmentFields.employeeId, '!=', false],
          ])
        : 0;

    final availableCount = await _count(<Object?>[
      ...notRetired(),
      ...notInMaintenance(),
      if (hasEmployee) <Object?>[EquipmentFields.employeeId, '=', false],
    ]);

    return <AssetStatus, int>{
      AssetStatus.assigned: assigned,
      AssetStatus.available: availableCount,
      AssetStatus.underMaintenance: maintenance,
      AssetStatus.retired: retired,
    };
  }

  /// Moves overlaid assets out of Available into their local bucket.
  ///
  /// The overlay only ever refines Available (the resolver rejects anything
  /// else), so the three local counts come out of that one bucket and the
  /// total stays constant.
  Future<Map<AssetStatus, int>> _applyLocalOverlay(
    Map<AssetStatus, int> counts,
  ) async {
    final overlaid = Map<AssetStatus, int>.from(counts);

    final local = await _localOverlayCounts();
    var reclassified = 0;

    for (final entry in local.entries) {
      overlaid[entry.key] = entry.value;
      reclassified += entry.value;
    }

    final availableCount = overlaid[AssetStatus.available] ?? 0;
    // Clamped rather than trusted: an overlay whose asset was since deleted or
    // reassigned in Odoo would otherwise drive the tile negative.
    overlaid[AssetStatus.available] = (availableCount - reclassified).clamp(
      0,
      availableCount,
    );

    return overlaid;
  }

  Future<Map<AssetStatus, int>> _localOverlayCounts() async {
    final counts = <AssetStatus, int>{};
    try {
      for (final status in await _states.statuses(_model)) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    } on Object catch (error) {
      AppLogger.warn('Recorded state counts unavailable — $error');
    }
    return counts;
  }

  // ── Breakdowns ───────────────────────────────────────────────────────────

  /// Category totals via `read_group`, so Odoo aggregates instead of the app.
  Future<List<CategoryCount>> _categoryBreakdown() async {
    if (!(await _capabilities.getFields(
      _model,
    )).contains(EquipmentFields.categoryId)) {
      return const <CategoryCount>[];
    }

    final result = await _odoo.executeKw(
      model: _model,
      method: OdooMethods.readGroup,
      args: <Object?>[
        const <Object?>[],
        <Object?>[EquipmentFields.categoryId],
        <Object?>[EquipmentFields.categoryId],
      ],
      kwargs: const <String, dynamic>{'lazy': true},
    );

    if (result is! List) return const <CategoryCount>[];

    final counts = <CategoryCount>[];
    for (final group in result.whereType<Map<Object?, Object?>>()) {
      final row = Map<String, dynamic>.from(group);
      final ref = row.readRef(EquipmentFields.categoryId);
      // `__count` is Odoo 17+; `<field>_count` is the older shape.
      final count =
          row.readInt('__count') ??
          row.readInt('${EquipmentFields.categoryId}_count') ??
          0;
      if (ref == null || count == 0) continue;
      counts.add(CategoryCount(label: ref.name, count: count));
    }

    counts.sort((a, b) => b.count.compareTo(a.count));
    return counts.take(AppConstants.categoryChartLimit).toList(growable: false);
  }

  // ── Trend ────────────────────────────────────────────────────────────────

  /// Assets in service at the end of each of the last twelve months.
  ///
  /// ## Why one read instead of `read_group`
  ///
  /// Grouping by `effective_date:month` is the obvious call and the wrong one:
  /// Odoo returns the bucket as a **localised label** ("March 2024"), and the
  /// machine-readable `__range` alongside it only appeared in 16. Parsing
  /// either means version-sniffing the one place the app has none.
  ///
  /// Reading a single date column and bucketing on the device is one round
  /// trip, is exact, and behaves identically on 17, 18 and 19.
  ///
  /// Returns empty when too few records carry a date to draw an honest shape.
  /// A line through three points implies a trend the data does not support,
  /// and this figure ends up in front of whoever signs the hardware budget.
  Future<List<int>> _inServiceTrend() async {
    final fields = await _capabilities.getFields(_model);
    if (!fields.contains(EquipmentFields.effectiveDate)) return const <int>[];

    final hasScrap = fields.contains(EquipmentFields.scrapDate);
    final records = await _odoo.searchRead(
      model: _model,
      domain: <List<Object?>>[
        <Object?>[EquipmentFields.effectiveDate, '!=', false],
        if (hasScrap) <Object?>[EquipmentFields.scrapDate, '=', false],
      ],
      fields: const <String>[EquipmentFields.effectiveDate],
      limit: AppConstants.trendScanLimit,
    );

    final dates = <DateTime>[
      for (final record in records)
        if (record.readDate(EquipmentFields.effectiveDate) case final date?)
          date,
    ];
    if (dates.length < AppConstants.trendMinimumRecords) return const <int>[];

    final now = _clock();
    final buckets = <int>[];
    for (var back = AppConstants.trendMonths - 1; back >= 0; back--) {
      // First instant of the month *after* the bucket, so an asset registered
      // on the last day of the month is counted in it.
      final cutoff = DateTime(now.year, now.month - back + 1);
      buckets.add(dates.where((date) => date.isBefore(cutoff)).length);
    }

    // A flat line is not a trend, it is a chart with nothing to say.
    return buckets.first == buckets.last ? const <int>[] : buckets;
  }

  Future<int> _warrantyExpiringCount() async {
    if (!(await _capabilities.getFields(
      _model,
    )).contains(EquipmentFields.warrantyDate)) {
      return 0;
    }

    final now = _clock();
    final horizon = now.add(
      const Duration(days: AppConstants.warrantyWarningDays),
    );

    return _count(
      OdooDomainBuilder()
          .isSet(EquipmentFields.warrantyDate)
          .lessOrEqual(EquipmentFields.warrantyDate, OdooWrite.date(horizon))
          .build(),
    );
  }

  /// The activity feed, from `mail.message` when the Discuss app is present.
  ///
  /// Optional by design: an instance without it simply shows no feed, which
  /// the dashboard renders as an empty state rather than an error.
  Future<List<ActivityEntry>> _recentActivity() async {
    if (!await _capabilities.modelExists(OdooModels.mailMessage)) {
      return const <ActivityEntry>[];
    }

    try {
      final records = await _odoo.searchRead(
        model: OdooModels.mailMessage,
        domain: <Object?>[
          <Object?>[MailMessageFields.model, '=', _model],
        ],
        fields: MailMessageFields.readSet,
        limit: AppConstants.activityFeedLimit,
        order: '${MailMessageFields.date} desc',
      );

      return records
          .map(_toActivity)
          .whereType<ActivityEntry>()
          .toList(growable: false);
    } on AppException catch (error) {
      // The feed is the least important thing on the screen; losing it must
      // not cost the user their counts.
      AppLogger.warn('Activity feed unavailable — ${error.message}');
      return const <ActivityEntry>[];
    }
  }

  ActivityEntry? _toActivity(OdooRecord record) {
    final body = record.readHtmlAsText(MailMessageFields.body);
    final subject = record.readString(MailMessageFields.subject);
    final title = subject ?? body;
    final occurredAt = record.readDate(MailMessageFields.date);

    if (title == null || occurredAt == null) return null;

    // Chatter bodies can run long; the feed row shows one line.
    final headline = title.split('\n').first.trim();

    return ActivityEntry(
      id: record.recordId,
      title: headline,
      occurredAt: occurredAt,
      detail: record.readRef(MailMessageFields.authorId)?.name,
      assetId: record.readInt(MailMessageFields.resId),
      kind: _classify(headline),
    );
  }

  /// Infers the entry's kind from the note the app itself wrote.
  ///
  /// Matched against the English the repository posts to the chatter, which is
  /// fixed regardless of the phone's language — see `_AssetNote`.
  static ActivityKind _classify(String headline) {
    final text = headline.toLowerCase();
    if (text.startsWith('assigned to')) return ActivityKind.assigned;
    if (text.startsWith('returned')) return ActivityKind.returned;
    if (text.contains('maintenance') || text.contains('repair')) {
      return ActivityKind.maintenance;
    }
    if (text.contains('created')) return ActivityKind.created;
    return ActivityKind.note;
  }

  Future<int> _count(OdooDomain domain) =>
      _odoo.searchCount(model: _model, domain: domain);
}
