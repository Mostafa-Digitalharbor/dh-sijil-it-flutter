import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

/// One screen must not show two numbering systems.
///
/// The Arabic copy is written with Arabic-Indic digits ("١٢ شهر", "٣٠ يومًا").
/// Every *number the app computes* has to match — and by default it does not:
/// CLDR moved generic `ar` to Latin digits, so both `NumberFormat` and the ICU
/// placeholders inside the ARB files render `124` right next to `١٢٤`.
///
/// The fix is that Arabic resolves to `ar_EG`. This locks it in, because the
/// symptom is subtle enough to survive a dozen screenshots unnoticed.
void main() {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  bool isArabicIndic(String s) => s.split('').any(arabicIndic.contains);
  bool hasLatinDigits(String s) => RegExp(r'[0-9]').hasMatch(s);

  test('the Arabic the app resolves to is the one with Arabic-Indic digits', () {
    // Guards the ordering in supportedLocales: Flutter picks the first entry
    // matching the language, so ar_EG has to come before bare ar.
    final arabic = AppSettingsCubit.supportedLocales
        .where((l) => l.languageCode == 'ar')
        .toList();

    expect(arabic, isNotEmpty);
    expect(
      arabic.first.countryCode,
      'EG',
      reason: 'plain `ar` formats numbers in Latin — see app_ar_EG.arb',
    );
  });

  test('NumberFormat gives Arabic-Indic digits for the resolved locale', () {
    final locale = AppSettingsCubit.supportedLocales
        .firstWhere((l) => l.languageCode == 'ar')
        .toString();

    final formatted = NumberFormat.decimalPattern(locale).format(124);

    expect(isArabicIndic(formatted), isTrue, reason: 'got "$formatted"');
    expect(hasLatinDigits(formatted), isFalse);
  });

  test('English is unaffected', () {
    expect(NumberFormat.decimalPattern('en').format(124), '124');
  });

  group('locale resolution', () {
    Future<AppPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return AppPreferences.create();
    }

    testWidgets('picking "Arabic" resolves to the locale with the digits', (
      _,
    ) async {
      // MaterialApp.locale is set explicitly from this cubit, so Flutter's own
      // resolution against supportedLocales never runs — the cubit must do it.
      final cubit = AppSettingsCubit(await prefsWith(<String, Object>{}));

      await cubit.setLocale(const Locale('ar'));

      expect(cubit.state.locale, const Locale('ar', 'EG'));
      expect(cubit.state.isArabic, isTrue);
    });

    testWidgets('a stored language code reloads as the resolved locale', (
      _,
    ) async {
      final cubit = AppSettingsCubit(
        await prefsWith(<String, Object>{'locale': 'ar'}),
      );

      expect(cubit.state.locale, const Locale('ar', 'EG'));
    });

    testWidgets('English is left alone', (_) async {
      final cubit = AppSettingsCubit(await prefsWith(<String, Object>{}));

      await cubit.setLocale(const Locale('en'));

      expect(cubit.state.locale, const Locale('en'));
    });
  });

  group('ICU placeholders', () {
    late AppL10n ar;

    setUpAll(() async {
      ar = await AppL10n.delegate.load(const Locale('ar', 'EG'));
    });

    test('a plain count placeholder renders Arabic-Indic', () {
      final rendered = ar.auditOf(3, 22);

      expect(isArabicIndic(rendered), isTrue, reason: 'got "$rendered"');
      expect(
        hasLatinDigits(rendered),
        isFalse,
        reason: 'an int placeholder fell back to Latin: "$rendered"',
      );
    });

    test('a plural placeholder renders Arabic-Indic too', () {
      // Plurals are why the locale had to carry this rather than each call
      // site: an ICU plural cannot take a pre-formatted string.
      final rendered = ar.historyHolders(7);

      expect(hasLatinDigits(rendered), isFalse, reason: 'got "$rendered"');
    });

    test('the ar_EG class inherits every string from ar, none duplicated', () {
      // app_ar_EG.arb is deliberately empty; if someone starts adding strings
      // to it the two Arabic files drift apart silently.
      final content = File('lib/l10n/app_ar_EG.arb').readAsStringSync();
      final keys = RegExp(r'"(?!@)([A-Za-z][A-Za-z0-9_]*)"\s*:').allMatches(content);

      expect(
        keys,
        isEmpty,
        reason: 'app_ar_EG.arb must stay empty — translate in app_ar.arb',
      );
      expect(ar.auditTitle, isNotEmpty, reason: 'inheritance is working');
    });
  });

  test('no number reaches the UI through Dart interpolation', () {
    // The fourth time this bug appeared. `'$count'` is always Latin whatever
    // the locale, so a value interpolated straight into a widget renders "8"
    // beside "٣٠" on the same card — which is what the dashboard's two
    // attention tiles were doing while every other number on that screen was
    // already correct.
    //
    // Counts go through AppNumber; identifiers go through MonoText. Nothing
    // goes through string interpolation.
    final interpolated = RegExp(
      r"""'\$\{?([A-Za-z_][\w.]*(?:\(\))?)\}?'""",
    );
    final numeric = RegExp(
      'count|total|length|number|days|remaining|size|index',
      caseSensitive: false,
    );
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('generated'))) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;

        for (final match in interpolated.allMatches(line)) {
          if (numeric.hasMatch(match.group(1)!)) {
            offenders.add('${file.path}:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'route these through AppNumber.count:\n${offenders.join('\n')}',
    );
  });

  test('Arabic copy in the ARB uses Arabic-Indic, matching what is computed', () {
    // The rule is only worth anything if both halves agree. This catches the
    // reverse drift: someone typing Latin digits into an Arabic string.
    final content = File('lib/l10n/app_ar.arb').readAsStringSync();
    final offenders = <String>[];

    for (final line in content.split('\n')) {
      final match = RegExp(r'^\s*"([A-Za-z][A-Za-z0-9_]*)"\s*:\s*"(.*)",?$')
          .firstMatch(line);
      if (match == null) continue;
      final value = match.group(2)!;
      // Identifiers, URLs and format patterns legitimately carry Latin digits.
      if (value.contains('http') || value.contains('{')) continue;
      if (RegExp(r'[0-9]').hasMatch(value) &&
          RegExp(r'[؀-ۿ]').hasMatch(value)) {
        offenders.add('${match.group(1)}: $value');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Arabic strings mixing Latin digits with Arabic text:\n'
          '${offenders.join('\n')}',
    );
  });
}
