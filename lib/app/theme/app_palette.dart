import 'package:flutter/material.dart';

import './app_colors.dart';

/// The Obsidian tokens that have no home in [ColorScheme].
///
/// `ColorScheme` covers primary/surface/error and little else. The design
/// leans on a handful of roles Material has no slot for — the ground behind a
/// raised card, the faint third text tier, the progress track, the glass
/// gradient — and a widget that reaches for `isDark ? x : y` to get them puts
/// a brightness branch in every build method.
///
/// A [ThemeExtension] resolves them once per theme instead, so widgets read
/// `context.palette.faint` and stay brightness-agnostic. It also means the
/// responsive/dark sweep tests exercise the real values rather than a branch
/// the test has to remember to flip.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.ground,
    required this.raised,
    required this.sunken,
    required this.line,
    required this.lineSoft,
    required this.ink,
    required this.dim,
    required this.faint,
    required this.track,
    required this.mint,
    required this.onMint,
    required this.glassTop,
    required this.glassBottom,
    required this.edge,
    required this.navBar,
  });

  /// The page ground. Every raised surface sits on this.
  final Color ground;

  /// A card, row or field — one step above [ground].
  final Color raised;

  /// Deeper than [ground]: the QR plate, a signature pad, an empty well.
  final Color sunken;

  final Color line;
  final Color lineSoft;

  /// Primary, secondary and tertiary text tiers.
  final Color ink;
  final Color dim;
  final Color faint;

  /// The unfilled part of a progress bar, ring or donut.
  final Color track;

  /// Accent, and the ink that stays legible on top of it.
  final Color mint;
  final Color onMint;

  /// The two stops of a glass card's fill, and the 1px highlight along its top
  /// edge that gives it a lit rim.
  final Color glassTop;
  final Color glassBottom;
  final Color edge;

  /// Bottom navigation ground — translucent so the list scrolls under it.
  final Color navBar;

  static const AppPalette dark = AppPalette(
    ground: AppColors.surfaceDark,
    raised: AppColors.cardDark,
    sunken: AppColors.voidDark,
    line: AppColors.borderDark,
    lineSoft: AppColors.borderSoftDark,
    ink: AppColors.textPrimaryDark,
    dim: AppColors.textSecondaryDark,
    faint: AppColors.textFaintDark,
    track: AppColors.trackDark,
    mint: AppColors.mint,
    onMint: AppColors.onMintDark,
    glassTop: AppColors.glassTopDark,
    glassBottom: AppColors.glassBottomDark,
    edge: AppColors.glassEdgeDark,
    navBar: AppColors.navBarDark,
  );

  static const AppPalette light = AppPalette(
    ground: AppColors.surfaceLight,
    raised: AppColors.cardLight,
    sunken: AppColors.trackLight,
    line: AppColors.borderLight,
    lineSoft: AppColors.borderSoftLight,
    ink: AppColors.textPrimaryLight,
    dim: AppColors.textSecondaryLight,
    faint: AppColors.textFaintLight,
    track: AppColors.trackLight,
    mint: AppColors.mintInk,
    onMint: AppColors.onMintLight,
    glassTop: AppColors.glassTopLight,
    glassBottom: AppColors.glassBottomLight,
    edge: AppColors.glassEdgeLight,
    navBar: AppColors.navBarLight,
  );

  /// The palette for the current theme.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  /// Fill for a tinted surface in this palette's status colour.
  ///
  /// Light mode needs a weaker tint than dark: the same alpha over white reads
  /// far louder than it does over navy.
  double get tintAlpha => this == light ? 0.11 : 0.14;

  @override
  AppPalette copyWith({
    Color? ground,
    Color? raised,
    Color? sunken,
    Color? line,
    Color? lineSoft,
    Color? ink,
    Color? dim,
    Color? faint,
    Color? track,
    Color? mint,
    Color? onMint,
    Color? glassTop,
    Color? glassBottom,
    Color? edge,
    Color? navBar,
  }) {
    return AppPalette(
      ground: ground ?? this.ground,
      raised: raised ?? this.raised,
      sunken: sunken ?? this.sunken,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      ink: ink ?? this.ink,
      dim: dim ?? this.dim,
      faint: faint ?? this.faint,
      track: track ?? this.track,
      mint: mint ?? this.mint,
      onMint: onMint ?? this.onMint,
      glassTop: glassTop ?? this.glassTop,
      glassBottom: glassBottom ?? this.glassBottom,
      edge: edge ?? this.edge,
      navBar: navBar ?? this.navBar,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      ground: c(ground, other.ground),
      raised: c(raised, other.raised),
      sunken: c(sunken, other.sunken),
      line: c(line, other.line),
      lineSoft: c(lineSoft, other.lineSoft),
      ink: c(ink, other.ink),
      dim: c(dim, other.dim),
      faint: c(faint, other.faint),
      track: c(track, other.track),
      mint: c(mint, other.mint),
      onMint: c(onMint, other.onMint),
      glassTop: c(glassTop, other.glassTop),
      glassBottom: c(glassBottom, other.glassBottom),
      edge: c(edge, other.edge),
      navBar: c(navBar, other.navBar),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPalette &&
          other.ground == ground &&
          other.raised == raised &&
          other.ink == ink &&
          other.mint == mint;

  @override
  int get hashCode => Object.hash(ground, raised, ink, mint);
}

extension AppPaletteX on BuildContext {
  /// Obsidian tokens for the current theme.
  AppPalette get palette => AppPalette.of(this);

  /// A status hue tinted for use as a surface behind its own label.
  Color tint(Color tone) => tone.withValues(alpha: palette.tintAlpha);

  /// A status hue at the weight it should be *read* at in this theme.
  ///
  /// Dark mode uses the raw hue; light mode swaps in the darkened partner,
  /// because the raw hue was tuned to glow on navy and fails as text on white.
  Color ink(Color tone) => Theme.of(this).brightness == Brightness.dark
      ? tone
      : AppColors.inkFor(tone);
}
