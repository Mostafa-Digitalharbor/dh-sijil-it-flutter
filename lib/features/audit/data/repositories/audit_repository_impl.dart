import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/odoo_models.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assets/data/services/asset_note_vocabulary.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/entities/asset_query.dart';
import '../../../assets/domain/repositories/asset_repository.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/repositories/audit_repository.dart';

/// Implements [AuditRepository] on top of the asset repository and the chatter.
///
/// Deliberately owns no query logic of its own. "Every laptop" and "everything
/// Sara holds" are questions [AssetRepository] already answers, including the
/// status overlay and the retired-by-default rule, and re-deriving them here
/// is how an audit ends up counting a different set than the list the user was
/// looking at a moment earlier.
class AuditRepositoryImpl with RepositoryGuard implements AuditRepository {
  const AuditRepositoryImpl({
    required AssetRepository assets,
    required OdooObjectService odoo,
  }) : _assets = assets,
       _odoo = odoo;

  final AssetRepository _assets;
  final OdooObjectService _odoo;

  @override
  String get guardLabel => 'audit repository';

  @override
  ResultFuture<List<Asset>> expectedFor({
    required AuditScope scope,
    int? categoryId,
    int? departmentId,
  }) => guard(() async {
    final filters = AssetFilters(
      categoryIds: <int>{if (categoryId != null) categoryId},
      departmentId: departmentId,
      // A retired asset is one nobody expects to find, so counting it as
      // missing would put noise in the only number that has to be trusted.
      includeRetired: false,
    );

    final collected = <Asset>[];
    var offset = 0;

    while (collected.length < AppConstants.auditMaxAssets) {
      final page = await _assets.getAssets(
        AssetQuery(
          filters: filters,
          page: PageRequest(offset: offset, limit: AppConstants.auditPageSize),
        ),
      );

      final batch = page.fold(
        (failure) => throw _AuditScopeFailure(failure.kind.name),
        (result) => result,
      );

      collected.addAll(batch.items);
      if (!batch.hasMore) break;
      offset = batch.scannedCount;
    }

    return collected;
  });

  @override
  ResultFuture<int> commit(AuditSession session) => guard(() async {
    final stamp = _day(session.finishedAt ?? session.startedAt);
    final scope = session.scopeLabel;
    var written = 0;

    Future<void> note(int assetId, String body) async {
      await _odoo.executeKw(
        model: OdooModels.maintenanceEquipment,
        method: OdooMethods.messagePost,
        args: <Object?>[
          <int>[assetId],
        ],
        kwargs: <String, dynamic>{
          MailMessageFields.argBody: body,
          MailMessageFields.argSubtype: MailMessageFields.subtypeNote,
        },
      );
      written++;
    }

    // Only the findings are written, and only to the assets they concern.
    // Posting "seen" to four hundred records would bury every real signal in
    // the chatter under a wall of confirmations nobody reads.
    for (final entry in session.results.values) {
      if (entry.outcome == AuditOutcome.unexpected) {
        await note(
          entry.asset.id,
          AssetNoteVocabulary.compose(
            '${AssetNoteVocabulary.auditPrefix} on $stamp: found while '
            'counting ${scope ?? 'all assets'}, which this asset is not '
            'part of.',
            null,
          ),
        );
      }
    }

    for (final asset in session.missing) {
      await note(
        asset.id,
        AssetNoteVocabulary.compose(
          '${AssetNoteVocabulary.auditPrefix} on $stamp: not found while '
          'counting ${scope ?? 'all assets'}.',
          null,
        ),
      );
    }

    return written;
  });

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Carries an asset-layer failure out of the paging loop so [RepositoryGuard]
/// can turn it back into the same `Failure` the list screen would have shown.
class _AuditScopeFailure implements Exception {
  const _AuditScopeFailure(this.kind);

  final String kind;

  @override
  String toString() => 'Audit scope could not be read ($kind)';
}
