import 'package:equatable/equatable.dart';

import 'page_request.dart';

/// The records for one page plus enough metadata to drive infinite scroll.
class PaginatedResult<T> extends Equatable {
  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.request,
    int? scannedCount,
  }) : _scannedCount = scannedCount;

  const PaginatedResult.empty()
    : items = const [],
      totalCount = 0,
      request = const PageRequest(),
      _scannedCount = null;

  final List<T> items;

  /// Result of Odoo's `search_count` for the same domain.
  final int totalCount;

  /// The page this result answered. After a [merge] it is the most recent one.
  final PageRequest request;

  /// How far into the server's result set the app has read, counted from zero
  /// and **before** any narrowing done on the device.
  ///
  /// Needed because two filters — the warranty buckets and the three
  /// local-overlay statuses — have no Odoo field to query on, so the
  /// repository widens the domain and drops non-matching rows in Dart. Without
  /// this, [hasMore] would compare a narrowed count against an unnarrowed
  /// total and keep requesting pages that do not exist.
  ///
  /// It is an absolute position rather than a per-page delta so that [merge]
  /// can simply take the newer value instead of summing — summing would
  /// double-count the offset that is already baked into each page.
  final int? _scannedCount;

  int get scannedCount => _scannedCount ?? request.offset + items.length;

  /// True while the server still has rows beyond the ones read so far.
  bool get hasMore => scannedCount < totalCount;

  /// How many rows the user is actually looking at.
  int get loadedCount => items.length;

  PaginatedResult<T> merge(PaginatedResult<T> next) => PaginatedResult<T>(
    items: [...items, ...next.items],
    totalCount: next.totalCount,
    request: next.request,
    // The later page already knows the absolute position; `max` guards the
    // case where an out-of-order response would otherwise rewind it.
    scannedCount: next.scannedCount > scannedCount
        ? next.scannedCount
        : scannedCount,
  );

  @override
  List<Object?> get props => [items, totalCount, request, scannedCount];
}
