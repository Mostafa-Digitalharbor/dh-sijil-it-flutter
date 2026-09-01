import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// Where an asset sits in its working life.
enum LifecycleState {
  /// No purchase date recorded, so there is nothing to measure from.
  ///
  /// The overwhelming majority of a freshly-imported fleet. Reported as its
  /// own state rather than as "new", because guessing that an undated asset
  /// was bought today would put a five-year-old laptop at the healthy end of
  /// the scale and quietly make the whole screen wrong.
  unknown,

  /// Comfortably inside its expected life.
  healthy,

  /// Inside [AppConstants.assetReplacementNoticeMonths] of the end of it.
  ageing,

  /// Past its expected service life and still in use.
  overdue;

  /// Whether this is worth putting in front of somebody.
  bool get needsAttention =>
      this == LifecycleState.ageing || this == LifecycleState.overdue;
}

/// What an asset has cost so far, and how much life it has left.
///
/// ## Why this exists
///
/// Everything needed for it was already on the record — a purchase date, a
/// purchase value — and the app did nothing with either beyond printing them
/// on a detail screen. That makes the product a register: it can tell you what
/// you own and who has it, and nothing about what to do next.
///
/// The question an IT manager actually has is "which of these do I replace
/// this year, and what will that cost?" Two numbers answer it, and both come
/// out of fields already being read:
///
/// * how far through its expected life a machine is, and
/// * what it has cost per year of that life so far.
///
/// The second is the one that changes conversations. A £2,400 laptop bought
/// four years ago has cost £600 a year; the same laptop replaced after
/// eighteen months cost £1,600 a year. Neither number is visible from a
/// purchase price on its own.
///
/// ## Why it is a value object
///
/// Same shape as [Warranty] and [ReturnDue], and for the same reason: the same
/// questions get asked on the detail screen, in the replacement list and in an
/// export, and all three have to agree about what "overdue" means down to the
/// month. Deciding it once, from an injectable clock, is what stops a list
/// disagreeing with the screen it navigates to.
class AssetLifecycle extends Equatable {
  const AssetLifecycle({
    required this.state,
    this.purchaseDate,
    this.purchaseValue,
    this.ageInMonths,
    this.remainingMonths,
    this.annualisedCost,
  });

  final LifecycleState state;

  final DateTime? purchaseDate;
  final double? purchaseValue;

  /// Whole months in service. Null when [purchaseDate] is unknown.
  final int? ageInMonths;

  /// Months left of the expected life. Negative once it is past.
  final int? remainingMonths;

  /// What the asset has cost for each year it has been in service.
  ///
  /// Null when there is no price, no date, or less than a month of service —
  /// dividing a purchase price by a few days produces a number that is
  /// arithmetically correct and completely misleading.
  final double? annualisedCost;

  static const AssetLifecycle unknown = AssetLifecycle(
    state: LifecycleState.unknown,
  );

  /// Builds the value object from what the record actually carries.
  ///
  /// [now] is injectable so tests never flake on a month boundary.
  factory AssetLifecycle.evaluate({
    DateTime? purchaseDate,
    double? purchaseValue,
    DateTime? now,
    int serviceLifeMonths = AppConstants.assetServiceLifeMonths,
  }) {
    if (purchaseDate == null) return AssetLifecycle.unknown;

    final today = now ?? DateTime.now();
    final age = _wholeMonthsBetween(purchaseDate, today);

    // A date in the future is a typo, not a prediction. Treated as unknown
    // rather than as negative age, which would otherwise report a laptop as
    // having six years of life left because somebody typed 2035.
    if (age < 0) return AssetLifecycle.unknown;

    final remaining = serviceLifeMonths - age;

    final state = switch (remaining) {
      <= 0 => LifecycleState.overdue,
      <= AppConstants.assetReplacementNoticeMonths => LifecycleState.ageing,
      _ => LifecycleState.healthy,
    };

    return AssetLifecycle(
      state: state,
      purchaseDate: purchaseDate,
      purchaseValue: purchaseValue,
      ageInMonths: age,
      remainingMonths: remaining,
      annualisedCost: _annualise(purchaseValue, age),
    );
  }

  bool get isOverdue => state == LifecycleState.overdue;

  /// How far through its expected life the asset is, from 0 to 1.
  ///
  /// Clamped at the top so a machine kept for eight years draws a full bar
  /// rather than one that has run off the end of its track.
  double get progress {
    final age = ageInMonths;
    if (age == null) return 0;
    return (age / AppConstants.assetServiceLifeMonths).clamp(0, 1).toDouble();
  }

  /// How many whole months late, or zero when it is not.
  int get monthsOverdue {
    final remaining = remainingMonths;
    if (remaining == null || remaining > 0) return 0;
    return -remaining;
  }

  /// Cost per year of service so far.
  ///
  /// Guarded at a month rather than at zero: an asset bought last Tuesday has
  /// an age of nought months, and anything divided by that is either a crash
  /// or a number with six figures in it.
  static double? _annualise(double? value, int ageInMonths) {
    if (value == null || value <= 0 || ageInMonths < 1) return null;
    return value / (ageInMonths / 12);
  }

  /// Whole months from [from] to [to], counting only completed ones.
  ///
  /// Day-aware: bought on the 30th of January, an asset is nought months old
  /// on the 15th of February and one month old on the 28th — not one month old
  /// the moment the calendar flips.
  static int _wholeMonthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months;
  }

  @override
  List<Object?> get props => <Object?>[
    state,
    purchaseDate,
    purchaseValue,
    ageInMonths,
    remainingMonths,
    annualisedCost,
  ];
}
