import '../../domain/entities/asset_history.dart';
import '../../domain/entities/asset_status.dart';

/// The wording the app posts to an asset's chatter, and the rules for reading
/// it back.
///
/// ## Why one class owns both directions
///
/// Odoo's chatter has no structured "kind of event" field — a note is a string.
/// The history screen has to recover the kind from that string, which means
/// matching on the same words the app wrote. Keeping the composer and the
/// classifier apart is how that goes wrong: someone rewords "Assigned to" and
/// every past handover silently becomes a generic note, with no compile error
/// and no failing test unless one exists for exactly this.
///
/// Here they cannot drift, because the prefix is a constant both sides use.
///
/// ## Why the notes stay English
///
/// The chatter is read in Odoo's web client by whoever opens the record —
/// finance, HR, an auditor — not only by this app's user. A log in whatever
/// language the phone happened to be set to at the time is worse than one
/// consistent language, and English is what the rest of a stock Odoo writes.
abstract final class AssetNoteVocabulary {
  static const String assignedPrefix = 'Assigned to';
  static const String returnedPrefix = 'Returned';
  static const String statusPrefix = 'Status set to';
  static const String auditPrefix = 'Audit';
  static const String handoverPrefix = 'Handover';

  /// Joins a headline and the user's own note.
  ///
  /// A dash rather than a newline: Odoo wraps the whole body in one `<p>`, and
  /// HTML collapses a newline to a space, so a line break would silently
  /// become a run-on sentence.
  static String compose(String headline, String? notes) {
    final trimmed = notes?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? headline
        : '$headline — $trimmed';
  }

  /// The part of an assignment note that says it was one item in a signed
  /// handover.
  ///
  /// Written as the *tail* of "Assigned to X on D — …" rather than as a second
  /// note, so each asset's chatter carries one entry for one event. Two notes
  /// would have said the same thing twice on every record in the bundle, and
  /// the history screen would have shown the handover as two rows.
  ///
  /// The whole bundle is listed on every asset in it: opening one record and
  /// finding "and these three went with it" is the question a handover note is
  /// actually asked, and it cannot be answered by a note that only names
  /// itself.
  static String handoverDetail({
    required List<String> items,
    required String fingerprint,
    String? notes,
  }) => compose(
    '$handoverPrefix of ${items.length} '
    '${items.length == 1 ? 'item' : 'items'}: ${items.join(', ')}. '
    'Signed by the recipient ($fingerprint).',
    notes,
  );

  /// The note that *records* a Reserved / Damaged / Lost state.
  ///
  /// This string is not a description of the write — it **is** the write.
  /// Standard Odoo has no field for these three states and spec §2 forbids a
  /// custom addon, so the chatter is where they live; [statusIn] reads them
  /// back out. That is why the label comes from [_statusLabels] rather than
  /// being typed inline: the composer and the parser share one table, so a
  /// reworded label cannot silently orphan every status ever written.
  static String statusNote(AssetStatus status) => compose(
    '$statusPrefix ${_statusLabels[status]} by the Sijil IT mobile app. '
    'Standard Odoo has no field for this state, so this note is the record '
    'of it.',
    null,
  );

  /// The state a [statusNote] body records, or null if it is not one.
  ///
  /// Longest label first, so "Under maintenance" is not read as "Under" —
  /// and so a future label that starts with an existing one cannot shadow it.
  ///
  /// Reads notes written by every past version of the app: only the prefix
  /// and the label are matched, and the sentence after them was free to
  /// change (it did — it used to end "kept on the device that recorded it").
  static AssetStatus? statusIn(String body) {
    final text = body.trimLeft();
    if (!text.startsWith(statusPrefix)) return null;

    final rest = text.substring(statusPrefix.length).trimLeft();
    for (final entry in _statusLabelsByLength) {
      if (rest.startsWith(entry.value)) return entry.key;
    }
    return null;
  }

  /// Both directions of the status⇄label mapping, in one place.
  ///
  /// English on purpose, like every other note this class writes: the chatter
  /// is read in Odoo's web client by whoever opens the record, and a log whose
  /// wording depends on the phone's language at the time is one nobody can
  /// search.
  static const Map<AssetStatus, String> _statusLabels = <AssetStatus, String>{
    AssetStatus.available: 'Available',
    AssetStatus.assigned: 'Assigned',
    AssetStatus.reserved: 'Reserved',
    AssetStatus.underMaintenance: 'Under maintenance',
    AssetStatus.damaged: 'Damaged',
    AssetStatus.lost: 'Lost',
    AssetStatus.retired: 'Retired',
  };

  static final List<MapEntry<AssetStatus, String>> _statusLabelsByLength =
      _statusLabels.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

  /// What kind of event a chatter body describes.
  ///
  /// Anything this app did not write falls through to [AssetEventKind.note],
  /// which is the right answer: a comment somebody typed in the web client is
  /// a note, and guessing a richer kind from free text would be worse than
  /// admitting the app does not know.
  static AssetEventKind classify(String body) {
    final text = body.trimLeft();
    if (text.startsWith(assignedPrefix)) return AssetEventKind.assigned;
    if (text.startsWith(handoverPrefix)) return AssetEventKind.assigned;
    if (text.startsWith(returnedPrefix)) return AssetEventKind.returned;
    if (text.startsWith(statusPrefix)) return AssetEventKind.statusChanged;
    if (text.startsWith(auditPrefix)) return AssetEventKind.audited;
    return AssetEventKind.note;
  }
}
