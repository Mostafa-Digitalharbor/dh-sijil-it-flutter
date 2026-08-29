/// How the app glues two facts onto one line.
///
/// ## Why a separator needs a home
///
/// `' · '` was written out at nine call sites. That is not merely repetition:
/// the middot is the character that broke Arabic. Set directly beside an
/// Arabic-Indic numeral it is bidi-neutral, so `"١٢ · ٣"` reordered on screen
/// and read back as a different number — a bug that survived a dozen
/// screenshots because it is invisible unless you already know the value.
///
/// With one definition, fixing that is one edit. With nine, it is nine edits
/// and a tenth call site written next week that never got the memo.
///
/// The strings here are punctuation, not words: they are identical in English
/// and Arabic and are deliberately **not** in the ARB files, which hold only
/// what a translator would change.
abstract final class AppText {
  /// Between two facts on one line — "IT · Systems Engineer".
  static const String separator = ' · ';

  /// Joins what is actually there.
  ///
  /// Nulls and blanks are dropped rather than rendered, because the failure
  /// mode of joining them is a row that opens or ends with a stray separator —
  /// which reads as missing data rather than as absent data.
  static String joined(Iterable<String?> parts) => parts
      .where((part) => part != null && part.trim().isNotEmpty)
      .map((part) => part!.trim())
      .join(separator);

  /// The same, but null when nothing survived — for a subtitle slot that
  /// should collapse rather than render an empty line.
  static String? joinedOrNull(Iterable<String?> parts) {
    final text = joined(parts);
    return text.isEmpty ? null : text;
  }

  /// What a screen reader hears for a labelled value: "Available: 12".
  ///
  /// The colon is punctuation in both languages the app ships, so it is a
  /// constant rather than a translated string — but it is a *constant*, so a
  /// locale that needs a different one has a single place to change.
  static String labelled(String label, String value) => '$label: $value';

  /// What a screen reader hears for a two-line row: "MacBook Pro, DH-LAP-0027".
  static String announced(String title, String subtitle) =>
      subtitle.isEmpty ? title : '$title, $subtitle';

  const AppText._();
}
