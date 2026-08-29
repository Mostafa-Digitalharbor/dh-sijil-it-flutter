/// Builds RFC 4180 CSV.
///
/// Hand-written rather than a package, for one reason that is not code size:
/// the escaping rule is the whole job, and an asset name containing a comma —
/// "Dell UltraSharp, 27 inch" — is not an edge case in this data, it is
/// Tuesday. Six lines that are tested beat a dependency that is not.
abstract final class CsvWriter {
  /// A UTF-8 BOM.
  ///
  /// Excel on Windows reads a BOM-less UTF-8 file as the system codepage, so
  /// an Arabic asset name opens as mojibake — on the one platform an IT
  /// manager is most likely to open it with. Every other reader ignores it.
  static const String bom = '\u{FEFF}';

  static String rows(List<List<String>> rows, {bool withBom = true}) {
    final text = rows.map(line).join('\r\n');
    return withBom ? '$bom$text' : text;
  }

  /// One record, terminated by the caller.
  static String line(List<String> cells) => cells.map(cell).join(',');

  /// Quotes only what has to be quoted, and doubles an embedded quote.
  ///
  /// A leading `=`, `+`, `-` or `@` is also escaped: a spreadsheet treats
  /// those as the start of a formula, which turns an exported asset name into
  /// code the recipient's machine runs. It is a real attack against exports
  /// and the fix belongs here rather than in every caller.
  static String cell(String value) {
    final risky = value.startsWith(RegExp(r'[=+\-@]'));
    final escaped = risky ? "'$value" : value;

    if (!escaped.contains(RegExp('[",\r\n]'))) return escaped;
    return '"${escaped.replaceAll('"', '""')}"';
  }
}
