import 'dart:io';

import 'package:speech_to_text/speech_to_text.dart';

import '../../app/theme/app_dimens.dart';
import '../utils/logger.dart';

/// What came back from one dictation.
class VoiceResult {
  const VoiceResult({required this.text, required this.isFinal});

  /// What the recogniser heard. Empty while it is still deciding.
  final String text;

  /// Whether the recogniser has committed to this.
  ///
  /// Partial results arrive as the person is still speaking, and they are the
  /// reason this is worth showing live: a search that fills in while you talk
  /// tells you it is working, and a search that appears only at the end looks
  /// like nothing happened for four seconds.
  final bool isFinal;
}

/// Turning speech into a search string.
///
/// ## Why an interface
///
/// Same reason as `XmlRpcClient`: the plugin needs a microphone, a recogniser
/// service and a permission, none of which a host VM has. Everything above
/// this — the button, its states, what it does with the transcript — is then
/// testable without any of them.
abstract interface class VoiceInput {
  /// Whether the microphone button may be shown — asking the user for
  /// nothing.
  ///
  /// Separate from [isAvailable] because the only way to ask the platform
  /// whether it can dictate is to *initialise a recogniser*, and that raises
  /// the system microphone prompt. Calling it to decide whether to draw a
  /// button meant the prompt appeared when a screen with a search field was
  /// built — before the user had touched anything, with no context for what
  /// was being asked or why.
  ///
  /// That is not a cosmetic problem. The natural answer to an unexplained
  /// permission dialog is "Don't allow", Android never shows it again once
  /// that has been chosen twice, and the feature is then dead for that
  /// install with no way back except the system settings screen. The prompt
  /// has to be attached to the button press, which is the only moment the
  /// user knows what it is for.
  Future<bool> canOffer();

  /// Whether this device can dictate, initialising the recogniser and asking
  /// for the microphone if it has not been asked yet.
  ///
  /// Call this from the press, never from a build. False on a tablet with no
  /// microphone, on an emulator without Google services, and on a device
  /// where the user has refused the permission. The button is hidden rather
  /// than disabled in that case: an affordance that can never work is worse
  /// than no affordance.
  Future<bool> isAvailable();

  /// Starts listening. [onResult] fires repeatedly as the recogniser refines
  /// what it heard, and a last time with [VoiceResult.isFinal] set.
  Future<bool> listen({
    required void Function(VoiceResult result) onResult,
    required String localeId,
  });

  Future<void> stop();

  bool get isListening;
}

/// The real one, backed by the platform recogniser.
class PlatformVoiceInput implements VoiceInput {
  PlatformVoiceInput([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  /// Initialisation is a platform round trip and a permission prompt, so it
  /// happens once and the answer is kept.
  bool? _available;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> canOffer() async {
    // Already initialised once: repeating the answer costs nothing and asks
    // for nothing.
    final known = _available;
    if (known != null) return known;

    // The two platforms with a system recogniser behind this plugin. On a
    // desktop build there is nothing to dictate into, and offering a button
    // that can never work is the thing this class is trying to avoid.
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    try {
      // Permission already granted, so initialising raises no dialog and the
      // answer is a real one — which keeps the button off a device that has
      // the permission but no recogniser installed.
      if (await _speech.hasPermission) return isAvailable();
    } on Object catch (error) {
      AppLogger.debug('Voice permission check failed: $error');
      return false;
    }

    // Undecided, or refused. Offer the button either way: pressing it is what
    // asks, and a refusal comes back as `listen` returning false, at which
    // point the button removes itself. One wasted tap on a device that turns
    // out not to support it, against no unexplained prompt on every device
    // that does.
    return true;
  }

  @override
  Future<bool> isAvailable() async {
    final known = _available;
    if (known != null) return known;

    try {
      final ready = await _speech.initialize(
        // Both are noisy and neither is actionable by the user: a recogniser
        // that cannot start is reported by the button going away.
        onError: (error) => AppLogger.debug('Voice: ${error.errorMsg}'),
        onStatus: (status) => AppLogger.debug('Voice: $status'),
      );
      _available = ready;
      return ready;
    } on Object catch (error) {
      // A missing recogniser throws on some OEM builds rather than answering
      // false. Either way the answer is the same and it must not be an
      // exception the search field has to handle.
      AppLogger.debug('Voice unavailable: $error');
      _available = false;
      return false;
    }
  }

  @override
  Future<bool> listen({
    required void Function(VoiceResult result) onResult,
    required String localeId,
  }) async {
    if (!await isAvailable()) return false;

    await _speech.listen(
      onResult: (result) => onResult(
        VoiceResult(text: result.recognizedWords, isFinal: result.finalResult),
      ),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        // The transcript is going into a search box, not a document. Partial
        // results are what make it feel immediate.
        partialResults: true,
        // An asset tag read aloud is a string of letters and digits, and the
        // recogniser's guess at a *word* is usually wrong for one. This asks
        // for the raw dictation rather than the tidied-up sentence.
        listenMode: ListenMode.search,
        cancelOnError: true,
        listenFor: AppDurations.voiceListen,
        pauseFor: AppDurations.voicePause,
      ),
    );

    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}
