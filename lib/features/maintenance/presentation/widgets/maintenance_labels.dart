import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/maintenance_request.dart';

/// Translated names and tones for the maintenance enums.
///
/// Kept beside the widgets rather than on the entities: the domain layer owns
/// what a priority *is*, and the presentation layer owns what it looks like
/// and what it is called in the user's language.
abstract final class MaintenanceLabels {
  static String type(AppL10n l10n, MaintenanceType? type) => switch (type) {
    MaintenanceType.corrective => l10n.maintenanceTypeCorrective,
    MaintenanceType.preventive => l10n.maintenanceTypePreventive,
    null => l10n.labelUnknown,
  };

  static String priority(AppL10n l10n, MaintenancePriority priority) =>
      switch (priority) {
        MaintenancePriority.veryLow => l10n.maintenancePriorityVeryLow,
        MaintenancePriority.low => l10n.maintenancePriorityLow,
        MaintenancePriority.normal => l10n.maintenancePriorityNormal,
        MaintenancePriority.high => l10n.maintenancePriorityHigh,
      };

  static Color priorityTone(MaintenancePriority priority) => switch (priority) {
    MaintenancePriority.high => AppColors.danger,
    MaintenancePriority.normal => AppColors.info,
    MaintenancePriority.low || MaintenancePriority.veryLow => AppColors.navy300,
  };

  static IconData typeIcon(MaintenanceType? type) => switch (type) {
    MaintenanceType.preventive => Icons.event_repeat_rounded,
    MaintenanceType.corrective => Icons.build_rounded,
    null => Icons.help_outline_rounded,
  };

  /// The tone for a request's stage chip.
  ///
  /// Stages are customer-configurable, so this keys off the `done` flag rather
  /// than the stage name — the only thing about a stage the app can rely on.
  static Color stageTone(MaintenanceRequest request) =>
      request.isDone ? AppColors.statusAvailable : AppColors.statusMaintenance;

  const MaintenanceLabels._();
}
