import 'package:flutter/material.dart';

/// The **Obsidian** palette (design/v3).
///
/// ## The one idea
///
/// The product is dark by default and the ground is deep *navy*, not black.
/// Pure black collapses the separation between a card and the surface behind
/// it; a navy ground keeps every layer legible while still reading as dark.
///
/// ## Two tiers per status, not one
///
/// A status hue has to work as a **fill** on a dark ground and as **label ink**
/// on a light one, and no single value does both: the hue tuned to glow on
/// `#0B1226` fails 4.5:1 as text on a 10% tint of itself. So every status has
/// two values — the raw hue here, and a darkened partner in [_inkByFill] that
/// [inkFor] returns in light mode. Widgets pass a single `tone` and the chip,
/// tile and avatar helpers resolve the right tier for the current brightness.
///
/// Widgets must read colours from `Theme.of(context)`, [AppPalette] or this
/// class — never declare a literal `Color(0x...)` inside a widget.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF16255C);
  static const Color navy300 = Color(0xFF6E7799);

  static const Color mint = Color(0xFF2FE3A8);

  /// Mint that clears 4.5:1 as text and as a filled button on a light ground.
  static const Color mintInk = Color(0xFF0F9E73);

  /// Ink for a filled mint button — near-black in dark mode, white in light.
  static const Color onMintDark = Color(0xFF04231A);
  static const Color onMintLight = Color(0xFFFFFFFF);

  // ── Neutrals (light) ─────────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFF3F6FC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFDCE3F1);
  static const Color borderSoftLight = Color(0xFFE7ECF7);
  static const Color textPrimaryLight = Color(0xFF101A38);
  static const Color textSecondaryLight = Color(0xFF5A6790);
  static const Color textFaintLight = Color(0xFF8792B4);
  static const Color trackLight = Color(0xFFE7ECF7);

  /// Secondary text on a saturated hero fill in light mode.
  static const Color heroSubdued = Color(0xFF9AA6CE);

  // ── Neutrals (dark) ──────────────────────────────────────────────────────
  /// Deepest ground. Used behind the app bar glow and inside the QR sheet.
  static const Color voidDark = Color(0xFF070C1E);
  static const Color surfaceDark = Color(0xFF0B1226);
  static const Color cardDark = Color(0xFF101A38);
  static const Color borderDark = Color(0xFF253361);
  static const Color borderSoftDark = Color(0xFF1B2749);
  static const Color textPrimaryDark = Color(0xFFF3F6FD);
  static const Color textSecondaryDark = Color(0xFF8E9AC4);
  static const Color textFaintDark = Color(0xFF626F9B);
  static const Color trackDark = Color(0xFF111B3B);

  /// A camera preview is never white. The scanner and audit viewfinders keep
  /// this ground in both themes, and their captions use [cameraInk].
  static const Color camera = Color(0xFF05091A);
  static const Color cameraInk = Color(0xFFC6D0EC);

  // ── Ink that is white on purpose ─────────────────────────────────────────
  //
  // Four separate decisions that happen to share a value. They are named
  // rather than written as `Colors.white` at the call site because each can
  // move independently — [qrPaper] in particular is a *functional* white, not
  // a stylistic one, and must never follow a palette change.

  /// Ink on a saturated fill: a mint button, a filled status chip, a selected
  /// tile, an avatar on a coloured ground.
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Ink on the navy brand band — the login hero, the splash, the lock gate.
  /// Follows the band, which is navy in both themes, not the theme.
  static const Color onBrand = Color(0xFFFFFFFF);

  /// Ink and rules drawn over a live camera preview or a photo thumbnail.
  /// The ground underneath is whatever the lens is pointed at, so this is the
  /// one value that stays legible over all of it.
  static const Color onCamera = Color(0xFFFFFFFF);

  /// The quiet zone a QR code needs. A code rendered in the dark palette does
  /// not scan once printed, and printing is the entire point of that screen,
  /// so this stays white in both themes.
  static const Color qrPaper = Color(0xFFFFFFFF);

  // ── Status fills (tuned for a dark ground) ───────────────────────────────
  static const Color statusAvailable = Color(0xFF2FE3A8);
  static const Color statusAssigned = Color(0xFF4C82F7);
  static const Color statusReserved = Color(0xFF9271FF);
  static const Color statusMaintenance = Color(0xFFFFB443);
  static const Color statusDamaged = Color(0xFFFF6A50);
  static const Color statusLost = Color(0xFFE14FA8);
  static const Color statusRetired = Color(0xFF8492B4);

  // ── Status ink (the same seven, legible as text on a light ground) ───────
  static const Color statusAvailableInk = Color(0xFF0F9E73);
  static const Color statusAssignedInk = Color(0xFF2E62D8);
  static const Color statusReservedInk = Color(0xFF6B45D6);
  static const Color statusMaintenanceInk = Color(0xFFC97F17);
  static const Color statusDamagedInk = Color(0xFFD33F26);
  static const Color statusLostInk = Color(0xFFB03A8C);
  static const Color statusRetiredInk = Color(0xFF67718D);

  // ── Surface treatments ───────────────────────────────────────────────────
  //
  // The glass card's two gradient stops and its lit top edge. Dark mode layers
  // translucent white over navy so the card reads as *above* the page; light
  // mode has nothing to lift off a white ground, so the "gradient" is two
  // near-identical whites and the rim drops to a hairline.
  static const Color glassTopDark = Color(0x0EFFFFFF);
  static const Color glassBottomDark = Color(0x04FFFFFF);
  static const Color glassEdgeDark = Color(0x38FFFFFF);
  static const Color navBarDark = Color(0xEB070C1E);

  static const Color glassTopLight = Color(0xFFFFFFFF);
  static const Color glassBottomLight = Color(0xFFFAFCFF);
  static const Color glassEdgeLight = Color(0x1A101A38);
  static const Color navBarLight = Color(0xF2FFFFFF);

  /// A captured signature is exported dark-on-white in **both** themes: its
  /// audience is whoever opens the record in Odoo's web client, on white.
  /// Exporting what the dark pad showed would ship an invisible image.
  static const Color signaturePaper = Color(0xFFFFFFFF);
  static const Color signatureInk = Color(0xFF101A38);

  static const Color success = statusAvailable;
  static const Color warning = statusMaintenance;
  static const Color danger = statusDamaged;
  static const Color info = statusAssigned;

  /// Light-mode label ink for a status tint.
  ///
  /// Unknown hues are returned unchanged, which is the safe default: the ones
  /// that need darkening are exactly the ones listed.
  static Color inkFor(Color tone) => _inkByFill[tone.toARGB32()] ?? tone;

  static const Map<int, Color> _inkByFill = <int, Color>{
    0xFF2FE3A8: statusAvailableInk,
    0xFF14C289: statusAvailableInk,
    0xFF4C82F7: statusAssignedInk,
    0xFF9271FF: statusReservedInk,
    0xFFFFB443: statusMaintenanceInk,
    0xFFFF6A50: statusDamagedInk,
    0xFFE14FA8: statusLostInk,
    0xFF8492B4: statusRetiredInk,
  };

  const AppColors._();
}
