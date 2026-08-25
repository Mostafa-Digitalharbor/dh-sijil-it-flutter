import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/responsive/responsive.dart';
import 'app_button.dart';

/// Page chrome shared by every screen.
///
/// Handles four things a feature should never re-implement: the two-line app
/// bar, the responsive gutter, the safe-area maths, and the sticky action bar
/// that must sit above the home indicator. A screen supplies its content and
/// nothing else.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBack = false,
    this.onBack,
    this.bottomBar,
    this.floatingAction,
    this.aboveBody,
    this.backgroundColor,
    this.compactTitle = false,
    this.titleWidget,
    super.key,
  });

  final String title;

  /// Second line under the title — a count, a sync time, a server name.
  final String? subtitle;

  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;

  /// Sticky footer: a confirm bar, not the tab bar.
  final Widget? bottomBar;

  final Widget? floatingAction;

  /// Pinned under the app bar and above the scrolling body — search fields,
  /// filter rows.
  final Widget? aboveBody;

  final Color? backgroundColor;

  /// Renders the title at body weight, for modal-style screens where the
  /// screen name is context rather than a heading.
  final bool compactTitle;

  /// Replaces the title/subtitle block entirely.
  ///
  /// The dashboard's header is a person — photo, greeting, name — not a
  /// string, and forcing it through [title] would have meant either a second
  /// scaffold or a widget-shaped `String`. [title] stays required because it
  /// is still the screen's accessible name.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = context.screen;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        // Scaled with the text, not fixed. The bar holds a title and an
        // optional subtitle, and both grow with the user's font size — pinned
        // at 66 px it clips them by a few pixels at a large accessibility
        // setting, on every screen at once.
        preferredSize: Size.fromHeight(
          MediaQuery.textScalerOf(context).scale(
            subtitle == null
                ? AppDimens.appBarHeight
                : AppDimens.appBarHeightWithSubtitle,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: (showBack || leading != null)
                  ? AppSpacing.xs
                  : screen.gutter,
              end: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                if (leading != null)
                  leading!
                else if (showBack)
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    bordered: false,
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: (showBack || leading != null) ? AppSpacing.xs : 0,
                    ),
                    child:
                        titleWidget ??
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: compactTitle
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (aboveBody != null) aboveBody!,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : StickyActionBar(child: bottomBar!),
      floatingActionButton: floatingAction,
    );
  }
}

/// Footer that stays above the keyboard and the home indicator.
///
/// A confirm button placed with plain padding ends up under the gesture bar on
/// a modern phone; this measures the real inset instead of guessing.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({required this.child, this.hint, super.key});

  final Widget child;

  /// A line above the action explaining what confirming will do.
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = context.screen;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: screen.gutter,
            end: screen.gutter,
            top: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                hint!,
                const SizedBox(height: AppSpacing.md),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrolling page body with the responsive gutter, a max content width on
/// wide screens, and pull-to-refresh.
///
/// Every list and detail screen uses this, which is what guarantees the same
/// gutter on a phone and a tablet without any screen doing the maths.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    required this.children,
    this.onRefresh,
    this.controller,
    this.gap = AppSpacing.md,
    this.padded = true,
    super.key,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double gap;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final screen = context.screen;

    final list = ListView.separated(
      controller: controller,
      padding: EdgeInsetsDirectional.only(
        start: padded ? screen.gutter : 0,
        end: padded ? screen.gutter : 0,
        top: AppSpacing.xs,
        bottom: AppSpacing.xxxl,
      ),
      itemCount: children.length,
      separatorBuilder: (_, __) => SizedBox(height: gap),
      itemBuilder: (_, index) => children[index],
    );

    final constrained = screen.size.isExpanded
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.contentMaxWidth,
              ),
              child: list,
            ),
          )
        : list;

    if (onRefresh == null) return constrained;
    return RefreshIndicator(onRefresh: onRefresh!, child: constrained);
  }
}
