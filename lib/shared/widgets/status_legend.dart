import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../utils/app_number.dart';

/// One row of a chart's legend: a colour, what it means, how many.
///
/// Public rather than private to the dashboard because it is the only place
/// the ring's numbers are *readable* — the arcs carry the shape and this
/// carries the values, for a screen reader and for anyone who needs the exact
/// figure rather than the impression.
class StatusLegendRow extends StatelessWidget {
  const StatusLegendRow({
    required this.tone,
    required this.label,
    required this.count,
    this.muted = false,
    super.key,
  });

  final Color tone;
  final String label;
  final int count;

  /// Dims the row so a grouped or rare bucket does not compete with the
  /// statuses that carry the day-to-day meaning.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      label: label,
      value: AppNumber.count(context, count),
      child: Row(
        children: <Widget>[
          Container(
            width: AppDimens.legendDot,
            height: AppDimens.legendDot,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(AppRadii.swatch),
            ),
          ),
          const SizedBox(width: AppSpacing.tight),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                fontSize: AppTextSize.legend,
                color: muted ? palette.faint : palette.dim,
              ),
            ),
          ),
          Text(
            AppNumber.count(context, count),
            style: text.titleSmall?.copyWith(
              fontSize: AppTextSize.legendValue,
              color: muted ? palette.faint : palette.ink,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
