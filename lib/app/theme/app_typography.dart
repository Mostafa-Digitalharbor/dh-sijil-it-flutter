import 'package:flutter/material.dart';

/// Type scale for the product (design/v3 "Obsidian").
///
/// ## Three families, three jobs
///
/// **Archivo** is the Latin UI face — an engineered grotesque that holds its
/// shape at `w900`, which the dashboard's big numerals need. It ships **zero
/// Arabic glyphs**, so it cannot carry the Arabic UI on its own.
///
/// **IBM Plex Sans Arabic** is registered as a per-glyph
/// [TextStyle.fontFamilyFallback] rather than as a separate Arabic theme. That
/// choice matters: asset records mix scripts constantly
/// (`ماك بوك برو M4 · DH-LAP-0027`), and a fallback resolves per glyph, so one
/// [TextStyle] renders both halves correctly with no locale branching anywhere
/// in the widget tree.
///
/// **JetBrains Mono** is for identifiers only — asset tags, serials, ISO
/// dates, server addresses, versions. Those are printed on the hardware in
/// Latin and get compared character by character, so they are set in a face
/// where `0`/`O` and `1`/`l` differ and where columns line up. See [mono].
///
/// ## Digits
///
/// A **count** follows the language: `١٢٤ أصل` in Arabic, `124 assets` in
/// English — that is Flutter's default via `NumberFormat`, and nothing here
/// overrides it. An **identifier** never does. `SJL-0042` is the same six
/// characters in every locale because that is what is on the sticker, which
/// is exactly what [mono] enforces by pairing a Latin-only face with
/// [TextDirection.ltr] at the call site.
/// The type steps that live *below* the Material text theme.
///
/// `bodySmall` is the smallest style [AppTypography.textTheme] defines.
/// Everything under it is a micro label — a chart axis tick, a nav caption, a
/// badge sitting on a photo — and those were being typed at the call site as
/// bare numbers, which is how `9.5` and `10` ended up on two labels that were
/// meant to match. At this size half a point is visible, and a drift nobody
/// reports is one everybody notices.
///
/// Named by the job, not the number: changing what a chart axis reads at is
/// one edit here, and it cannot accidentally resize a photo badge that
/// happened to share the value.
abstract final class AppTextSize {
  /// Text inside a small overlay chip — the "+3" on a photo stack.
  static const double badge = 8.5;

  /// A caption under a thumbnail.
  static const double caption = 9;

  /// Chart axis ticks, and the hint inside the signature pad.
  static const double axis = 9.5;

  /// Bottom-navigation labels and photo metadata.
  static const double nav = 10;

  /// The secondary line in a timeline entry.
  static const double meta = 10.5;

  /// Identifiers and inline labels — the most-used micro step.
  static const double label = 11;

  /// A status-legend entry.
  static const double legend = 11.5;

  /// The count beside a legend entry, one step up so the number leads.
  static const double legendValue = 12;

  const AppTextSize._();
}

abstract final class AppTypography {
  static const String latinFamily = 'Archivo';
  static const String arabicFamily = 'IBMPlexSansArabic';
  static const String monoFamily = 'JetBrainsMono';

  /// Every style falls back through here for glyphs Archivo lacks.
  static const List<String> fallback = <String>[arabicFamily];

  static const FontWeight black = FontWeight.w900;
  static const FontWeight heavy = FontWeight.w800;
  static const FontWeight boldest = FontWeight.w700;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight regular = FontWeight.w400;

  /// A numeral set solid — line box equal to the font size.
  ///
  /// For the big figures on stat tiles, where the theme's generous leading
  /// pushes the number off-centre in a box sized to the number.
  static const double solidLineHeight = 1;

  /// Cancels the tracking the text theme applies to label styles.
  ///
  /// Micro labels are already tight; the extra letter-spacing that makes a
  /// button legible makes a 9-point caption look spaced out. Named, because
  /// `letterSpacing: 0` at a call site reads as "no opinion" when it is in
  /// fact a deliberate override of one.
  static const double noTracking = 0;

  static TextStyle _style({
    required double size,
    required FontWeight weight,
    double? tracking,
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: latinFamily,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: color,
    );
  }

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      double? tracking,
      double? height,
      Color? color,
    }) => _style(
      size: size,
      weight: weight,
      tracking: tracking,
      height: height,
      color: color ?? primary,
    );

    return TextTheme(
      displayLarge: style(size: 44, weight: black, tracking: -1.8, height: 1.0),
      displayMedium: style(
        size: 36,
        weight: black,
        tracking: -1.4,
        height: 1.05,
      ),
      displaySmall: style(size: 30, weight: black, tracking: -1.1, height: 1.1),
      headlineMedium: style(
        size: 24,
        weight: heavy,
        tracking: -0.7,
        height: 1.18,
      ),
      headlineSmall: style(
        size: 20,
        weight: heavy,
        tracking: -0.5,
        height: 1.2,
      ),
      titleLarge: style(size: 17, weight: heavy, tracking: -0.3),
      titleMedium: style(size: 15, weight: boldest, tracking: -0.15),
      titleSmall: style(size: 13, weight: boldest),
      bodyLarge: style(size: 15, weight: regular, height: 1.45),
      bodyMedium: style(
        size: 14,
        weight: regular,
        height: 1.45,
        color: secondary,
      ),
      bodySmall: style(size: 12, weight: medium, height: 1.4, color: secondary),
      labelLarge: style(size: 14, weight: boldest, tracking: 0.1),
      labelMedium: style(size: 12, weight: semiBold, tracking: 0.2),
      labelSmall: style(
        size: 11,
        weight: boldest,
        tracking: 0.6,
        color: secondary,
      ),
    );
  }

  /// Style for an **identifier** — a tag, serial, ISO date, host or version.
  ///
  /// Callers pair this with `Directionality(textDirection: TextDirection.ltr)`
  /// or a `Text` inside an RTL-isolating span. Setting the face alone is not
  /// enough: under an Arabic locale a bare `SJL-0042 · 2026-08-24` reorders
  /// around the separator and the two halves swap.
  static TextStyle mono({
    required double size,
    FontWeight weight = medium,
    Color? color,
    double? tracking,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: tracking,
      fontFeatures: tabular,
    );
  }

  /// A large tabular numeral — the donut centre, a KPI, a progress percentage.
  static TextStyle numeric({
    required double size,
    FontWeight weight = black,
    Color? color,
  }) {
    return _style(
      size: size,
      weight: weight,
      tracking: size * -0.045,
      height: 1,
      color: color,
    ).copyWith(fontFeatures: tabular);
  }

  /// The small all-caps section label above a group of content.
  ///
  /// Latin gets the wide tracking the design asks for; Arabic does not —
  /// letter-spacing in Arabic breaks the joins between characters, so the
  /// caller passes the current locale's direction and this drops it.
  static TextStyle eyebrow({required Color color, required bool isRtl}) {
    return _style(
      size: isRtl ? 12 : 10.5,
      weight: isRtl ? boldest : heavy,
      tracking: isRtl ? null : 1.5,
      color: color,
    );
  }

  /// Tabular figures for anything that lines up in a column — KPI counts,
  /// prices, serial numbers. Without this the dashboard tiles jitter as the
  /// numbers change.
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];
}
