import '../../constants/app_constants.dart';
import '../../constants/odoo_models.dart';
import 'odoo_object_service.dart';
import 'odoo_value.dart';

/// One entry in a record's chatter.
class ChatterEntry {
  const ChatterEntry({
    required this.id,
    required this.body,
    required this.postedAt,
    this.author,
    this.subject,
  });

  final int id;

  /// Plain text. Odoo stores the body as HTML, and every consumer in this app
  /// renders it into a Flutter `Text`, so the tag stripping happens once here
  /// rather than in each caller.
  final String body;

  final DateTime? postedAt;
  final OdooNameRef? author;
  final String? subject;
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
/// Reading `mail.message` needs no special right beyond read access on the
/// record itself, but a hardened instance can still refuse. Callers treat an
/// empty list and a failure differently: the first means "nothing happened
/// yet", the second is surfaced.
class OdooChatterService {
  const OdooChatterService(this._odoo);

  final OdooObjectService _odoo;

  /// Chatter for [id] on [model], newest first.
  Future<List<ChatterEntry>> history({
    required String model,
    required int id,
    int limit = AppConstants.historyLimit,
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
      fields: MailMessageFields.readSet,
      order: '${MailMessageFields.date} desc',
      limit: limit,
    );

    final entries = <ChatterEntry>[];
    for (final record in records) {
      final entryId = record.readInt(MailMessageFields.id);
      if (entryId == null) continue;

      final body = record.readHtmlAsText(MailMessageFields.body);
      final subject = record.readString(MailMessageFields.subject);
      // A tracking-only row has no body — Odoo renders it from the tracking
      // values, which are not in this read. Nothing to show, so drop it.
      if (body == null && subject == null) continue;

      entries.add(
        ChatterEntry(
          id: entryId,
          body: body ?? subject!,
          postedAt: record.readDate(MailMessageFields.date),
          author: record.readRef(MailMessageFields.authorId),
          subject: subject,
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
  /// and a list that loads.
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
}
