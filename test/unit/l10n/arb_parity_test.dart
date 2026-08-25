import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Arabic translation against drift.
///
/// The failure this prevents is silent: `flutter gen-l10n` happily generates a
/// build where an untranslated Arabic key falls back to English, so a missing
/// string ships and is only noticed by an Arabic-speaking user. This turns
/// that into a red build.
void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() {
    Map<String, dynamic> load(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    en = load('lib/l10n/app_en.arb');
    ar = load('lib/l10n/app_ar.arb');
  });

  /// Message keys only — `@@locale` and the `@key` metadata entries are not
  /// translatable strings.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('every English message has an Arabic translation', () {
    final missing = messageKeys(en).difference(messageKeys(ar));

    expect(
      missing,
      isEmpty,
      reason: 'Missing from app_ar.arb: ${missing.join(', ')}',
    );
  });

  test('Arabic has no keys that English does not define', () {
    final extra = messageKeys(ar).difference(messageKeys(en));

    expect(
      extra,
      isEmpty,
      reason: 'Not in the app_en.arb template: ${extra.join(', ')}',
    );
  });

  test('placeholders match between locales', () {
    final placeholder = RegExp(r'\{(\w+)\}');

    for (final key in messageKeys(en)) {
      final enPlaceholders = placeholder
          .allMatches('${en[key]}')
          .map((m) => m.group(1))
          .toSet();
      final arPlaceholders = placeholder
          .allMatches('${ar[key]}')
          .map((m) => m.group(1))
          .toSet();

      expect(
        arPlaceholders,
        enPlaceholders,
        reason:
            'Placeholder mismatch on "$key". A missing placeholder in the '
            'Arabic string is a runtime formatting error.',
      );
    }
  });

  test('no Arabic value was left as its English source', () {
    // Catches copy-paste stubs. Values that are legitimately identical across
    // locales are listed explicitly, each with the reason it is exempt.
    const identicalOnPurpose = <String>{
      // Example URLs and identifiers are not prose.
      'fieldServerUrlHint',
      'fieldDatabaseHint',
      'fieldUsernameHint',
      // A language is named in its own script in every locale, so the Arabic
      // endonym is correct in the English file too.
      'languageArabic',
      'languageSystem',
      // Odoo model names are identifiers, never translated.
      'assignSourceHint',
    };

    final untranslated = messageKeys(en)
        .where((k) => !identicalOnPurpose.contains(k))
        .where((k) => en[k] == ar[k])
        .toList();

    expect(
      untranslated,
      isEmpty,
      reason: 'Still in English inside app_ar.arb: ${untranslated.join(', ')}',
    );
  });
}
