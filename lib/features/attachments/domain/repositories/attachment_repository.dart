import 'dart:typed_data';

import '../../../../core/utils/typedefs.dart';
import '../entities/record_photo.dart';

/// Photographs on a record, stated without reference to Odoo.
///
/// The contract is deliberately model-agnostic: an asset and a maintenance
/// request need exactly the same four operations, and the only difference is
/// the string naming the model. Splitting this per feature would have produced
/// two implementations of base64 handling that drift.
abstract interface class AttachmentRepository {
  /// Metadata for every photo on [recordId], newest first. No image data.
  ResultFuture<List<RecordPhoto>> photosFor({
    required String model,
    required int recordId,
  });

  /// The bytes for one photo. Null when it has been deleted server-side.
  ResultFuture<Uint8List?> load(int photoId);

  /// Uploads a file the user picked from the camera or gallery.
  ResultFuture<RecordPhoto> addFile({
    required String model,
    required int recordId,
    required String path,
  });

  /// Uploads bytes the app produced itself — a captured signature.
  ResultFuture<RecordPhoto> addBytes({
    required String model,
    required int recordId,
    required String filename,
    required Uint8List data,
  });

  ResultFuture<void> remove(int photoId);
}
