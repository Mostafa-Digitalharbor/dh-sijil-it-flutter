import 'package:flutter/widgets.dart';

/// Bounds how large an image is *decoded*, independently of how large it is
/// drawn.
///
/// ## The problem this exists for
///
/// Flutter decodes an image at its intrinsic resolution unless told otherwise,
/// and holds the decoded bitmap — four bytes per pixel, uncompressed — in the
/// image cache. A photograph from a phone camera is routinely 4000×3000, which
/// is **48 MB decoded**. Drawing it into a 64-pt thumbnail changes nothing
/// about that: the 48 MB is allocated, cached, and counted against the same
/// budget as everything else.
///
/// A return screen showing four such thumbnails asked for roughly 190 MB. On a
/// 2 GB handset that is not slow, it is killed — and on a better one it
/// thrashes Flutter's 100 MB image cache, so every scroll re-decodes what it
/// just evicted and the list janks for a reason no profile obviously explains.
///
/// Decoding to the size actually drawn costs about 2% of that.
abstract final class DecodedImage {
  /// How much larger than its box a thumbnail is decoded.
  ///
  /// A `BoxFit.cover` draw needs the image's *shorter* side to reach the box,
  /// and [ResizeImagePolicy.fit] sizes the *longer* one — so a target of
  /// exactly the box leaves a 4:3 photo a third short on its height, and
  /// visibly soft. This covers every aspect ratio a phone camera produces and
  /// still costs a fiftieth of a full-resolution decode.
  static const double _headroom = 1.5;

  /// The longest side a full-screen image is decoded at.
  ///
  /// Enough to stay sharp under the viewer's 4× zoom on any phone, and a hard
  /// ceiling regardless of what the camera that took it was capable of.
  static const int _viewerMaxSide = 2048;

  /// [image], decoded no larger than a [side]-point box needs.
  ///
  /// Returns the provider unchanged when the device pixel ratio is not yet
  /// known, which is only true outside a [MediaQuery].
  static ImageProvider thumbnail(
    BuildContext context,
    ImageProvider image, {
    required double side,
  }) {
    final target = (side * _headroom * MediaQuery.devicePixelRatioOf(context))
        .round();
    if (target <= 0) return image;

    return ResizeImage(
      image,
      width: target,
      height: target,
      policy: ResizeImagePolicy.fit,
      // A photo smaller than the box stays small. Upscaling at decode time
      // costs memory to gain nothing the GPU cannot do for free.
      allowUpscaling: false,
    );
  }

  /// Decode dimensions for a full-screen image, for `Image.memory`'s
  /// `cacheWidth`/`cacheHeight`.
  ///
  /// Returned as a pair rather than applied, because [Image.memory] takes the
  /// bounds directly and wrapping it in a [ResizeImage] would mean giving up
  /// its `errorBuilder`.
  static int get viewerMaxSide => _viewerMaxSide;
}
