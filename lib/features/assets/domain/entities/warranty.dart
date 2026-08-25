import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// Warranty bucket used by the dashboard and the warranty filter (spec §15).
enum WarrantyState {
  /// No warranty date recorded on the asset.
  unknown,

  /// Expires more than 90 days from now.
  valid,

  /// Expires within 90 days.
  expiringSoon,

  /// Expires within 30 days.
  expiringCritical,

  expired;

  bool get needsAttention => switch (this) {
    WarrantyState.expiringCritical ||
    WarrantyState.expiringSoon ||
    WarrantyState.expired => true,
    _ => false,
  };
}

/// Pure value object describing an asset's warranty position.
///
/// The calculation happens entirely in Flutter (spec §15) — Odoo stores only
/// the raw `warranty_date`, so nothing here depends on a server-side field.
class Warranty extends Equatable {
  const Warranty({
    this.startDate,
    this.endDate,
    required this.state,
    this.daysRemaining,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final WarrantyState state;

  /// Negative once expired, so the UI can render "expired 12 days ago"
  /// from the same number.
  final int? daysRemaining;

  static const Warranty unknown = Warranty(state: WarrantyState.unknown);

  /// Builds the value object from the raw dates.
  ///
  /// [now] is injectable so tests are deterministic and never flake at
  /// midnight.
  factory Warranty.evaluate({
    DateTime? startDate,
    DateTime? endDate,
    DateTime? now,
  }) {
    if (endDate == null) return Warranty.unknown;

    final today = _dateOnly(now ?? DateTime.now());
    final expiry = _dateOnly(endDate);
    final days = expiry.difference(today).inDays;

    final state = switch (days) {
      < 0 => WarrantyState.expired,
      <= AppConstants.warrantyWarningDays => WarrantyState.expiringCritical,
      <= AppConstants.warrantyNoticeDays => WarrantyState.expiringSoon,
      _ => WarrantyState.valid,
    };

    return Warranty(
      startDate: startDate,
      endDate: endDate,
      state: state,
      daysRemaining: days,
    );
  }

  bool get isExpired => state == WarrantyState.expired;

  /// Strips the time component so a warranty expiring later today counts as
  /// having 0 days left, not a fraction of a day.
  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  List<Object?> get props => [startDate, endDate, state, daysRemaining];
}
