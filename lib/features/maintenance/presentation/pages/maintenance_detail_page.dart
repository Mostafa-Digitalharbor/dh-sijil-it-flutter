import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/odoo_models.dart';
import '../../../../features/attachments/domain/usecases/attachment_usecases.dart';
import '../../../../features/attachments/presentation/cubit/photo_cubit.dart';
import '../../../../features/attachments/presentation/widgets/photo_section.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_data_view.dart';
import '../../../../shared/widgets/key_value.dart';
import '../../../../shared/widgets/skeleton_screens.dart';
import '../../domain/entities/maintenance_request.dart';
import '../cubit/maintenance_cubit.dart';
import '../widgets/maintenance_labels.dart';

/// One maintenance request in full (spec §16).
class MaintenanceDetailPage extends StatelessWidget {
  const MaintenanceDetailPage({required this.requestId, super.key});

  final int requestId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<MaintenanceDetailCubit>(
          create: (_) => sl<MaintenanceDetailCubit>()..load(requestId),
        ),
        // Scoped to this request, so leaving the screen disposes it and the
        // next repair opens with its own photos rather than the last one's.
        BlocProvider<PhotoCubit>(
          create: (_) => sl<PhotoCubit>(
            param1: RecordRef(
              model: OdooModels.maintenanceRequest,
              id: requestId,
            ),
          )..load(),
        ),
      ],
      child: _MaintenanceDetailView(requestId: requestId),
    );
  }
}

class _MaintenanceDetailView extends StatelessWidget {
  const _MaintenanceDetailView({required this.requestId});

  final int requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<
      MaintenanceDetailCubit,
      SimpleViewState<MaintenanceRequest>
    >(
      builder: (context, state) {
        final cubit = context.read<MaintenanceDetailCubit>();
        final request = state.data;

        return AppScaffold(
          title: l10n.maintenanceRequestTitle,
          compactTitle: true,
          showBack: true,
          onBack: () => context.go(AppRoutes.maintenancePath),
          body: AsyncDataView<MaintenanceRequest>(
            status: state.status,
            data: request,
            failure: state.failure,
            onRetry: () => cubit.load(requestId),
            loadingView: const SkeletonDetail(hasActions: false),
            builder: (_, request) =>
                _RequestBody(request: request, requestId: requestId),
          ),
        );
      },
    );
  }
}

class _RequestBody extends StatelessWidget {
  const _RequestBody({required this.request, required this.requestId});

  final MaintenanceRequest request;
  final int requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<MaintenanceDetailCubit>();

    return AppPageBody(
      onRefresh: () => cubit.load(requestId, refresh: true),
      children: <Widget>[
        AppCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppLeadingTile(
                    icon: MaintenanceLabels.typeIcon(request.type),
                    tone: MaintenanceLabels.stageTone(request),
                    size: AppDimens.tileLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      request.name,
                      style: theme.textTheme.headlineSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppChipWrap(
                children: <Widget>[
                  if (request.stage != null)
                    AppChip(
                      label: request.stage!.name,
                      tone: MaintenanceLabels.stageTone(request),
                      leadingDot: true,
                      bordered: true,
                      dense: true,
                    ),
                  AppChip(
                    label: MaintenanceLabels.priority(l10n, request.priority),
                    tone: MaintenanceLabels.priorityTone(request.priority),
                    dense: true,
                  ),
                  if (request.isOverdue())
                    AppChip(
                      label: l10n.maintenanceOverdue,
                      tone: MaintenanceLabels.priorityTone(
                        MaintenancePriority.high,
                      ),
                      icon: Icons.schedule_rounded,
                      dense: true,
                    ),
                ],
              ),
            ],
          ),
        ),

        SectionCard(
          title: l10n.maintenanceTitle,
          child: KeyValueGrid(
            items: <KeyValue>[
              KeyValue(
                label: l10n.maintenanceStage,
                value: request.stage?.name,
              ),
              KeyValue(
                label: l10n.maintenanceTypeField,
                value: MaintenanceLabels.type(l10n, request.type),
              ),
              KeyValue(
                label: l10n.maintenanceTechnician,
                value: request.technician?.name,
              ),
              KeyValue(
                label: l10n.maintenanceDuration,
                value: request.durationHours == null
                    ? null
                    : l10n.maintenanceHours(
                        request.durationHours!.toStringAsFixed(1),
                      ),
              ),
            ],
          ),
        ),

        // Evidence of the fault and of the fix. Sits above the activity log
        // because a technician opening a repair looks at the damage first.
        PhotoSection(hint: l10n.photosEmptyHint),

        SectionCard(
          title: l10n.sectionActivity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InlineFact(
                icon: Icons.event_available_rounded,
                label: l10n.maintenanceRequestedOn,
                value: context.dates.day(request.requestedOn),
              ),
              if (request.scheduledFor != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                InlineFact(
                  icon: Icons.schedule_rounded,
                  label: l10n.maintenanceScheduled,
                  value: context.dates.dateAndTime(request.scheduledFor),
                ),
              ],
              if (request.closedOn != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                InlineFact(
                  icon: Icons.check_circle_outline_rounded,
                  label: l10n.actionDone,
                  value: context.dates.day(request.closedOn),
                ),
              ],
            ],
          ),
        ),

        if (request.equipment != null)
          AppCard(
            onTap: () =>
                context.go(AppRoutes.assetDetailPath(request.equipment!.id)),
            child: Row(
              children: <Widget>[
                const AppLeadingTile(icon: Icons.devices_other_rounded),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.assetDetailTitle,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        request.equipment!.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
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

        if (request.description != null)
          AppExpansionCard(
            title: l10n.labelNotes,
            icon: Icons.sticky_note_2_outlined,
            initiallyExpanded: true,
            child: Text(
              request.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
