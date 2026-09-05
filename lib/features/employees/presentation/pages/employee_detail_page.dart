import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_number.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_data_views.dart';
import '../../../../shared/widgets/app_media_row.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/async_data_view.dart';
import '../../../../shared/widgets/skeleton_screens.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../assets/presentation/widgets/asset_row.dart';
import '../../domain/entities/employee.dart';
import '../cubit/employee_detail_cubit.dart';

/// One employee's profile and the assets they hold (spec §9).
class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({required this.employeeId, super.key});

  final int employeeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EmployeeDetailCubit>(
      create: (_) => sl<EmployeeDetailCubit>()..load(employeeId),
      child: _EmployeeDetailView(employeeId: employeeId),
    );
  }
}

class _EmployeeDetailView extends StatelessWidget {
  const _EmployeeDetailView({required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocBuilder<EmployeeDetailCubit, EmployeeDetailState>(
      builder: (context, state) {
        final cubit = context.read<EmployeeDetailCubit>();
        final employee = state.employee;

        return AppScaffold(
          title: l10n.employeeTitle,
          compactTitle: true,
          showBack: true,
          onBack: () => context.go(AppRoutes.employees),
          body: AsyncDataView<Employee>(
            status: state.status,
            data: employee,
            failure: state.failure,
            onRetry: () => cubit.load(employeeId),
            loadingView: const SkeletonDetail(hasActions: false),
            builder: (_, employee) => _ProfileBody(
              employee: employee,
              state: state,
              employeeId: employeeId,
            ),
          ),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.employee,
    required this.state,
    required this.employeeId,
  });

  final Employee employee;
  final EmployeeDetailState state;
  final int employeeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<EmployeeDetailCubit>();

    return AppPageBody(
      onRefresh: () => cubit.load(employeeId, refresh: true),
      children: <Widget>[
        _ProfileCard(employee: employee),
        _HoldingSummary(state: state),

        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xxs,
            top: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.employeeAssignedAssets,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                l10n.employeeItemCount(state.assets.length),
                style: theme.textTheme.bodySmall,
              ),
              // The way through to the paginated list.
              //
              // `EmployeeAssetsPage` has been paginated since it was written
              // and had nothing anywhere in the product that opened it: this
              // screen read a single capped page of a hundred and stopped, so
              // a pool account holding more than that simply had the rest of
              // its assets missing, with no control anywhere that hinted at
              // them. The route existed; only the link did not.
              if (state.hasMoreAssets) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                AppTextAction(
                  label: l10n.actionSeeAll,
                  onPressed: () =>
                      context.go(AppRoutes.employeeAssetsPath(employeeId)),
                ),
              ],
            ],
          ),
        ),

        if (state.isLoadingAssets)
          const SkeletonListRow()
        else if (state.assets.isEmpty)
          _NothingAssigned()
        else
          for (final asset in state.assets)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: AssetRow(
                asset: asset,
                showWarranty: false,
                showHolder: false,
                onTap: () => context.go(AppRoutes.assetDetailPath(asset.id)),
                trailing: StatusChip(
                  status: asset.status,
                  isLocal: asset.isStatusLocal,
                  dense: true,
                ),
              ),
            ),
      ],
    );
  }
}

/// Avatar, name, role, department and the two contact actions.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.employee});

  final Employee employee;

  /// Opens a `mailto:` / `tel:` URL.
  ///
  /// A device with no mail or dialler app is a real configuration — a tablet
  /// kiosk, a Wi-Fi-only tablet, an emulator — so the failure is reported to
  /// the user rather than swallowed into a button that appears to do nothing.
  ///
  /// The message names *which* handler is missing. It used to be
  /// `errorUnknownTitle` — "Something went wrong" — on a button the user had
  /// deliberately pressed, which tells them neither what failed nor that the
  /// answer is "this tablet has no mail app and never will". The scheme is
  /// already in hand at the call site, so there is nothing to guess.
  static Future<void> _launch(BuildContext context, Uri uri) async {
    final l10n = AppL10n.of(context);
    final message = uri.scheme == _telScheme
        ? l10n.launchNoPhoneApp
        : l10n.launchNoMailApp;

    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) AppSnack.info(context, message);
    } on Object catch (error) {
      // Sanitised: the URI carries the employee's own address or number.
      AppLogger.warn('Could not launch a ${uri.scheme}: URL — $error');
      if (context.mounted) AppSnack.info(context, message);
    }
  }

  static const String _telScheme = 'tel';
  static const String _mailScheme = 'mailto';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return AppCard(
      radius: AppRadii.xl,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppMediaRow(
            gap: AppSpacing.lg,
            leading: AppAvatar(
              name: employee.name,
              size: AppDimens.avatarXl,
              emphasised: true,
            ),
            children: <Widget>[
              Text(
                employee.name,
                style: theme.textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (employee.role != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  employee.role!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (employee.department != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                AppChip.neutral(
                  label: employee.department!.name,
                  icon: Icons.apartment_rounded,
                  dense: true,
                ),
              ],
            ],
          ),
          if (employee.hasEmail || employee.hasPhone) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                if (employee.hasEmail)
                  Expanded(
                    child: AppButton.outlined(
                      label: l10n.actionEmail,
                      icon: Icons.mail_outline_rounded,
                      isCompact: true,
                      onPressed: () => _launch(
                        context,
                        Uri(scheme: _mailScheme, path: employee.workEmail),
                      ),
                    ),
                  ),
                if (employee.hasEmail && employee.hasPhone)
                  const SizedBox(width: AppSpacing.gridGap),
                if (employee.hasPhone)
                  Expanded(
                    child: AppButton.outlined(
                      label: l10n.actionCall,
                      icon: Icons.call_outlined,
                      isCompact: true,
                      onPressed: () => _launch(
                        context,
                        Uri(
                          scheme: _telScheme,
                          path: employee.callableNumber!.replaceAll(' ', ''),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Held / in service / warranty due.
class _HoldingSummary extends StatelessWidget {
  const _HoldingSummary({required this.state});

  final EmployeeDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppStatGrid(
      tiles: <Widget>[
        AppStatTile(
          value: AppNumber.count(context, state.heldCount),
          label: l10n.employeeAssetsHeld,
          icon: Icons.inventory_2_outlined,
        ),
        AppStatTile(
          value: AppNumber.count(context, state.inServiceCount),
          label: l10n.employeeInService,
          tone: AppColors.statusAvailable,
        ),
        AppStatTile(
          value: AppNumber.count(context, state.warrantyDueCount),
          label: l10n.employeeWarrantyDue,
          tone: AppColors.warning,
        ),
      ],
    );
  }
}

class _NothingAssigned extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return AppCard(
      child: AppMediaRow(
        leading: Icon(
          Icons.inbox_rounded,
          size: AppDimens.iconXl,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: <Widget>[
          Text(
            l10n.emptyEmployeeAssetsTitle,
            style: theme.textTheme.titleSmall,
          ),
          Text(l10n.emptyEmployeeAssetsBody, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
