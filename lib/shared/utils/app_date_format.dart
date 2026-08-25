import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// Every date the product renders, formatted in one place.
///
/// Two reasons this is not `DateFormat(...)` scattered through the widgets:
///
/// 1. **Locale.** `intl` needs the locale name passed explicitly; taking it
///    from the widget's `AppL10n` means an Arabic user sees Arabic month names
///    without any screen asking what the locale is.
/// 2. **Relative time is translated, not formatted.** "12 minutes ago" is a
///    sentence with a plural, so it comes from the ARB files, not from a
///    pattern string.
///
/// [now] is injectable on every relative method so tests are deterministic
/// and never flake when the clock rolls over mid-run.
@immutable
class AppDateFormat {
  const AppDateFormat(this._l10n, this._localeName);

  factory AppDateFormat.of(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppDateFormat(l10n, l10n.localeName);
  }

  final AppL10n _l10n;
  final String _localeName;

  /// `24 Aug 2026` — the default for list rows and compact facts.
  String day(DateTime? value) => value == null
      ? _l10n.labelUnknown
      : _westernDigits(DateFormat.yMMMd(_localeName).format(value));

  /// `24 August 2026` — for date pickers and confirmation screens, where the
  /// abbreviated month is ambiguous enough to matter.
  String dayLong(DateTime? value) => value == null
      ? _l10n.labelUnknown
      : _westernDigits(DateFormat('d MMMM y', _localeName).format(value));

  /// `24 Aug 2026, 09:31`.
  String dateAndTime(DateTime? value) => value == null
      ? _l10n.labelUnknown
      : _westernDigits(DateFormat.yMMMd(_localeName).add_Hm().format(value));

  /// A short, human description of how long ago something happened.
  ///
  /// Falls back to an absolute date past a week: "37 days ago" is a number the
  /// reader has to convert, whereas "18 Jul 2026" is the thing they wanted.
  String relative(DateTime? value, {DateTime? now}) {
    if (value == null) return _l10n.labelUnknown;

    final reference = now ?? DateTime.now();
    final elapsed = reference.difference(value);

    if (elapsed.isNegative) return day(value);
    if (elapsed.inMinutes < 1) return _l10n.timeJustNow;
    if (elapsed.inMinutes < 60) return _l10n.timeMinutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return _l10n.timeHoursAgo(elapsed.inHours);

    final days = _wholeDaysBetween(value, reference);
    if (days == 1) return _l10n.timeYesterday;
    if (days < 7) return _l10n.timeDaysAgo(days);

    return day(value);
  }

  /// "held 312 days" / "0 days" — the span an asset has been with someone.
  String daysSince(DateTime? value, {DateTime? now}) {
    if (value == null) return _l10n.labelUnknown;
    return _l10n.labelHeldDays(_wholeDaysBetween(value, now ?? DateTime.now()));
  }

  /// Rewrites Arabic-Indic digits (٠١٢) as Western ones (012).
  ///
  /// `intl` renders Arabic dates with Arabic-Indic numerals, which is correct
  /// for prose but wrong for this app: every other number on the same screen is
  /// Western — asset tags (`DH-LAP-0027`), serial numbers, counts, the Odoo
  /// version — because they come from the data rather than from a formatter.
  /// "٢٠ يوليو ٢٠٢٥ · 400 يومًا · DH-LAP-0012" on one card is the result, and
  /// picking one numeral system for the whole product is the only way out.
  /// Month and day names stay fully localized.
  static String _westernDigits(String value) {
    const arabicIndicZero = 0x0660;
    final buffer = StringBuffer();

    for (final rune in value.runes) {
      final offset = rune - arabicIndicZero;
      buffer.writeCharCode(offset >= 0 && offset <= 9 ? 0x30 + offset : rune);
    }
    return buffer.toString();
  }

  /// Whole calendar days between two moments, ignoring the time of day.
  ///
  /// Counted on the dates rather than on the elapsed `Duration`: something
  /// recorded at 23:00 yesterday is "1 day ago", not "0 days" because only
  /// ten hours of wall clock have passed.
  static int _wholeDaysBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }
}

/// `context.dates` — the entry point used throughout the UI.
extension AppDateFormatContext on BuildContext {
  AppDateFormat get dates => AppDateFormat.of(this);
}
