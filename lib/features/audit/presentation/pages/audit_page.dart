import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/cubit/async_guards.dart';
import '../../../../shared/utils/app_number.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/data_charts.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/mono_text.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_icons.dart';
import '../../../scanner/presentation/widgets/camera_lifecycle.dart';
import '../../domain/entities/audit_session.dart';
import '../cubit/audit_cubit.dart';

/// Counts assets by walking around and scanning them.
///
/// One route for all three phases — pick a scope, walk, review — because the
/// session lives in the Cubit and only exists for as long as this route does.
/// Pushing the walk onto its own route would mean a stray back gesture throws
/// away a half-finished count with nothing to restore it from.
class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuditCubit>(
      create: (_) => sl<AuditCubit>()..loadScopes(),
      child: const _AuditView(),
    );
  }
}

class _AuditView extends StatelessWidget {
  const _AuditView();

  /// Guards the back gesture while a count is in progress.
  Future<bool> _confirmLeave(BuildContext context, AuditState state) async {
    final session = state.session;
    if (session == null || session.results.isEmpty || session.isFinished) {
      return true;
    }
    final l10n = AppL10n.of(context);
    return AppConfirmDialog.show(
      context,
      title: l10n.auditDiscardTitle,
      message: l10n.auditDiscardBody,
      confirmLabel: l10n.auditDiscardConfirm,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuditCubit, AuditState>(
      listenWhen: (a, b) =>
          a.committedNotes != b.committedNotes ||
          a.unknownCode != b.unknownCode,
      listener: (context, state) {
        final l10n = AppL10n.of(context);
        if (state.committedNotes != null) {
          AppSnack.success(
            context,
            state.committedNotes == 0 ? l10n.auditSavedNone : l10n.auditSaved,
          );
        }
        if (state.unknownCode != null) {
          AppSnack.info(context, l10n.auditUnknownCode);
        }
      },
      builder: (context, state) {
        final l10n = AppL10n.of(context);

        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (!await _confirmLeave(context, state)) return;
            if (context.mounted) context.pop();
          },
          child: AppScaffold(
            title: switch (state.phase) {
              AuditPhase.setup => l10n.auditTitle,
              AuditPhase.counting => l10n.auditCounting,
              AuditPhase.report => l10n.auditReportTitle,
            },
            subtitle: state.session?.scopeLabel,
            showBack: true,
            onBack: () async {
              if (!await _confirmLeave(context, state)) return;
              if (context.mounted) context.pop();
            },
            body: switch (state.phase) {
              AuditPhase.setup => _SetupView(state: state),
              AuditPhase.counting => _CountingView(state: state),
              AuditPhase.report => _ReportView(state: state),
            },
          ),
        );
      },
    );
  }
}

// ── Phase 1 · scope ─────────────────────────────────────────────────────────

class _SetupView extends StatelessWidget {
  const _SetupView({required this.state});

