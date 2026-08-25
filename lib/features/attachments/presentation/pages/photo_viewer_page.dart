import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/record_photo.dart';

/// Full-screen photo viewer.
///
/// Always dark, in both themes. A photograph is judged against its own
/// contents, and a light chrome around it shifts how the image itself reads —
/// which matters when the photo is evidence of damage that someone is deciding
/// a repair-or-replace call on.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    required this.photos,
    this.initialIndex = 0,
    super.key,
  });

  final List<RecordPhoto> photos;
  final int initialIndex;

  /// Opens the viewer over the current screen.
  static Future<void> open(
    BuildContext context, {
    required List<RecordPhoto> photos,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoViewerPage(photos: photos, initialIndex: initialIndex),
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
    final loaded = widget.photos
        .where((p) => p.isLoaded)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.camera,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.dark.ink,
        title: loaded.length > 1
            ? Text(
                l10n.photosPosition(_index + 1, loaded.length),
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
      body: loaded.isEmpty
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
              itemCount: loaded.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Image.memory(
                      loaded[i].bytes!,
                      fit: BoxFit.contain,
                      // Odoo will happily store a file whose mimetype says
                      // image and whose bytes do not decode. Showing the
                      // failure beats an exception in the frame callback.
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
