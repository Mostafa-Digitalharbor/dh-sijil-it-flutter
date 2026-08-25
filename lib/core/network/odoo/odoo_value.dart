import '../../utils/typedefs.dart';
import 'odoo_object_service.dart';

/// Safe readers for the values Odoo actually puts on the wire.
///
/// Odoo does not send `null`. An unset `char`, `date`, `many2one` or `html`
/// field all come back as the boolean `false`, an unset `integer` as `0`, and
/// a `float` may arrive as an `int` when it happens to be whole. A mapper that
/// casts directly is therefore wrong on real data roughly as often as it is
/// right — so every field read in the app goes through this extension instead.
///
/// The rules, once, in one place:
///
/// | Odoo sends            | This returns |
/// |-----------------------|--------------|
/// | `false`               | `null`       |
/// | `''` or whitespace    | `null`       |
/// | `[id, "Name"]`        | `OdooNameRef`|
/// | `"2026-08-24"`        | `DateTime`   |
/// | `"<p>Note</p>"`       | `"Note"`     |
extension OdooValueReader on OdooRecord {
  /// The record's own id. Zero when absent, which no real record has.
  int get recordId => readInt('id') ?? 0;

  /// A text field, with Odoo's `false` and blank strings both collapsing to
  /// null so the UI shows its "not recorded" placeholder rather than an empty
  /// row that reads as a rendering bug.
  String? readString(String field) {
    final raw = this[field];
    if (raw == null || raw == false) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// An `html` field rendered as plain text.
  ///
  /// Odoo stores `note` and `description` as HTML, so a raw read shows the
  /// user `<p>Cracked display.</p>`. The app has no rich-text surface, so the
  /// markup is stripped rather than rendered.
  String? readHtmlAsText(String field) {
    final raw = readString(field);
    if (raw == null) return null;

    final text = raw
        // Block-level boundaries become line breaks before tags are dropped,
        // otherwise multi-paragraph notes collapse into one run-on sentence.
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(?:p|div|li|h[1-6])>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return text.isEmpty ? null : text;
  }

  int? readInt(String field) {
    final raw = this[field];
    if (raw == null || raw == false) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return int.tryParse(raw.toString());
  }

  /// An integer that is meaningful at zero — counters, mostly.
  int readCount(String field) => readInt(field) ?? 0;

  /// A float. Odoo drops the fraction when a `float` happens to be whole, so
  /// `cost` arrives as `int` for a round number and `double` otherwise.
  double? readDouble(String field) {
    final raw = this[field];
    if (raw == null || raw == false) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  bool readBool(String field) => this[field] == true;

  /// A `date` (`2026-08-24`) or `datetime` (`2026-08-24 09:31:02`).
  ///
  /// Odoo sends datetimes in UTC without a zone marker, so the string is
  /// parsed as UTC and converted, rather than being read as local time — which
  /// would shift every timestamp by the device's offset.
  DateTime? readDate(String field) {
    final raw = readString(field);
    if (raw == null) return null;

    // A bare date has no time component and no zone: it means that calendar
    // day everywhere, so it must not be shifted.
    if (raw.length == 10) return DateTime.tryParse(raw);

    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return null;
    return parsed.isUtc
        ? parsed.toLocal()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
          ).toLocal();
  }

  /// A `many2one`, which Odoo sends as `[id, "Display name"]` or `false`.
  OdooNameRef? readRef(String field) => OdooNameRef.fromPair(this[field]);

  /// The id half of a `many2one`, for building a domain.
  int? readRefId(String field) => readRef(field)?.id;

  /// A `one2many` / `many2many`, which Odoo sends as a list of ids.
  List<int> readIds(String field) {
    final raw = this[field];
    if (raw is! List) return const <int>[];
    return raw.whereType<int>().toList(growable: false);
  }

  /// A `selection`, validated against the values the app understands.
  ///
  /// Returns null for a value this build has never heard of, so a customised
  /// Odoo selection degrades to "unset" instead of throwing.
  String? readSelection(String field, Set<String> allowed) {
    final raw = readString(field);
    return (raw != null && allowed.contains(raw)) ? raw : null;
  }
}

/// Writers for the other direction: Dart values into an Odoo `create`/`write`
/// payload.
///
/// Odoo wants `false` to clear a field, never `null`, and dates in its own
/// `YYYY-MM-DD` form regardless of the device locale.
abstract final class OdooWrite {
  /// A `date` value for the wire. Pass null to clear the field.
  static Object date(DateTime? value) => value == null
      ? false
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  /// A `datetime` value for the wire, in UTC as Odoo stores it.
  static Object dateTime(DateTime? value) {
    if (value == null) return false;
    final utc = value.toUtc();
    return '${date(utc)} '
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')}';
  }

  /// A `char`/`text` value. Blank clears the field.
  static Object text(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? false : trimmed;
  }

  /// A `many2one`. Null clears the relation.
  static Object ref(int? id) => id ?? false;

  /// Plain text wrapped for an `html` field, with the characters that would
  /// otherwise inject markup escaped.
  static Object html(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;

    final escaped = trimmed
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    return '<p>${escaped.replaceAll('\n', '<br/>')}</p>';
  }

  const OdooWrite._();
}
