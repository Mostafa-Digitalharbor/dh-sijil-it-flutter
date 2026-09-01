import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_lifecycle.dart';

/// How far through its working life an asset is, and what it has cost.
///
/// ## Why the arithmetic is worth pinning
///
/// Both inputs were already on the record and the app did nothing with
/// either. The value they add is entirely in the derivation, so the derivation
/// is where this can be quietly wrong — and a replacement list that disagrees
/// with the screen it navigates to is worse than no replacement list.
///
/// The cost figure is the one that changes conversations: a 2,400 laptop
/// bought four years ago has cost 600 a year, and the same laptop replaced
/// after eighteen months cost 1,600 a year. Getting the divisor wrong turns
/// the argument for buying the better machine into the argument against it.
void main() {
  final now = DateTime(2026, 8, 29);

  AssetLifecycle at({
    required DateTime purchased,
    double? value,
    int? serviceLifeMonths,
  }) => AssetLifecycle.evaluate(
    purchaseDate: purchased,
    purchaseValue: value,
    now: now,
    serviceLifeMonths: serviceLifeMonths ?? AppConstants.assetServiceLifeMonths,
  );

  group('age', () {
    test('counts whole months only', () {
      expect(at(purchased: DateTime(2026, 6, 29)).ageInMonths, 2);
    });

    test('a month is not complete until the day comes round', () {
      // Bought on the 30th of January, an asset is nought months old on the
      // 15th of February — not one the moment the calendar flips.
      final lifecycle = AssetLifecycle.evaluate(
        purchaseDate: DateTime(2026, 1, 30),
        now: DateTime(2026, 2, 15),
      );

      expect(lifecycle.ageInMonths, 0);
    });

    test('and is complete on the day itself', () {
      final lifecycle = AssetLifecycle.evaluate(
        purchaseDate: DateTime(2026, 1, 30),
        now: DateTime(2026, 2, 28),
      );

      expect(lifecycle.ageInMonths, 0);
      expect(
        AssetLifecycle.evaluate(
          purchaseDate: DateTime(2026, 1, 30),
          now: DateTime(2026, 3, 30),
        ).ageInMonths,
        2,
      );
    });

    test('bought today is nought months old, not an error', () {
      expect(at(purchased: now).ageInMonths, 0);
      expect(at(purchased: now).state, LifecycleState.healthy);
    });
  });

  group('state', () {
    test('a new asset is healthy', () {
      expect(
        at(purchased: DateTime(2025, 8, 29)).state,
        LifecycleState.healthy,
      );
    });

    test('one inside the notice window is ageing', () {
      // Five-year life, so 55 months in leaves five months.
      final lifecycle = at(purchased: DateTime(2022, 1, 29));

      expect(lifecycle.state, LifecycleState.ageing);
      expect(
        lifecycle.remainingMonths,
        lessThanOrEqualTo(AppConstants.assetReplacementNoticeMonths),
      );
      expect(lifecycle.remainingMonths, greaterThan(0));
    });

    test('one past its life is overdue, and says by how much', () {
      final lifecycle = at(purchased: DateTime(2020, 8, 29));

      expect(lifecycle.state, LifecycleState.overdue);
      expect(lifecycle.isOverdue, isTrue);
      expect(lifecycle.monthsOverdue, 12);
    });

    test('only ageing and overdue ask for attention', () {
      expect(LifecycleState.healthy.needsAttention, isFalse);
      expect(LifecycleState.unknown.needsAttention, isFalse);
      expect(LifecycleState.ageing.needsAttention, isTrue);
      expect(LifecycleState.overdue.needsAttention, isTrue);
    });

    test('a shorter service life moves the boundary', () {
      // The constant is one number for the whole fleet, but the factory takes
      // it so a caller can ask a different question.
      final lifecycle = at(
        purchased: DateTime(2023, 8, 29),
        serviceLifeMonths: 24,
      );

      expect(lifecycle.state, LifecycleState.overdue);
    });
  });

  group('an asset with nothing to measure from', () {
    test('no purchase date is unknown, not new', () {
      // The overwhelming majority of a freshly-imported fleet. Guessing
      // "bought today" would put a five-year-old laptop at the healthy end and
      // make the whole screen wrong.
      final lifecycle = AssetLifecycle.evaluate(purchaseDate: null, now: now);

      expect(lifecycle.state, LifecycleState.unknown);
      expect(lifecycle.ageInMonths, isNull);
      expect(lifecycle.remainingMonths, isNull);
    });

    test('a date in the future is a typo, not a prediction', () {
      final lifecycle = at(purchased: DateTime(2035, 1, 1));

      expect(
        lifecycle.state,
        LifecycleState.unknown,
        reason:
            'negative age would report six years of life left because '
            'somebody typed 2035',
      );
    });
  });

  group('cost per year', () {
    test('a four-year-old 2,400 machine has cost 600 a year', () {
      final lifecycle = at(purchased: DateTime(2022, 8, 29), value: 2400);

      expect(lifecycle.annualisedCost, closeTo(600, 0.01));
    });

    test('the same machine replaced after eighteen months cost 1,600', () {
      final lifecycle = at(purchased: DateTime(2025, 2, 28), value: 2400);

      expect(
        lifecycle.annualisedCost,
        closeTo(1600, 1),
        reason: 'this is the number that argues for the better machine',
      );
    });

    test('an asset bought this month has no meaningful annual cost', () {
      // Anything divided by nought months is either a crash or a number with
      // six figures in it.
      expect(at(purchased: now, value: 2400).annualisedCost, isNull);
    });

    test('no price means no figure, rather than zero', () {
      expect(at(purchased: DateTime(2022, 8, 29)).annualisedCost, isNull);
    });

    test('a zero price is treated as no price', () {
      // Odoo reports an unset cost as 0.0, and "this laptop cost nothing per
      // year" is a claim the screen should not make.
      expect(
        at(purchased: DateTime(2022, 8, 29), value: 0).annualisedCost,
        isNull,
      );
    });
  });

  group('progress', () {
    test('runs from nought to one across the expected life', () {
      expect(at(purchased: now).progress, 0);
      expect(at(purchased: DateTime(2024, 2, 29)).progress, closeTo(0.5, 0.02));
    });

    test('is clamped, so an old machine draws a full bar not a longer one', () {
      expect(at(purchased: DateTime(2015, 1, 1)).progress, 1);
    });

    test('is nought when there is nothing to measure', () {
      expect(AssetLifecycle.unknown.progress, 0);
    });
  });

  group('monthsOverdue', () {
    test('is nought while there is life left', () {
      expect(at(purchased: DateTime(2025, 8, 29)).monthsOverdue, 0);
    });

    test('and is never negative', () {
      expect(AssetLifecycle.unknown.monthsOverdue, 0);
    });
  });
}
