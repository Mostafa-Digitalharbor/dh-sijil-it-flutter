import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_text.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../assets/domain/entities/asset_status.dart';

/// The four-way condition picker on the return screen (spec §8).
///
/// A grid of cards rather than a radio list because each option carries a
/// consequence — "Marks as damaged", "Opens a request" — and that second line
/// is the whole reason the choice matters. A radio list has nowhere to put it.
class ConditionPicker extends StatelessWidget {
  const ConditionPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final ReturnCondition selected;
  final ValueChanged<ReturnCondition> onChanged;

  @override
  Widget build(BuildContext context) {
    final screen = context.screen;

    // Two columns normally; one when text is scaled up, where a two-column
    // card cannot fit a label plus its consequence line without clipping.
    final columns = screen.isLargeText ? 1 : (screen.size.isCompact ? 2 : 4);
    const options = ReturnCondition.values;

    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += columns) {
      final slice = options.sublist(i, (i + columns).clamp(0, options.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var c = 0; c < columns; c++) ...<Widget>[
                if (c > 0) const SizedBox(width: AppSpacing.sm + 1),
                Expanded(
                  child: c < slice.length
                      ? _ConditionCard(
                          condition: slice[c],
                          isSelected: slice[c] == selected,
                          onTap: () => onChanged(slice[c]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm + 1),
          rows[i],
        ],
      ],
    );
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.condition,
    required this.isSelected,
    required this.onTap,
  });

  final ReturnCondition condition;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final tone = ConditionLabels.tone(condition);
    final ink = AppInk.of(context, tone);

    return AppCard(
      onTap: onTap,
      selected: isSelected,
      borderColor: isSelected ? tone : null,
      semanticLabel: AppText.announced(
        ConditionLabels.name(l10n, condition),
        ConditionLabels.effect(l10n, condition),
      ),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: AppDimens.tileSm + 1,
                height: AppDimens.tileSm + 1,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: AppOpacities.chipFillStrong),
                  borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                ),
                child: Icon(
                  ConditionLabels.icon(condition),
                  size: AppDimens.iconMd,
                  color: ink,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  width: AppDimens.checkboxSize + 1,
                  height: AppDimens.checkboxSize + 1,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: AppDimens.iconSm,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 1),
          Text(
            ConditionLabels.name(l10n, condition),
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            ConditionLabels.effect(l10n, condition),
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
