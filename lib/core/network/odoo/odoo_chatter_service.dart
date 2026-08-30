import '../../constants/app_constants.dart';
import '../../constants/odoo_models.dart';
import '../../utils/logger.dart';
import '../../utils/typedefs.dart';
import 'odoo_capability_service.dart';
import 'odoo_object_service.dart';
import 'odoo_value.dart';

/// One tracked field change, as Odoo recorded it.
///
/// The pieces are kept apart rather than pre-formatted because the caller
/// decides two different things with them: what the line *says*, and what kind
/// of event it *was*. "Used By: Ahmed Mohamed" is a handover, and only
/// [field] — the technical name — can say so, because [label] is whatever
/// language the person who made the change had Odoo set to.
class TrackedChange {
  const TrackedChange({required this.label, this.field, this.from, this.to});

  /// Odoo's own label for the field, in the reader's Odoo language.
  final String label;

  /// The technical name (`employee_id`), when it could be resolved.
  final String? field;

  /// The values, as text. Null means the field was empty on that side.
  final String? from;
  final String? to;

  /// Whether this change put something into a field that was empty.
  bool get isSet => (to ?? '').isNotEmpty;

  /// Whether this change emptied a field that had something in it.
  bool get isCleared => (to ?? '').isEmpty && (from ?? '').isNotEmpty;
}

/// One entry in a record's chatter.
class ChatterEntry {
  const ChatterEntry({
    required this.id,
    required this.body,
    required this.postedAt,
    this.author,
    this.subject,
    this.changes = const <TrackedChange>[],
  });

  final int id;

  /// Plain text. Odoo stores the body as HTML, and every consumer in this app
  /// renders it into a Flutter `Text`, so the tag stripping happens once here
  /// rather than in each caller.
  ///
  /// For a row Odoo left empty because it *is* a field change, this is the
  /// sentence composed from [changes] — the same sentence the web client
  /// renders in the browser.
  final String body;

  final DateTime? postedAt;
  final OdooNameRef? author;
  final String? subject;

  /// The tracked field changes this message recorded, if any.
  final List<TrackedChange> changes;
}

/// Reads a record's chatter — the log Odoo already keeps of everything that
/// happened to it.
///
/// ## Why this is worth a service
///
/// The app has been *writing* to the chatter since the first release: every
/// assignment, return and status change posts a note. Nothing ever read it
/// back, so an asset's whole history existed on the server and was visible
/// only in the web client. The history screen is almost entirely this call —
/// no new fields, no new writes, no migration.
///
/// ## Why it reads `mail.tracking.value` too
///
/// Because the log was only half of the record. A `mail.message` posted for a
/// *field change* — somebody setting "Used By" on the equipment form in Odoo
/// — carries no body at all: Odoo renders that sentence in the browser, from
/// tracking rows this service used to ignore and then drop as "nothing to
/// show". So an asset handed over in the web client had a history in which the
/// handover had not happened, and a holder count of zero next to a detail
/// screen naming the holder.
///
/// The fix is one extra read per page of history, and it works retroactively:
/// every tracked change the customer's database already holds appears the
/// moment this ships.
///
/// Reading `mail.message` needs no special right beyond read access on the
/// record itself, but a hardened instance can still refuse. Callers treat an
/// empty list and a failure differently: the first means "nothing happened
/// yet", the second is surfaced.
class OdooChatterService {
  OdooChatterService(this._odoo, this._capabilities);

  final OdooObjectService _odoo;
  final OdooCapabilityService _capabilities;

  /// `ir.model.fields` id → technical name, memoised for the process.
  ///
  /// A field's technical name cannot change while the app is running, and the
  /// same handful of fields are tracked on every asset — so a fleet's whole
  /// history costs one lookup per distinct field, not one per page.
  final Map<int, String> _fieldNames = <int, String>{};

