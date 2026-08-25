import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/utils/l10n_lookup.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/state_views.dart';
import '../cubit/asset_form_cubit.dart';

/// Creates or edits an asset (spec §14).
///
/// One screen for both: the fields are identical, and the only difference is
/// whether the draft starts blank or from an existing record.
class AssetFormPage extends StatelessWidget {
  const AssetFormPage({required this.assetId, super.key});

  /// Null creates; an id edits.
  final int? assetId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssetFormCubit>(
      create: (_) => sl<AssetFormCubit>()..start(assetId),
      child: _AssetFormView(assetId: assetId),
    );
  }
}

class _AssetFormView extends StatefulWidget {
  const _AssetFormView({required this.assetId});

  final int? assetId;

  @override
  State<_AssetFormView> createState() => _AssetFormViewState();
}

class _AssetFormViewState extends State<_AssetFormView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _tag = TextEditingController();
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  /// Filled once, when the draft first arrives.
  ///
  /// The controllers are the source of truth for what the user is typing;
  /// pushing every Cubit state back into them would move the caret to the end
  /// on every keystroke.
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    _serial.dispose();
    _model.dispose();
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _seed(AssetFormState state) {
    if (_seeded || !state.isEdit) return;
    _seeded = true;

    final draft = state.draft;
    _name.text = draft.name;
    _tag.text = draft.assetTag ?? '';
    _serial.text = draft.serialNumber ?? '';
    _model.text = draft.model ?? '';
    _notes.text = draft.notes ?? '';
    final purchaseValue = draft.purchaseValue;
    _value.text = (purchaseValue == null || purchaseValue == 0)
        ? ''
        : purchaseValue.toStringAsFixed(2);
  }

  void _close() {
    final id = widget.assetId;
    context.go(id == null ? AppRoutes.assets : AppRoutes.assetDetailPath(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocConsumer<AssetFormCubit, AssetFormState>(
      listenWhen: (previous, current) =>
          previous.saved != current.saved ||
          previous.failure != current.failure ||
          previous.draft != current.draft,
      listener: (context, state) {
        _seed(state);

        final failure = state.failure;
        if (failure != null && state.status != ViewStatus.failure) {
          AppSnack.failure(context, failure);
          context.read<AssetFormCubit>().acknowledgeFailure();
          return;
        }

        final saved = state.saved;
        if (saved != null) {
          AppSnack.success(context, l10n.assetSaved(saved.name));
          context.go(AppRoutes.assetDetailPath(saved.id));
        }
      },
      builder: (context, state) {
        final cubit = context.read<AssetFormCubit>();

        return AppScaffold(
          title: state.isEdit ? l10n.assetEditTitle : l10n.assetNewTitle,
          compactTitle: true,
          leading: AppIconButton(
            icon: Icons.close_rounded,
            tooltip: l10n.actionClose,
            bordered: false,
            onPressed: _close,
          ),
          bottomBar: AppButton(
            label: l10n.actionSave,
            icon: Icons.check_rounded,
            isBusy: state.isSubmitting,
            onPressed: state.canSubmit ? cubit.submit : null,
          ),
          body: switch (state) {
            _ when state.isLoading => const SkeletonList(),
            _ when state.hasFailed && state.draft.name.isEmpty => FailureView(
              failure: state.failure!,
              onRetry: () => cubit.start(widget.assetId),
            ),
            _ => _FormFields(
              state: state,
              name: _name,
              tag: _tag,
              serial: _serial,
              model: _model,
              value: _value,
              notes: _notes,
            ),
          },
        );
      },
    );
  }
}

class _FormFields extends StatelessWidget {
  const _FormFields({
    required this.state,
    required this.name,
    required this.tag,
    required this.serial,
    required this.model,
    required this.value,
    required this.notes,
  });

  final AssetFormState state;
  final TextEditingController name;
  final TextEditingController tag;
  final TextEditingController serial;
  final TextEditingController model;
  final TextEditingController value;
  final TextEditingController notes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cubit = context.read<AssetFormCubit>();
    final draft = state.draft;

    final category = state.categories
        .where((c) => c.id == draft.categoryId)
        .map((c) => c.name)
        .firstOrNull;

    return AppPageBody(
      gap: AppSpacing.lg,
      children: <Widget>[
        AppTextField(
          label: l10n.labelAssetName,
          controller: name,
          hint: l10n.labelAssetName,
          errorText: l10n.lookup(state.nameError),
          textInputAction: TextInputAction.next,
          onChanged: cubit.editName,
        ),
        AppTextField(
          label: l10n.labelAssetTag,
          controller: tag,
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          onChanged: cubit.editTag,
        ),
        AppTextField(
          label: l10n.labelSerialNumber,
          controller: serial,
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          onChanged: cubit.editSerial,
        ),
        AppTextField(
          label: l10n.labelModel,
          controller: model,
          textInputAction: TextInputAction.next,
          onChanged: cubit.editModel,
        ),

        if (state.categories.isNotEmpty)
          AppPickerField(
            label: l10n.labelCategory,
            value: category ?? l10n.labelNone,
            icon: Icons.category_outlined,
            onTap: () async {
              final picked = await AppOptionSheet.show<int>(
                context,
                title: l10n.filterCategory,
                selected: draft.categoryId,
                options: <AppSheetOption<int>>[
                  for (final option in state.categories)
                    AppSheetOption<int>(value: option.id, label: option.name),
                ],
              );
              if (picked != null) cubit.editCategory(picked);
            },
          ),

        AppPickerField(
          label: l10n.labelPurchaseDate,
          value: draft.purchaseDate == null
              ? l10n.labelNone
              : context.dates.dayLong(draft.purchaseDate),
          icon: Icons.calendar_month_rounded,
          onTap: () async {
            final picked = await AppDatePicker.show(
              context,
              initial: draft.purchaseDate,
            );
            if (picked != null) cubit.editPurchaseDate(picked);
          },
        ),

        AppTextField(
          label: l10n.labelPurchaseValue,
          controller: value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          // Digits plus one separator: Odoo takes a float, and letting a comma
          // and a dot both through is what makes the field work in Arabic and
          // English locales without a locale-aware parser.
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: cubit.editPurchaseValue,
        ),

        AppPickerField(
          label: l10n.sectionWarranty,
          value: draft.warrantyEnd == null
              ? l10n.labelNone
              : context.dates.dayLong(draft.warrantyEnd),
          icon: Icons.shield_outlined,
          onTap: () async {
            final picked = await AppDatePicker.show(
              context,
              initial: draft.warrantyEnd,
            );
            if (picked != null) cubit.editWarrantyEnd(picked);
          },
        ),

        AppTextField(
          label: l10n.labelNotes,
          controller: notes,
          maxLines: 3,
          onChanged: cubit.editNotes,
        ),
      ],
    );
  }
}
