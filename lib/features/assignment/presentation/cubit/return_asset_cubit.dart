import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../../assets/domain/usecases/asset_usecases.dart';
import '../../domain/entities/assignment.dart';

/// What the return-asset screen renders (spec §8).
class ReturnAssetState extends ViewState {
  const ReturnAssetState({
    super.status,
    super.failure,
    this.asset,
    this.condition = ReturnCondition.good,
    this.returnedOn,
    this.notes,
    this.photoPaths = const <String>[],
    this.isSubmitting = false,
    this.returned,
  });

  final Asset? asset;

  /// Good is the default because it is the common case; the other three are
  /// deliberate choices the user makes.
  final ReturnCondition condition;

  final DateTime? returnedOn;
  final String? notes;
  final List<String> photoPaths;
  final bool isSubmitting;

  /// The updated asset, set once the return succeeds.
  final Asset? returned;

  bool get canSubmit => returnedOn != null && !isSubmitting;

  bool get canAddPhoto => photoPaths.length < ReturnRequest.maxPhotos;

  /// Where the asset lands, so the sticky footer can say so before the user
  /// commits rather than after.
  AssetStatus get resultingStatus => condition.resultingStatus;

  ReturnAssetState copyWith({
    ViewStatus? status,
    Asset? asset,
    ReturnCondition? condition,
    DateTime? returnedOn,
    String? notes,
    List<String>? photoPaths,
    bool? isSubmitting,
    Asset? returned,
    Failure? failure,
    bool clearFailure = false,
  }) => ReturnAssetState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    asset: asset ?? this.asset,
    condition: condition ?? this.condition,
    returnedOn: returnedOn ?? this.returnedOn,
    notes: notes ?? this.notes,
    photoPaths: photoPaths ?? this.photoPaths,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    returned: returned ?? this.returned,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    asset,
    condition,
    returnedOn,
    notes,
    photoPaths,
    isSubmitting,
    returned,
  ];
}

/// The return-asset workflow's ViewModel.
class ReturnAssetCubit extends Cubit<ReturnAssetState> {
  ReturnAssetCubit({
    required GetAsset getAsset,
    required ReturnAsset returnAsset,
    DateTime Function()? clock,
  }) : _getAsset = getAsset,
       _returnAsset = returnAsset,
       _now = clock ?? DateTime.now,
       super(const ReturnAssetState());

  final GetAsset _getAsset;
  final ReturnAsset _returnAsset;
  final DateTime Function() _now;

  Future<void> start(int assetId) async {
    emit(
      ReturnAssetState(status: ViewStatus.loading, returnedOn: _startOfToday()),
    );

    final result = await _getAsset(assetId);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: ViewStatus.failure, failure: failure),
        (asset) => state.copyWith(status: ViewStatus.success, asset: asset),
      ),
    );
  }

  void setCondition(ReturnCondition condition) =>
      emit(state.copyWith(condition: condition));

  void setDate(DateTime date) => emit(state.copyWith(returnedOn: date));

  void setNotes(String notes) => emit(state.copyWith(notes: notes));

  void addPhoto(String path) {
    if (!state.canAddPhoto || state.photoPaths.contains(path)) return;
    emit(state.copyWith(photoPaths: [...state.photoPaths, path]));
  }

  void removePhoto(String path) => emit(
    state.copyWith(
      photoPaths: state.photoPaths.where((p) => p != path).toList(),
    ),
  );

  Future<void> submit() async {
    final asset = state.asset;
    final date = state.returnedOn;
    if (asset == null || date == null || state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _returnAsset(
      ReturnRequest(
        assetId: asset.id,
        condition: state.condition,
        returnedOn: date,
        employeeName: asset.assignedEmployee?.name,
        notes: state.notes,
        photoPaths: state.photoPaths,
      ),
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (updated) => state.copyWith(isSubmitting: false, returned: updated),
      ),
    );
  }

  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));

  DateTime _startOfToday() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }
}
