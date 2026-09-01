/// Every fixed measurement in the product.
///
/// Nothing in `lib/features` or `lib/shared` may write a bare number into a
/// `SizedBox`, `EdgeInsets`, `width`, `height`, `size` or `borderRadius`.
/// If a value is not here, it does not exist yet — add it here first.
///
/// Split by role rather than by value so that renaming a role (say, making
/// list avatars larger) is one edit, not a search-and-replace over a number
/// that also happens to mean something else.
/// How far the app lets the system font scale move.
///
/// The OS allows far more than this. An asset row carries a name, a tag and a
/// status chip on one line, and past the ceiling the chip wins and the name
/// disappears — so the app narrows the range rather than shipping a screen
/// that silently drops the thing the row is about.
///
/// The floor matters too: below it the identifiers under each row stop being
/// legible against a sticker, which is the one comparison the screen exists
/// to support.
abstract final class AppTextScale {
  static const double min = 0.85;
  static const double max = 1.4;

  const AppTextScale._();
}

abstract final class AppDimens {
  // ── Icons ────────────────────────────────────────────────────────────────
  static const double iconXs = 10;
  static const double iconSm = 13;
  static const double iconMd = 16;
  static const double iconLg = 18;
  static const double iconXl = 20;
  static const double iconXxl = 22;

  /// Icons inside small controls. [iconChip] leads a chip; [iconControl] is a
  /// chip's trailing affordance and a compact segment's glyph; [iconSegment]
  /// is the glyph in a full-size segment.
  static const double iconChip = 11;
  static const double iconControl = 12;
  static const double iconSegment = 14;

  /// The icon leading a key/value fact row. Between [iconSm] and [iconMd]
  /// because it sits on the same baseline as `bodySmall`, and either
  /// neighbour makes the row look mis-set.
  static const double iconFact = 15;

  static const double iconHuge = 32;

  // ── Avatars & leading tiles ──────────────────────────────────────────────
  static const double avatarMd = 38;
  static const double avatarXl = 56;
  static const double tileSm = 29;
  static const double tileMd = 40;
  static const double tileLg = 46;

  // ── Controls ─────────────────────────────────────────────────────────────
  static const double buttonHeight = 52;
  static const double buttonHeightCompact = 46;
  static const double buttonHeightSmall = 38;
  static const double fieldHeight = 50;
  static const double appBarActionSize = 38;
  static const double segmentHeight = 32;
  static const double chipHeight = 32;
  static const double stepBadgeSize = 19;
  static const double checkboxSize = 19;

  /// The condition picker's own tile and check indicator. Deliberately a
  /// point larger than [tileSm] and [checkboxSize]: the picker is a
  /// walk-around control used one-handed, and it was the one place the shared
  /// sizes tested too small to hit reliably.
  static const double conditionTile = 30;
  static const double conditionCheck = 20;

  /// The × that removes a photograph.
  static const double photoRemoveButton = 19;
  static const double radioSize = 22;

  /// Minimum interactive target. Anything tappable must clear this.
  static const double minTapTarget = 48;

  // ── Bars & rails ─────────────────────────────────────────────────────────
  static const double appBarHeight = 56;
  static const double appBarHeightWithSubtitle = 66;

  /// Bottom navigation, before the safe-area inset and before text scaling.
  ///
  /// Explicit rather than intrinsic: Scaffold hands `bottomNavigationBar`
  /// constraints as tall as the screen, and any `Center`/`Align` inside will
  /// take all of it — which is exactly how the bar once rendered vertically
  /// centred with the page squeezed to nothing behind it.
  static const double navBarHeight = 58;
  static const double progressBarHeight = 7;
  static const double statusStripHeight = 6;
  static const double statusStripGap = 2;
  static const double dotSize = 7;

  /// The swatch in the dashboard's status legend. A point larger than
  /// [dotSize]: the legend's dot is read as a colour sample rather than as a
  /// marker, and at 7 the tint is too small to name.
  static const double legendDot = 8;
  static const double hairline = 1;
  static const double focusedBorder = 1.6;

  /// The mint ring around the signed-in employee's photo.
  ///
  /// Its own token rather than [focusedBorder]: they happen to share a value
  /// today, and a change to what "focused" looks like must not silently
  /// redraw the header's avatar.
  static const double avatarRing = 1.6;

  /// The track inset that reveals the segmented control's thumb.
  ///
  /// Off the 4-pt spacing scale on purpose — it is the gap *inside* a control,
  /// not layout, and 4 makes a 32-pt segmented control look hollow.
  static const double segmentInset = 3;

  /// How far a radial glow reaches, as a fraction of its box.
  ///
  /// A ratio, not a length, which is why it is not on the spacing scale. Just
  /// over 1 so the falloff clears the corners instead of banding across them.
  static const double glowSpread = 1.1;

  /// The sparkline itself: the stroke, the halo behind its last point, and
  /// that point's own dot.
  static const double sparklineStroke = 2.2;
  static const double sparklineHaloRadius = 8;
  static const double sparklinePoint = 4;

  /// Stroke of a circular progress indicator.
  static const double progressStroke = 2;
  static const double progressStrokeThick = 2.5;
  static const double selectedBorder = 1.8;

