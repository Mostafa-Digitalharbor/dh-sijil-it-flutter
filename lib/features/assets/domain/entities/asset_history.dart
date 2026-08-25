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
  });

  final int id;
  final AssetEventKind kind;

  /// The chatter body as plain text.
  final String summary;

  final DateTime? occurredAt;
  final OdooNameRef? author;

  @override
  List<Object?> get props => <Object?>[id, kind, summary, occurredAt, author];
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
  });

  /// Newest first.
  final List<AssetHistoryEntry> entries;

  /// `create_date`, appended as the final entry so the timeline visibly ends
  /// at the asset's beginning rather than trailing off at whatever the chatter
  /// happened to reach.
  final DateTime? registeredOn;

  bool get isEmpty => entries.isEmpty && registeredOn == null;

  /// How many distinct people have held this asset.
  ///
  /// Paired with time in service on the summary line, because together they
  /// answer the replacement question: a device on its fourth holder in two
  /// years is being passed around, not settled.
  int get holderCount => entries
      .where((entry) => entry.kind == AssetEventKind.assigned)
      .map((entry) => entry.summary)
      .toSet()
      .length;

  @override
  List<Object?> get props => <Object?>[entries, registeredOn];
}
