import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/decoded_image.dart';
import '../../domain/entities/record_photo.dart';
import '../../domain/usecases/attachment_usecases.dart';
import '../widgets/record_photo_image.dart';

/// Full-screen photo viewer.
///
/// Always dark, in both themes. A photograph is judged against its own
/// contents, and a light chrome around it shifts how the image itself reads —
/// which matters when the photo is evidence of damage that someone is deciding
/// a repair-or-replace call on.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    required this.photos,
    required this.loadData,
    this.initialIndex = 0,
    super.key,
  });

  final List<RecordPhoto> photos;

  /// Fetches one photo's pixels. Held rather than the pixels themselves: a
  /// six-photo repair would otherwise arrive here as eighteen megabytes of
  /// JPEG passed down a constructor.
  final LoadPhotoData loadData;

  final int initialIndex;

  /// Opens the viewer over the current screen.
  static Future<void> open(
    BuildContext context, {
    required List<RecordPhoto> photos,
    required LoadPhotoData loadData,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerPage(
          photos: photos,
          loadData: loadData,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Every photo, not only the ones already downloaded. The provider fetches
    // on paint, so paging to a photo is what loads it — which is also what
    // stops opening a six-photo repair from pulling all six at once.
    final photos = widget.photos;

    return Scaffold(
      backgroundColor: AppColors.camera,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.dark.ink,
        title: photos.length > 1
            ? Text(
                l10n.photosPosition(_index + 1, photos.length),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppPalette.dark.ink),
              )
            : null,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
      ),
      body: photos.isEmpty
          ? Center(
              child: Text(
                l10n.photosEmpty,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.dark.dim),
              ),
            )
          : PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Image(
                      // A 12-megapixel photo decodes to 48 MB. This screen
                      // shows one at a time and allows a 4x zoom, so it needs
                      // real resolution — but not the camera's, and not
                      // whatever a future camera decides to produce.
                      image: ResizeImage(
                        RecordPhotoImage(photos[i].id, widget.loadData),
                        width: DecodedImage.viewerMaxSide,
                        height: DecodedImage.viewerMaxSide,
                        policy: ResizeImagePolicy.fit,
                        allowUpscaling: false,
                      ),
                      fit: BoxFit.contain,
                      // Odoo will happily store a file whose mimetype says
                      // image and whose bytes do not decode, and a photo can
                      // be deleted in the web client between the list call and
                      // this tap. Showing the failure beats an exception in
                      // the frame callback.
                      errorBuilder: (context, _, _) => Icon(
                        Icons.broken_image_outlined,
                        size: AppSpacing.huge,
                        color: AppPalette.dark.faint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
