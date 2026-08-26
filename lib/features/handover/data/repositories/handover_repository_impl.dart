import '../../../../core/error/guard.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assets/data/services/asset_note_vocabulary.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/repositories/asset_repository.dart';
import '../../../assignment/domain/entities/assignment.dart';
import '../../../attachments/domain/repositories/attachment_repository.dart';
import '../../domain/entities/handover.dart';
import '../../domain/repositories/handover_repository.dart';

/// Implements [HandoverRepository] on top of the assignment path the app
/// already has.
///
/// ## Why it delegates rather than writing the records itself
///
/// A handover *is* several assignments. Reimplementing the write here would
/// mean a second copy of the field mapping, and — the part that actually
/// breaks — a second path that forgets to invalidate the asset cache and to
/// announce the change on [AssetRepository.changes]. The detail screen sitting
/// behind this one would keep reading "Available" for an asset that had just
/// been handed to somebody.
///
/// So the only thing this class owns is what makes a bundle a bundle: one
/// date, one note naming every item, one signature, and an honest account of
/// what happened when Odoo accepted some of it.
class HandoverRepositoryImpl
    with RepositoryGuard
    implements HandoverRepository {
  const HandoverRepositoryImpl({
    required AssetRepository assets,
    required AttachmentRepository attachments,
    required String model,
  }) : _assets = assets,
       _attachments = attachments,
       _model = model;

  final AssetRepository _assets;
  final AttachmentRepository _attachments;

  /// The Odoo model assets live on.
  ///
  /// Injected as a string rather than read off the data source, because that
  /// is genuinely all this class needs from it: the attachment repository is
  /// model-agnostic by design, and which model an asset *is* was decided by
  /// the strategy chosen at startup.
  final String _model;

  @override
  String get guardLabel => 'handover repository';

  @override
  ResultFuture<HandoverReceipt> submit(HandoverBundle bundle) => guard(
    () async {
      final note = AssetNoteVocabulary.handoverDetail(
        items: bundle.assets.map(_describe).toList(growable: false),
        fingerprint: bundle.signatureFingerprint,
        notes: bundle.notes,
      );

      final handedOver = <Asset>[];
      final failed = <Asset>[];

      // Sequential, not concurrent. Twelve simultaneous writes against one Odoo
      // worker is how a bundle turns into a timeout, and a failure halfway
      // through a `Future.wait` leaves the receipt unable to say which of them
      // landed — which is the one thing it exists to say.
      for (final asset in bundle.assets) {
        final result = await _assets.assign(
          AssignmentRequest(
            assetId: asset.id,
            employeeId: bundle.recipient.id,
            employeeName: bundle.recipient.name,
            assignedOn: bundle.handedOverOn,
            notes: note,
          ),
        );

        result.fold((failure) {
          AppLogger.warn(
            'Handover: ${asset.name} refused by Odoo (${failure.kind.name})',
          );
          failed.add(asset);
        }, handedOver.add);
      }

      return HandoverReceipt(
        handedOver: handedOver,
        failed: failed,
        signedCount: await _attachSignature(bundle, handedOver),
      );
    },
  );

  /// Puts the signature on every asset that actually changed hands.
  ///
  /// On each record rather than once somewhere central, because there is no
  /// central place: standard Odoo has no handover object, and an attachment on
  /// a record nobody thinks to open is not evidence. Anyone auditing one
  /// laptop finds the receipt on the laptop.
  ///
  /// Failures here are counted, never raised. The assignment has already
  /// landed and is the fact; losing the image weakens the proof, and undoing a
  /// correct record to protect a thumbnail would be the wrong trade.
  Future<int> _attachSignature(
    HandoverBundle bundle,
    List<Asset> assets,
  ) async {
    final filename =
        'handover-${_stamp(bundle.handedOverOn)}-'
        '${bundle.signatureFingerprint.replaceAll(':', '')}.png';

    var attached = 0;
    for (final asset in assets) {
      final result = await _attachments.addBytes(
        model: _model,
        recordId: asset.id,
        filename: filename,
        data: bundle.signature,
      );
      result.fold(
        (failure) => AppLogger.warn(
          'Handover: signature not attached to ${asset.name} '
          '(${failure.kind.name})',
        ),
        (_) => attached++,
      );
    }
    return attached;
  }

  /// "Dell Latitude 5440 (SJL-0244)" — the name someone reads and the code
  /// they match against the sticker.
  static String _describe(Asset asset) {
    final tag = asset.assetTag ?? asset.serialNumber;
    return tag == null ? asset.name : '${asset.name} ($tag)';
  }

  static String _stamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}
