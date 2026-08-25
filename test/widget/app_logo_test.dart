import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/shared/widgets/app_logo.dart';

import '../fake_odoo/test_app_harness.dart';

/// The brand mark has to change with the surface, not with the theme alone.
///
/// The bug this guards against is silent: a navy mark on a navy ground renders
/// as an empty gap, and nothing throws. Only an assertion on which file was
/// chosen catches it.
void main() {
  /// The asset the widget actually resolved to.
  String assetOf(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  Future<void> pumpLogo(
    WidgetTester tester, {
    required ThemeMode themeMode,
    bool? onDarkSurface,
    BrandMark mark = BrandMark.lockup,
  }) async {
    await tester.pumpWidget(
      TestApp(
        themeMode: themeMode,
        child: Scaffold(
          body: Center(child: AppLogo(mark, onDarkSurface: onDarkSurface)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('every declared asset exists on disk', () {
    test('light and dark variants are both bundled', () {
      const paths = <String>[
        AppAssets.logoLockup,
        AppAssets.logoLockupDark,
        AppAssets.logoMonogram,
        AppAssets.logoMonogramDark,
        AppAssets.logoWordmark,
        AppAssets.logoWordmarkDark,
        AppAssets.appIcon,
      ];

      final missing = paths.where((p) => !File(p).existsSync()).toList();

      expect(
        missing,
        isEmpty,
        reason:
            'A missing asset renders as a grey box at runtime and throws '
            'nothing.\n${missing.join('\n')}',
      );
    });

    test('the assets directory is declared in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/'));
    });
  });

  group('the mark follows the theme', () {
    testWidgets('light theme uses the navy artwork', (tester) async {
      await pumpLogo(tester, themeMode: ThemeMode.light);
      expect(assetOf(tester), AppAssets.logoLockup);
    });

    testWidgets('dark theme uses the light-ink artwork', (tester) async {
      await pumpLogo(tester, themeMode: ThemeMode.dark);
      expect(assetOf(tester), AppAssets.logoLockupDark);
    });

    testWidgets('each mark has its own pair', (tester) async {
      for (final mark in BrandMark.values) {
        await pumpLogo(tester, themeMode: ThemeMode.light, mark: mark);
        final light = assetOf(tester);

        await pumpLogo(tester, themeMode: ThemeMode.dark, mark: mark);
        final dark = assetOf(tester);

        expect(
          light,
          isNot(dark),
          reason: '${mark.name} resolved to the same file in both themes.',
        );
        expect(dark, endsWith('-dark.png'));
      }
    });
  });

  group('the mark follows the surface when told to', () {
    testWidgets('a navy band in light theme still gets the dark mark', (
      tester,
    ) async {
      // The splash and the login band paint navy in *both* themes. A plain
      // theme check would hand them the navy mark and it would disappear.
      await pumpLogo(tester, themeMode: ThemeMode.light, onDarkSurface: true);

      expect(assetOf(tester), AppAssets.logoLockupDark);
    });

    testWidgets('a light card in dark theme gets the navy mark', (
      tester,
    ) async {
      await pumpLogo(tester, themeMode: ThemeMode.dark, onDarkSurface: false);

      expect(assetOf(tester), AppAssets.logoLockup);
    });
  });

  group('resolution is pure', () {
    test('assetFor maps every mark in both directions', () {
      for (final mark in BrandMark.values) {
        final light = AppLogo.assetFor(mark, isDark: false);
        final dark = AppLogo.assetFor(mark, isDark: true);

        expect(light, isNot(dark));
        expect(light, startsWith('assets/'));
        expect(dark, '${light.substring(0, light.length - 4)}-dark.png');
      }
    });
  });
}
