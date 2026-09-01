import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/utils/app_number.dart';
import '../../../../shared/utils/app_text.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/key_value.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../maintenance/domain/entities/maintenance_request.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_lifecycle.dart';
import '../../domain/entities/return_due.dart';
import '../../domain/entities/warranty.dart';
import 'asset_icons.dart';

/// The navy header of the asset detail screen.
class AssetHeroCard extends StatelessWidget {
  const AssetHeroCard({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subdued = AppHeroCard.subduedText(context);
    final primary = AppHeroCard.primaryText(context);

    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: AppDimens.tileLg,
                height: AppDimens.tileLg,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: AppOpacities.overlay),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(
                  AssetIcons.forCategory(asset.category?.name),
                  size: AppDimens.iconXxl,
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      asset.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: primary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_descriptor.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _descriptor,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subdued,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatusChip(
                status: asset.status,
                isLocal: asset.isStatusLocal,
                dense: true,
              ),
              if (asset.assetTag != null)
                AppChip.neutral(label: asset.assetTag!, dense: true),
            ],
          ),
        ],
      ),
    );
  }

  /// "Laptop · Apple · MacBook Pro 14-inch", dropping whatever is missing.
  String get _descriptor => AppText.joined(<String?>[
    asset.category?.name,
    asset.manufacturer,
    asset.model,
  ]);
}

/// The "Device information" block (spec §14).
class AssetDeviceSection extends StatelessWidget {
  const AssetDeviceSection({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SectionCard(
      title: l10n.sectionDeviceInformation,
      child: KeyValueGrid(
        items: <KeyValue>[
          KeyValue(label: l10n.labelManufacturer, value: asset.manufacturer),
          KeyValue(label: l10n.labelModel, value: asset.model),
          KeyValue(
            label: l10n.labelSerialNumber,
            value: asset.serialNumber,
            isMonospace: true,
          ),
          KeyValue(label: l10n.labelCategory, value: asset.category?.name),
        ],
      ),
    );
  }
}

/// The "Ownership" block: who holds it and since when (spec §14).
class AssetOwnershipSection extends StatelessWidget {
  const AssetOwnershipSection({
    required this.asset,
    this.onOpenEmployee,
    super.key,
  });

  final Asset asset;
  final VoidCallback? onOpenEmployee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final employee = asset.assignedEmployee;

    return SectionCard(
      title: l10n.sectionOwnership,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (employee == null)
            Row(
              children: <Widget>[
                Icon(
                  Icons.person_off_outlined,
                  size: AppDimens.iconXl,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.labelUnassigned,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: onOpenEmployee,
              child: Row(
                children: <Widget>[
                  AppAvatar(name: employee.name),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          employee.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (asset.department != null)
                          Text(
                            asset.department!.name,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (onOpenEmployee != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppDimens.iconXl,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
              ),
            ),
          // Only when someone actually holds it. Odoo stamps `assign_date`
          // with today on create whether or not an employee is set, so keying
          // off the date alone puts "Assigned 24 Aug · 0 days" directly under
          // the word "Unassigned".
          if (employee != null && asset.assignmentDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Divider(
              height: AppDimens.hairline,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            InlineFact(
              icon: Icons.calendar_month_rounded,
              label: l10n.labelAssignedOn,
              value: context.dates.day(asset.assignmentDate),
              trailing: context.dates.daysSince(asset.assignmentDate),
            ),
          ],
          // Only when somebody promised it back. A handover with no date is
          // the common case and is not late for anything, so the row would be
          // an empty fact on most of the fleet.
          if (asset.dueBack.isSet) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _DueFact(due: asset.dueBack),
          ],
        ],
      ),
    );
  }
}

/// The expected-return line, tinted once the date matters.
///
/// Full sentence here rather than the list row's one-word chip: this is the
/// screen somebody is on when they decide whether to chase it, and "4 days
/// overdue" is the part of that decision the app can supply.
class _DueFact extends StatelessWidget {
  const _DueFact({required this.due});

  final ReturnDue due;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final tone = DueChip.colorFor(due.state);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: due.state.needsAttention
            ? tone.withValues(alpha: AppOpacities.overlay)
            : theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: AppOpacities.overlay,
              ),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: InlineFact(
        icon: due.isOverdue
            ? Icons.event_busy_rounded
            : Icons.event_available_rounded,
        label: l10n.labelDueBack,
        value: context.dates.day(due.date),
        trailing: DueChip.detailFor(l10n, due),
      ),
    );
  }
}

