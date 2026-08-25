import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/state_views.dart';
import '../cubit/scanner_cubit.dart';
import '../widgets/camera_lifecycle.dart';
import '../widgets/scan_result_sheet.dart';
import '../widgets/scanner_viewfinder.dart';

/// Reads an asset QR code or barcode and opens the matching asset (spec §13).
class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScannerCubit>(
      create: (_) => sl<ScannerCubit>(),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with WidgetsBindingObserver, CameraLifecycle {
  @override
  void onCode(String code) => context.read<ScannerCubit>().onDetected(code);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScannerCubit, ScannerState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.surfaceDark,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MobileScanner(
                controller: controller,
                onDetect: handleDetection,
                errorBuilder: (context, error, _) => _CameraError(error: error),
              ),
              const ScannerScrim(),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    _TopBar(controller: controller, state: state),
                    const Expanded(child: Center(child: ScannerViewfinder())),
                    _Instructions(state: state),
                    const SizedBox(height: AppSpacing.lg),
                    _ModeSwitch(state: state),
                    const SizedBox(height: AppSpacing.lg),
                    if (state.hasResult || state.isResolving)
                      ScanResultSheet(state: state),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.state});

  final MobileScannerController controller;
  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.actionClose,
            bordered: false,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(
              alpha: AppOpacities.overlay,
            ),
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
          Expanded(
            child: Text(
              l10n.scanTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
          AppIconButton(
            icon: state.torchOn
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            tooltip: l10n.scanTorch,
            bordered: false,
            color: state.torchOn ? AppColors.navy : AppColors.mint,
            backgroundColor: state.torchOn
                ? AppColors.mint
                : AppColors.mint.withValues(
                    alpha: AppOpacities.toggleRestingFill,
                  ),
            onPressed: () {
              context.read<ScannerCubit>().toggleTorch();
              unawaited(controller.toggleTorch());
            },
          ),
        ],
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.scanInstruction,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            l10n.scanInstructionDetail,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.heroSubdued,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xxxl,
          ),
          child: AppSegmented<ScanMode>(
            value: state.mode,
            compact: true,
            semanticLabel: l10n.scanTitle,
            onChanged: context.read<ScannerCubit>().setMode,
            options: <SegmentOption<ScanMode>>[
              SegmentOption<ScanMode>(
                value: ScanMode.qr,
                label: l10n.scanModeQr,
              ),
              SegmentOption<ScanMode>(
                value: ScanMode.barcode,
                label: l10n.scanModeBarcode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the camera cannot start — most often a denied permission.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: AppColors.surfaceDark,
      child: EmptyStateView(
        icon: isPermission
            ? Icons.no_photography_outlined
            : Icons.videocam_off_outlined,
        title: isPermission ? l10n.scanPermissionTitle : l10n.errorUnknownTitle,
        message: isPermission
            ? l10n.scanPermissionBody
            : l10n.scanPermissionFix,
      ),
    );
  }
}
