import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../domain/usecases/attachment_usecases.dart';

/// One `ir.attachment` photograph, as something Flutter can paint.
///
/// ## Why this replaced bytes in the Cubit
///
/// `RecordPhoto` used to carry its own `Uint8List`, filled in by the Cubit
/// after the list arrived. That put the **compressed JPEG** — three megabytes
/// for a phone photo — into Bloc state, where it stayed for as long as the
/// screen was open, on top of the decoded bitmap the image cache was already
/// holding. A maintenance request with six photos parked roughly eighteen
/// megabytes of raw bytes in a Cubit, and nothing ever evicted them because
/// state is not a cache.
///
/// It also meant every photo was downloaded the moment the list came back,
/// whether or not anything drew it.
///
/// An [ImageProvider] fixes both by putting the bytes where Flutter already
/// manages this: they are fetched when something actually paints the photo,
/// held only while the codec runs, and the decoded result is owned by
/// `ImageCache`, which has an eviction policy. The Cubit goes back to holding
/// what it should — which photos exist.
///
/// Equality is on [photoId] alone, which is what lets the cache recognise the
/// same photo across a rebuild, across the strip and the full-screen viewer,
/// and across two screens showing the same record.
@immutable
class RecordPhotoImage extends ImageProvider<RecordPhotoImage> {
  const RecordPhotoImage(this.photoId, this._load, {this.scale = 1.0});

  /// The `ir.attachment` id.
  final int photoId;

  final double scale;

  /// The same use case the Cubit would have called. Fetching still goes
  /// through the domain layer; only *when* it happens has changed.
  final LoadPhotoData _load;

  @override
  Future<RecordPhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<RecordPhotoImage>(this);

  @override
  ImageStreamCompleter loadImage(
    RecordPhotoImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _fetchAndDecode(key, decode),
      scale: key.scale,
      debugLabel: 'ir.attachment/${key.photoId}',
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<RecordPhotoImage>('Image provider', this),
        DiagnosticsProperty<int>('Attachment id', key.photoId),
      ],
    );
  }

  Future<ui.Codec> _fetchAndDecode(
    RecordPhotoImage key,
    ImageDecoderCallback decode,
  ) async {
    final result = await key._load(key.photoId);

    final bytes = result.fold<Uint8List?>((_) => null, (data) => data);

    // Thrown rather than returned as a blank image so the `errorBuilder` on
    // the tile runs and the user sees the "this one would not load" mark
    // instead of a hole the same colour as the card.
    if (bytes == null || bytes.isEmpty) {
      // Flutter evicts a provider whose load threw, so a later rebuild
      // retries rather than caching the failure forever.
      throw StateError('Attachment ${key.photoId} has no readable image data.');
    }

    // `ImmutableBuffer` takes ownership; the Uint8List is unreachable from
    // here on and the decoded frame is what the image cache accounts for.
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is RecordPhotoImage &&
      other.photoId == photoId &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(photoId, scale);

  @override
  String toString() => 'RecordPhotoImage($photoId)';
}
