import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/utils/l10n_lookup.dart';

/// Every validation key a Cubit publishes must resolve to its own message.
///
/// Cubits deliberately emit a *key* rather than a sentence, so their tests can
/// assert on something a translator will not reword. The cost is a switch that
/// maps keys to messages, and a key missing from that switch does not fail to
/// compile — it silently falls through to the generic "Fix the highlighted
/// field", which is exactly what `validationEnterAssetName` did.
///
/// This finds the keys by reading the source, so a new one is covered the day
/// it is written rather than the day someone remembers to add a test.
void main() {
  late AppL10n en;
  late AppL10n ar;

  setUpAll(() async {
    en = await AppL10n.delegate.load(const Locale('en'));
    ar = await AppL10n.delegate.load(const Locale('ar', 'EG'));
  });

  /// Every `'validationXxx'` string literal used as a key in `lib/`.
  ///
  /// The capital after `validation` is load-bearing: it keeps the all-lowercase
  /// `'validationerror'` out, which is a fragment of an Odoo fault string that
  /// `ErrorMapper` matches on, not a key any Cubit publishes.
  Set<String> publishedKeys() {
    final keys = <String>{};
    final pattern = RegExp(r"'(validation[A-Z][A-Za-z0-9_]*)'");

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      // The lookup itself lists them all; that is the thing under test.
      if (path.endsWith('l10n_lookup.dart')) continue;
      if (path.contains('/l10n/generated/')) continue;

      for (final match in pattern.allMatches(file.readAsStringSync())) {
        keys.add(match.group(1)!);
      }
    }
    return keys;
  }

  test('the source publishes at least one validation key', () {
    expect(publishedKeys(), isNotEmpty);
  });

  test('every published key resolves to its own message, not the fallback', () {
    final fallback = en.errorValidationFix;
    final unresolved = <String>[];

    for (final key in publishedKeys()) {
      if (en.lookup(key) == fallback) unresolved.add(key);
    }

    expect(
      unresolved,
      isEmpty,
      reason:
          'These keys fall through to the generic validation message. Add '
          'each to L10nLookup.lookup:\n${unresolved.join('\n')}',
    );
  });

  test('every published key resolves in Arabic too', () {
    final fallback = ar.errorValidationFix;
    final unresolved = <String>[
      for (final key in publishedKeys())
        if (ar.lookup(key) == fallback) key,
    ];

    expect(unresolved, isEmpty);
  });

  test('a null key stays null, so it drops into an errorText unchanged', () {
    expect(en.lookup(null), isNull);
  });

  test('an unknown key degrades to the generic message, never to the key', () {
    final resolved = en.lookup('validationSomethingNobodyDefined');

    expect(resolved, en.errorValidationFix);
    expect(resolved, isNot(contains('validation')));
  });
}
