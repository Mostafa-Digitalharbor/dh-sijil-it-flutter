import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/app_sheets.dart';
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
          // Listens to the controller rather than only handing `MobileScanner`
          // an `errorBuilder`.
          //
          // `errorBuilder` renders *inside* the scanner widget, which is the
          // bottom layer of this stack — so a failed camera drew its "camera
          // access is off" message underneath the scrim, the viewfinder
          // brackets and the sweep line, with "point the camera at the asset
          // code" still printed below it. The message was there and unreadable,
          // and the screen was instructing the user to do the one thing it had
          // just told them they could not.
          //
          // Read here, the failure replaces the whole apparatus instead.
          body: ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, scanner, _) {
              final error = scanner.error;
              if (error != null) {
                return SafeArea(
                  child: Column(
                    children: <Widget>[
                      _TopBar(controller: controller, state: state),
                      Expanded(child: _CameraError(error: error)),
                      const _ManualEntryFallback(),
                    ],
                  ),
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  MobileScanner(
                    controller: controller,
                    onDetect: handleDetection,
                  ),
                  const ScannerScrim(),
                  SafeArea(
                    child: Column(
                      children: <Widget>[
                        _TopBar(controller: controller, state: state),
                        const Expanded(
                          child: Center(child: ScannerViewfinder()),
                        ),
                        _Instructions(state: state),
                        const SizedBox(height: AppSpacing.lg),
                        _ModeSwitch(state: state),
                        const SizedBox(height: AppSpacing.sm),
                        const _ManualEntry(),
                        const SizedBox(height: AppSpacing.md),
                        if (state.hasResult || state.isResolving)
                          ScanResultSheet(state: state),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ],
              );
            },
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
          const SizedBox(height: AppSpacing.fine),
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

/// The way in when the camera is not the answer.
///
/// ## Why a scanner needs one
///
/// Until now the viewfinder was the only route to an asset by code, and it has
/// three failure modes a technician meets every week: the sticker is scuffed,
/// the store room is dark, or the label is on the underside of a desk nobody
/// is going to crawl under. Each of those was a dead end — the screen kept
/// telling the user to point the camera at a code it could not read.
///
/// The typed code goes through exactly the same path as a scanned one, so an
/// `asset://118` payload, a serial and a manufacturer barcode all resolve the
/// way they always did. There is no second lookup to keep in step.
class _ManualEntry extends StatelessWidget {
  const _ManualEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<ScannerCubit>();

    return Center(
      child: AppTextAction(
        label: l10n.scanEnterCode,
        icon: Icons.keyboard_alt_outlined,
        onPressed: () async {
          final code = await AppPromptDialog.show(
            context,
            title: l10n.scanEnterCodeTitle,
            message: l10n.scanEnterCodeBody,
            hint: l10n.scanEnterCodeHint,
            confirmLabel: l10n.actionOpen,
          );
          if (code == null) return;
          await cubit.onDetected(code);
        },
      ),
    );
  }
}

/// Shown when the camera cannot start — most often a denied permission.
///
/// ## What this used to say
///
/// ```dart
/// title:   isPermission ? l10n.scanPermissionTitle : l10n.errorUnknownTitle,
/// message: isPermission ? l10n.scanPermissionBody  : l10n.scanPermissionFix,
/// ```
///
/// Both arms were wrong, and in opposite directions. A user who had denied the
/// permission — the case this screen exists for — was told *what* happened and
/// *why*, and then never shown `scanPermissionFix`, the one sentence naming
/// the switch that turns the camera back on. Meanwhile a camera that failed
/// for some entirely different reason was headed "Something went wrong" and
/// told to go and enable a permission it already had.
///
/// So the two cases are separated, and each gets the full three parts the rest
/// of the app promises: what, why, and what to do about it.
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
        title: isPermission
            ? l10n.scanPermissionTitle
            : l10n.scanCameraErrorTitle,
        message: isPermission
            ? l10n.scanPermissionBody
            : l10n.scanCameraErrorBody,
        fix: isPermission ? l10n.scanPermissionFix : l10n.scanCameraErrorFix,
        // Only for the permission case, and only because the instruction
        // above it is otherwise a dead end: once "Don't allow" has been
        // chosen on Android the system dialog never appears again, so the
        // settings page is the single place the answer lives. A camera that
        // failed for another reason has nothing to open.
        actionLabel: isPermission ? l10n.actionOpenSettings : null,
        onAction: isPermission ? () => unawaited(openAppSettings()) : null,
      ),
    );
  }
}

/// The manual entry, repeated under the camera-failure screen.
///
/// This is where it matters most. A camera that will not start used to end the
/// screen: the user was told what happened, told how to fix it, and left with
/// no way to look up the asset they are standing in front of in the meantime.
class _ManualEntryFallback extends StatelessWidget {
  const _ManualEntryFallback();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
    child: _ManualEntry(),
  );
}
