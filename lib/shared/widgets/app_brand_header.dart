import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../features/settings/presentation/cubit/app_settings_cubit.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_button.dart';
import 'app_logo.dart';

/// The header on the pre-sign-in screens: the mark, centred, with the two
/// controls a user may need *before* they have an account to configure.
///
/// Language and theme live here rather than only in Settings because Settings
/// is behind a sign-in. Someone who cannot read the connection form has no way
/// to reach the switch that would fix it — so it sits on the first screen.
class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({this.compact = false, super.key});

  /// Uses the monogram instead of the full lockup, for tighter layouts.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimens.minTapTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centred independently of the buttons, so the mark stays optically
          // centred whether the row has one control or three.
          Center(
            child: compact
                ? const AppLogo.monogram(size: AppDimens.logoMonogramSm)
                : const AppLogo.lockup(width: AppDimens.logoLockupWidthCompact),
          ),
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _HeaderControls(),
          ),
        ],
      ),
    );
  }
}

class _HeaderControls extends StatelessWidget {
  const _HeaderControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final settings = context.read<AppSettingsCubit>();

    // Read the *resolved* values rather than the stored preference: with
    // ThemeMode.system or a null locale the stored value says "follow the
    // device", and the toggle has to act on what is actually on screen.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageToggle(
          isArabic: isArabic,
          tooltip: l10n.tooltipToggleLanguage,
          onPressed: () => settings.setLocale(Locale(isArabic ? 'en' : 'ar')),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppIconButton(
          // Shows the mode the tap will switch *to*, which is the convention
          // users already expect from every other app's theme switch.
          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          tooltip: l10n.tooltipToggleTheme,
          onPressed: () =>
              settings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
        ),
      ],
    );
  }
}

/// The language control shows the language it will switch to, spelled in that
/// language — clearer than a globe glyph, which tells you nothing about which
/// languages are on offer.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.isArabic,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isArabic;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = isArabic ? 'EN' : 'ع';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: AppDimens.minTapTarget,
          height: AppDimens.minTapTarget,
          child: Center(
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  width: AppDimens.appBarActionSize,
                  height: AppDimens.appBarActionSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    target,
                    // Locked to LTR so "EN" never mirrors inside an Arabic
                    // layout, and sized by hand because a two-glyph label at
                    // label size reads as a control, not as body text.
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      letterSpacing: AppTypography.noTracking,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
