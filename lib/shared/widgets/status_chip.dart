import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../features/assets/domain/entities/asset_status.dart';
import '../../features/assets/domain/entities/warranty.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_chip.dart';

/// Visual status indicator for an asset (spec §6).
///
/// A thin wrapper over [AppChip]: its only job is to map an [AssetStatus] to
/// a tone and a translated label, so the chip system stays single-sourced.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.status,
    this.isLocal = false,
    this.dense = false,
    super.key,
  });

  final AssetStatus status;

  /// Whether the status came from the app's own log rather than an Odoo
  /// field. Marked, because someone filtering by status in the Odoo web
  /// client will not find these three — see [AssetStatus].
  final bool isLocal;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppChip(
      label: labelFor(l10n, status),
      tone: colorFor(status),
      leadingDot: true,
      bordered: true,
      dense: dense,
      trailingIcon: isLocal ? Icons.history_rounded : null,
      semanticSuffix: isLocal ? l10n.statusKeptInLog : null,
    );
  }

  static Color colorFor(AssetStatus status) => switch (status) {
    AssetStatus.available => AppColors.statusAvailable,
    AssetStatus.assigned => AppColors.statusAssigned,
    AssetStatus.reserved => AppColors.statusReserved,
    AssetStatus.underMaintenance => AppColors.statusMaintenance,
    AssetStatus.damaged => AppColors.statusDamaged,
    AssetStatus.lost => AppColors.statusLost,
    AssetStatus.retired => AppColors.statusRetired,
  };

  static String labelFor(AppL10n l10n, AssetStatus status) => switch (status) {
    AssetStatus.available => l10n.statusAvailable,
    AssetStatus.assigned => l10n.statusAssigned,
    AssetStatus.reserved => l10n.statusReserved,
    AssetStatus.underMaintenance => l10n.statusMaintenance,
    AssetStatus.damaged => l10n.statusDamaged,
    AssetStatus.lost => l10n.statusLost,
    AssetStatus.retired => l10n.statusRetired,
  };

  static IconData iconFor(AssetStatus status) => switch (status) {
    AssetStatus.available => Icons.check_circle_outline_rounded,
    AssetStatus.assigned => Icons.person_rounded,
    AssetStatus.reserved => Icons.bookmark_outline_rounded,
    AssetStatus.underMaintenance => Icons.build_rounded,
    AssetStatus.damaged => Icons.report_problem_outlined,
    AssetStatus.lost => Icons.help_outline_rounded,
    AssetStatus.retired => Icons.archive_outlined,
  };
}

/// Warranty counterpart of [StatusChip] (spec §15).
///
/// Renders nothing at all when Odoo has no warranty date — an empty chip
/// saying "unknown" is noise on every row of a list.
class WarrantyChip extends StatelessWidget {
  const WarrantyChip({required this.warranty, this.dense = true, super.key});

  final Warranty warranty;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (warranty.state == WarrantyState.unknown) {
      return const SizedBox.shrink();
    }

    final l10n = AppL10n.of(context);

    return AppChip(
      label: labelFor(l10n, warranty),
      tone: colorFor(warranty.state),
      icon: Icons.shield_outlined,
      dense: dense,
    );
  }

  static Color colorFor(WarrantyState state) => switch (state) {
    WarrantyState.unknown => AppColors.navy300,
    WarrantyState.valid => AppColors.success,
    WarrantyState.expiringSoon => AppColors.info,
    WarrantyState.expiringCritical => AppColors.warning,
    WarrantyState.expired => AppColors.danger,
  };

  static String labelFor(AppL10n l10n, Warranty warranty) {
    final days = warranty.daysRemaining ?? 0;

    return switch (warranty.state) {
      WarrantyState.unknown => l10n.warrantyUnknown,
      WarrantyState.valid => l10n.warrantyValid,
      WarrantyState.expiringSoon ||
      WarrantyState.expiringCritical => l10n.warrantyExpiresIn(days),
      WarrantyState.expired => l10n.warrantyExpiredAgo(days.abs()),
    };
  }
}

/// Condition picker label helper, shared by the return workflow and any
/// summary that reports a past return.
abstract final class ConditionLabels {
  static String name(AppL10n l10n, ReturnCondition condition) =>
      switch (condition) {
        ReturnCondition.good => l10n.conditionGood,
        ReturnCondition.minorDamage => l10n.conditionMinorDamage,
        ReturnCondition.damaged => l10n.conditionDamaged,
        ReturnCondition.needsMaintenance => l10n.conditionNeedsMaintenance,
      };

  /// One line describing what confirming will actually do, so the user never
  /// has to guess the consequence of a choice.
  static String effect(AppL10n l10n, ReturnCondition condition) =>
      switch (condition) {
        ReturnCondition.good ||
        ReturnCondition.minorDamage => l10n.conditionGoodEffect,
        ReturnCondition.damaged => l10n.conditionDamagedEffect,
        ReturnCondition.needsMaintenance =>
          l10n.conditionNeedsMaintenanceEffect,
      };

  static Color tone(ReturnCondition condition) => switch (condition) {
    ReturnCondition.good => AppColors.statusAvailable,
    ReturnCondition.minorDamage => AppColors.statusMaintenance,
    ReturnCondition.damaged => AppColors.statusDamaged,
    ReturnCondition.needsMaintenance => AppColors.statusReserved,
  };

  static IconData icon(ReturnCondition condition) => switch (condition) {
    ReturnCondition.good => Icons.check_circle_outline_rounded,
    ReturnCondition.minorDamage => Icons.warning_amber_rounded,
    ReturnCondition.damaged => Icons.close_rounded,
    ReturnCondition.needsMaintenance => Icons.build_rounded,
  };

  const ConditionLabels._();
}