  final AuditState state;

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<OdooNameRef> options,
    required int? selected,
    required void Function(int?) onPicked,
  }) async {
    final chosen = await AppOptionSheet.show<int>(
      context,
      title: title,
      selected: selected,
      options: <AppSheetOption<int>>[
        for (final option in options)
          AppSheetOption<int>(value: option.id, label: option.name),
      ],
    );
    if (chosen != null) onPicked(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AuditCubit>();
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    if (state.isLoading && state.categories.isEmpty) {
      return const LoadingView();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(l10n.auditStartTitle, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.auditStartBody,
          style: text.bodyMedium?.copyWith(color: palette.dim),
        ),
        const SizedBox(height: AppSpacing.lg),

        for (final scope in AuditScope.values) ...<Widget>[
          AppSettingTile(
            icon: state.scope == scope
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            tone: state.scope == scope ? palette.mint : null,
            title: _scopeLabel(l10n, scope),
            subtitle: _scopeValue(l10n, scope),
            showDivider: false,
            showChevron: false,
            onTap: () => cubit.setScope(scope),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        if (state.scope == AuditScope.category)
          AppButton.outlined(
            label:
                _scopeValue(l10n, AuditScope.category) ??
                l10n.auditPickCategory,
            icon: Icons.category_rounded,
            onPressed: () => _pick(
              context,
              title: l10n.auditPickCategory,
              options: state.categories,
              selected: state.categoryId,
              onPicked: cubit.setCategory,
            ),
          ),
        if (state.scope == AuditScope.department)
          AppButton.outlined(
            label:
                _scopeValue(l10n, AuditScope.department) ??
                l10n.auditPickDepartment,
            icon: Icons.apartment_rounded,
            onPressed: () => _pick(
              context,
              title: l10n.auditPickDepartment,
              options: state.departments,
              selected: state.departmentId,
              onPicked: cubit.setDepartment,
            ),
          ),

        if (state.hasFailed && state.failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          FailureView(failure: state.failure!, onRetry: cubit.start),
        ],

        const SizedBox(height: AppSpacing.xl),
        AppButton.accent(
          label: l10n.auditBegin,
          icon: Icons.qr_code_scanner_rounded,
          isBusy: state.isLoading,
          onPressed: state.canStart ? cubit.start : null,
        ),
      ],
    );
  }

  String _scopeLabel(AppL10n l10n, AuditScope scope) => switch (scope) {
    AuditScope.all => l10n.auditScopeAll,
    AuditScope.category => l10n.auditScopeCategory,
    AuditScope.department => l10n.auditScopeDepartment,
  };

  String? _scopeValue(AppL10n l10n, AuditScope scope) =>
      scope == state.scope ? state.scopeLabel : null;
}

// ── Phase 2 · the walk ──────────────────────────────────────────────────────

class _CountingView extends StatefulWidget {
  const _CountingView({required this.state});

  final AuditState state;

  @override
  State<_CountingView> createState() => _CountingViewState();
}

class _CountingViewState extends State<_CountingView>
    with WidgetsBindingObserver, CameraLifecycle {
  /// Re-arms the same sticker after a moment.
  ///
  /// Without it, a re-scan to check "did that register?" is silently dropped
  /// forever by the detector's duplicate suppression.
  final Debouncer _rearm = Debouncer(delay: AppDurations.scanCooldown);

  @override
  void dispose() {
    _rearm.dispose();
    super.dispose();
  }

  @override
  void onCode(String code) {
    unawaited(context.read<AuditCubit>().onDetected(code));
    _rearm.run(() {
      if (mounted) context.read<AuditCubit>().clearLastCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final session = widget.state.session;
    if (session == null) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: <Widget>[
              _Tally(session: session),
              const SizedBox(height: AppSpacing.md),
              _Viewfinder(controller: controller, onDetect: handleDetection),
              const SizedBox(height: AppSpacing.md),
              if (session.feed.isNotEmpty) ...<Widget>[
                Text(
                  l10n.auditJustScanned,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final entry in session.feed.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ScanRow(entry: entry),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: AppButton.accent(
            label: l10n.auditFinish,
            icon: Icons.flag_rounded,
            onPressed: context.read<AuditCubit>().finish,
          ),
        ),
      ],
    );
  }
}

/// Progress ring plus the three outcomes.
class _Tally extends StatelessWidget {
  const _Tally({required this.session});

  final AuditSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return GlassCard(
      child: Row(
        children: <Widget>[
          ProgressRing(
            progress: session.progress,
            primary: AppNumber.percent(context, session.progress),
            secondary: l10n.auditOf(session.foundCount, session.expectedCount),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _TallyRow(
                  icon: Icons.check_rounded,
                  tone: AppColors.statusAvailable,
                  label: l10n.auditFound,
                  count: session.foundCount,
                ),
                const SizedBox(height: AppSpacing.sm),
                _TallyRow(
                  icon: Icons.moving_rounded,
                  tone: AppColors.statusReserved,
                  label: l10n.auditUnexpected,
                  count: session.unexpectedCount,
                ),
                const SizedBox(height: AppSpacing.sm),
                _TallyRow(
                  icon: Icons.error_outline_rounded,
                  tone: AppColors.statusDamaged,
                  label: l10n.auditMissing,
                  count: session.missingCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TallyRow extends StatelessWidget {
  const _TallyRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final read = context.ink(tone);

    return Row(
      children: <Widget>[
        Container(
          width: AppDimens.tileSm,
          height: AppDimens.tileSm,
          decoration: BoxDecoration(
            color: context.tint(tone),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, size: AppDimens.iconSm, color: read),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.dim),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        MonoText(
          AppNumber.count(context, count),
          size: AppDimens.iconMd,
          weight: AppTypography.boldest,
          color: read,
        ),
      ],
    );
  }
}

/// The live camera, sized as a panel rather than the whole screen.
///
/// The counters have to stay visible while scanning — watching them move is
/// the feedback that tells you the walk is working — so the camera gets a
/// fixed panel instead of the full-bleed treatment the one-shot scanner uses.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.controller, required this.onDetect});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        height: AppDimens.photoStrip + AppSpacing.huge,
        decoration: BoxDecoration(
          // A camera preview is a camera preview: it stays dark in both
          // themes, and the text on it comes from the dark set.
          color: AppColors.camera,
          border: Border.all(color: palette.line),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (context, error, _) => const Center(
                child: Icon(
                  Icons.videocam_off_rounded,
                  color: AppColors.cameraInk,
                  size: AppDimens.iconLg,
                ),
              ),
            ),
            const Center(child: _AuditBrackets()),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.sm,
              child: Text(
                l10n.auditKeepScanning,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.cameraInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four corner brackets rather than a closed box.
///
/// A full outline reads as a frame you must fit the code *inside*, which makes
/// people back away until the whole sticker is in it and the code gets too
/// small to decode. Corners read as an aim point.
class _AuditBrackets extends StatelessWidget {
  const _AuditBrackets();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppDimens.viewfinderCompact,
      height: AppDimens.viewfinderCompact,
      child: Stack(
        children: <Widget>[
          for (final corner in const <Alignment>[
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: corner,
              child: _Corner(corner: corner),
            ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.corner});

  final Alignment corner;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(
      color: AppColors.mint,
      width: AppDimens.viewfinderCornerWeight,
    );
    const radius = Radius.circular(AppRadii.md);
    final top = corner.y < 0;
    final left = corner.x < 0;

    return Container(
      width: AppDimens.viewfinderCorner,
      height: AppDimens.viewfinderCorner,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? radius : Radius.zero,
          topRight: top && !left ? radius : Radius.zero,
          bottomLeft: !top && left ? radius : Radius.zero,
          bottomRight: !top && !left ? radius : Radius.zero,
        ),
      ),
    );
  }
}

/// One line in the live feed.
class _ScanRow extends StatelessWidget {
  const _ScanRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final found = entry.outcome == AuditOutcome.found;
    final tone = found ? AppColors.statusAvailable : AppColors.statusReserved;
    final read = context.ink(tone);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.dense),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: AppOpacities.overlaySoft),
        border: Border.all(
          color: tone.withValues(alpha: AppOpacities.chipBorder),
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: AppDimens.statusTileSmall,
            height: AppDimens.statusTileSmall,
            decoration: BoxDecoration(
              color: context.tint(tone),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              found ? Icons.check_rounded : Icons.moving_rounded,
              size: AppDimens.iconSm,
              color: read,
            ),
          ),
          const SizedBox(width: AppSpacing.dense),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.asset.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimens.hairline),
                Row(
                  children: <Widget>[
                    if (entry.asset.assetTag != null) ...<Widget>[
                      MonoText.tag(entry.asset.assetTag!, color: palette.faint),
                      Text(
                        ' · ',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palette.faint),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        found ? l10n.auditWhereExpected : l10n.auditOutOfScope,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palette.faint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase 3 · the report ────────────────────────────────────────────────────

class _ReportView extends StatelessWidget {
  const _ReportView({required this.state});

  final AuditState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AuditCubit>();
    final session = state.session;
    if (session == null) return const SizedBox.shrink();

    final missing = session.missing;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: <Widget>[
              _Tally(session: session),
              const SizedBox(height: AppSpacing.lg),

              if (missing.isEmpty)
                GlassCard(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.verified_rounded,
                        color: context.ink(AppColors.statusAvailable),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(l10n.auditNothingMissing)),
                    ],
                  ),
                )
              else ...<Widget>[
                Text(
                  l10n.auditMissing,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final asset in missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _MissingRow(asset: asset),
                  ),
              ],

              if (state.hasFailed && state.failure != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FailureView(failure: state.failure!, onRetry: cubit.commit),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: AppButton.outlined(
                  label: l10n.auditResume,
                  onPressed: state.committedNotes == null ? cubit.resume : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton.accent(
                  label: state.committedNotes != null
                      ? l10n.auditSaved
                      : l10n.auditSaveToOdoo,
                  icon: state.committedNotes != null
                      ? Icons.check_rounded
                      : Icons.cloud_upload_rounded,
                  isBusy: state.isCommitting,
                  onPressed: state.committedNotes != null ? null : cubit.commit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const tone = AppColors.statusDamaged;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.dense),
      decoration: BoxDecoration(
        color: palette.raised,
        border: Border.all(color: palette.lineSoft),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: AppDimens.statusTileSmall,
            height: AppDimens.statusTileSmall,
            decoration: BoxDecoration(
              color: context.tint(tone),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              AssetIcons.forCategory(asset.category?.name),
              size: AppDimens.iconSm,
              color: context.ink(tone),
            ),
          ),
          const SizedBox(width: AppSpacing.dense),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  asset.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (asset.assetTag != null)
                  MonoText.tag(asset.assetTag!, color: palette.faint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
