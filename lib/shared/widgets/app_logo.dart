import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Which form of the brand mark to draw.
enum BrandMark {
  /// Full horizontal lockup: symbol, wordmark and the IT badge.
  lockup,

  /// The symbol alone — app bars, avatars, tight spaces.
  monogram,

  /// Wordmark with the tagline, stacked.
  wordmark,
}

/// The brand mark, in the variant that suits the surface it sits on.
///
/// The mark is navy artwork with a mint accent, which disappears on a dark
/// ground. A dark-mode set exists where the navy becomes the dark theme's ink
/// and the mint is left alone — this widget is the only thing that knows which
/// file to reach for, so no screen ever picks by hand and none can get it
/// wrong.
///
/// The choice follows [Theme.of] by default, but a screen that paints its own
/// dark ground in *both* themes — the splash, the login band — passes
/// [onDarkSurface] to override it. That is the case a plain theme check gets
/// wrong: the theme says light, the surface underneath is navy, and the mark
/// would vanish into it.
class AppLogo extends StatelessWidget {
  const AppLogo(
    this.mark, {
    this.width,
    this.height,
    this.onDarkSurface,
    super.key,
  });

  const AppLogo.lockup({double? width, bool? onDarkSurface, Key? key})
    : this(
        BrandMark.lockup,
        width: width,
        onDarkSurface: onDarkSurface,
        key: key,
      );

  const AppLogo.monogram({double? size, bool? onDarkSurface, Key? key})
    : this(
        BrandMark.monogram,
        width: size,
        height: size,
        onDarkSurface: onDarkSurface,
        key: key,
      );

  const AppLogo.wordmark({double? width, bool? onDarkSurface, Key? key})
    : this(
        BrandMark.wordmark,
        width: width,
        onDarkSurface: onDarkSurface,
        key: key,
      );

  final BrandMark mark;
  final double? width;
  final double? height;

  /// Overrides the theme when the surface behind the mark is not the theme's
  /// own. Null follows [Theme.of].
  final bool? onDarkSurface;

  @override
  Widget build(BuildContext context) {
    final isDark =
        onDarkSurface ?? Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      assetFor(mark, isDark: isDark),
      width: width,
      height: height,
      // The mark is decoration beside a title that already names the product;
      // announcing it again would just make a screen reader say "Sijil IT"
      // twice.
      excludeFromSemantics: true,
    );
  }

  /// The asset path for a mark on a light or dark ground.
  static String assetFor(BrandMark mark, {required bool isDark}) =>
      switch (mark) {
        BrandMark.lockup =>
          isDark ? AppAssets.logoLockupDark : AppAssets.logoLockup,
        BrandMark.monogram =>
          isDark ? AppAssets.logoMonogramDark : AppAssets.logoMonogram,
        BrandMark.wordmark =>
          isDark ? AppAssets.logoWordmarkDark : AppAssets.logoWordmark,
      };
}
