/// 4-pt spacing scale — the single source of truth for all padding, gaps and
/// margins in the app. Never hardcode a raw number in a widget.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  // ── Half-steps ───────────────────────────────────────────────────────────
  //
  // The scale above measures the space *between* things. These measure space
  // *inside* a control, where a 4-pt jump is too coarse: a 32-pt segmented
  // control reads hollow at 12 and cramped at 8, and the answer is 9.
  //
  // They existed already — written as `AppSpacing.sm + 1` and
  // `AppSpacing.md - 2` at forty-odd call sites. That is a bare number in a
  // widget wearing a token's clothes, and it hid the fact that thirteen
  // separate places had each independently arrived at 9. Naming them is what
  // makes "the gap between tiles" one edit instead of a search for `+ 1`.

  /// The thinnest deliberate gap — between a label and the rule under it.
  static const double micro = 3;

  /// A hair more than [micro], under a two-line stat value.
  static const double fine = 5;

  /// Inside a badge or a segmented control's track.
  static const double snug = 6;

  /// A gap tighter than [sm], between stacked lines inside one card.
  static const double tight = 7;

  /// The gap between tiles in a grid and between rows in a list.
  ///
  /// The most-used value in the product after the page gutter. If a grid looks
  /// wrong, this is the number to change.
  static const double gridGap = 9;

  /// Padding inside a compact tile, and the gap in a dense row.
  static const double dense = 10;

  /// A settings group's internal gap.
  static const double cozy = 11;

  /// Padding inside a large tappable tile.
  static const double roomy = 13;

  /// Horizontal page gutter, phone.
  static const double pageGutter = 16;

  /// Horizontal page gutter, tablet / wide layouts.
  static const double pageGutterWide = 32;
}

/// Corner-radius scale.
abstract final class AppRadii {
  /// The rounded square of a legend swatch — softened, not a circle, so it
  /// reads as a sample of a fill rather than as a status dot.
  static const double swatch = 3;

  /// The corner *inside* another corner — a badge on a photo, the thumb well
  /// of a segmented control. Anything smaller reads as square.
  static const double xs = 6;

  static const double sm = 8;

  /// A segmented control's track, and the dot on the history timeline.
  static const double control = 9;

  /// A small avatar and the condition picker's tiles.
  static const double tile = 10;

  /// The moving thumb inside a segmented control — one step tighter than the
  /// track it slides in, which is what stops the two corners fighting.
  static const double thumb = 11;

  /// A photograph's corner. Its own token because photos appear in four
  /// places and drifted apart twice.
  static const double photo = 13;

  /// The stat and attention tiles on the dashboard.
  static const double card = 14;

  /// A card floating inside a sheet.
  static const double sheetCard = 18;

  /// The top corners of the login sheet.
  static const double sheetTop = 26;

  /// The scanner's viewfinder well.
  static const double viewfinder = 28;

  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  /// The glass cards on the dashboard and the scanner well. Obsidian leans on
  /// a softer corner than the previous flat-card design did.
  static const double xxl = 24;
  static const double pill = 999;
}

/// Responsive breakpoints (phone / tablet / desktop-web).
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}
