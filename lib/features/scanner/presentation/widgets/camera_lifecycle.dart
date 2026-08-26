import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Owns the camera for a screen that scans.
///
/// ## What this is really guarding
///
/// A live camera preview held by a backgrounded app is the thing users
/// uninstall an app over — and on some Android builds it is also how the
/// camera ends up locked until the process dies. Releasing it needs three
/// things to line up: register as a [WidgetsBindingObserver], stop the
/// controller on every non-resumed lifecycle state, and deregister on dispose.
/// Miss the deregistration and the observer outlives the [State] it belongs
/// to; miss a lifecycle case and the camera keeps running.
///
/// The scanner screen and the audit's counting step each had their own copy of
/// all three, plus their own copy of the barcode format list. Two copies of a
/// resource-release path is one too many: the bug only appears on a real
/// handset, only after backgrounding, and never in a test.
///
/// The `on State<T>, WidgetsBindingObserver` constraint is what makes the
/// mixin cheap — the using class supplies the observer, so nothing here has to
/// stub out the dozen callbacks a camera does not care about.
///
/// ```dart
/// class _CountingViewState extends State<_CountingView>
///     with WidgetsBindingObserver, CameraLifecycle {
///   @override
///   void onCode(String code) => context.read<AuditCubit>().onDetected(code);
/// }
/// ```
mixin CameraLifecycle<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  /// The symbologies the app can act on.
  ///
  /// Deliberately narrow. A wider set makes the detector slower, and it is how
  /// a stray Data Matrix on a shipping label gets read as an asset code.
  static const List<BarcodeFormat> supportedFormats = <BarcodeFormat>[
    BarcodeFormat.qrCode,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
  ];

  late final MobileScannerController controller = MobileScannerController(
    formats: supportedFormats,
    // `noDuplicates` for both callers, for opposite reasons: the single-shot
    // scanner must not fire twice on one sticker, and the audit runs the
    // camera continuously and must not count one asset forty times.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Called with the first readable payload in a capture.
  ///
  /// A capture can carry several barcodes when two stickers are in frame. The
  /// first is the one the user aimed at; acting on all of them would register
  /// an asset nobody pointed the phone at.
  void onCode(String code);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(controller.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(controller.stop());
    }
  }

  /// Hand this to `MobileScanner.onDetect`.
  void handleDetection(BarcodeCapture capture) {
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    onCode(raw);
  }
}
