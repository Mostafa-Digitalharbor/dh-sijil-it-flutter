import 'package:flutter/material.dart';

import '../../app/di/injector.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/services/voice_input.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_button.dart';
import 'app_sheets.dart';

/// Dictate a search instead of typing it.
///
/// ## Why this earns its place in the search field
///
/// The technician this app is for is holding a laptop in one hand and a phone
/// in the other, often standing at a desk that is not theirs. Typing
/// "MacBook Pro" into a search box needs both hands and a flat surface; saying
/// it needs neither. The search field is the way into every list in the
/// product, so this is the single control that most changes what the app is
/// like to use one-handed.
///
/// ## Why it can be absent
///
/// A device with no microphone, no recogniser, or a refused permission cannot
/// do this, and the button hides rather than greying out. A disabled control
/// invites a tap and then explains that the tap was pointless; an absent one
/// costs the user nothing, because the keyboard beside it does the same job.
///
/// The availability check is a platform round trip, so the button starts
/// hidden and appears when the answer lands. On the phones that have it that
/// is one frame; on the ones that do not, it never flickers into view.
class VoiceSearchButton extends StatefulWidget {
  const VoiceSearchButton({required this.onTranscript, super.key});

  /// Called with the recogniser's best guess so far, and again when it
  /// commits. Wired straight to the same callback the keyboard drives, so a
  /// dictated search and a typed one go down one path.
  final ValueChanged<String> onTranscript;

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> {
  late final VoiceInput _voice = sl<VoiceInput>();

  bool _available = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  /// Asks whether to draw the button, and asks the *user* for nothing.
  ///
  /// This used to call `isAvailable`, which initialises the recogniser — and
  /// so raised the system microphone dialog the moment any screen carrying a
  /// search field was built. It was observed on a device doing exactly that:
  /// "Allow Sijil IT to record audio?" over a screen the user had not
  /// interacted with. Anyone who answered "Don't allow" — the reasonable
  /// answer to a question with no context — lost the feature permanently,
  /// because Android stops showing the dialog after that.
  Future<void> _probe() async {
    final offered = await _voice.canOffer();
    if (mounted) setState(() => _available = offered);
  }

  @override
  void dispose() {
    // A microphone left open by a screen the user has left is the thing people
    // uninstall an app over, and on some Android builds it stays open until
    // the process dies.
    if (_listening) _voice.stop();
    super.dispose();
  }

  Future<void> _toggle(AppL10n l10n) async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    var heardAnything = false;

    final started = await _voice.listen(
      localeId: _localeIdFor(context),
      onResult: (result) {
        if (!mounted) return;
        if (result.text.isNotEmpty) heardAnything = true;

        // Fed through on every partial, so the list narrows while the person
        // is still speaking rather than sitting still for four seconds.
        widget.onTranscript(result.text);

        if (result.isFinal) {
          setState(() => _listening = false);
          if (!heardAnything) AppSnack.info(context, l10n.voiceHeardNothing);
        }
      },
    );

    if (!mounted) return;
    if (started) {
      setState(() => _listening = true);
    } else {
      // The permission was refused at the prompt. The button goes away rather
      // than staying to be pressed again: on Android the system dialog never
      // reappears once "Don't allow" has been chosen.
      setState(() => _available = false);
    }
  }

  /// The recogniser wants a full locale, and getting it wrong is not subtle:
  /// an Arabic recogniser handed English audio returns confident nonsense.
  static String _localeIdFor(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    // Defaults for the two languages the app ships in.
    return switch (locale.languageCode) {
      'ar' => 'ar_EG',
      _ => 'en_US',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);

    return AppIconButton(
      icon: _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
      tooltip: _listening ? l10n.voiceSearchStop : l10n.voiceSearchStart,
      bordered: false,
      // Mint while listening, because the one thing the user needs to know is
      // whether the microphone is open.
      color: _listening ? AppColors.mint : null,
      size: AppDimens.iconXl,
      onPressed: () => _toggle(l10n),
    );
  }
}