/// The "Warranty" block, with the elapsed-time bar (spec §15).
class AssetWarrantySection extends StatelessWidget {
  const AssetWarrantySection({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final warranty = asset.warranty;

    // An asset Odoo has no warranty date for gets no section, rather than an
    // empty bar between two "Not recorded" labels.
    if (warranty.state == WarrantyState.unknown) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: l10n.sectionWarranty,
      trailing: WarrantyChip(warranty: warranty, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _WarrantyBar(warranty: warranty),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.warrantyStarted(context.dates.day(warranty.startDate)),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  l10n.warrantyEnds(context.dates.day(warranty.endDate)),
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How much of the warranty period has elapsed.
///
/// Falls back to a full bar when only the end date is known, which is the
/// common case — Odoo records `warranty_date` but nothing that reliably means
/// "warranty started", so inventing a start would draw a fictional proportion.
class _WarrantyBar extends StatelessWidget {
  const _WarrantyBar({required this.warranty});

  final Warranty warranty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = WarrantyChip.colorFor(warranty.state);
    final fraction = _elapsedFraction();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Stack(
        children: <Widget>[
          Container(
            height: AppDimens.progressBarHeight,
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: AppOpacities.divider,
            ),
          ),
          FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              height: AppDimens.progressBarHeight,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _elapsedFraction() {
    final start = warranty.startDate;
    final end = warranty.endDate;
    if (end == null) return 0;
    if (warranty.isExpired) return 1;
    if (start == null) return 1;

    final total = end.difference(start).inDays;
    if (total <= 0) return 1;

    final remaining = warranty.daysRemaining ?? 0;
    return (1 - remaining / total).clamp(0.0, 1.0);
  }
}

/// How far through its working life the asset is, and what it has cost.
///
/// ## Why this is on the detail screen and not only in a report
///
/// The two numbers behind it were already on the record and the app did
/// nothing with either: a purchase date and a purchase value, printed as facts
/// and left there. Read together they answer the question an IT manager
/// actually has — "do I replace this one?" — and the moment they are most
/// useful is the moment somebody is looking at the asset, not a quarter later
/// in a spreadsheet.
///
/// The cost line is the one that changes conversations. A laptop bought four
/// years ago for 2,400 has cost 600 a year; the same laptop replaced after
/// eighteen months cost 1,600 a year. Neither figure is visible from a
/// purchase price on its own, and the second is the argument for buying the
/// better machine.
class AssetLifecycleSection extends StatelessWidget {
  const AssetLifecycleSection({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final lifecycle = asset.lifecycle;

    // Shown even with nothing to measure, unlike the warranty section, and for
    // the opposite reason: a missing warranty date is Odoo's business, while a
    // missing purchase date is a gap somebody here can close — and the section
    // is the only place that says so.
    if (lifecycle.state == LifecycleState.unknown) {
      return SectionCard(
        title: l10n.lifecycleTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.lifecycleUnknown, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.lifecycleUnknownHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final tone = lifecycleTone(lifecycle.state);

    return SectionCard(
      title: l10n.lifecycleTitle,
      trailing: lifecycle.state.needsAttention
          ? AppChip(
              label: lifecycle.isOverdue
                  ? l10n.lifecycleOverdue
                  : l10n.lifecycleAgeing,
              tone: tone,
              icon: Icons.autorenew_rounded,
              dense: true,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LifecycleBar(lifecycle: lifecycle, tone: tone),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.lifecycleAge(lifecycle.ageInMonths ?? 0),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            lifecycle.isOverdue
                ? l10n.lifecycleOverdueBy(lifecycle.monthsOverdue)
                : l10n.lifecycleRemaining(lifecycle.remainingMonths ?? 0),
            style: theme.textTheme.bodySmall?.copyWith(
              color: lifecycle.state.needsAttention
                  ? tone
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (lifecycle.annualisedCost != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            InlineFact(
              icon: Icons.savings_outlined,
              label: l10n.lifecycleCostPerYear,
              value: AppNumber.money(
                context,
                lifecycle.annualisedCost,
                symbol: asset.currencySymbol,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The colour a lifecycle state is drawn in.
  ///
  /// Static and public so a list row and an export can use the same mapping
  /// rather than each deciding what "ageing" looks like.
  static Color lifecycleTone(LifecycleState state) => switch (state) {
    LifecycleState.unknown => AppColors.navy300,
    LifecycleState.healthy => AppColors.success,
    LifecycleState.ageing => AppColors.warning,
    LifecycleState.overdue => AppColors.danger,
  };
}

/// How much of the expected life has been used.
class _LifecycleBar extends StatelessWidget {
  const _LifecycleBar({required this.lifecycle, required this.tone});

  final AssetLifecycle lifecycle;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Stack(
        children: <Widget>[
          Container(
            height: AppDimens.progressBarHeight,
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: AppOpacities.divider,
            ),
          ),
          FractionallySizedBox(
            widthFactor: lifecycle.progress,
            child: Container(
              height: AppDimens.progressBarHeight,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The collapsed "Purchase & vendor" block.
class AssetPurchaseSection extends StatelessWidget {
  const AssetPurchaseSection({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppExpansionCard(
      title: l10n.sectionPurchase,
      icon: Icons.receipt_long_rounded,
      child: KeyValueGrid(
        items: <KeyValue>[
          KeyValue(label: l10n.labelVendor, value: asset.vendor?.name),
          KeyValue(
            label: l10n.labelPurchaseDate,
            value: asset.purchaseDate == null
                ? null
                : context.dates.day(asset.purchaseDate),
          ),
          KeyValue(
            label: l10n.labelPurchaseValue,
            value: _formattedValue(asset),
          ),
        ],
      ),
    );
  }

  /// Odoo returns 0 for an unpriced asset, which is a value the user never
  /// typed — it reads as the "not recorded" placeholder instead of "0.00".
  static String? _formattedValue(Asset asset) {
    final value = asset.purchaseValue;
    if (value == null || value == 0) return null;
    return value.toStringAsFixed(2);
  }
}

/// The collapsed notes block, shown only when Odoo actually has a note.
class AssetNotesSection extends StatelessWidget {
  const AssetNotesSection({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final notes = asset.notes;
    if (notes == null || notes.isEmpty) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);

    return AppExpansionCard(
      title: l10n.labelNotes,
      icon: Icons.sticky_note_2_outlined,
      child: Text(notes, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// The banner shown when a status is device-local (docs/ARCHITECTURE.md §6).
///
/// Explicit rather than implied: a user who marks something Damaged must not
/// believe their colleague sees it in the Odoo web client.
class AssetLocalStateNotice extends StatelessWidget {
  const AssetLocalStateNotice({required this.asset, super.key});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    if (!asset.isStatusLocal) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final tone = StatusChip.colorFor(asset.status);
    final ink = AppInk.of(context, tone);

    return AppCard(
      backgroundColor: tone.withValues(alpha: AppOpacities.overlay),
      borderColor: tone.withValues(alpha: AppOpacities.chipBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.history_rounded, size: AppDimens.iconMd, color: ink),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.statusKeptInLog,
                  style: theme.textTheme.labelSmall?.copyWith(color: ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.assetLocalStateNote,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// This asset's maintenance history (spec §14).
///
/// Open requests first, then closed ones — the order someone triaging a device
/// reads them in. Renders nothing at all when the instance has no Maintenance
/// app or the asset has never been serviced, rather than an empty card.
class AssetMaintenanceSection extends StatelessWidget {
  const AssetMaintenanceSection({
    required this.open,
    required this.closed,
    required this.onOpenRequest,
    super.key,
  });

  final List<MaintenanceRequest> open;
  final List<MaintenanceRequest> closed;
  final ValueChanged<MaintenanceRequest> onOpenRequest;

  @override
  Widget build(BuildContext context) {
    if (open.isEmpty && closed.isEmpty) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);

    return AppExpansionCard(
      title: l10n.sectionMaintenance,
      icon: Icons.build_outlined,
      // Open work is the reason someone looks; it should not need a tap.
      initiallyExpanded: open.isNotEmpty,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final request in <MaintenanceRequest>[...open, ...closed])
            _RequestRow(request: request, onTap: () => onOpenRequest(request)),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.onTap});

  final MaintenanceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final tone = request.isDone
        ? AppColors.statusAvailable
        : AppColors.statusMaintenance;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppDimens.minTapTarget),
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            AppLeadingTile.small(
              icon: request.isDone
                  ? Icons.check_circle_outline_rounded
                  : Icons.build_rounded,
              tone: tone,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    request.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _subtitle(context, l10n),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconXl,
              color: theme.colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// "Closed 21 Aug 2026" for finished work; the stage and, when Odoo has one,
  /// the next scheduled date for work still open.
  String _subtitle(BuildContext context, AppL10n l10n) {
    if (request.isDone) {
      return l10n.maintenanceClosed(context.dates.day(request.closedOn));
    }

    return AppText.joined(<String?>[
      request.stage?.name,
      request.scheduledFor == null
          ? null
          : _scheduledLabel(context, l10n, request.scheduledFor),
    ]);
  }

  static String _scheduledLabel(
    BuildContext context,
    AppL10n l10n,
    DateTime? when,
  ) => '${l10n.maintenanceNextScheduled}: ${context.dates.day(when)}';
}
