import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../cubit/asset_list_cubit.dart';

/// What the user can do with the rows they have picked.
///
/// ## Why these two actions and no others
///
/// Multi-select is only worth its complexity if the actions behind it are ones
/// nobody would do forty times by hand. Both of these are:
///
/// * **A label sheet.** Printing a QR code has always been one screen per
///   asset, which is fine for a laptop already on a shelf and useless for a
///   delivery of thirty.
/// * **A department move.** The change an IT manager makes after a re-org or
///   a floor move, and the one field where "these, all at once" is a real
///   sentence rather than a shortcut.
///
/// Deleting is deliberately absent. A bulk delete is the one bulk action whose
/// mistake cannot be undone from inside the app, and nothing in the product
/// asks for it.
class AssetSelectionBar extends StatelessWidget {
  const AssetSelectionBar({
    required this.state,
    required this.onMove,
    required this.onLabels,
    super.key,
  });

  final AssetListState state;
  final VoidCallback onMove;
  final VoidCallback onLabels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Both actions need rows; the move also needs somewhere to move them to,
    // and a button that can only apologise is worse than a disabled one.
    final enabled = state.hasSelection && !state.isBulkWorking;

    return StickyActionBar(
      child: Row(
        children: <Widget>[
          Expanded(
            child: AppButton.outlined(
              label: l10n.bulkPrintLabels,
              icon: Icons.qr_code_2_rounded,
              isCompact: true,
              onPressed: enabled ? onLabels : null,
            ),
          ),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(
            child: AppButton.accent(
              label: l10n.bulkMoveDepartment,
              icon: Icons.drive_file_move_outline,
              isCompact: true,
              isBusy: state.isBulkWorking,
              onPressed: enabled && state.permissions.canEdit ? onMove : null,
            ),
          ),
        ],
      ),
    );
  }
}