  /// Chatter for [id] on [model], newest first.
  Future<List<ChatterEntry>> history({
    required String model,
    required int id,
    int limit = AppConstants.historyLimit,
    int offset = 0,
  }) async {
    final records = await _odoo.searchRead(
      model: OdooModels.mailMessage,
      domain: <List<Object?>>[
        <Object?>[MailMessageFields.model, '=', model],
        <Object?>[MailMessageFields.resId, '=', id],
        // Odoo logs a tracking row for every field change, including ones the
        // app never touches. Keeping notes and comments is what makes the
        // timeline read as a history of *events* rather than of writes.
        <Object?>[
          MailMessageFields.messageType,
          'in',
          <String>[
            MailMessageFields.typeComment,
            MailMessageFields.typeNotification,
          ],
        ],
      ],
      // Narrowed to what this instance has, like every other read set: it is
      // the one field here an older or trimmed Odoo can genuinely lack, and an
      // "invalid field" fault would take the whole history screen with it.
      fields: await _capabilities.supportedFields(
        OdooModels.mailMessage,
        MailMessageFields.readSet,
      ),
      order: '${MailMessageFields.date} desc',
      limit: limit,
      offset: offset,
    );

    final changes = await _changesFor(records);

    final entries = <ChatterEntry>[];
    for (final record in records) {
      final entryId = record.readInt(MailMessageFields.id);
      if (entryId == null) continue;

      final body = record.readHtmlAsText(MailMessageFields.body);
      final subject = record.readString(MailMessageFields.subject);
      final tracked = changes[entryId] ?? const <TrackedChange>[];

      // A row with no body, no subject and no tracked change is one Odoo
      // renders from something this app does not read. Nothing to show.
      final text = body ?? subject ?? _describe(tracked);
      if (text == null) continue;

      entries.add(
        ChatterEntry(
          id: entryId,
          body: text,
          postedAt: record.readDate(MailMessageFields.date),
          author: record.readRef(MailMessageFields.authorId),
          subject: subject,
          changes: tracked,
        ),
      );
    }
    return entries;
  }

  /// The newest body per record that contains [contains], for a whole page of
  /// records in one round trip.
  ///
  /// ## Why this exists
  ///
  /// Three asset states — Reserved, Damaged, Lost — have no Odoo field, so the
  /// note the app posts *is* the record of them. Reading that back per row
  /// would be one XML-RPC call per asset; a fifty-row list would open with
  /// fifty round trips, which is the difference between a list that appears
  /// and a list that loads. The expected return date is recorded the same way
  /// and read back through the same call.
  ///
  /// Only `res_id` and `body` are read, and the domain filters to the marker
  /// before Odoo sends anything, so the payload is proportional to how many of
  /// these notes actually exist — which for most fleets is a handful, not one
  /// per asset.
  ///
  /// [limit] caps how deep the scan goes. Past it the oldest records simply do
  /// not appear in the result; callers treat a missing entry as "no state
  /// recorded", which is what a caller with no note at all also sees.
  /// [ids] null asks about every record of [model] — what the dashboard needs
  /// to count the states across a fleet it has no id list for. An *empty* list
  /// is the opposite question, and answering it with the whole fleet would be
  /// a fleet-wide read triggered by an empty page.
  Future<Map<int, String>> latestBodies({
    required String model,
    required String contains,
    List<int>? ids,
    int limit = AppConstants.markerNoteScanLimit,
  }) async {
    if (ids != null && ids.isEmpty) return const <int, String>{};

    final records = await _odoo.searchRead(
      model: OdooModels.mailMessage,
      domain: <List<Object?>>[
        <Object?>[MailMessageFields.model, '=', model],
        if (ids != null) <Object?>[MailMessageFields.resId, 'in', ids],
        <Object?>[MailMessageFields.body, 'like', contains],
      ],
      fields: <String>[MailMessageFields.resId, MailMessageFields.body],
      // Newest first, so the first row seen for a record is its current state
      // and every older note for it is skipped. `id` rather than `date`
      // because two notes posted in the same second are ordered by neither
      // the clock nor the payload — and re-recording a status twice in a row
      // is exactly what someone correcting a mistake does.
      order: '${MailMessageFields.id} desc',
      limit: limit,
    );

    final latest = <int, String>{};
    for (final record in records) {
      final id = record.readInt(MailMessageFields.resId);
      if (id == null || latest.containsKey(id)) continue;

      final body = record.readHtmlAsText(MailMessageFields.body);
      if (body != null) latest[id] = body;
    }
    return latest;
  }

  // ── Tracked field changes ────────────────────────────────────────────────

