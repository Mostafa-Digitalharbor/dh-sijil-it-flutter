import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The contract between the two ARB files and the code that reads them.
///
/// A missing translation does not crash and does not fail a build — it renders
/// the English string inside an Arabic screen, which is exactly the kind of
/// defect that ships. Every rule here failed at least once during development.
void main() {
  Map<String, dynamic> arb(String name) =>
      jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, String> messages(String name) => <String, String>{
    for (final entry in arb(name).entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };

  late Map<String, String> en;
  late Map<String, String> ar;

  setUpAll(() {
    en = messages('app_en.arb');
    ar = messages('app_ar.arb');
  });

  /// Example values a translator is meant to leave alone: a URL, a database
  /// name, an email shape, and each language's own name in a picker.
  const identicalOnPurpose = <String>{
    'fieldServerUrlHint',
    'fieldDatabaseHint',
    'fieldUsernameHint',
    'languageArabic',
  };

  test('every English string has an Arabic one, and nothing extra', () {
    expect(en.keys.toSet().difference(ar.keys.toSet()), isEmpty,
        reason: 'these would render in English on an Arabic device');
    expect(ar.keys.toSet().difference(en.keys.toSet()), isEmpty,
        reason: 'an Arabic string with no English key is unreachable');
  });

  test('no Arabic value is an untranslated copy of the English', () {
    // The failure this catches is a paste: the key exists, the parity test
    // above passes, and the screen is still in English.
    final copies = en.keys
        .where((k) => !identicalOnPurpose.contains(k) && en[k] == ar[k])
        .toList();

    expect(copies, isEmpty, reason: 'untranslated: $copies');
  });

  test('every Arabic value actually contains Arabic', () {
    final arabicScript = RegExp(r'[؀-ۿ]');
    final offenders = ar.entries
        .where((e) =>
            !identicalOnPurpose.contains(e.key) &&
            e.value.trim().isNotEmpty &&
            !arabicScript.hasMatch(e.value))
        .map((e) => '${e.key}: ${e.value}')
        .toList();

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('placeholders match, so neither language throws at runtime', () {
    // A placeholder present in one file and not the other is a crash in the
    // language nobody on the team reads day to day.
    /// The placeholder names a string actually substitutes.
    ///
    /// An ICU plural reads `{count, plural, =0{…} other{{count} x}}`: the name
    /// before the comma is the placeholder, while `=0` / `other` / `few` are
    /// branch labels that differ between the two languages **by design** —
    /// Arabic carries `=2` and `few`, English does not.
    String holders(String text) {
      final names = <String>{
        for (final match
            in RegExp(r'\{(\w+)\s*,\s*(?:plural|select)\s*,').allMatches(text))
          match.group(1)!,
        for (final match in RegExp(r'\{(\w+)\}').allMatches(text))
          match.group(1)!,
      };
      // Sorted and joined, because two Sets in Dart compare by identity: an
      // earlier version of this test compared `{count}` with `{count}`, got
      // "not equal", and reported a mismatch that did not exist.
      return (names.toList()..sort()).join(',');
    }

    final mismatched = <String>[
      for (final key in en.keys)
        if (holders(en[key]!) != holders(ar[key]!))
          '$key: en=[${holders(en[key]!)}] ar=[${holders(ar[key]!)}]',
    ];

    expect(mismatched, isEmpty, reason: mismatched.join('\n'));
  });

  test('every numeric placeholder declares a format', () {
    // Without `"format": "decimalPattern"` gen_l10n emits plain Dart
    // interpolation, which is always Latin — the bug that put "124" next to
    // "١٢٤" on the same card. See digit_consistency_test.dart.
    final template = arb('app_en.arb');
    final undeclared = <String>[];

    for (final entry in template.entries) {
      if (!entry.key.startsWith('@')) continue;
      final meta = entry.value;
      if (meta is! Map) continue;
      final placeholders = meta['placeholders'];
      if (placeholders is! Map) continue;

      for (final holder in placeholders.entries) {
        final spec = holder.value;
        if (spec is! Map) continue;
        final type = spec['type'];
        if (type != 'int' && type != 'double' && type != 'num') continue;
        if (spec['format'] == null) {
          undeclared.add('${entry.key}.${holder.key}');
        }
      }
    }

    expect(undeclared, isEmpty,
        reason: 'these render Latin digits in Arabic:\n${undeclared.join('\n')}');
  });

  test('every key the code calls exists in the template', () {
    final called = <String>{};
    final callSite = RegExp(r'\b_?[lL]10n\.([a-z]\w*)');

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('generated'))) {
      called.addAll(
        callSite.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
      );
    }

    // Members of AppL10n itself rather than message keys.
    called.removeAll(<String>{'localeName', 'lookup', 'delegate', 'of'});

    expect(called.difference(en.keys.toSet()), isEmpty,
        reason: 'called but never defined');
  });

  test('no user-facing English is typed into a widget', () {
    // The rule the ARB files exist to enforce. Catches the literal handed to a
    // Text() or to a label/hint/title parameter — the two shapes a hardcoded
    // sentence actually takes.
    final literal = RegExp(
      r'''(?:Text\(\s*'([^'\\]{3,})'|(?:label|title|hint|tooltip|message'''
      r'''|subtitle|hintText|labelText|errorText|helperText)'''
      r''':\s*'([^'\\]{3,})')''',
    );
    final words = RegExp(r'[A-Za-z]{3,}\s+[A-Za-z]{3,}');
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('generated'))) {
      final source = file.readAsStringSync();
      for (final line in source.split('\n')) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

        for (final match in literal.allMatches(line)) {
          final value = match.group(1) ?? match.group(2)!;
          // Two or more words is prose; one token is an identifier or a key.
          if (words.hasMatch(value)) {
            offenders.add('${file.path}: "$value"');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'move these into the ARB files:\n${offenders.join('\n')}');
  });
}
