import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/utils/app_text.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/asset.dart';
import 'asset_icons.dart';

/// One asset in a list.
///
/// The single row used by the assets screen, the employee profile and the
/// scanner's recent results — so a spacing or chip change lands in all three
/// at once rather than drifting between them.
class AssetRow extends StatelessWidget {
  const AssetRow({
    required this.asset,
    required this.onTap,
    this.onLongPress,
    this.selectable = false,
    this.selected = false,
    this.showWarranty = true,
    this.showHolder = true,
    this.trailing,
    super.key,
  });

  final Asset asset;
  final VoidCallback onTap;

  /// Starts multi-select from this row. Null on the screens that do not have
  /// it — the employee profile and the scanner's recent results.
  final VoidCallback? onLongPress;

  /// Whether the list is currently choosing rows.
  ///
  /// Replaces the leading category glyph with a checkbox and the trailing
  /// chevron with nothing, because in this mode a tap picks rather than opens
  /// and the row must not promise otherwise.
  final bool selectable;

  final bool selected;

  /// The employee profile already groups by person and has no room for a
  /// second chip, so it turns the warranty chip off.
  final bool showWarranty;

  /// Replaces the chevron — the employee profile puts the status chip here.
  final Widget? trailing;

  /// False on a screen that is already about one person.
  ///
  /// Repeating "Ahmed Mohamed" on every row of Ahmed's own profile spends the
  /// subtitle on something the heading already said; the date he received it is
  /// the fact that row can add.
  final bool showHolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppListTile(
      onTap: onTap,
      // Tinted by status, not neutral. It is the first thing the eye lands
      // on, so it carries the state; the glyph inside carries the kind of
      // device. Two facts in the space of one, before a word is read.
      leading: selectable
          ? _SelectionBox(selected: selected)
          : AppLeadingTile(
              icon: AssetIcons.forCategory(asset.category?.name),
              tone: StatusChip.colorFor(asset.status),
            ),
      onLongPress: onLongPress,
      selected: selected,
      showChevron: !selectable,
      title: asset.name,
      subtitle: _subtitle(context, l10n),
      // Tag, manufacturer and holder are Latin identifiers even in an Arabic
      // UI, so the line keeps its reading order instead of being reordered
      // around the separators.
      subtitleIsLatin: true,
      trailing: trailing,
      chips: trailing != null
          ? const <Widget>[]
          : <Widget>[
              StatusChip(
                status: asset.status,
                isLocal: asset.isStatusLocal,
                dense: true,
              ),
              // Ahead of the warranty chip on purpose: "not sent yet" is about
              // whether this row is even true on the server, which outranks
              // anything it says about the device.
              if (asset.hasPendingSync)
                AppChip(
                  label: l10n.syncPendingChip,
                  icon: Icons.cloud_upload_outlined,
                  tone: AppColors.warning,
                  dense: true,
                ),
              // Ahead of the warranty chip too, and for the same kind of
              // reason: a warranty running out is a purchase decision months
              // away, and a laptop that should have come back last week is
              // somebody to ring today.
              DueChip(due: asset.dueBack),
              if (showWarranty) WarrantyChip(warranty: asset.warranty),
            ],
    );
  }

  /// "DH-LAP-0027 · Apple · Ahmed Mohamed", skipping whichever parts this
  /// instance does not record rather than leaving stray separators.
  String? _subtitle(BuildContext context, AppL10n l10n) {
    final parts = <String>[
      if (asset.assetTag != null)
        asset.assetTag!
      else if (asset.serialNumber != null)
        asset.serialNumber!,
      if (asset.manufacturer != null) asset.manufacturer!,
      if (showHolder)
        asset.assignedEmployee?.name ?? l10n.labelUnassigned
      else if (asset.assignmentDate != null)
        l10n.employeeSince(context.dates.day(asset.assignmentDate)),
    ];

    return AppText.joinedOrNull(parts);
  }
}

/// The checkbox that stands in for the category glyph while selecting.
///
/// Sized to the tile it replaces so the rows do not jump when the list enters
/// selection mode — a list that reflows under the finger that long-pressed it
/// is a list where the user loses their place.
class _SelectionBox extends StatelessWidget {
  const _SelectionBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: AppDimens.tileMd,
      height: AppDimens.tileMd,
      child: Center(
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: AppDimens.radioSize,
          height: AppDimens.radioSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            color: selected ? AppColors.mint : Colors.transparent,
            border: selected
                ? null
                : Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: AppDimens.focusedBorder,
                  ),
          ),
          child: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: AppDimens.iconSm,
                  color: AppColors.navy,
                )
              : null,
        ),
      ),
    );
  }
}
