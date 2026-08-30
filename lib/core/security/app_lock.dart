import 'package:local_auth/local_auth.dart';

import '../utils/logger.dart';

/// The device's own unlock, asked for before the app opens.
///
/// ## What this protects, and what it does not
///
/// The Odoo credential has always been in the keychain, encrypted at rest and
/// never written anywhere else (spec §25). What it was not protected from is
/// the ordinary case: a phone already unlocked and lying on a desk. Anybody
/// who picks it up can reassign company equipment, mark a laptop lost, or
/// delete an asset — under the signed-in user's name, in Odoo, for everyone.
///
/// This closes that. It is not a second factor and does not re-authenticate
/// against Odoo; it is the same check the banking app on the same home screen
/// makes, and it is worth exactly as much: it stops the person holding the
/// unlocked phone, which is who the threat is.
///
/// ## Why device credentials, not biometrics only
///
/// `authenticate` is called without `biometricOnly`, so the prompt falls back
/// through fingerprint, face, PIN, pattern and password. A biometric-only gate
/// strands the technician with a cut finger or wet hands — in a server room,
/// holding the device they need to look up — with no way past it and no way to
/// turn the setting off from behind the lock screen.
///
/// Availability follows the same rule: [isAvailable] asks whether the device
/// has *any* secure lock, because a phone with no lock at all has nothing to
/// ask for, and offering the switch there would promise a protection the OS
/// cannot deliver.
class AppLock {
  AppLock([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether this device can be asked to unlock at all.
  ///
  /// A failure answers false rather than propagating: a settings screen that
  /// cannot decide whether to show a switch shows none, which degrades to the
  /// behaviour the app had before this existed.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object catch (error) {
      AppLogger.warn('Device lock support unavailable — $error');
      return false;
    }
  }

  /// Asks the OS to confirm the person holding the phone.
  ///
  /// [reason] is shown by the system inside its own prompt, so it is passed in
  /// already translated rather than written here — this class has no
  /// localizations and should not grow any.
  ///
  /// Returns false for every outcome that is not a confirmed unlock: a
  /// cancelled prompt, a failed match, a lockout after too many attempts, or a
  /// platform that threw. They are one answer to the only question the caller
  /// asks, which is whether to let the app through.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Survives the app being backgrounded mid-prompt — which is what
          // happens on Android when the system dialog takes focus, and
          // without it the prompt is dismissed by its own appearance.
          stickyAuth: true,
          // False on purpose: see the class comment. The PIN is the way out
          // for anybody whose finger the sensor will not read.
          biometricOnly: false,
        ),
      );
    } on Object catch (error) {
      // Includes `PlatformException` for a device whose enrolment was removed
      // between the check and the prompt. Denied is the safe answer.
      AppLogger.warn('Unlock attempt failed — $error');
      return false;
    }
  }
}
