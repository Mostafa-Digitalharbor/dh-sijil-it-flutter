import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// A circular initials avatar for a person.
///
/// Odoo avatars are base64 blobs that cost a round trip per row, so lists use
/// initials and only detail screens fetch the image. Initials are derived
/// here rather than at each call site so "Mostafa Bader" and "مصطفى بدر" both
/// produce two letters.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.size = AppDimens.avatarMd,
    this.emphasised = true,
    super.key,
  });

  final String name;
  final double size;

  /// Filled navy (a person in focus) versus muted (a person in a list).
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = emphasised && !isDark
        ? AppColors.navy
        : (isDark ? AppColors.borderDark : AppColors.surfaceLight);
    final foreground = emphasised && !isDark
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Semantics(
      label: name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: theme.textTheme.labelLarge?.copyWith(
            color: foreground,
            fontSize: size * 0.33,
            letterSpacing: AppTypography.noTracking,
          ),
        ),
      ),
    );
  }

  /// Up to two initials from a display name, in either script.
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return (words.first.characters.first + words.last.characters.first)
        .toUpperCase();
  }
}

/// The rounded square that leads a list row — a category icon, a workflow
/// glyph, an activity marker.
class AppLeadingTile extends StatelessWidget {
  const AppLeadingTile({
    required this.icon,
    this.tone,
    this.size = AppDimens.tileMd,
    super.key,
  });

  /// Compact variant used inside cards and activity rows.
  const AppLeadingTile.small({required this.icon, this.tone, super.key})
    : size = AppDimens.tileSm;

  final IconData icon;

  /// Null uses the neutral surface tint.
  final Color? tone;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = tone == null
        ? (isDark ? AppColors.borderDark : AppColors.surfaceLight)
        : tone!.withValues(alpha: AppOpacities.tileFill);
    final foreground = tone == null
        ? theme.colorScheme.onSurface
        : (isDark ? tone! : AppColors.inkFor(tone!));

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          size >= AppDimens.tileMd ? AppRadii.md : AppRadii.sm + 2,
        ),
      ),
      child: Icon(icon, size: size * 0.48, color: foreground),
    );
  }
}
