import 'package:equatable/equatable.dart';

/// A single page of an Odoo query (spec §20 — never fetch thousands of records
/// at once).
class PageRequest extends Equatable {
  const PageRequest({
    this.offset = 0,
    this.limit = defaultPageSize,
    this.order,
  });

  static const int defaultPageSize = 50;

  final int offset;
  final int limit;

  /// Odoo `order` clause, e.g. `'write_date desc'`.
  final String? order;

  PageRequest next() =>
      PageRequest(offset: offset + limit, limit: limit, order: order);

  PageRequest first() => PageRequest(limit: limit, order: order);

  @override
  List<Object?> get props => [offset, limit, order];
}
