import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';

void main() {
  // Fixed "now" so the buckets never flake at a day boundary.
  final now = DateTime(2026, 8, 23);

  group('Warranty.evaluate', () {
    test('is unknown when Odoo has no warranty date', () {
      final warranty = Warranty.evaluate(now: now);

      expect(warranty.state, WarrantyState.unknown);
      expect(warranty.daysRemaining, isNull);
    });

    test('is valid beyond 90 days', () {
      final warranty = Warranty.evaluate(
        endDate: DateTime(2027, 1, 1),
        now: now,
      );

      expect(warranty.state, WarrantyState.valid);
      expect(warranty.needsAttentionValue, isFalse);
    });

    test('is expiringSoon inside 90 days', () {
      final warranty = Warranty.evaluate(
        endDate: DateTime(2026, 10, 23),
        now: now,
      );

      expect(warranty.state, WarrantyState.expiringSoon);
      expect(warranty.daysRemaining, 61);
    });

    test('is expiringCritical inside 30 days', () {
      final warranty = Warranty.evaluate(
        endDate: DateTime(2026, 9, 5),
        now: now,
      );

      expect(warranty.state, WarrantyState.expiringCritical);
      expect(warranty.daysRemaining, 13);
    });

    test('is expired with a negative day count the UI can render', () {
      final warranty = Warranty.evaluate(
        endDate: DateTime(2026, 8, 11),
        now: now,
      );

      expect(warranty.state, WarrantyState.expired);
      expect(warranty.daysRemaining, -12);
      expect(warranty.isExpired, isTrue);
    });

    test('treats an expiry later today as zero days left, not expired', () {
      final warranty = Warranty.evaluate(
        endDate: DateTime(2026, 8, 23, 23, 59),
        now: DateTime(2026, 8, 23, 8, 0),
      );

      expect(warranty.daysRemaining, 0);
      expect(warranty.state, WarrantyState.expiringCritical);
    });
  });
}

extension on Warranty {
  bool get needsAttentionValue => state.needsAttention;
}
