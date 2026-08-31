import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the conventions the codebase is built on, by reading the source.
///
/// A code review catches these once; a test catches them on every commit. Each
/// group below encodes one rule that is easy to state and easy to break by
/// accident, and each failure message names the file and line so the fix is
/// obvious.
void main() {
  late List<_SourceFile> ui;
  late List<_SourceFile> all;

  setUpAll(() {
    all = _dartFilesUnder('lib');
    // Every file that draws something. `app/theme` and `core/constants` are
    // where the literals are *supposed* to live, so they are excluded — but
    // `app/router` renders a navigation bar and a More page, and used to be
    // the one place hardcoded English survived because this list was narrower.
    ui = all
        .where(
          (f) =>
              f.path.contains('lib/features/') ||
              f.path.contains('lib/shared/') ||
              f.path.contains('lib/app/router/') ||
              f.path.contains('lib/app/app.dart'),
        )
        .toList();
  });

  group('no hardcoded user-facing text', () {
    test('every Text() gets its string from AppL10n or a variable', () {
      final offenders = <String>[];

      // Text('literal') — but not Text(''), and not the l10n/variable forms.
      final literalText = RegExp(r'''\bText\(\s*['"]([^'"]{2,})['"]''');

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          final match = literalText.firstMatch(line);
          if (match == null) return;
          offenders.add('${file.path}:$number  ${match.group(1)}');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'User-facing text must come from AppL10n so it translates.\n'
            '${offenders.join('\n')}',
      );
    });

    test('no Arabic or English prose is embedded in widget code', () {
      final offenders = <String>[];
      final arabic = RegExp(r'[؀-ۿ]{3,}');

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          if (!arabic.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Arabic belongs in lib/l10n/app_ar.arb, never in a widget.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('no magic numbers in layout', () {
    test('SizedBox uses the spacing scale', () {
      final offenders = <String>[];
      final literal = RegExp(
        r'SizedBox\(\s*(?:width|height):\s*(\d+(?:\.\d+)?)\s*[,)]',
      );

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          final match = literal.firstMatch(line);
          if (match == null) return;
          // 0 and 1 are not measurements; they are "none" and "a hairline".
          final value = double.parse(match.group(1)!);
          if (value <= 1) return;
          offenders.add('${file.path}:$number  SizedBox(${match.group(1)})');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppSpacing / AppDimens so one edit changes the whole app.\n'
            '${offenders.join('\n')}',
      );
    });

    test('EdgeInsets values come from the spacing scale', () {
      final offenders = <String>[];
      final literal = RegExp(
        r'EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB)\('
        r'[^)]*?\b(\d{2,})(?:\.\d+)?\b',
      );

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          final match = literal.firstMatch(line);
          if (match == null) return;
          offenders.add('${file.path}:$number  ${match.group(0)}');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppSpacing constants inside EdgeInsets.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('no hardcoded resource paths', () {
    test('asset paths come from AppAssets', () {
      final offenders = <String>[];
      final assetPath = RegExp(r'''['"]assets/[^'"]+['"]''');

      for (final file in all) {
        // AppAssets is the one place the paths are allowed to be written.
        if (file.path.endsWith('app_constants.dart')) continue;
        file.forEachLine((line, number, raw) {
          if (!assetPath.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Reference assets through AppAssets so a rename is one edit.\n'
            '${offenders.join('\n')}',
      );
    });

    test('Odoo model names come from OdooModels', () {
      final offenders = <String>[];
      // Quoted `some.model` identifiers, which is how a model name looks.
      final modelName = RegExp(
        r'''['"](?:hr|maintenance|res|ir|stock|product|mail)\.[a-z_.]+['"]''',
      );

      for (final file in all) {
        if (file.path.endsWith('odoo_models.dart')) continue;
        file.forEachLine((line, number, raw) {
          if (!modelName.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use the OdooModels catalog so a version rename is one edit.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('no hardcoded colours outside the palette', () {
    test('Color(0x…) literals live only in AppColors', () {
      final offenders = <String>[];
      final colorLiteral = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');

      for (final file in all) {
        if (file.path.endsWith('app_colors.dart')) continue;
        file.forEachLine((line, number, raw) {
          if (!colorLiteral.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Add the colour to AppColors and reference it.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('no hardcoded colours outside the palette (continued)', () {
    test('named Material colours are not used as design decisions', () {
      // `Color(0x…)` was already banned, and `Colors.white` walked straight
      // past it — twenty-odd call sites, each one an unnamed decision about
      // what ink goes on a saturated fill, a camera preview or a printed QR
      // code. They are not the same decision and they do not have to keep the
      // same value.
      //
      // `Colors.transparent` is exempt: it is "none", the same kind of thing
      // as `EdgeInsets.zero`, not a colour anybody would want to restyle.
      final offenders = <String>[];
      final named = RegExp(r'\bColors\.(?!transparent\b)([a-z][A-Za-z0-9]*)');

      for (final file in all) {
        if (file.path.endsWith('app_colors.dart')) continue;
        file.forEachLine((line, number, raw) {
          final match = named.firstMatch(line);
          if (match == null) return;
          offenders.add('${file.path}:$number  Colors.${match.group(1)}');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Name the decision in AppColors (onAccent, onBrand, onCamera, '
            'qrPaper) and reference that.\n${offenders.join('\n')}',
      );
    });
  });

  group('no bare durations', () {
    test('animation and timeout lengths come from AppDurations', () {
      // AppDurations already says "no bare `Duration` literals in feature
      // code" in its own doc comment. Nothing enforced it, and one had
      // already drifted back in.
      final offenders = <String>[];
      final literal = RegExp(r'\bDuration\(\s*(?:milli|micro)?seconds:');

      for (final file in all) {
        // The scales themselves, and `AppConstants`, are where the numbers
        // are supposed to be written.
        if (file.path.endsWith('app_dimens.dart') ||
            file.path.endsWith('app_constants.dart')) {
          continue;
        }
        file.forEachLine((line, number, raw) {
          if (!literal.hasMatch(line)) return;
          // `Duration(days: …)` computed from a constant is arithmetic, not a
          // design token — the warranty buckets are the real case.
          if (line.contains('AppConstants.')) return;
          offenders.add('${file.path}:$number  ${line.trim()}');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Add it to AppDurations and reference it.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('secrets never bypass the sanitizer', () {
    test('nothing in lib prints directly', () {
      // Every line AppLogger emits goes through LogSanitizer, whose redaction
      // rules are covered in test/unit/core/security/log_sanitizer_test.dart.
      // A bare `print` or `debugPrint` goes around that — and the moment
      // somebody reaches for one is while debugging the very code that handles
      // credentials, which is exactly how a password reaches a log line and
      // then survives into a release build.
      final offenders = <String>[];
      final bare = RegExp(r'(^|[^A-Za-z0-9_.])(print|debugPrint)\s*\(');

      for (final file in all) {
        file.forEachLine((line, number, raw) {
          if (!bare.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppLogger, which scrubs secrets before writing.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('layering', () {
    test('no widget imports an Odoo service directly (spec §18)', () {
      final offenders = <String>[];

      for (final file in ui) {
        if (!file.path.contains('/presentation/')) continue;
        file.forEachLine((line, number, raw) {
          if (!raw.trimLeft().startsWith('import ')) return;
          if (raw.contains('core/network/odoo/odoo_object_service') ||
              raw.contains('core/network/odoo/odoo_auth_service') ||
              raw.contains('core/network/xmlrpc/')) {
            offenders.add('${file.path}:$number');
          }
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Presentation talks to use cases and repositories, never to the '
            'XML-RPC layer.\n${offenders.join('\n')}',
      );
    });

    test('domain never imports data or presentation', () {
      final offenders = <String>[];

      for (final file in all) {
        if (!file.path.contains('/domain/')) continue;
        file.forEachLine((line, number, raw) {
          if (!raw.trimLeft().startsWith('import ')) return;
          if (raw.contains('/data/') || raw.contains('/presentation/')) {
            offenders.add('${file.path}:$number  ${raw.trim()}');
          }
        });
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Dependencies point inward only.\n${offenders.join('\n')}',
      );
    });
  });

  group('the platform config the plugins need', () {
    // Neither of these is a compile error, and neither shows up until a user
    // taps the thing that needs it. The Android host activity in particular
    // gets regenerated by tooling now and then, and a plain FlutterActivity
    // builds, installs and launches perfectly well — then throws
    // `no_fragment_activity` the first time somebody turns on the device
    // unlock, which is the one moment they are least able to report it.
    test('MainActivity hosts fragments, so local_auth can show its prompt', () {
      final activity = Directory('android')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('MainActivity.kt'));

      final source = activity.readAsStringSync();

      expect(
        source,
        contains('FlutterFragmentActivity'),
        reason:
            "AndroidX's BiometricPrompt is a fragment. A plain "
            'FlutterActivity cannot host it.',
      );
    });

    test('the manifest declares the biometric permission', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android.permission.USE_BIOMETRIC'),
        reason:
            'A normal permission, granted at install and never prompted — '
            'but BiometricPrompt refuses to show without it.',
      );
    });

    test('iOS explains why it is asking for Face ID', () {
      // Apple rejects a build that uses Face ID without this key, at
      // submission rather than at build time.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('NSFaceIDUsageDescription'));
    });
  });

  group('RTL safety', () {
    test('no absolute Border(left:/right:)', () {
      // The same mistake as `EdgeInsets.only(left:)`, one class over, and it
      // is harder to spot: a bracket drawn with an absolute left border still
      // looks like a bracket in Arabic, it is just the wrong one.
      final offenders = <String>[];
      final absolute = RegExp(r'\bBorder\([^)]*\b(?:left|right):');

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          if (!absolute.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use BorderDirectional with start/end.\n'
            '${offenders.join('\n')}',
      );
    });

    test('no absolute BorderRadius.only(topLeft:/…)', () {
      final offenders = <String>[];
      final absolute = RegExp(
        r'\bBorderRadius\.only\([^)]*\b(?:topLeft|topRight|bottomLeft|bottomRight):',
      );

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          if (!absolute.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use BorderRadiusDirectional with topStart/topEnd.\n'
            '${offenders.join('\n')}',
      );
    });

    test('no directional EdgeInsets.only(left:/right:)', () {
      final offenders = <String>[];
      final leftRight = RegExp(r'EdgeInsets\.only\([^)]*\b(?:left|right):');

      for (final file in ui) {
        file.forEachLine((line, number, raw) {
          if (!leftRight.hasMatch(line)) return;
          offenders.add('${file.path}:$number');
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use EdgeInsetsDirectional with start/end so Arabic mirrors '
            'correctly.\n${offenders.join('\n')}',
      );
    });
  });
}

/// One source file, with comments and doc comments stripped from the line the
/// matchers see — so a rule explained in a comment does not trip the rule.
class _SourceFile {
  _SourceFile(this.path, this._lines);

  final String path;
  final List<String> _lines;

  static _SourceFile read(File file) =>
      _SourceFile(file.path.replaceAll(r'\', '/'), file.readAsLinesSync());

  void forEachLine(
    void Function(String stripped, int number, String raw) body,
  ) {
    var inBlockComment = false;

    for (var i = 0; i < _lines.length; i++) {
      final raw = _lines[i];
      final trimmed = raw.trimLeft();

      if (inBlockComment) {
        if (trimmed.contains('*/')) inBlockComment = false;
        continue;
      }
      if (trimmed.startsWith('/*')) {
        if (!trimmed.contains('*/')) inBlockComment = true;
        continue;
      }
      if (trimmed.startsWith('//')) continue;

      // Strip a trailing line comment, but not a `//` inside a string.
      final stripped = _stripTrailingComment(raw);
      if (stripped.trim().isEmpty) continue;

      body(stripped, i + 1, raw);
    }
  }

  static String _stripTrailingComment(String line) {
    var inSingle = false;
    var inDouble = false;

    for (var i = 0; i < line.length - 1; i++) {
      final char = line[i];
      if (char == r'\') {
        i++;
        continue;
      }
      if (char == "'" && !inDouble) inSingle = !inSingle;
      if (char == '"' && !inSingle) inDouble = !inDouble;
      if (!inSingle && !inDouble && char == '/' && line[i + 1] == '/') {
        return line.substring(0, i);
      }
    }
    return line;
  }
}

List<_SourceFile> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    // Generated localizations are not hand-written source.
    .where((f) => !f.path.replaceAll(r'\', '/').contains('/l10n/generated/'))
    .map(_SourceFile.read)
    .toList();
