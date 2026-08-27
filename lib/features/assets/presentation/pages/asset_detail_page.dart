import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/odoo_models.dart';
import '../../../../features/attachments/domain/usecases/attachment_usecases.dart';
import '../../../../features/attachments/presentation/cubit/photo_cubit.dart';
import '../../../../features/attachments/presentation/widgets/photo_section.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/async_data_view.dart';
import '../../../../shared/widgets/skeleton_screens.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/asset.dart';
import '../cubit/asset_detail_cubit.dart';
import '../widgets/asset_detail_sections.dart';
import '../widgets/asset_status_sheet.dart';

/// The full asset record (spec §14).
class AssetDetailPage extends StatelessWidget {
  const AssetDetailPage({required this.assetId, super.key});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AssetDetailCubit>(
          create: (_) => sl<AssetDetailCubit>()..load(assetId),
        ),
        // The app has uploaded return photos to `ir.attachment` since the
        // first release and never displayed them. This is what reads them
        // back — no migration, and every photo already taken shows up.
        BlocProvider<PhotoCubit>(
          create: (_) => sl<PhotoCubit>(
            param1: RecordRef(
              model: OdooModels.maintenanceEquipment,
              id: assetId,
            ),
          )..load(),
        ),
      ],
      child: _AssetDetailView(assetId: assetId),
    );
  }
}

class _AssetDetailView extends StatelessWidget {
  const _AssetDetailView({required this.assetId});

  final int assetId;

  Future<void> _confirmDelete(BuildContext context, Asset asset) async {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetDetailCubit>();

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.assetDeleteConfirm,
      message: l10n.assetDeleteBody,
      confirmLabel: l10n.actionDelete,
      isDestructive: true,
    );
    if (!confirmed) return;

    await cubit.delete();
  }

  Future<void> _changeStatus(BuildContext context, Asset asset) async {
    final cubit = context.read<AssetDetailCubit>();
    final status = await AssetStatusSheet.show(context, current: asset.status);
    if (status == null) return;
    await cubit.setStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocConsumer<AssetDetailCubit, AssetDetailState>(
      listenWhen: (previous, current) =>
          previous.actionFailure != current.actionFailure ||
          previous.wasDeleted != current.wasDeleted ||
          previous.openedRequest != current.openedRequest,
      listener: (context, state) {
        final failure = state.actionFailure;
        if (failure != null) {
          AppSnack.failure(context, failure);
          context.read<AssetDetailCubit>().acknowledgeActionFailure();
          return;
        }

        if (state.openedRequest != null) {
          AppSnack.success(
            context,
            l10n.maintenanceRequestCreated(state.asset?.name ?? ''),
          );
          context.read<AssetDetailCubit>().acknowledgeOpenedRequest();
          return;
        }

        if (state.wasDeleted) {
          AppSnack.success(context, l10n.assetDeleted(state.asset?.name ?? ''));
          context.go(AppRoutes.assets);
        }
      },
      builder: (context, state) {
        final cubit = context.read<AssetDetailCubit>();
        final asset = state.asset;

        return AppScaffold(
          title: l10n.assetDetailTitle,
          compactTitle: true,
          showBack: true,
          onBack: () => context.go(AppRoutes.assets),
          actions: <Widget>[
            if (asset != null) ...<Widget>[
              AppIconButton(
                icon: Icons.qr_code_2_rounded,
                tooltip: l10n.assetShowQr,
                onPressed: () => context.go(AppRoutes.assetQrPath(asset.id)),
              ),
              _OverflowMenu(
                state: state,
                onHistory: () => context.go(
                  Uri(
                    path: AppRoutes.assetHistoryPath(asset.id),
                    queryParameters: <String, String>{'name': asset.name},
                  ).toString(),
                ),
                onEdit: () => context.go(AppRoutes.assetEditPath(asset.id)),
                onChangeStatus: () => _changeStatus(context, asset),
                onDelete: () => _confirmDelete(context, asset),
              ),
            ],
          ],
          body: AsyncDataView<Asset>(
            status: state.status,
            data: asset,
            failure: state.failure,
            onRetry: () => cubit.load(assetId),
            loadingView: const SkeletonDetail(),
            builder: (_, asset) =>
                _DetailBody(asset: asset, state: state, assetId: assetId),
          ),
        );
      },
    );
  }
}

