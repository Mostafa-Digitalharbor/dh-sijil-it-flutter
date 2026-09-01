import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats every number the UI renders.
///
/// ## The rule this exists to enforce
///
/// **The product uses one numeral system: Western digits, in every language.**
/// An Arabic screen reads `124 أصل`, not `١٢٤ أصل`.
///
/// That is a product decision rather than a technical one, and it is made here
/// so that it is made once. The reasoning:
///
/// * Most of the numbers on any screen in this app are **identifiers** — an
///   asset tag, a serial, a MAC address, an Odoo version, an ISO date. Those
///   are printed on the hardware in Western digits, and the user is holding
///   the phone next to the sticker to compare them character by character.
///   They can never be localised.
/// * A screen that localises the rest puts two numeral systems side by side.
///   The asset card did exactly that: `٧ يومًا` sat beside `20 يوليو 2026`
///   and `DH-LAP-0012`, three numbering conventions on one card.
///
/// So rather than split numbers into "counts, which follow the language" and
/// "identifiers, which do not" — a line that has to be redrawn correctly at
/// every call site, and was not — every number goes Western and the question
/// stops being asked.
///
/// The formatter still follows the locale for everything *except* the digits:
/// grouping, the decimal mark and the percent sign stay whatever the language
/// uses. Only the ten glyphs are pinned.
abstract final class AppNumber {
  /// A count. Use for anything the user would say out loud as a quantity:
  /// totals, tallies, badge numbers, "N open".
  ///
  /// Takes `num` rather than `int` because a chart axis carries the same
  /// numbers through a `num`, and the alternative — casting at each call site —
  /// is how one of them ends up bypassing this entirely.
  static String count(BuildContext context, num value) => latinDigits(
    NumberFormat.decimalPattern(_localeName(context)).format(value),
  );

  /// An amount of money, grouped and rounded to whole units.
  ///
  /// ## Why whole units
  ///
  /// Every figure this renders is either a purchase price or a price divided
  /// by a number of years, and nobody deciding whether to replace a laptop
  /// cares about the pence. "2,400" is a number somebody reads at a glance;
  /// "2,399.97" is one they have to parse.
  ///
  /// ## Why the symbol is optional and trailing-agnostic
  ///
  /// Odoo reports the company currency's symbol, and where it belongs is a
  /// property of the *language*, not of the currency — Arabic puts it after
  /// the number, English before. `NumberFormat.currency` with a locale gets
  /// that right; concatenating by hand does not, which is what the purchase
  /// figure used to do by not showing a symbol at all.
  static String money(BuildContext context, num? value, {String? symbol}) {
    if (value == null) return '';

    return latinDigits(
      NumberFormat.currency(
        locale: _localeName(context),
        symbol: symbol ?? '',
        decimalDigits: 0,
      ).format(value).trim(),
    );
  }

  /// A fraction rendered as a percentage — `0.72` becomes `72%`.
  static String percent(BuildContext context, double fraction) => latinDigits(
    NumberFormat.percentPattern(_localeName(context)).format(fraction),
  );

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

  /// A count shown as an increment — the "+3" badge over a photo thumbnail.
  ///
  /// Not an ARB string. "+{count}" carries no prose for a translator to
  /// translate, and routing it through gen_l10n produces `'+$countString'` in
  /// both locales — an unisolated sign, which is precisely the bug
  /// [signedPercent] describes.
  static String plusCount(BuildContext context, num value) =>
      '$_isolateStart+${count(context, value)}$_isolateEnd';

  /// Rewrites Arabic-Indic digits (`٠١٢`) as Western ones (`012`).
  ///
  /// The single implementation of the product's numeral rule. It is public and
  /// `AppDateFormat` uses it too: this logic existed in both files, and two
  /// copies of "which glyphs count as digits" is how one of them ends up
  /// covering a block the other does not — which is exactly what happened.
  ///
  /// ## Two blocks, not one
  ///
  /// Unicode has **two** Arabic-Indic digit ranges, and they are not
  /// interchangeable:
  ///
  /// * `U+0660`–`U+0669` — Arabic-Indic. Arabic (`ar_EG`) uses these: `١٢٤`.
  /// * `U+06F0`–`U+06F9` — *Extended* Arabic-Indic. Persian (`fa`) and Urdu
  ///   (`ur`) use these: `۱۲۴`. Different code points, near-identical shapes.
  ///
  /// Handling only the first is a bug that a reviewer cannot see, because the
  /// two sets render almost the same. The version of this that lived in
  /// `AppDateFormat` covered only the first.
  ///
  /// Belt and braces rather than dead code: the app resolves Arabic to plain
  /// `ar`, which CLDR already gives Western digits, so today this changes
  /// nothing on any string the product produces. That is the point — adding
  /// `ar_EG`, `fa` or `ur` later cannot silently reintroduce a second numeral
  /// system.
  static String latinDigits(String value) {
    const arabicIndicZero = 0x0660;
    const extendedArabicIndicZero = 0x06F0;
    const westernZero = 0x30;
    const digitsPerSet = 10;

    int? offsetOf(int rune) {
      for (final zero in const <int>[
        arabicIndicZero,
        extendedArabicIndicZero,
      ]) {
        final offset = rune - zero;
        if (offset >= 0 && offset < digitsPerSet) return offset;
      }
      return null;
    }

    if (!value.runes.any((r) => offsetOf(r) != null)) return value;

    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final offset = offsetOf(rune);
      buffer.writeCharCode(offset == null ? rune : westernZero + offset);
    }
    return buffer.toString();
  }

  /// FIRST STRONG ISOLATE / POP DIRECTIONAL ISOLATE.
  ///
  /// Deliberately *first-strong* rather than a hard LTR isolate: the direction
  /// is taken from the content itself, so the sign stays attached whichever
  /// way the surrounding line runs.
  ///
  /// Built from code points rather than written as literals. Both characters
  /// are invisible, so in source they are a pair of zero-width holes that a
  /// reviewer cannot see, an editor can silently drop, and the analyzer warns
  /// about for exactly that reason.
  static const int _firstStrongIsolate = 0x2068;
  static const int _popDirectionalIsolate = 0x2069;

  static final String _isolateStart = String.fromCharCode(_firstStrongIsolate);
  static final String _isolateEnd = String.fromCharCode(_popDirectionalIsolate);

  /// The locale `intl` formats against.
  ///
  /// Straight from the resolved locale now. This used to pin Arabic to `ar_EG`
  /// to *get* Arabic-Indic digits; that requirement is gone, and with it the
  /// empty `app_ar_EG.arb` whose only job was to make the pin resolve.
  static String _localeName(BuildContext context) =>
      Localizations.localeOf(context).toString();
}
