import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale for the product. Uses Plus Jakarta Sans — geometric, slightly
/// rounded, matching the rounded terminals of the Sijil wordmark.
///
/// `google_fonts` falls back to the platform font when offline, so the app
/// still renders correctly on a first cold launch without connectivity.
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    final base = GoogleFonts.plusJakartaSansTextTheme();

    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: primary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, color: primary),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, color: secondary),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: secondary),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: secondary,
      ),
    );
  }
}
