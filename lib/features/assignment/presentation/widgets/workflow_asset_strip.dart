import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_title_block.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_icons.dart';

/// The "this is what you are about to act on" strip at the top of the assign
/// and return screens.
///
/// One widget for both, because the two screens differ only in whether the
/// leading slot shows the asset's category glyph or the holder's initials —
/// and in a workflow the user reached by tapping a specific asset, that strip
/// is the confirmation they picked the right one.
class WorkflowAssetStrip extends StatelessWidget {
  const WorkflowAssetStrip({
    required this.asset,
    this.showHolder = false,
    super.key,
  });

  final Asset asset;

  /// Leads with the current holder's avatar and shows how long they have had
  /// it — the framing the return screen needs.
  final bool showHolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final holder = asset.assignedEmployee;

    return AppCard.row(
      child: Row(
        children: <Widget>[
          if (showHolder && holder != null)
            AppAvatar(name: holder.name, size: AppDimens.avatarMd)
          else
            AppLeadingTile(
              icon: AssetIcons.forCategory(asset.category?.name),
              size: AppDimens.avatarMd,
            ),
          const SizedBox(width: AppSpacing.md),
          AppTitleBlock(
            title: asset.name,
            subtitle: _subtitle(l10n),
            titleMaxLines: 2,
            subtitleMaxLines: 2,
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(
            status: asset.status,
            isLocal: asset.isStatusLocal,
            dense: true,
          ),
        ],
      ),
    );
  }

  String _subtitle(AppL10n l10n) {
    final holder = asset.assignedEmployee;

    if (showHolder && holder != null) {
      return <String>[
        holder.name,
        if (asset.assignmentDate != null) l10n.returnHeldFor(_daysHeld(asset)),
      ].join(' · ');
    }

    // The chip beside this already carries the status, so the subtitle spends
    // itself on the identifier instead of saying "Available · Available".
    return asset.assetTag ?? asset.serialNumber ?? asset.model ?? '';
  }

  /// Whole days the current holder has had it, counted on the dates so a
  /// handover this morning reads as 0 rather than a fraction.
  static int _daysHeld(Asset asset) {
    final since = asset.assignmentDate;
    if (since == null) return 0;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(since.year, since.month, since.day)).inDays;
  }
}

/// The one date field both workflows use.
///
/// A thin composition of [AppPickerField] and [AppDatePicker]: the only thing
/// it adds is the "Today" marker, which is the single most useful piece of
/// feedback on a field that defaults to today and is usually left alone.
///
/// It also carries the *optional* case, for the expected return date. An
/// optional date field needs two things a required one does not: something to
/// say while it is empty, and a way back to empty once it is not — a user who
/// opened the picker to look, or who decided the handover is permanent after
/// all, otherwise has to abandon the screen to undo it.
class WorkflowDateField extends StatelessWidget {
  const WorkflowDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showLabel = true,
    this.emptyLabel,
    this.onCleared,
    this.clearLabel,
    this.initialWhenEmpty,
    this.firstDate,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  /// False where a step header or section label already names the field.
  final bool showLabel;

  /// What the field reads while empty. Defaults to the "unknown" placeholder,
  /// which is right for a date that is missing and wrong for one that is
  /// optional — "No return date" is a fact, "Unknown" is a gap.
  final String? emptyLabel;

  /// Makes the field clearable. Null keeps it required.
  final VoidCallback? onCleared;
  final String? clearLabel;

  /// Where the picker opens when nothing is chosen yet.
  final DateTime? initialWhenEmpty;

  /// The earliest date the picker offers — a return cannot precede the
  /// handover it ends.
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isClearable = onCleared != null && value != null;

    final field = AppPickerField(
      label: label,
      showLabel: showLabel,
      value: value == null
          ? (emptyLabel ?? l10n.labelUnknown)
          : context.dates.dayLong(value),
      icon: Icons.calendar_month_rounded,
      trailingLabel: _isToday(value) ? l10n.actionToday : null,
      onTap: () async {
        final picked = await AppDatePicker.show(
          context,
          initial: value ?? initialWhenEmpty,
          firstDate: firstDate,
        );
        if (picked != null) onChanged(picked);
      },
    );

    if (!isClearable) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        field,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppTextAction(
            label: clearLabel ?? l10n.actionClear,
            icon: Icons.close_rounded,
            onPressed: onCleared,
          ),
        ),
      ],
    );
  }

  static bool _isToday(DateTime? value) {
    if (value == null) return false;
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }
}
