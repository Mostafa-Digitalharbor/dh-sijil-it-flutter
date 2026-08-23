import 'package:flutter/material.dart';

/// Brand palette extracted from the Sijil IT logo assets.
///
/// Navy  `#16255C` — primary brand / headings / app bars.
/// Mint  `#2FE3A8` — accent, "available" state, call-to-action highlights.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF16255C);
  static const Color navy700 = Color(0xFF1D3175);
  static const Color navy500 = Color(0xFF2C4494);
  static const Color navy300 = Color(0xFF6E7799);
  static const Color navy100 = Color(0xFFD7DCE9);

  static const Color mint = Color(0xFF2FE3A8);
  static const Color mint600 = Color(0xFF14C289);
  static const Color mint100 = Color(0xFFD3F9EC);

  // ── Neutrals (light) ─────────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFF5F7FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE4E8F2);
  static const Color textPrimaryLight = Color(0xFF16255C);
  static const Color textSecondaryLight = Color(0xFF6E7799);

  // ── Neutrals (dark) ──────────────────────────────────────────────────────
  static const Color surfaceDark = Color(0xFF0C1330);
  static const Color cardDark = Color(0xFF141E42);
  static const Color borderDark = Color(0xFF25315C);
  static const Color textPrimaryDark = Color(0xFFF2F5FC);
  static const Color textSecondaryDark = Color(0xFF9AA3C2);

  // ── Semantic / asset-status colours ──────────────────────────────────────
  static const Color statusAvailable = Color(0xFF14C289);
  static const Color statusAssigned = Color(0xFF3B6FE0);
  static const Color statusReserved = Color(0xFF7C5CE0);
  static const Color statusMaintenance = Color(0xFFF2A63B);
  static const Color statusDamaged = Color(0xFFE5533D);
  static const Color statusLost = Color(0xFFB03A8C);
  static const Color statusRetired = Color(0xFF7A849F);

  static const Color success = Color(0xFF14C289);
  static const Color warning = Color(0xFFF2A63B);
  static const Color danger = Color(0xFFE5533D);
  static const Color info = Color(0xFF3B6FE0);

  const AppColors._();
}
