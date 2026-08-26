import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_colors.dart';
import './app_spacing.dart';
import './app_typography.dart';
import 'app_palette.dart';

/// Material 3 themes for the product, built once from the Obsidian tokens.
///
/// Both brightnesses are designed, not derived: the light theme is not an
/// inversion of the dark one. Mint drops to [AppColors.mintInk] so it clears
/// 4.5:1 on white, the seven status hues swap to their ink tier, and the
/// glass gradient becomes an opaque white-on-white card, because a translucent
/// white fill over a light ground is invisible.
///
/// Widgets read colours from `Theme.of(context)` or `context.palette` — never
/// a literal `Color(0x...)`, and never `isDark ? a : b`.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final palette = isLight ? AppPalette.light : AppPalette.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          brightness: brightness,
        ).copyWith(
          primary: palette.mint,
          onPrimary: palette.onMint,
          secondary: AppColors.statusAssigned,
          onSecondary: Colors.white,
          surface: palette.raised,
          onSurface: palette.ink,
          surfaceContainerHighest: palette.ground,
          error: isLight ? AppColors.statusDamagedInk : AppColors.statusDamaged,
          outline: palette.line,
          outlineVariant: palette.lineSoft,
        );

    final textTheme = AppTypography.textTheme(palette.ink, palette.dim);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.ground,
      textTheme: textTheme,
      // Set on ThemeData too, so widgets that build a TextStyle from scratch
      // (and any Material internals) inherit the same Latin+Arabic pairing.
      fontFamily: AppTypography.latinFamily,
      fontFamilyFallback: AppTypography.fallback,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: palette.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: palette.lineSoft),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.faint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.dim),
        border: _inputBorder(palette.lineSoft),
        enabledBorder: _inputBorder(palette.lineSoft),
        focusedBorder: _inputBorder(palette.mint, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: palette.mint,
          foregroundColor: palette.onMint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: palette.line),
          foregroundColor: palette.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.mint,
          textStyle: textTheme.labelLarge,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.raised,
        side: BorderSide(color: palette.lineSoft),
        labelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: AppTypography.boldest,
          color: palette.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.lineSoft,
        thickness: 1,
        space: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.navBar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            letterSpacing: 0,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? palette.mint
                : palette.faint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? palette.mint
                : palette.faint,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.ground,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xxl),
          ),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: palette.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: palette.lineSoft),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: palette.ink),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(palette.raised),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              side: BorderSide(color: palette.lineSoft),
            ),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: palette.lineSoft),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.textPrimaryLight : palette.raised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? Colors.white : palette.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.mint,
        linearTrackColor: palette.track,
        circularTrackColor: palette.track,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
