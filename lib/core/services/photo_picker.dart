import 'package:image_picker/image_picker.dart';

import '../constants/app_constants.dart';

/// Where a photo comes from.
///
/// The two are a real choice, not a menu: a technician photographing a cracked
/// screen wants the camera, and one attaching a supplier's photo of a
/// replacement part wants the gallery. Hiding either behind a long-press makes
/// half the users think the app cannot do it.
enum PhotoSource { camera, gallery }

/// Picks a photo from the device.
///
/// An interface so a Cubit can depend on *picking* rather than on
/// `image_picker`. The plugin needs a platform channel, which means a widget
/// test that touches a screen with a camera button would otherwise have to
/// stand up a mock method channel — and, before this, the plugin was
/// constructed inside the return screen's `State`, which put a platform
/// dependency in the widget layer and made that flow untestable.
abstract interface class PhotoPicker {
  /// Absolute path to the picked file, or null when the user backed out.
  Future<String?> pick(PhotoSource source);

  /// Several at once, for a repair where the technician shot the fault from
  /// three angles. Empty when the user backed out.
  Future<List<String>> pickMany();
}

/// [PhotoPicker] over the `image_picker` plugin.
///
/// Downscales on the way in. A modern phone camera produces an 8–12 MB JPEG,
/// and `ir.attachment` stores it base64-encoded — a third larger again — so
/// six unresized photos on one repair is most of a 100 MB Odoo Online
/// attachment quota, uploaded over whatever signal a server room has.
class ImagePickerAdapter implements PhotoPicker {
  ImagePickerAdapter([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: AppConstants.photoMaxWidth,
      imageQuality: AppConstants.photoQuality,
    );
    return file?.path;
  }

  @override
  Future<List<String>> pickMany() async {
    final files = await _picker.pickMultiImage(
      maxWidth: AppConstants.photoMaxWidth,
      imageQuality: AppConstants.photoQuality,
      limit: AppConstants.maxPhotosPerPick,
    );
    return files.map((f) => f.path).toList(growable: false);
  }
}
