import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_data_views.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/state_views.dart';
import '../cubit/assign_asset_cubit.dart';
import '../widgets/workflow_asset_strip.dart';

/// Hands an asset to an employee (spec §7).
class AssignAssetPage extends StatelessWidget {
  const AssignAssetPage({required this.assetId, super.key});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssignAssetCubit>(
      create: (_) => sl<AssignAssetCubit>()..start(assetId),
      child: _AssignAssetView(assetId: assetId),
    );
  }
}

class _AssignAssetView extends StatefulWidget {
  const _AssignAssetView({required this.assetId});

  final int assetId;

  @override
  State<_AssignAssetView> createState() => _AssignAssetViewState();
}

class _AssignAssetViewState extends State<_AssignAssetView> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _close() => context.go(AppRoutes.assetDetailPath(widget.assetId));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocConsumer<AssignAssetCubit, AssignAssetState>(
      listenWhen: (previous, current) =>
          previous.assigned != current.assigned ||
          previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null && state.asset != null) {
          AppSnack.failure(context, failure);
          context.read<AssignAssetCubit>().acknowledgeFailure();
          return;
        }

        final assigned = state.assigned;
        if (assigned != null) {
          AppSnack.success(
            context,
            l10n.assignSuccess(assigned.name, state.selected?.name ?? ''),
          );
          _close();
        }
      },
      builder: (context, state) {
        final cubit = context.read<AssignAssetCubit>();

        return AppScaffold(
          title: l10n.assignTitle,
          compactTitle: true,
          leading: AppIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.actionClose,
            bordered: false,
            onPressed: _close,
          ),
          bottomBar: state.asset == null
              ? null
              : AppButton(
                  label: l10n.assignConfirm,
                  icon: Icons.check_rounded,
                  isBusy: state.isSubmitting,
                  onPressed: state.canSubmit ? cubit.submit : null,
                ),
          body: switch (state) {
            _ when state.isLoading && state.asset == null =>
              const SkeletonList(),
            _ when state.hasFailed && state.asset == null => FailureView(
              failure: state.failure!,
              onRetry: () => cubit.start(widget.assetId),
            ),
            _ when state.asset == null => const SizedBox.shrink(),
            _ => _AssignForm(state: state, search: _search, notes: _notes),
          },
        );
      },
    );
  }
}

class _AssignForm extends StatelessWidget {
  const _AssignForm({
    required this.state,
    required this.search,
    required this.notes,
  });

  final AssignAssetState state;
  final TextEditingController search;
  final TextEditingController notes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssignAssetCubit>();

    return AppPageBody(
      gap: AppSpacing.sm,
      children: <Widget>[
        WorkflowAssetStrip(asset: state.asset!),
        const SizedBox(height: AppSpacing.sm),

        AppStepHeader(step: 1, title: l10n.assignStepEmployee),
        AppSearchField(
          controller: search,
          hint: l10n.assignSearchHint,
          onChanged: cubit.searchEmployees,
          onClear: () => cubit.searchEmployees(''),
        ),
        _EmployeeResults(state: state),

        const SizedBox(height: AppSpacing.sm),
        AppStepHeader(step: 2, title: l10n.assignStepDate),
        WorkflowDateField(
          label: l10n.assignStepDate,
          showLabel: false,
          value: state.assignedOn,
          onChanged: cubit.setDate,
        ),

        const SizedBox(height: AppSpacing.sm),
        AppStepHeader(
          step: 3,
          title: l10n.assignStepNotes,
          trailing: l10n.labelOptional,
          isActive: false,
        ),
        AppTextField(
          label: l10n.assignStepNotes,
          showLabel: false,
          controller: notes,
          hint: l10n.assignNotesHint,
          maxLines: 3,
          onChanged: cubit.setNotes,
        ),
      ],
    );
  }
}

/// The typeahead results, or the reason there are none.
class _EmployeeResults extends StatelessWidget {
  const _EmployeeResults({required this.state});

  final AssignAssetState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssignAssetCubit>();

    if (state.isSearching && state.candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.md),
        child: SkeletonBox(height: AppDimens.skeletonRowHeight),
      );
    }

    if (state.candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
        child: Text(
          l10n.emptyEmployeesTitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final employee in state.candidates)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: AppSelectableTile(
              title: employee.name,
              subtitle: employee.summary,
              caption: employee.workEmail,
              selected: state.selected?.id == employee.id,
              onTap: () => cubit.selectEmployee(employee),
            ),
          ),
      ],
    );
  }
}
