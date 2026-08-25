import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A photograph attached to an Odoo record.
///
/// [bytes] is filled lazily. Listing a record's photos returns the metadata
/// only; the image data arrives when something actually renders that photo.
/// A repair with six photos is several megabytes of base64, and a detail
/// screen that eagerly downloaded all of them would stall on open over the
/// mobile connection an IT technician is standing in a server room with.
class RecordPhoto extends Equatable {
  const RecordPhoto({
    required this.id,
    required this.name,
    this.bytes,
    this.sizeBytes,
  });

  final int id;
  final String name;

  /// Decoded image data, once loaded.
  final Uint8List? bytes;

  /// Size Odoo reports, used to show a placeholder of the right weight before
  /// the bytes arrive.
  final int? sizeBytes;

  bool get isLoaded => bytes != null;

  RecordPhoto withBytes(Uint8List data) =>
      RecordPhoto(id: id, name: name, bytes: data, sizeBytes: sizeBytes);

  @override
  List<Object?> get props => <Object?>[id, name, sizeBytes, bytes?.length];
}
