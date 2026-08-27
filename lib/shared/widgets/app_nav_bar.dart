import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// One destination in [AppNavBar].
@immutable
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.glyph,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;

  /// Overrides [icon] with a drawn glyph, for shapes Material does not ship.
  final Widget? glyph;

  /// Lifts this destination out of the bar as a raised action.
  final bool isPrimary;
}

/// The app's bottom navigation.
///
/// ## Why not `NavigationBar`
///
/// Scanning is the most-performed action in the product — it is how a
/// technician finds an asset while standing in front of it — and Material's
/// `NavigationBar` gives every destination identical weight. The design lifts
/// scan into a raised button at the centre of the bar, which is both the
/// clearest signal of what the app is *for* and the easiest target for a thumb
/// on a phone held one-handed.
///
/// The rest of the bar stays a plain row of destinations, so nothing else
/// competes with it.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.navBar,
        border: Border(top: BorderSide(color: palette.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: SizedBox(
            // Scaled, not pinned: the labels grow with the user's font size,
            // and a fixed 58 px clips them at a large accessibility setting.
            height: MediaQuery.textScalerOf(
              context,
            ).scale(AppDimens.navBarHeight),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: items[i].isPrimary
                        ? _PrimaryDestination(
                            item: items[i],
                            onTap: () => onSelected(i),
                          )
                        : _Destination(
                            item: items[i],
                            isSelected: i == currentIndex,
                            onTap: () => onSelected(i),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = isSelected ? palette.mint : palette.faint;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.snug),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconTheme(
                data: IconThemeData(color: tone, size: AppDimens.iconMd),
                child:
                    item.glyph ??
                    Icon(
                      isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: AppTextSize.nav,
                  letterSpacing: AppTypography.noTracking,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised scan button.
///
/// Never renders a selected state: it is an action, and the screen it opens is
/// a viewfinder the user leaves the moment it finds something. Showing it as a
/// "current tab" would imply somewhere to come back to.
class _PrimaryDestination extends StatelessWidget {
  const _PrimaryDestination({required this.item, required this.onTap});

  final NavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: item.label,
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -AppDimens.navFabLift / 2),
          child: Material(
            color: palette.mint,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: AppDimens.navFab,
                height: AppDimens.navFab,
                child: Icon(
                  item.icon,
                  size: AppDimens.iconLg,
                  color: palette.onMint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Six rounded squares, three across and two down.
///
/// Material ships a 2x2 grid and a 3x3 of dots, and neither is the shape the
/// design calls for. It matters more than it sounds: the previous "More" tab
/// used a horizontal ellipsis, which means *a menu*, and the screen behind it
/// is a board of tools. A grid of tiles says what is actually there.
class GridGlyph extends StatelessWidget {
  const GridGlyph({this.columns = 3, this.rows = 2, super.key});

  final int columns;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? AppDimens.iconMd;
    final gap = size * 0.14;
    final cell = (size - gap * (columns - 1)) / columns;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var r = 0; r < rows; r++) ...<Widget>[
              if (r > 0) SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var c = 0; c < columns; c++) ...<Widget>[
                    if (c > 0) SizedBox(width: gap),
                    Container(
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        color: theme.color,
                        borderRadius: BorderRadius.circular(cell * 0.28),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