  // ── Cards & media ────────────────────────────────────────────────────────
  static const double fabSize = 56;
  static const double photoThumb = 64;
  static const double scannerFinder = 244;
  static const double scannerCorner = 54;
  static const double scannerCornerWidth = 3.5;
  static const double logoLockupWidthCompact = 128;
  static const double logoMonogramSize = 46;
  static const double logoMonogramSm = 34;
  static const double emptyStateIconBox = 72;

  /// Largest a printed QR square is drawn. Shrinks to fit a small viewport.
  static const double qrCodeMaxSize = 280;

  /// The hairline that sweeps the scanner viewfinder.
  static const double scannerLine = 2;

  // ── Layout ───────────────────────────────────────────────────────────────
  static const double contentMaxWidth = 720;
  static const double dialogMaxWidth = 480;

  /// Placeholder sizes for the two dashboard cards whose real content is a
  /// drawing rather than text. Taken from what the ring and the sparkline
  /// actually settle at, so the page does not jump when the summary lands.
  static const double donutSkeleton = 116;
  static const double trendSkeleton = 132;
  static const double barLabelMaxWidth = 88;
  static const double barLabelMinWidth = 56;
  static const double barValueWidth = 28;

  /// How close to the end of a list the next page is requested — roughly three
  /// rows, so the fetch usually lands before the user arrives.
  static const double listPrefetchExtent = 320;

  // ── Elevation / blur ─────────────────────────────────────────────────────

  /// The glow behind the scanner's sweep line.
  static const double glowBlur = 18;

  // ── Obsidian (design/v3) ─────────────────────────────────────────────────
  /// Dot column on the history timeline. Doubles as the dot's own size, so the
  /// rail and the dot are the same width and the connecting line is centred.
  static const double timelineRail = 26;

  /// The coloured square that leads an asset row and carries its status.
  static const double statusTileSmall = 34;

  /// Height of the photo strip on a detail screen. The thumbnails beside the
  /// lead image reuse the existing [photoThumb].
  static const double photoStrip = 104;

  /// The signature area. Below this people cannot sign, they scribble — and
  /// the whole point of the capture is that it looks like the signature the
  /// person actually writes.
  ///
  /// A fixed height, not a minimum: the pad lives in a scrolling form, where
  /// "as tall as the space allows" is unbounded, and the exported image has to
  /// be produced at exactly the size the strokes were drawn at.
  static const double signaturePadHeight = 132;
  static const double signatureStroke = 2.6;

  /// Scanner and audit viewfinders, and the corner brackets drawn on them.
  static const double viewfinderCompact = 112;
  static const double viewfinderCorner = 30;
  static const double viewfinderCornerWeight = 3;

  /// The floating scan button in the middle of the navigation bar.
  static const double navFab = 46;
  static const double navFabLift = 14;

  const AppDimens._();
}

/// Named durations. Same rule as [AppDimens]: no bare `Duration` literals in
/// feature code.
abstract final class AppDurations {
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Debounce before a typed search query hits Odoo (spec §11).
  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// How long a snackbar stays up.
  static const Duration snackBar = Duration(seconds: 4);

  /// Scanner cooldown so one physical code is not read twice.
  static const Duration scanCooldown = Duration(milliseconds: 1200);

  /// One pass of the scanner's sweep line across the viewfinder. Slow enough
  /// to read as "still looking" rather than as a progress bar that is stuck.
  static const Duration scannerSweep = Duration(seconds: 2);

  /// How long the microphone stays open for one dictated search.
  ///
  /// Long enough to say "MacBook Pro belonging to Ahmed", short enough that a
  /// microphone opened by accident in a pocket gives up on its own rather than
  /// recording a corridor.
  static const Duration voiceListen = Duration(seconds: 12);

  /// The silence that ends a dictation early.
  ///
  /// Three seconds rather than one: a technician reading a serial off a
  /// sticker pauses in the middle of it, and cutting them off at the pause is
  /// how half a serial ends up in the search box.
  static const Duration voicePause = Duration(seconds: 3);

  const AppDurations._();
}

/// Opacity values used to tint status colours consistently.
abstract final class AppOpacities {
  static const double chipFill = 0.12;
  static const double chipFillStrong = 0.14;
  static const double chipBorder = 0.28;
  static const double tileFill = 0.12;
  static const double overlay = 0.10;
  static const double overlaySoft = 0.07;
  static const double disabled = 0.38;
  static const double scrim = 0.55;

  /// A hairline or divider softened against its surface.
  static const double divider = 0.5;
  static const double dividerSoft = 0.6;

  /// The torch button's resting tint, before it is switched on.
  static const double toggleRestingFill = 0.18;

  /// The barely-there wash inside the scanner viewfinder.
  static const double viewfinderFill = 0.04;

  /// Glow around the scanner's sweep line.
  static const double glow = 0.8;

  /// The scrim behind a badge, a remove button and a "+N" overlay, all of
  /// which sit on top of a photograph the app does not control. Graded rather
  /// than shared: the overlay covers a whole thumbnail, the badge a corner of
  /// one, and the button has to stay legible over both.
  static const double photoOverlay = 0.62;
  static const double photoBadge = 0.78;
  static const double photoControl = 0.8;

  /// The area fill under a sparkline, at the top of its gradient, and the
  /// halo behind its final point.
  static const double sparklineArea = 0.34;
  static const double sparklineHalo = 0.22;

  /// A destructive control's border, and a chip's secondary icon.
  static const double dangerBorder = 0.35;
  static const double secondaryIcon = 0.75;

  const AppOpacities._();
}
