import 'dart:convert';
import 'dart:typed_data';

import '../../constants/app_constants.dart';
import '../../constants/odoo_models.dart';
import 'odoo_object_service.dart';
import 'odoo_value.dart';

/// One file hanging off an Odoo record.
///
/// Deliberately does **not** carry the bytes. A maintenance request with six
/// photos is several megabytes of base64, and a list screen that wants to show
/// "3 photos" would pull all of it to count to three.
class OdooAttachment {
  const OdooAttachment({
    required this.id,
    required this.name,
    this.mimetype,
    this.bytes,
  });

  final int id;
  final String name;
  final String? mimetype;

  /// The file size Odoo reports, in bytes.
  final int? bytes;

  bool get isImage => mimetype?.startsWith('image/') ?? false;
}

/// Reads and writes `ir.attachment`, for every feature that handles files.
///
/// Attachments are not an asset concern or a maintenance concern — they are an
/// Odoo concern, and both features need the identical four calls. Putting them
/// here rather than on each data source is what stops the second feature from
/// re-deriving the base64/`datas` handling and getting it subtly different.
class OdooAttachmentService {
  const OdooAttachmentService(this._odoo);

  final OdooObjectService _odoo;

  /// Files attached to [id] on [model], newest first.
  ///
  /// [imagesOnly] filters server-side on `mimetype`, so a record whose chatter
  /// carries a PDF quote does not put a broken image tile in the photo strip.
  Future<List<OdooAttachment>> list({
    required String model,
    required int id,
    bool imagesOnly = true,
    int limit = AppConstants.attachmentListLimit,
  }) async {
    final domain = <List<Object?>>[
      <Object?>[AttachmentFields.resModel, '=', model],
      <Object?>[AttachmentFields.resId, '=', id],
      if (imagesOnly) <Object?>[AttachmentFields.mimetype, 'like', 'image/%'],
    ];

    final records = await _odoo.searchRead(
      model: OdooModels.irAttachment,
      domain: domain,
      fields: AttachmentFields.listSet,
      order: '${AttachmentFields.id} desc',
      limit: limit,
    );

    return <OdooAttachment>[
      for (final record in records)
        if (record.readInt(AttachmentFields.id) case final int attachmentId)
          OdooAttachment(
            id: attachmentId,
            name: record.readString(AttachmentFields.name) ?? '',
            mimetype: record.readString(AttachmentFields.mimetype),
            bytes: record.readInt(AttachmentFields.fileSize),
          ),
    ];
  }

  /// The file's contents.
  ///
  /// Returns null rather than throwing when the record has gone or the field
  /// is empty: a photo deleted in the web client between the list call and the
  /// tap is an ordinary race, not an error worth showing anyone.
  Future<Uint8List?> download(int attachmentId) async {
    final records = await _odoo.read(
      model: OdooModels.irAttachment,
      ids: <int>[attachmentId],
      fields: const <String>[AttachmentFields.datas],
    );
    if (records.isEmpty) return null;

    final encoded = records.first.readString(AttachmentFields.datas);
    if (encoded == null) return null;

    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  /// Attaches [data] to [id] and returns the new attachment's id.
  Future<int> upload({
    required String model,
    required int id,
    required String filename,
    required Uint8List data,
    String? mimetype,
  }) {
    return _odoo.create(
      model: OdooModels.irAttachment,
      values: <String, dynamic>{
        AttachmentFields.name: filename,
        AttachmentFields.datas: base64Encode(data),
        AttachmentFields.resModel: model,
        AttachmentFields.resId: id,
        if (mimetype != null) AttachmentFields.mimetype: mimetype,
      },
    );
  }

  Future<void> delete(int attachmentId) =>
      _odoo.unlink(model: OdooModels.irAttachment, ids: <int>[attachmentId]);

  /// Guesses a mimetype from a filename, for the handful of formats a phone
  /// camera and gallery actually produce.
  static String mimetypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
