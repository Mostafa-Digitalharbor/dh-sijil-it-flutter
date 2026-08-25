import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/pagination/page_request.dart';
import 'package:sijil_it/core/pagination/paginated_result.dart';

/// Infinite scroll rests entirely on `hasMore`, and `hasMore` has to survive
/// the case where the app narrowed a page on the device — the warranty buckets
/// and the three local-overlay statuses have no Odoo field to filter on.
void main() {
  PaginatedResult<String> page({
    required List<String> items,
    required int total,
    int offset = 0,
    int limit = 50,
    int? scanned,
  }) => PaginatedResult<String>(
    items: items,
    totalCount: total,
    request: PageRequest(offset: offset, limit: limit),
    scannedCount: scanned,
  );

  group('hasMore', () {
    test('is false once the page covers the total', () {
      expect(page(items: ['a', 'b'], total: 2).hasMore, isFalse);
    });

    test('is true while the server has more rows', () {
      expect(page(items: ['a', 'b'], total: 10).hasMore, isTrue);
    });

    test('accounts for the offset of a later page', () {
      final second = page(items: ['c'], total: 3, offset: 2);
      expect(second.hasMore, isFalse);
    });
  });

  group('narrowed pages', () {
    test('paging follows what the server sent, not what survived', () {
      // The server returned 50 rows; only 2 matched a warranty bucket.
      final narrowed = page(items: ['a', 'b'], total: 200, scanned: 50);

      expect(narrowed.loadedCount, 2, reason: 'the user sees two');
      expect(narrowed.hasMore, isTrue, reason: '150 rows are still unread');
      expect(narrowed.scannedCount, 50);
    });

    test('a fully-narrowed page still advances', () {
      // Nothing matched, but the list must not conclude it has reached the end.
      final narrowed = page(items: <String>[], total: 200, scanned: 50);

      expect(narrowed.hasMore, isTrue);
    });

    test('stops once the scan reaches the total', () {
      final narrowed = page(items: <String>[], total: 50, scanned: 50);

      expect(narrowed.hasMore, isFalse);
    });
  });

  group('merge', () {
    test('appends the items', () {
      final merged = page(
        items: ['a'],
        total: 3,
      ).merge(page(items: ['b'], total: 3, offset: 1));

      expect(merged.items, ['a', 'b']);
    });

    test('takes the newer absolute scan position rather than summing', () {
      // Summing would double-count the offset already baked into each page and
      // end the list early.
      final merged = page(
        items: ['a'],
        total: 200,
        scanned: 50,
      ).merge(page(items: ['b'], total: 200, offset: 50, scanned: 100));

      expect(merged.scannedCount, 100);
      expect(merged.hasMore, isTrue);
    });

    test('an out-of-order response cannot rewind the scan position', () {
      final merged = page(
        items: ['a'],
        total: 200,
        scanned: 100,
      ).merge(page(items: ['b'], total: 200, offset: 0, scanned: 50));

      expect(merged.scannedCount, 100);
    });

    test('adopts the newer total', () {
      final merged = page(
        items: ['a'],
        total: 3,
      ).merge(page(items: ['b'], total: 2, offset: 1));

      expect(merged.totalCount, 2);
    });
  });

  test('scannedCount defaults to the offset plus what arrived', () {
    expect(page(items: ['a', 'b'], total: 9, offset: 4).scannedCount, 6);
  });

  test('an empty result is finished', () {
    const empty = PaginatedResult<String>.empty();

    expect(empty.hasMore, isFalse);
    expect(empty.loadedCount, 0);
  });
}
