import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/async_data_view.dart';
import '../../../../shared/widgets/skeleton_screens.dart';
import '../../domain/entities/asset.dart';
import '../cubit/asset_detail_cubit.dart';

/// The asset's printable QR code (spec §12).
///
/// The payload is `asset://<id>` and nothing else — no URL, no database name,
/// no session token. A label stuck to a laptop travels; anything more on it
/// would be a credential leak waiting to be photographed.
class AssetQrPage extends StatelessWidget {
  const AssetQrPage({required this.assetId, super.key});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssetDetailCubit>(
      create: (_) => sl<AssetDetailCubit>()..load(assetId),
      child: _AssetQrView(assetId: assetId),
    );
  }
}

class _AssetQrView extends StatelessWidget {
  const _AssetQrView({required this.assetId});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<AssetDetailCubit, AssetDetailState>(
      builder: (context, state) {
        final asset = state.asset;

        return AppScaffold(
          title: l10n.qrTitle,
          compactTitle: true,
          showBack: true,
          onBack: () => context.go(AppRoutes.assetDetailPath(assetId)),
          body: AsyncDataView<Asset>(
            status: state.status,
            data: asset,
            failure: state.failure,
            onRetry: () => context.read<AssetDetailCubit>().load(assetId),
            loadingView: const SkeletonDetail(hasActions: false),
            builder: (_, asset) => _QrBody(asset: asset),
          ),
        );
      },
    );
  }
}

class _QrBody extends StatelessWidget {
  const _QrBody({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final screen = context.screen;

    // Sized from the viewport rather than fixed: a small phone in landscape
    // has less height than a 280-px code plus the caption needs.
    final side = <double>[
      AppDimens.qrCodeMaxSize,
      screen.width - screen.gutter * 4,
      screen.height / 2,
    ].reduce((a, b) => a < b ? a : b);

    return AppPageBody(
      children: <Widget>[
        AppCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Always drawn dark-on-white regardless of theme: a code
              // rendered in dark mode's palette does not scan when printed,
              // and printing is the entire point of this screen.
              Container(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: QrImageView(
                  data: asset.qrPayload,
                  size: side,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.navy,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                asset.name,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (asset.assetTag != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    asset.assetTag!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),

        _PayloadRow(payload: asset.qrPayload),

        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.lock_outline_rounded,
                size: AppDimens.iconMd,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(l10n.qrHint, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the payload and lets the user copy it.
///
/// Visible on purpose: a user who can read exactly what the label encodes can
/// verify for themselves that it carries no credentials.
class _PayloadRow extends StatelessWidget {
  const _PayloadRow({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                payload,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
            icon: Icons.copy_rounded,
            tooltip: l10n.diagnosticsCopy,
            bordered: false,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (context.mounted) {
                AppSnack.success(context, l10n.diagnosticsCopied);
              }
            },
          ),
        ],
      ),
    );
  }
}
