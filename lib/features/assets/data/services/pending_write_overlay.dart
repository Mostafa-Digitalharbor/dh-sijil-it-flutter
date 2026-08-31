import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../core/sync/outbox_entry.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_status.dart';
import '../../domain/entities/return_due.dart';

/// What a queued write means for the asset the user is looking at.
///
/// ## Why it exists
///
/// Without it the app tells two stories at once: the banner says a handover is
/// waiting to send, and the screen underneath still says the laptop is on the
/// shelf — because the record it re-read is the one from before the technician
/// gave it away.
///
/// ## Why it is its own file
///
/// `AssetRepositoryImpl` has seven collaborators and three jobs, and most of
/// what looks separable in it is not: composing an entity and parking a write
/// both need four of those seven, so pulling them out buys a constructor with
/// five parameters and no less coupling.
///
/// This is the exception. It is a **pure function** of `(asset, queue)` — it
/// touches no data source, no store and no clock — and it is also the densest
/// rule in the file: three outbox kinds, each rewriting a different set of
/// fields, with an ordering constraint between them. Pure and dense is exactly
/// what belongs in front of a unit test rather than behind a repository and a
/// fake Odoo.
abstract final class PendingWriteOverlay {
  /// [asset] as it will read once [queue] has been sent, for the entries in
  /// [queue] that concern it.
  ///
  /// Entries are applied **oldest first**, so an assign-then-return lands the
  /// same way it will on Odoo. The result carries [Asset.hasPendingSync] when
  /// anything was applied, so nothing on screen claims Odoo agrees yet.
  static Asset apply(Asset asset, List<OutboxEntry> queue) {
    var result = asset;
    var touched = false;

    for (final entry in queue.where((e) => e.subjectId == asset.id)) {
      touched = true;
      result = switch (entry.kind) {
        OutboxKind.assignAsset => result.copyWith(
          status: AssetStatus.assigned,
          isStatusLocal: false,
          assignedEmployee: OdooNameRef(
            entry.payload['employeeId'] as int? ?? 0,
            '${entry.payload['employeeName'] ?? ''}',
          ),
          assignmentDate:
              DateTime.tryParse('${entry.payload['assignedOn']}') ??
              entry.queuedAt,
          // Re-evaluated rather than carried over: the asset is assigned as of
          // this entry, which is the fact `ReturnDue` needs and the one the
          // record read back from Odoo does not know yet.
          dueBack: ReturnDue.evaluate(
            date: DateTime.tryParse('${entry.payload['dueOn']}'),
            isAssigned: true,
          ),
        ),
        OutboxKind.returnAsset => result.copyWith(
          status: returnStatus(entry),
          isStatusLocal: returnStatus(entry).isLocalOnly,
          clearAssignment: true,
        ),
        OutboxKind.setAssetStatus => result.copyWith(
          status: queuedStatus(entry) ?? result.status,
          isStatusLocal: true,
        ),
      };
    }

    return touched ? result.copyWith(hasPendingSync: true) : result;
  }

  /// The status a queued return will leave the asset in.
  ///
  /// Falls back to available rather than throwing: a payload written by an
  /// older build of the app, or one whose condition was renamed, must still
  /// replay rather than wedge the queue.
  static AssetStatus returnStatus(OutboxEntry entry) =>
      ReturnCondition.values
          .where((c) => c.name == entry.payload['condition'])
          .firstOrNull
          ?.resultingStatus ??
      AssetStatus.available;

  /// The status a queued manual status change asks for, or null when the
  /// payload names one this build does not have.
  static AssetStatus? queuedStatus(OutboxEntry entry) => AssetStatus.values
      .where((s) => s.name == entry.payload['status'])
      .firstOrNull;

  const PendingWriteOverlay._();
}