/// Asks for a one-line summary, then opens a maintenance request (spec §16).
///
/// A top-level function rather than a method: the button that calls it lives
/// several widgets down from the screen, and threading a callback through each
/// of them would be plumbing for its own sake.
Future<void> _openMaintenance(BuildContext context, Asset asset) async {
  final l10n = AppL10n.of(context);
  final cubit = context.read<AssetDetailCubit>();

  final summary = await AppPromptDialog.show(
    context,
    title: l10n.maintenanceNewRequest,
    message: asset.name,
    hint: l10n.maintenanceRequestHint,
    confirmLabel: l10n.actionMaintain,
  );
  if (summary == null) return;

  await cubit.openMaintenanceRequest(summary);
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.asset,
    required this.state,
    required this.assetId,
  });

  final Asset asset;
  final AssetDetailState state;
  final int assetId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssetDetailCubit>();

    return AppPageBody(
      onRefresh: () => cubit.load(assetId, refresh: true),
      children: <Widget>[
        // Above the identity card: on an asset the photograph *is* the
        // subject, which is why it gets the featured layout here and the
        // even grid on a repair, where photos are evidence.
        const PhotoSection(featured: true),
        AssetHeroCard(asset: asset),
        AssetLocalStateNotice(asset: asset),
        _PrimaryActions(
          asset: asset,
          state: state,
          onMaintain: () => _openMaintenance(context, asset),
        ),
        AssetDeviceSection(asset: asset),
        AssetOwnershipSection(
          asset: asset,
          onOpenEmployee: asset.assignedEmployee == null
              ? null
              : () => context.go(
                  AppRoutes.employeeDetailPath(asset.assignedEmployee!.id),
                ),
        ),
        AssetWarrantySection(asset: asset),
        AssetMaintenanceSection(
          open: state.openRequests,
          closed: state.closedRequests,
          onOpenRequest: (request) =>
              context.go(AppRoutes.maintenanceDetailPath(request.id)),
        ),
        AssetPurchaseSection(asset: asset),
        AssetNotesSection(asset: asset),
      ],
    );
  }
}

/// Assign / Return plus the secondary actions, gated on ACLs and on what the
/// asset's current state actually permits (spec §21).
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.asset,
    required this.state,
    required this.onMaintain,
  });

  final Asset asset;
  final AssetDetailState state;
  final VoidCallback onMaintain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final capabilities = context.watch<AuthCubit>().state.capabilities;

    // Maintenance is optional: an instance without the app gets no button
    // rather than one that can only fail (spec §17).
    final canMaintain =
        capabilities.hasMaintenanceRequests && state.permissions.canEdit;

    final primary = switch (asset.status) {
      _ when state.canReturn => AppButton.accent(
        label: l10n.actionReturn,
        icon: Icons.assignment_return_rounded,
        isCompact: true,
        onPressed: () => context.go(AppRoutes.assetReturnPath(asset.id)),
      ),
      _ when state.canAssign => AppButton.accent(
        label: l10n.actionAssign,
        icon: Icons.person_add_alt_1_rounded,
        isCompact: true,
        onPressed: () => context.go(AppRoutes.assetAssignPath(asset.id)),
      ),
      _ => null,
    };

    final actions = <Widget>[
      if (primary != null) primary,
      if (canMaintain)
        AppButton.outlined(
          label: l10n.actionMaintain,
          icon: Icons.build_outlined,
          isCompact: true,
          onPressed: state.isActing ? null : onMaintain,
        ),
      if (state.permissions.canEdit)
        AppButton.outlined(
          label: l10n.actionEdit,
          icon: Icons.edit_outlined,
          isCompact: true,
          onPressed: () => context.go(AppRoutes.assetEditPath(asset.id)),
        ),
    ];

    // Nothing to offer: a retired asset with a read-only user has no action,
    // and an empty row of buttons is worse than no row.
    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: <Widget>[
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.gridGap),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

/// The app bar's overflow menu.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.state,
    required this.onHistory,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final AssetDetailState state;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return PopupMenuButton<_AssetMenuAction>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: l10n.assetActionsTitle,
      onSelected: (action) => switch (action) {
        _AssetMenuAction.history => onHistory(),
        _AssetMenuAction.edit => onEdit(),
        _AssetMenuAction.status => onChangeStatus(),
        _AssetMenuAction.delete => onDelete(),
      },
      itemBuilder: (context) => <PopupMenuEntry<_AssetMenuAction>>[
        // Available to everyone, including read-only users: knowing who held
        // a device is a question support and finance ask far more often than
        // anyone edits one.
        PopupMenuItem<_AssetMenuAction>(
          value: _AssetMenuAction.history,
          child: _MenuRow(
            icon: Icons.history_rounded,
            label: l10n.assetActionHistory,
          ),
        ),
        if (state.permissions.canEdit) ...<PopupMenuEntry<_AssetMenuAction>>[
          PopupMenuItem<_AssetMenuAction>(
            value: _AssetMenuAction.edit,
            child: _MenuRow(icon: Icons.edit_outlined, label: l10n.actionEdit),
          ),
          PopupMenuItem<_AssetMenuAction>(
            value: _AssetMenuAction.status,
            child: _MenuRow(
              icon: Icons.flag_outlined,
              label: l10n.assetActionsTitle,
            ),
          ),
        ],
        if (state.permissions.canDelete)
          PopupMenuItem<_AssetMenuAction>(
            value: _AssetMenuAction.delete,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: l10n.actionDelete,
              tone: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

enum _AssetMenuAction { history, edit, status, delete }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, size: AppSpacing.xl, color: tone),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: tone),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
