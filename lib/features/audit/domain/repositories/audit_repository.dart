import '../../../../core/utils/typedefs.dart';
import '../../../assets/domain/entities/asset.dart';
import '../entities/audit_session.dart';

/// Counting assets by walking around and scanning them.
abstract interface class AuditRepository {
  /// Every asset the audit expects to find, read once at the start.
  ///
  /// A fixed set, deliberately: if the expectation were re-read as the walk
  /// went on, an asset somebody registered mid-count would appear as
  /// "missing" without ever having had a chance to be scanned.
  ResultFuture<List<Asset>> expectedFor({
    required AuditScope scope,
    int? categoryId,
    int? departmentId,
  });

  /// Writes the count to Odoo.
  ///
  /// Posts a note to each asset's chatter — the same log the history screen
  /// reads — so the result is auditable from the web client and survives the
  /// phone that recorded it. Returns how many notes were written.
  ResultFuture<int> commit(AuditSession session);
}
