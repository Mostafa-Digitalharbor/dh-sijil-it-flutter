import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats the numbers the UI *counts with*.
///
/// ## The rule this exists to enforce
///
/// A **count** follows the language: Arabic renders `١٢٤`, English `124`. An
/// **identifier** never does — an asset tag, a serial, an ISO date, an Odoo
/// version and a MAC address stay Latin in every locale, because they are
/// printed on the hardware in Latin and the user is holding the screen next to
/// the sticker to compare them. Identifiers go through `MonoText`, which is the
/// other half of the rule.
///
/// Getting this wrong is not cosmetic. Before this existed the dashboard put
/// "١٢٤ أصل" in a heading directly above a chip reading "124", because the
/// heading came from an ARB string and the chip came from `'$count'` — Dart
/// interpolation is always Latin, whatever the locale. One screen, two
/// numbering systems, same number.
abstract final class AppNumber {
  /// A count, localised. Use for anything the user would say out loud as a
  /// quantity: totals, tallies, badge numbers, "N open".
  ///
  /// Takes `num` rather than `int` because a chart axis carries the same
  /// numbers through a `num`, and the alternative — casting at each call site —
  /// is how one of them ends up bypassing this and printing Latin digits into
  /// an Arabic screen.
  static String count(BuildContext context, num value) =>
      NumberFormat.decimalPattern(_numberLocale(context)).format(value);

  /// A fraction rendered as a percentage — `0.72` becomes `٧٢٪` or `72%`.
  static String percent(BuildContext context, double fraction) =>
      NumberFormat.percentPattern(_numberLocale(context)).format(fraction);

  /// A percentage change, signed.
  ///
  /// The sign is the point: bare "120%" reads as *a level* — at 120% of
  /// something — while "+120%" reads as *growth*, which is what a trend line
  /// shows. Negative values already carry their own sign.
  ///
  /// The isolate matters. "+" is a bidi-neutral character, so in an Arabic line
  /// it does not belong to the number until it is told to: without the wrapper
  /// the plus detaches and renders on the far side, turning "+120%" into
  /// "120%+".
  static String signedPercent(BuildContext context, double fraction) {
    final formatted = percent(context, fraction);
    if (fraction <= 0) return formatted;
    return '$_isolateStart+$formatted$_isolateEnd';
  }

  /// FIRST STRONG ISOLATE / POP DIRECTIONAL ISOLATE.
  ///
  /// Deliberately *first-strong* rather than a hard LTR isolate: the direction
  /// is then taken from the digits themselves, so a Latin "120%" lays out
  /// left-to-right and an Arabic-Indic "١٢٠٪" lays out right-to-left, and the
  /// sign stays attached in both.
  static const String _isolateStart = '\u2068';
  static const String _isolateEnd = '\u2069';

  /// The locale to format numbers in.
  ///
  /// Arabic needs pinning to a country. CLDR's generic `ar` switched to Latin
  /// digits — `NumberFormat.decimalPattern('ar').format(124)` returns `124` —
  /// while `ar_EG` keeps the Arabic-Indic set this product's copy is written
  /// in ("١٢ شهر", "٣٠ يومًا"). Leaving it as plain `ar` is what put Latin
  /// counts next to Arabic-Indic prose on the same card.
  static String _numberLocale(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode != 'ar') return locale.toString();
    return locale.countryCode == null ? 'ar_EG' : locale.toString();
  }
}
