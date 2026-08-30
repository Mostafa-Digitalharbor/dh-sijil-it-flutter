import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// Where an assigned asset stands against the date it was promised back.
enum ReturnDueState {
  /// Nobody set a date. The overwhelming majority of assignments — a laptop
  /// handed to a permanent employee has no return date and should never be
  /// reported as late.
  none,

  /// Due, but not soon enough to say anything about.
  scheduled,

  /// Due within [AppConstants.returnDueSoonDays].
  dueSoon,

  /// The date has passed and the asset is still assigned.
  overdue;

  /// Whether this state earns a badge on a list row.
  bool get needsAttention =>
      this == ReturnDueState.dueSoon || this == ReturnDueState.overdue;
}

/// Pure value object describing an asset's expected return.
///
/// ## Why this is a value object rather than two getters on [Asset]
///
/// The same three questions get asked in four places — the list row, the
/// detail screen, the overdue list and the repository's own filter — and each
/// of them has to agree about what "overdue" means down to the day boundary.
/// Deciding it once, from an injectable clock, is what stops the list saying
/// "3 days late" beside a filter that did not include the row.
///
/// Modelled on [Warranty] deliberately: same shape, same `evaluate` factory,
/// same `now` parameter, so somebody who has read one has read both.
class ReturnDue extends Equatable {
  const ReturnDue({required this.state, this.date, this.daysRemaining});

  /// The date the holder is expected to hand it back.
  final DateTime? date;

  final ReturnDueState state;

  /// Negative once the date has passed, so "4 days late" and "4 days left"
  /// come from the same number.
  final int? daysRemaining;

  /// No date recorded — which is not the same as "on time".
  static const ReturnDue none = ReturnDue(state: ReturnDueState.none);

  /// Builds the value object from the raw date.
  ///
  /// [isAssigned] is required rather than inferred, because an asset that has
  /// already come back cannot be late: the note recording its due date is
  /// still in the chatter, and reading that alone would keep a returned laptop
  /// on the overdue list forever.
  ///
  /// [now] is injectable so tests never flake at midnight.
  factory ReturnDue.evaluate({
    DateTime? date,
    required bool isAssigned,
    DateTime? now,
  }) {
    if (date == null || !isAssigned) return ReturnDue.none;

    final today = _dateOnly(now ?? DateTime.now());
    final due = _dateOnly(date);
    final days = due.difference(today).inDays;

    final state = switch (days) {
      < 0 => ReturnDueState.overdue,
      <= AppConstants.returnDueSoonDays => ReturnDueState.dueSoon,
      _ => ReturnDueState.scheduled,
    };

    return ReturnDue(date: date, state: state, daysRemaining: days);
  }

  bool get isOverdue => state == ReturnDueState.overdue;

  bool get isSet => date != null;

  /// How many whole days past the date, positive. Zero when not overdue, so a
  /// caller never has to negate a number to display it.
  int get daysLate {
    final days = daysRemaining;
    return (days == null || days >= 0) ? 0 : -days;
  }

  /// Strips the time so an asset due back later today is not already late.
  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  List<Object?> get props => <Object?>[date, state, daysRemaining];
}