  /// The tracked changes for a page of messages, keyed by message id.
  ///
  /// One read for the whole page rather than one per message, and skipped
  /// entirely when nothing on the page has any — which is the common case for
  /// a fleet nobody edits in the web client.
  ///
  /// A failure here returns nothing rather than propagating: the notes the app
  /// wrote are the bulk of the history and are already in hand, and losing the
  /// screen because the *refinement* could not be read is the worse trade.
  Future<Map<int, List<TrackedChange>>> _changesFor(OdooRecords records) async {
    final wanted = <int>{};
    final byMessage = <int, Set<int>>{};

    for (final record in records) {
      final messageId = record.readInt(MailMessageFields.id);
      if (messageId == null) continue;

      final ids = record.readIds(MailMessageFields.trackingValueIds);
      if (ids.isEmpty) continue;

      byMessage[messageId] = ids.toSet();
      wanted.addAll(ids);
    }

    if (wanted.isEmpty) return const <int, List<TrackedChange>>{};

    try {
      final rows = await _odoo.read(
        model: OdooModels.mailTrackingValue,
        ids: wanted.toList(growable: false),
        fields: await _capabilities.supportedFields(
          OdooModels.mailTrackingValue,
          MailTrackingValueFields.readSet,
        ),
      );

      await _learnFieldNames(rows);

      final byId = <int, TrackedChange>{
        for (final row in rows)
          if (row.readInt(MailTrackingValueFields.id) case final int rowId)
            rowId: _toChange(row),
      };

      return <int, List<TrackedChange>>{
        for (final entry in byMessage.entries)
          entry.key: <TrackedChange>[
            for (final id in entry.value)
              if (byId[id] case final TrackedChange change) change,
          ],
      };
    } on Object catch (error) {
      AppLogger.warn('Tracked changes unavailable — $error');
      return const <int, List<TrackedChange>>{};
    }
  }

  /// Resolves the technical names of any tracked fields not seen before.
  ///
  /// The label alone cannot be reasoned about: "Used By" and "مستخدم بواسطة"
  /// are the same field, and only `employee_id` says which. One read per
  /// distinct field for the life of the process.
  Future<void> _learnFieldNames(OdooRecords rows) async {
    final unknown = <int>{};
    for (final row in rows) {
      final ref = _fieldRef(row);
      if (ref != null && !_fieldNames.containsKey(ref.id)) unknown.add(ref.id);
    }
    if (unknown.isEmpty) return;

    final fields = await _odoo.read(
      model: OdooModels.irModelFields,
      ids: unknown.toList(growable: false),
      fields: ModelFieldFields.readSet,
    );

    for (final field in fields) {
      final id = field.readInt(ModelFieldFields.id);
      final name = field.readString(ModelFieldFields.name);
      if (id != null && name != null) _fieldNames[id] = name;
    }
  }

  TrackedChange _toChange(OdooRecord row) {
    final ref = _fieldRef(row);

    for (final pair in MailTrackingValueFields.valuePairs) {
      final from = _readValue(row, pair.$1);
      final to = _readValue(row, pair.$2);
      if (from == null && to == null) continue;

      return TrackedChange(
        label: _labelFor(row, ref),
        field: ref == null ? null : _fieldNames[ref.id],
        from: from,
        to: to,
      );
    }

    // Every value column empty: Odoo records that when a field is cleared into
    // a type whose empty *is* the zero value. Still a change worth showing.
    return TrackedChange(
      label: _labelFor(row, ref),
      field: ref == null ? null : _fieldNames[ref.id],
    );
  }

  /// The link to `ir.model.fields`, under whichever name this Odoo uses.
  static OdooNameRef? _fieldRef(OdooRecord row) =>
      row.readRef(MailTrackingValueFields.fieldId) ??
      row.readRef(MailTrackingValueFields.fieldLegacy);

  /// The human label: Odoo ≤16's own column if it survives, otherwise the
  /// `ir.model.fields` display name — which *is* the translated description.
  static String _labelFor(OdooRecord row, OdooNameRef? ref) =>
      row.readString(MailTrackingValueFields.fieldDescription) ??
      ref?.name ??
      '';

  /// One value column as text, or null when Odoo left it empty.
  ///
  /// Numbers are read through the same path as text because the column type
  /// decides the shape, not the caller: a monetary change arrives as a double
  /// and a stage change as a string, and both end up in the same sentence.
  static String? _readValue(OdooRecord row, String field) {
    final raw = row[field];
    if (raw == null || raw == false) return null;
    final text = '$raw'.trim();
    return text.isEmpty ? null : text;
  }

  /// The sentence for a message whose whole content is its tracked changes.
  ///
  /// Returns null when there are none, which is how the caller tells "a field
  /// change" from "a row rendered out of something we do not read".
  static String? _describe(List<TrackedChange> changes) {
    if (changes.isEmpty) return null;

    return changes
        .map(
          (change) => <String>[
            if (change.label.isNotEmpty) '${change.label}: ',
            change.to ?? _emptyValue,
            if (change.from != null) ' ($_wasPrefix ${change.from})',
          ].join(),
        )
        .join('; ');
  }

  /// English, and deliberately so — like every other string this app writes
  /// into or reads out of a chatter that a colleague opens in the web client.
  /// It sits beside values Odoo itself supplied in the reader's own language,
  /// which is the same mixture the web client shows.
  static const String _wasPrefix = 'was';
  static const String _emptyValue = '—';
}
