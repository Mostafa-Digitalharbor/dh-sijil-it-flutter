import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/utils/app_number.dart';

/// One screen must not show two numbering systems.
///
/// The product's answer is **Western digits everywhere, in every language**: an
/// Arabic screen reads `124 أصل`, not `١٢٤ أصل`. The reasoning lives on
/// [AppNumber]; the short version is that most numbers in this app are
/// identifiers — asset tags, serials, ISO dates, MAC addresses — which are
/// printed on the hardware in Western digits and can never be localised. A
/// screen that localises only the rest ends up showing both.
///
/// This file is the lock. The symptom is subtle enough to survive a dozen
/// screenshots unnoticed, and it has now been got wrong in both directions.
void main() {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  bool hasArabicIndic(String s) => s.split('').any(arabicIndic.contains);

  test('Arabic resolves to plain `ar`, which CLDR gives Western digits', () {
    // The inverse of what this test used to assert. `ar_EG` was listed ahead
    // of `ar` specifically to *get* the Arabic-Indic set; both that entry and
    // the empty `app_ar_EG.arb` propping it up are gone.
    final arabic = AppSettingsCubit.supportedLocales
        .where((l) => l.languageCode == 'ar')
        .toList();

    expect(arabic, hasLength(1), reason: 'one Arabic locale, no variants');
    expect(
      arabic.single.countryCode,
      isNull,
      reason: 'a country variant would reintroduce a second numeral system',
    );
  });

  test('the empty ar_EG ARB is gone, not merely unreferenced', () {
    // Leaving the file behind would let gen_l10n regenerate the class the next
    // time someone runs it, and the locale would quietly come back.
    expect(File('lib/l10n/app_ar_EG.arb').existsSync(), isFalse);
  });

  test('NumberFormat gives Western digits for every supported locale', () {
    for (final locale in AppSettingsCubit.supportedLocales) {
      final formatted = NumberFormat.decimalPattern(
        locale.toString(),
      ).format(1234);

      expect(
        hasArabicIndic(formatted),
        isFalse,
        reason: '$locale formatted 1234 as "$formatted"',
      );
      expect(RegExp(r'[0-9]').hasMatch(formatted), isTrue);
    }
  });

  group('AppNumber.latinDigits', () {
    test('rewrites the Arabic-Indic set', () {
      expect(AppNumber.latinDigits('١٢٤'), '124');
      expect(AppNumber.latinDigits('٠٩'), '09');
    });

    test('leaves everything else untouched', () {
      expect(AppNumber.latinDigits('DH-LAP-0012'), 'DH-LAP-0012');
      expect(AppNumber.latinDigits('20 يوليو 2026'), '20 يوليو 2026');
      // Arabic letters share a block with the digits; only the ten glyphs go.
      expect(AppNumber.latinDigits('أصل'), 'أصل');
    });

    test('is the guard for a locale added later', () {
      // Today `ar` already formats Western, so this helper is a no-op on
      // everything the app produces. It exists so that adding `ar_EG`, `fa` or
      // `ur` cannot silently undo the rule.

      // Arabic-Indic, U+0660.
      expect(
        AppNumber.latinDigits(NumberFormat.decimalPattern('ar_EG').format(124)),
        '124',
      );

      // Extended Arabic-Indic, U+06F0 — a *different* block whose glyphs look
      // almost identical. Persian and Urdu use it, and the first version of
      // this helper covered only the block above, which is a bug no reviewer
      // could have caught by eye. This assertion is why it was caught.
      expect(
        AppNumber.latinDigits(NumberFormat.decimalPattern('fa').format(7)),
        '7',
      );
      // Asserted on the glyphs rather than on the whole string: `ur` groups
      // 2026 as "2,026", and the grouping is the locale's business. Only the
      // ten digit shapes are this helper's.
      final urdu = AppNumber.latinDigits(
        NumberFormat.decimalPattern('ur').format(2026),
      );
      expect(RegExp(r'^[0-9,.\s]+$').hasMatch(urdu), isTrue, reason: urdu);
    });
  });

  group('locale resolution', () {
    Future<AppPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return AppPreferences.create();
    }

    testWidgets('picking "Arabic" resolves to the supported entry', (_) async {
      // MaterialApp.locale is set explicitly from this cubit, so Flutter's own
      // resolution against supportedLocales never runs — the cubit must do it.
      final cubit = AppSettingsCubit(await prefsWith(<String, Object>{}));

      await cubit.setLocale(const Locale('ar'));

      expect(cubit.state.locale, const Locale('ar'));
      expect(cubit.state.isArabic, isTrue);
    });

    testWidgets('a stored language code reloads as the resolved locale', (
      _,
    ) async {
      final cubit = AppSettingsCubit(
        await prefsWith(<String, Object>{'locale': 'ar'}),
      );

      expect(cubit.state.locale, const Locale('ar'));
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
      ar = await AppL10n.delegate.load(const Locale('ar'));
    });

    test('a plain count placeholder renders Western', () {
      final rendered = ar.auditOf(3, 22);

      expect(hasArabicIndic(rendered), isFalse, reason: 'got "$rendered"');
      expect(rendered, contains('3'));
      expect(rendered, contains('22'));
    });

    test('a plural placeholder renders Western too', () {
      // Plurals are why the locale has to carry this rather than each call
      // site: an ICU plural cannot take a pre-formatted string, so the digits
      // come from whatever locale the generated class was built for.
      final rendered = ar.historyHolders(7);

      expect(hasArabicIndic(rendered), isFalse, reason: 'got "$rendered"');
      expect(rendered, contains('7'));
    });
  });

  test('no number reaches the UI through Dart interpolation', () {
    // `'$count'` bypasses the formatter entirely. That is no longer a *digit*
    // bug now that everything is Western, but it is still a grouping bug —
    // interpolation prints `1234567`, the formatter prints `1,234,567` — and
    // it is how a number escapes the one place the rule is enforced.
    //
    // The pattern is deliberately wider than the one this test shipped with,
    // which missed two live instances:
    //
    //   AppStepHeader   Text('$step')
    //   PhotoStrip      Text('+$extra'), '1/${photos.length}'
    //
    // Both escaped for the same two reasons. The old regex required the string
    // to be *nothing but* the interpolation, so anything with a sign or a
    // separator around it ('+$extra', '1/$n') was invisible; and the vocabulary
    // did not list `step` or `extra`.
    final interpolated = RegExp(r'\$\{?([A-Za-z_][\w.]*(?:\(\))?)\}?');
    // Whole words, not substrings. Without the boundaries `count` matched
    // inside `country` — `'${locale.languageCode}_$country'` is a locale id
    // handed to a speech recogniser, contains no number, and is not something
    // a user reads.
    final numeric = RegExp(
      r'\b(?:count|total|length|number|days|remaining|size|index|step|extra|'
      r'quantity|amount|position|page|hours|minutes|months|years)\b',
      caseSensitive: false,
    );
    final offenders = <String>[];

    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.contains('generated'))
            // The rule is about what a *user reads on a screen*, so two things
            // are deliberately outside it.
            //
            // `app_number.dart` is where the formatting is defined: it has to
            // interpolate to produce the string everything else consumes.
            //
            // `data/` composes text written **into Odoo** — chatter notes,
            // which `AssetNoteVocabulary` parses back out again on another
            // device in another language. Those are wire format, not copy.
            .where((f) => !f.path.endsWith('app_number.dart'))
            .where(
              (f) => !f.path.contains(
                '${Platform.pathSeparator}data'
                '${Platform.pathSeparator}',
              ),
            )) {
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

  test('no Arabic-Indic digit is typed into the Arabic copy', () {
    // The reverse drift, and the one a translator introduces rather than a
    // developer: four strings were written as "٣٠ يومًا" back when the computed
    // numbers matched. They now have to read "30 يومًا", because the number
    // beside them on the same card does.
    final content = File('lib/l10n/app_ar.arb').readAsStringSync();
    final offenders = <String>[];

    for (final line in content.split('\n')) {
      final match = RegExp(
        r'^\s*"([A-Za-z][A-Za-z0-9_]*)"\s*:\s*"(.*)",?$',
      ).firstMatch(line);
      if (match == null) continue;

      if (hasArabicIndic(match.group(2)!)) {
        offenders.add('${match.group(1)}: ${match.group(2)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'the product renders every number in Western digits:\n'
          '${offenders.join('\n')}',
    );
  });
}
