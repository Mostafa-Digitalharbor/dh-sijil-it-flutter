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

  /// Horizontal page gutter, phone.
  static const double pageGutter = 16;

  /// Horizontal page gutter, tablet / wide layouts.
  static const double pageGutterWide = 32;
}

/// Corner-radius scale.
abstract final class AppRadii {
  static const double sm = 8;
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
