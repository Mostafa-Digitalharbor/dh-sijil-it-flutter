import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_draft.dart';
import '../../domain/usecases/asset_usecases.dart';

/// Validation keys the form publishes.
///
/// Keys, not sentences: the Cubit decides *what* is wrong and the widget layer
/// turns it into words through `L10nLookup`, so a Cubit test asserts on a
/// stable identifier rather than on English a translator may later reword.
abstract final class AssetFormValidation {
  static const String nameRequired = 'validationEnterAssetName';

  const AssetFormValidation._();
}

/// What the create/edit form renders (spec §14).
class AssetFormState extends ViewState {
  const AssetFormState({
    super.status,
    super.failure,
    this.draft = const AssetDraft(),
    this.categories = const <OdooNameRef>[],
    this.isSubmitting = false,
    this.nameError,
    this.saved,
  });

  final AssetDraft draft;
  final List<OdooNameRef> categories;
  final bool isSubmitting;

  /// Validation key for the name field, or null when it is valid.
  final String? nameError;

  /// Set once the save succeeds, carrying the record Odoo returned so the
  /// caller can adopt it without re-reading.
  final Asset? saved;

  bool get isEdit => draft.isEdit;

  bool get canSubmit => draft.isValid && !isSubmitting;

  AssetFormState copyWith({
    ViewStatus? status,
    AssetDraft? draft,
    List<OdooNameRef>? categories,
    bool? isSubmitting,
    String? nameError,
    Asset? saved,
    Failure? failure,
    bool clearNameError = false,
    bool clearFailure = false,
  }) => AssetFormState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    draft: draft ?? this.draft,
    categories: categories ?? this.categories,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    nameError: clearNameError ? null : (nameError ?? this.nameError),
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    draft,
    categories,
    isSubmitting,
    nameError,
    saved,
  ];
}

/// The create/edit form's ViewModel.
class AssetFormCubit extends Cubit<AssetFormState> {
  AssetFormCubit({
    required GetAsset getAsset,
    required CreateAsset createAsset,
    required UpdateAsset updateAsset,
    required GetAssetListOptions getOptions,
  }) : _getAsset = getAsset,
       _createAsset = createAsset,
       _updateAsset = updateAsset,
       _getOptions = getOptions,
       super(const AssetFormState());

  final GetAsset _getAsset;
  final CreateAsset _createAsset;
  final UpdateAsset _updateAsset;
  final GetAssetListOptions _getOptions;

  /// Prepares the form. A null [assetId] opens a blank create form.
  Future<void> start(int? assetId) async {
    emit(state.copyWith(status: ViewStatus.loading, clearFailure: true));

    await _loadCategories();

    if (assetId == null) {
      emit(state.copyWith(status: ViewStatus.success));
      return;
    }

    final result = await _getAsset(assetId);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: ViewStatus.failure, failure: failure),
        (asset) => state.copyWith(
          status: ViewStatus.success,
          draft: AssetDraft.from(asset),
          clearFailure: true,
        ),
      ),
    );
  }

  void editName(String value) => emit(
    state.copyWith(
      draft: state.draft.copyWith(name: value),
      // Clearing as the user types is the whole reason the error is a field
      // rather than a snackbar: it disappears the moment it stops being true.
      clearNameError: value.trim().isNotEmpty,
    ),
  );

  void editSerial(String value) =>
      emit(state.copyWith(draft: state.draft.copyWith(serialNumber: value)));

  void editModel(String value) =>
      emit(state.copyWith(draft: state.draft.copyWith(model: value)));

  void editTag(String value) =>
      emit(state.copyWith(draft: state.draft.copyWith(assetTag: value)));

  void editNotes(String value) =>
      emit(state.copyWith(draft: state.draft.copyWith(notes: value)));

  void editCategory(int? categoryId) => emit(
    state.copyWith(
      draft: categoryId == null
          ? state.draft.copyWith(clearCategory: true)
          : state.draft.copyWith(categoryId: categoryId),
    ),
  );

  void editPurchaseDate(DateTime? value) => emit(
    state.copyWith(
      draft: value == null
          ? state.draft.copyWith(clearPurchaseDate: true)
          : state.draft.copyWith(purchaseDate: value),
    ),
  );

  void editWarrantyEnd(DateTime? value) => emit(
    state.copyWith(
      draft: value == null
          ? state.draft.copyWith(clearWarrantyEnd: true)
          : state.draft.copyWith(warrantyEnd: value),
    ),
  );

  /// Parses the typed purchase value.
  ///
  /// A number the device cannot parse leaves the previous value alone rather
  /// than silently becoming zero — an asset quietly worth nothing because of a
  /// stray keystroke is worse than one that ignores it.
  void editPurchaseValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(draft: state.draft.copyWith(purchaseValue: 0)));
      return;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) return;
    emit(state.copyWith(draft: state.draft.copyWith(purchaseValue: parsed)));
  }

  Future<void> submit() async {
    if (state.isSubmitting) return;

    if (!state.draft.isValid) {
      emit(state.copyWith(nameError: AssetFormValidation.nameRequired));
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearNameError: true,
      ),
    );

    final result = state.isEdit
        ? await _updateAsset(state.draft)
        : await _createAsset(state.draft);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (asset) => state.copyWith(isSubmitting: false, saved: asset),
      ),
    );
  }

  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));

  Future<void> _loadCategories() async {
    final result = await _getOptions();
    if (isClosed) return;
    result.fold(
      (_) {},
      (options) => emit(state.copyWith(categories: options.categories)),
    );
  }
}
