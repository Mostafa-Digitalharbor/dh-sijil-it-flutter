import 'package:equatable/equatable.dart';

import '../../../assets/domain/entities/asset.dart';

/// What a scan turned out to be.
///
/// ## Why three outcomes and not two
///
/// A count that only says *found* and *missing* cannot tell the difference
/// between an asset that is genuinely gone and one that is sitting two desks
/// away in the wrong scope. The third outcome is what makes a walk-around
/// worth doing: most "missing" assets are not missing, they have moved, and
/// only a scan can prove it.
enum AuditOutcome {
  /// Scanned, and expected in this audit's scope.
  found,

  /// Scanned, but not in scope — it belongs to a different category,
  /// department or holder than the one being counted.
  ///
  /// Standard Odoo's `maintenance.equipment` has no location field, so this
  /// cannot mean "moved rooms". It means what the data can actually support:
  /// this asset is physically here and the records say it belongs elsewhere.
  unexpected,

  /// In scope, never scanned. Only knowable once the walk is finished.
  missing,
}

/// One asset's result inside an audit.
class AuditEntry extends Equatable {
  const AuditEntry({
    required this.asset,
    required this.outcome,
    this.scannedAt,
  });

  final Asset asset;
  final AuditOutcome outcome;
  final DateTime? scannedAt;

  @override
  List<Object?> get props => <Object?>[asset.id, outcome, scannedAt];
}

/// What the audit is counting.
///
/// Scope is a real choice, not a formality: counting 400 assets in one pass is
/// a two-hour job nobody finishes, and counting the twelve laptops on the
/// second floor is ten minutes. The narrower the scope, the more likely the
/// count actually happens.
enum AuditScope { all, category, department }

/// A walk-around count in progress.
class AuditSession extends Equatable {
  const AuditSession({
    required this.startedAt,
    required this.scope,
    required this.expected,
    this.scopeLabel,
    this.results = const <int, AuditEntry>{},
    this.finishedAt,
  });

  final DateTime startedAt;
  final AuditScope scope;

  /// Human name of the scope — a category or department. Null for [all].
  final String? scopeLabel;

  /// Every asset the audit expects to find, by id. Read once at the start so
  /// the count is against a fixed set: an asset created mid-walk must not
  /// silently become "missing".
  final Map<int, Asset> expected;

  /// Scans so far, by asset id. A map, not a list, because scanning the same
  /// sticker twice is what people do when they are unsure — and it must not
  /// count the asset twice.
  final Map<int, AuditEntry> results;

  final DateTime? finishedAt;

  bool get isFinished => finishedAt != null;

  int get expectedCount => expected.length;

  int get foundCount =>
      results.values.where((e) => e.outcome == AuditOutcome.found).length;

  int get unexpectedCount =>
      results.values.where((e) => e.outcome == AuditOutcome.unexpected).length;

  /// In scope and not yet scanned.
  int get missingCount => expectedCount - foundCount;

  /// 0..1 over the expected set. Unexpected scans do not advance it: they are
  /// findings, not progress, and letting them push the ring past 100% would
  /// make it useless as a "how much is left" signal.
  double get progress =>
      expectedCount == 0 ? 0 : (foundCount / expectedCount).clamp(0.0, 1.0);

  /// Scans in the order they happened, newest first — the live feed.
  List<AuditEntry> get feed {
    final entries = results.values.toList()
      ..sort((a, b) {
        final at = a.scannedAt;
        final bt = b.scannedAt;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });
    return entries;
  }

  /// The assets that were never scanned. Meaningful only once finished.
  List<Asset> get missing => <Asset>[
    for (final entry in expected.entries)
      if (!results.containsKey(entry.key)) entry.value,
  ];

  AuditSession record(Asset asset, DateTime at) {
    return copyWith(
      results: <int, AuditEntry>{
        ...results,
        asset.id: AuditEntry(
          asset: asset,
          outcome: expected.containsKey(asset.id)
              ? AuditOutcome.found
              : AuditOutcome.unexpected,
          scannedAt: at,
        ),
      },
    );
  }

  AuditSession copyWith({Map<int, AuditEntry>? results, DateTime? finishedAt}) {
    return AuditSession(
      startedAt: startedAt,
      scope: scope,
      scopeLabel: scopeLabel,
      expected: expected,
      results: results ?? this.results,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    startedAt,
    scope,
    scopeLabel,
    expected.length,
    results,
    finishedAt,
  ];
}
