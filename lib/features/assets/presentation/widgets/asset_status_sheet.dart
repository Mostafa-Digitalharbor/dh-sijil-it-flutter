import 'package:flutter/widgets.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/asset_status.dart';

/// Lets the user record one of the states standard Odoo cannot express
/// (docs/ARCHITECTURE.md §6).
///
/// Only offers the three overlay states plus "back to available". The derived
/// ones — Assigned, Under maintenance, Retired — are deliberately absent: they
/// are facts Odoo owns, and offering them here would imply the app can set
/// something it can only read.
abstract final class AssetStatusSheet {
  /// The only statuses a user may set by hand.
  static const List<AssetStatus> _settable = <AssetStatus>[
    AssetStatus.available,
    AssetStatus.reserved,
    AssetStatus.damaged,
    AssetStatus.lost,
  ];

  static Future<AssetStatus?> show(
    BuildContext context, {
    required AssetStatus current,
  }) {
    final l10n = AppL10n.of(context);

    return AppOptionSheet.show<AssetStatus>(
      context,
      title: l10n.assetActionsTitle,
      subtitle: l10n.assetLocalStateNote,
      selected: current,
      options: <AppSheetOption<AssetStatus>>[
        for (final status in _settable)
          AppSheetOption<AssetStatus>(
            value: status,
            label: _label(l10n, status),
            icon: StatusChip.iconFor(status),
            tone: StatusChip.colorFor(status),
          ),
      ],
    );
  }

  static String _label(AppL10n l10n, AssetStatus status) => switch (status) {
    AssetStatus.available => l10n.assetMarkAvailable,
    AssetStatus.reserved => l10n.assetMarkReserved,
    AssetStatus.damaged => l10n.assetMarkDamaged,
    AssetStatus.lost => l10n.assetMarkLost,
    // Unreachable: the list above is the whole menu. Kept exhaustive so adding
    // a status is a compile error here rather than a silently missing option.
    AssetStatus.assigned => l10n.statusAssigned,
    AssetStatus.underMaintenance => l10n.statusMaintenance,
    AssetStatus.retired => l10n.statusRetired,
  };
}
