import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rule `app_dimens.dart` states about itself, made enforceable.
///
/// > Nothing in `lib/features` or `lib/shared` may write a bare number into a
/// > `SizedBox`, `EdgeInsets`, `width`, `height`, `size` or `borderRadius`.
/// > If a value is not here, it does not exist yet — add it here first.
///
/// It was a comment, so it was followed in spirit and broken in a way nobody
/// searched for: not `SizedBox(height: 9)`, which is obvious in review, but
/// `SizedBox(height: AppSpacing.sm + 1)`, which reads like a token and is a
/// bare `1` in a widget. Seventy of those had accumulated across forty files,
/// and thirteen separate call sites had each independently arrived at 9
/// without any of them being able to see the others.
///
/// Arithmetic on a token is worse than a plain number, because a plain number
/// is at least honest. `AppSpacing.sm + 1` also silently breaks the thing the
/// scale exists to guarantee: change `sm` and every `sm + 1` moves with it, to
/// a value nobody chose.
void main() {
  /// Everything under `lib`, minus the files that are allowed to hold numbers
  /// because defining them is their job.
  List<File> sourceFiles() {
    const scaleFiles = <String>{
      'app_spacing.dart',
      'app_dimens.dart',
      'app_typography.dart',
      'app_colors.dart',
      'app_palette.dart',
      'app_theme.dart',
    };

    // A different measurement system, not an exemption from this one.
    //
    // `core/export` lays out A4 pages in PostScript points through the `pdf`
    // package's own `SizedBox` and `EdgeInsets`. Those are not the widgets
    // this rule is about, and `AppSpacing.md` — a density-independent pixel
    // meant for a phone — is the wrong unit for a printed margin. Giving
    // print its own token scale would mean two scales, which is the thing
    // having one scale exists to prevent.
    bool isPrintLayout(File file) => file.path.contains(
      '${Platform.pathSeparator}export'
      '${Platform.pathSeparator}',
    );

    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('generated'))
        .where((f) => !scaleFiles.contains(f.uri.pathSegments.last))
        .where((f) => !isPrintLayout(f))
        .toList();
  }

  /// `path:line  text`, for every line matching [pattern].
  List<String> offendingLines(RegExp pattern) {
    final offenders = <String>[];

    for (final file in sourceFiles()) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // Doc comments quote the very patterns this test forbids.
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        if (pattern.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    return offenders;
  }

  test('no arithmetic on a design token', () {
    final offenders = offendingLines(
      RegExp(r'App(?:Spacing|Radii|Dimens|Opacities)\.\w+\s*[-+]\s*[\d.]+'),
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'A token plus a number is a magic number wearing a token\'s name, '
          'and it moves when the token moves. Name the value in '
          'app_spacing.dart or app_dimens.dart and use it:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no bare number in a SizedBox', () {
    final offenders = offendingLines(
      RegExp(r'SizedBox\(\s*(?:height|width):\s*[\d.]+\s*[,)]'),
    );

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no bare number in an EdgeInsets', () {
    // Two steps rather than one regex. A single pattern has to express "a
    // numeric literal anywhere in the argument list, but not the digits inside
    // a name like `AppRadii.sm`", and the first attempt at that caught
    // `EdgeInsets.symmetric(horizontal: 12)` while missing `EdgeInsets.all(12)`
    // — the argument with no label in front of it.
    //
    // So: find the call, then read its arguments.
    final call = RegExp(
      r'EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB)\(([^)]*)\)',
    );
    // A number that is not part of a dotted name, so `AppSpacing.md` is not a
    // match and a literal `12` is.
    final bareNumber = RegExp(r'(?<![\w.])\d+(?:\.\d+)?');

    final offenders = <String>[];
    for (final file in sourceFiles()) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

        for (final match in call.allMatches(lines[i])) {
          // Zero is the absence of a measurement rather than one, so naming it
          // would add a lookup and mean nothing.
          final numbers = bareNumber
              .allMatches(match.group(1)!)
              .map((m) => double.parse(m.group(0)!))
              .where((n) => n != 0);

          if (numbers.isNotEmpty) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no bare alpha on a colour', () {
    // Opacity is a design decision with a name in [AppOpacities]. A fully
    // transparent gradient stop is exempt for the same reason zero is above.
    final offenders = offendingLines(
      RegExp(r'withValues\(\s*alpha:\s*(?!0\s*[,)])[\d.]+'),
    );

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no bare number for a border radius', () {
    final offenders = offendingLines(
      RegExp(r'(?:BorderRadius|Radius)\.circular\(\s*[\d.]+\s*\)'),
    );

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every asset path is declared in AppAssets', () {
    // A path typed at the point of use is a file that still resolves after
    // the asset is renamed — until it is run.
    final offenders = offendingLines(
      RegExp("'assets/"),
    ).where((line) => !line.contains('app_constants.dart')).toList();

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
