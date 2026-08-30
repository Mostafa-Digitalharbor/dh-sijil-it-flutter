import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_name_ref.dart';

/// What kind of thing happened to an asset.
///
/// Recovered from the chatter body, because Odoo's `mail.message` has no field
/// for it — see `AssetNoteVocabulary`. [note] is the honest fallback for
/// anything this app did not write, such as a comment somebody typed in the
/// web client.
enum AssetEventKind {
  assigned,
  returned,
  statusChanged,
  audited,
  maintenance,
  registered,
  note,
}

/// One line of an asset's history.
class AssetHistoryEntry extends Equatable {
  const AssetHistoryEntry({
    required this.id,
    required this.kind,
    required this.summary,
    this.occurredAt,
    this.author,
    this.holder,
  });

  final int id;
  final AssetEventKind kind;

  /// The chatter body as plain text.
  final String summary;

  final DateTime? occurredAt;

  /// Who wrote the entry — not who received the asset.
  final OdooNameRef? author;

  /// Who this entry handed the asset *to*, when it handed it to anybody.
  ///
  /// Separate from [summary] because the holder count is a count of people,
  /// and the two ways an asset changes hands — a note this app wrote and a
  /// tracked field change somebody made in the web client — say the same thing
  /// in two different sentences. Counting sentences made one person look like
  /// two.
  final String? holder;

  @override
  List<Object?> get props => <Object?>[
    id,
    kind,
    summary,
    occurredAt,
    author,
    holder,
  ];
}

/// An asset's whole service life.
///
/// ## Why the app can show this at all
///
/// Every assignment, return and status change this app has ever performed
/// posted a note to the asset's chatter. That log has existed since the first
/// release and nothing ever read it back, so the history was visible only to
/// someone who opened the record in Odoo's web client. This screen is almost
/// entirely one `mail.message` search — no new fields, no new writes, no
/// migration, and it works retroactively on data already in the customer's
/// database.
class AssetHistory extends Equatable {
  const AssetHistory({
    this.entries = const <AssetHistoryEntry>[],
    this.registeredOn,
    this.hasMore = false,
  });

  /// Newest first.
  final List<AssetHistoryEntry> entries;

  /// `create_date`, appended as the final entry so the timeline visibly ends
  /// at the asset's beginning rather than trailing off at whatever the chatter
  /// happened to reach.
  final DateTime? registeredOn;

  /// Whether Odoo holds older entries than the ones read so far.
  ///
  /// Inferred from a full page rather than from a count: answering exactly
  /// would need a second `search_count` round trip, and this screen already
  /// runs two reads in parallel so that it opens quickly. The cost of the
  /// guess is one empty page at an exact multiple of the page size — a
  /// spinner that resolves to nothing — against a timeline that used to stop
  /// dead at sixty entries with no sign there was any more of it.
  final bool hasMore;

  bool get isEmpty => entries.isEmpty && registeredOn == null;

  /// This history with an older page appended.
  ///
  /// [registeredOn] is kept from the first page: it is the asset's creation
  /// date, it is what closes the timeline, and later pages do not carry it.
  AssetHistory merge(AssetHistory older) => AssetHistory(
    entries: <AssetHistoryEntry>[...entries, ...older.entries],
    registeredOn: registeredOn,
    hasMore: older.hasMore,
  );

  /// The same entries, with the "there is more" flag cleared.
  ///
  /// For a page that failed to load. Without this the footer would ask for
  /// the same page again the moment it rebuilt, and a server refusing that
  /// offset would be retried forever a few hundred milliseconds apart.
  AssetHistory copyWithNoMore() =>
      AssetHistory(entries: entries, registeredOn: registeredOn);

  /// How many distinct people have held this asset.
  ///
  /// Paired with time in service on the summary line, because together they
  /// answer the replacement question: a device on its fourth holder in two
  /// years is being passed around, not settled.
  ///
  /// Counted over the *names*, not the entries. A handover recorded in this
  /// app and the same handover seen as a tracked field change in Odoo are one
  /// person receiving one device — and an entry that names nobody (a bundled
  /// handover, a change whose field could not be resolved) is not counted at
  /// all, rather than counted as an anonymous extra holder.
  int get holderCount => entries
      .map((entry) => entry.holder)
      .whereType<String>()
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .length;

  @override
  List<Object?> get props => <Object?>[entries, registeredOn, hasMore];
}
