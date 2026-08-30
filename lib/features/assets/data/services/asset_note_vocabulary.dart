import '../../../../core/constants/odoo_models.dart';
import '../../../../core/network/odoo/odoo_chatter_service.dart';
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

  /// The marker that carries an expected return date.
  ///
  /// Unlike every other prefix here it is matched *anywhere* in a body rather
  /// than at the start, because it is a clause inside the assignment note
  /// rather than a note of its own. That is deliberate: one event should be
  /// one line in the history, and a second note saying "and it is due back on
  /// the 30th" would have shown every handover twice.
  static const String duePrefix = 'Due back';

  /// The words after [duePrefix] when a date was actually given.
  static const String dueOnJoiner = ' on ';

  /// What the clause says when nobody set a date.
  ///
  /// Written out rather than omitted, so that *every* assignment note carries
  /// the marker. The date is read back as "the newest note mentioning Due
  /// back", and a note that stayed silent would let the previous holder's
  /// date survive the next handover — quietly making a freshly-issued laptop
  /// overdue for a loan that ended months ago.
  static const String dueNotSet = ': not set';

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

  /// The sentence that records — or clears — an expected return date.
  ///
  /// English and ISO, like every other note this class writes: it is read in
  /// Odoo's web client by whoever opens the record, and `2026-09-30` is the
  /// one date format that cannot be read as the ninth of a different month.
  static String dueClause(DateTime? due) => due == null
      ? '$duePrefix$dueNotSet.'
      : '$duePrefix$dueOnJoiner${isoDay(due)}.';

  /// The date a body promises the asset back, or null when it names none.
  ///
  /// Searched anywhere in the text, because the clause rides along with the
  /// assignment sentence. Reads notes written by every version of the app that
  /// has one: only the marker and the ISO date are matched.
  static DateTime? dueDateIn(String body) {
    final marker = body.indexOf(duePrefix);
    if (marker < 0) return null;

    final rest = body.substring(marker + duePrefix.length);
    if (!rest.startsWith(dueOnJoiner)) return null;

    // Exactly ten characters: `DateTime.tryParse` would otherwise happily
    // swallow the rest of the sentence as a time component.
    final date = rest.substring(dueOnJoiner.length);
    if (date.length < _isoDayLength) return null;
    return DateTime.tryParse(date.substring(0, _isoDayLength));
  }

  /// `2026-09-30`. The one date format the chatter ever carries.
  static String isoDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static const int _isoDayLength = 10;

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

  /// What kind of event a set of *tracked field changes* describes.
  ///
  /// This is the half of an asset's history the app did not write. Odoo logs a
  /// row like this whenever somebody edits a tracked field in the web client,
  /// and matching on the technical field name is what turns "Used By changed"
  /// into a handover the timeline can draw the same way it draws its own.
  ///
  /// Matched on the name, never on the label: the label arrives in whatever
  /// language the person making the change had Odoo set to, so a rule written
  /// against it would work in one office and silently stop at the border.
  static AssetEventKind classifyChange(List<TrackedChange> changes) {
    for (final change in changes) {
      if (change.field != EquipmentFields.employeeId) continue;
      return change.isSet ? AssetEventKind.assigned : AssetEventKind.returned;
    }
    return AssetEventKind.note;
  }

  /// The person an assignment note names, or null when it names nobody.
  ///
  /// Feeds the holder count, which is a count of *people* — so it has to see
  /// that "Assigned to Ahmed Mohamed on 2026-01-04." and a tracked change
  /// setting Used By to "Ahmed Mohamed" are the same person receiving the same
  /// device once, not twice.
  static String? holderIn(String body) {
    final text = body.trimLeft();
    if (!text.startsWith(assignedPrefix)) return null;

    final rest = text.substring(assignedPrefix.length).trim();
    final end = rest.indexOf(_assignedOnJoiner);
    final name = (end < 0 ? rest : rest.substring(0, end)).trim();
    return name.isEmpty ? null : name;
  }

  /// The holder a tracked change hands the asset to, or null for anything
  /// else — including a change that *clears* the holder.
  static String? holderInChange(List<TrackedChange> changes) {
    for (final change in changes) {
      if (change.field != EquipmentFields.employeeId) continue;
      return change.isSet ? change.to : null;
    }
    return null;
  }

  /// What separates the holder's name from the date in an assignment note.
  static const String _assignedOnJoiner = ' on ';
}
