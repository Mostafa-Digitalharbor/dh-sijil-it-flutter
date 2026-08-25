import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/generated/app_localizations.dart';

/// One labelled fact: "Serial number / C02XK1YZQ6L4".
///
/// A null or blank [value] renders the localized "not recorded" placeholder
/// rather than an empty gap — Odoo returns `false` for unset fields often
/// enough that a blank row would look like a rendering bug.
class KeyValue extends StatelessWidget {
  const KeyValue({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.maxLines = 2,
    super.key,
  });

  final String label;
  final String? value;

  /// Serial numbers and references read better with locked letter spacing and
  /// forced LTR, even inside an Arabic layout.
  final bool isMonospace;

  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = (value == null || value!.trim().isEmpty)
        ? AppL10n.of(context).labelUnknown
        : value!;
    final isPlaceholder = text != value;

    final valueWidget = Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: isPlaceholder
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
        letterSpacing: isMonospace ? 0.4 : null,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        // Latin identifiers keep their reading order inside an RTL screen.
        isMonospace
            ? Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: valueWidget,
                ),
              )
            : valueWidget,
      ],
    );
  }
}

/// A responsive grid of [KeyValue] items.
///
/// Column count comes from the size class, and the whole grid collapses to a
/// single column when the user has turned text size up — which is where a
/// fixed two-column detail block normally overflows.
class KeyValueGrid extends StatelessWidget {
  const KeyValueGrid({required this.items, super.key});

  final List<KeyValue> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final screen = context.screen;
    final columns = screen.isLargeText ? 1 : screen.detailColumns;

    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            items[i],
          ],
        ],
      );
    }

    // Laid out by hand rather than with GridView: this sits inside a scrolling
    // Column, the rows are short, and an intrinsic-height grid here avoids
    // both a nested scrollable and a fixed childAspectRatio that would clip
    // a wrapped value.
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final slice = items.sublist(i, (i + columns).clamp(0, items.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: c < slice.length ? slice[c] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          rows[i],
        ],
      ],
    );
  }
}

/// A label/value pair on one line, for compact metadata rows
/// ("Assigned · 23 Aug 2026 · 12 days").
class InlineFact extends StatelessWidget {
  const InlineFact({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: AppSpacing.lg - 1,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) Text(trailing!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
