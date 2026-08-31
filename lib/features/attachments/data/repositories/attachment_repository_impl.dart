import 'dart:io';
import 'dart:typed_data';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/odoo/odoo_attachment_service.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/record_photo.dart';
import '../../domain/repositories/attachment_repository.dart';

/// Implements [AttachmentRepository] over `ir.attachment`.
class AttachmentRepositoryImpl
    with RepositoryGuard
    implements AttachmentRepository {
  const AttachmentRepositoryImpl(this._service);

  final OdooAttachmentService _service;

  @override
  String get guardLabel => 'attachment repository';

  @override
  ResultFuture<List<RecordPhoto>> photosFor({
    required String model,
    required int recordId,
  }) => guard(() async {
    final attachments = await _service.list(model: model, id: recordId);
    return <RecordPhoto>[
      for (final attachment in attachments)
        RecordPhoto(
          id: attachment.id,
          name: attachment.name,
          sizeBytes: attachment.bytes,
        ),
    ];
  });

  @override
  ResultFuture<Uint8List?> load(int photoId) =>
      guard(() => _service.download(photoId));

  @override
  ResultFuture<RecordPhoto> addFile({
    required String model,
    required int recordId,
    required String path,
  }) => guard(() async {
    final file = File(path);
    if (!file.existsSync()) {
      // The picker handed back a path the OS has already reclaimed — common on
      // Android when the camera intent is killed for memory. Naming it beats
      // letting the base64 encode throw something unreadable.
      throw const FileAccessException('picked file no longer exists');
    }

    final data = await file.readAsBytes();
    final filename = path.split(Platform.pathSeparator).last;

    return _upload(
      model: model,
      recordId: recordId,
      filename: filename,
      data: data,
    );
  });

  @override
  ResultFuture<RecordPhoto> addBytes({
    required String model,
    required int recordId,
    required String filename,
    required Uint8List data,
  }) => guard(
    () => _upload(
      model: model,
      recordId: recordId,
      filename: filename,
      data: data,
    ),
  );

  Future<RecordPhoto> _upload({
    required String model,
    required int recordId,
    required String filename,
    required Uint8List data,
  }) async {
    final id = await _service.upload(
      model: model,
      id: recordId,
      filename: filename,
      data: data,
      mimetype: OdooAttachmentService.mimetypeFor(filename),
    );

    return RecordPhoto(id: id, name: filename, sizeBytes: data.length);
  }

  @override
  ResultFuture<void> remove(int photoId) =>
      guard(() => _service.delete(photoId));
}
