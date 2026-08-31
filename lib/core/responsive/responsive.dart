import 'package:flutter/widgets.dart';

import '../../app/theme/app_spacing.dart';

/// The size class a layout is currently being built for.
///
/// Deliberately three buckets, not a continuum: more than three and nobody
/// remembers which is which, and the layouts start disagreeing with each
/// other.
enum ScreenSize {
  /// < 600 dp — phones in portrait.
  compact,

  /// 600–899 dp — large phones in landscape, small tablets.
  medium,

  /// >= 900 dp — tablets, foldables open, desktop.
  expanded;

  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;

  /// Medium and up: enough room for a rail and a two-pane layout.
  bool get isWide => this != ScreenSize.compact;

  /// The bucket a window width falls in.
  ///
  /// The single place the breakpoints are compared, so `context.pagePadding`
  /// — which reads the width directly, to avoid subscribing to anything else
  /// — cannot drift from [ResponsiveInfo].
  static ScreenSize forWidth(double width) => switch (width) {
    < AppBreakpoints.phone => ScreenSize.compact,
    < AppBreakpoints.tablet => ScreenSize.medium,
    _ => ScreenSize.expanded,
  };

  /// Horizontal page gutter for this size class.
  double get gutter => switch (this) {
    ScreenSize.compact => AppSpacing.pageGutter,
    ScreenSize.medium => AppSpacing.xxl,
    ScreenSize.expanded => AppSpacing.pageGutterWide,
  };
}

/// Layout facts derived once from the current [MediaQuery].
///
/// Read this instead of calling `MediaQuery.of(context).size.width` in a
/// widget: it keeps every breakpoint decision in one vocabulary, and a widget
/// that depends only on `context.screen` rebuilds for the right reasons.
@immutable
class ResponsiveInfo {
  const ResponsiveInfo({
    required this.size,
    required this.width,
    required this.height,
    required this.textScale,
  });

  final ScreenSize size;
  final double width;
  final double height;
  final double textScale;

  /// Reads the current [MediaQuery], one aspect at a time.
  ///
  /// Deliberately *not* `MediaQuery.of(context)`. That subscribes the calling
  /// widget to every field of the MediaQueryData — including `viewInsets`,
  /// which changes on **every frame of the keyboard animation**. Thirty-odd
  /// widgets read this, several of them page roots, so a single tap on a text
  /// field was rebuilding most of the screen twenty times on the way up and
  /// twenty more on the way down. On a low-end handset that is the difference
  /// between a keyboard that slides and one that stutters.
  ///
  /// The aspect-scoped accessors subscribe to one field each, so a widget that
  /// asks about width is not woken by the keyboard.
  factory ResponsiveInfo.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;

    return ResponsiveInfo(
      size: ScreenSize.forWidth(width),
      width: width,
      height: size.height,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  /// Horizontal page gutter for this size class.
  double get gutter => size.gutter;

  /// Columns for a tile grid (KPI tiles, condition pickers).
  int get tileColumns => switch (size) {
    ScreenSize.compact => 3,
    ScreenSize.medium => 4,
    ScreenSize.expanded => 6,
  };

  /// [tileColumns], narrowed when the user has turned text size well up.
  ///
  /// Three 110-pt tiles with a scaled label is where the dashboard used to
  /// overflow. Dropping to two costs a row and keeps the number the tile
  /// exists to show.
  int get statTileColumns => isLargeText ? _largeTextTileColumns : tileColumns;

  /// Columns for a card grid (asset rows on a tablet).
  int get cardColumns => switch (size) {
    ScreenSize.compact => 1,
    ScreenSize.medium => 2,
    ScreenSize.expanded => 3,
  };

  /// Columns for a key/value detail block.
  int get detailColumns => size.isCompact ? 2 : 3;

  /// Navigation lives in a side rail rather than a bottom bar from medium up.
  bool get usesNavigationRail => size.isWide;

  /// Detail screens sit beside the list instead of replacing it.
  bool get usesTwoPane => size.isExpanded;

  /// True when the user has turned text size well up: dense rows should
  /// reflow to a column rather than clip.
  bool get isLargeText => textScale > 1.15;

  /// How narrow [statTileColumns] goes. Two rather than one: a single column
  /// of stat tiles stops reading as a dashboard and starts reading as a list.
  static const int _largeTextTileColumns = 2;

  /// Pick a value per size class without writing a switch at the call site.
  T pick<T>({required T compact, T? medium, T? expanded}) => switch (size) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
  };

  @override
  bool operator ==(Object other) =>
      other is ResponsiveInfo &&
      other.size == size &&
      other.width == width &&
      other.height == height &&
      other.textScale == textScale;

  @override
  int get hashCode => Object.hash(size, width, height, textScale);
}

/// `context.screen` — the entry point used everywhere in the UI.
///
/// The two shorthands read the window size and nothing else. They are the
/// most-called accessors in the app, and going through [ResponsiveInfo] would
/// have subscribed each caller to the text scaler as well — so a row that
/// only wants to know "am I on a phone" would rebuild when somebody changed
/// their font size in Settings.
extension ResponsiveContext on BuildContext {
  ResponsiveInfo get screen => ResponsiveInfo.of(this);

  /// Shorthand for the most common check.
  bool get isCompact =>
      ScreenSize.forWidth(MediaQuery.sizeOf(this).width).isCompact;

  /// Horizontal page padding, already size-aware.
  EdgeInsetsGeometry get pagePadding => EdgeInsetsDirectional.symmetric(
    horizontal: ScreenSize.forWidth(MediaQuery.sizeOf(this).width).gutter,
  );
}
