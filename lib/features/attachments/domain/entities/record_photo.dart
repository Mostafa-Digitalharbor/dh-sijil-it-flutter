import 'package:equatable/equatable.dart';

/// A photograph attached to an Odoo record.
///
/// Metadata only, deliberately. This used to carry a `Uint8List` of the image
/// itself, filled in by the Cubit after the list arrived — which put a
/// three-megabyte JPEG per photo into Bloc state, on top of the decoded bitmap
/// the image cache was already holding, for as long as the screen was open. A
/// repair with six photos parked about eighteen megabytes there, and nothing
/// evicted them, because state is not a cache.
///
/// The pixels now travel through `RecordPhotoImage`, an [ImageProvider], so
/// they are fetched when something paints them and their lifetime belongs to
/// Flutter's `ImageCache`, which has an eviction policy. This holds what a
/// Cubit should: which photos exist.
class RecordPhoto extends Equatable {
  const RecordPhoto({required this.id, required this.name, this.sizeBytes});

  /// The `ir.attachment` id — also the key the image provider caches on.
  final int id;

  final String name;

  /// Size Odoo reports, used to size a placeholder before the image arrives.
  final int? sizeBytes;

  @override
  List<Object?> get props => <Object?>[id, name, sizeBytes];
}
