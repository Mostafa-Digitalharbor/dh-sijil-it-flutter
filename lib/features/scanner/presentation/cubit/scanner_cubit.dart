import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/usecases/asset_usecases.dart';

/// Which symbology the viewfinder is set to read (spec §13).
enum ScanMode { qr, barcode }

/// What the scanner screen renders.
class ScannerState extends ViewState {
  const ScannerState({
    super.status,
    super.failure,
    this.mode = ScanMode.qr,
    this.torchOn = false,
    this.isResolving = false,
    this.lastCode,
    this.match,
    this.unmatchedCode,
    this.isPermissionDenied = false,
  });

  final ScanMode mode;
  final bool torchOn;

  /// A lookup is in flight. The camera keeps running but detections are
  /// ignored, so one physical code cannot start three lookups.
  final bool isResolving;

  /// The most recent payload read, used to suppress duplicate detections.
  final String? lastCode;

  /// The asset the last scan resolved to.
  final Asset? match;

  /// A code that resolved to nothing — a legitimate outcome, not a failure.
  /// The screen offers to create an asset for it.
  final String? unmatchedCode;

  final bool isPermissionDenied;

  bool get hasResult => match != null || unmatchedCode != null;

  ScannerState copyWith({
    ViewStatus? status,
    ScanMode? mode,
    bool? torchOn,
    bool? isResolving,
    String? lastCode,
    Asset? match,
    String? unmatchedCode,
    bool? isPermissionDenied,
    Failure? failure,
    bool clearResult = false,
    bool clearFailure = false,
  }) => ScannerState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    mode: mode ?? this.mode,
    torchOn: torchOn ?? this.torchOn,
    isResolving: isResolving ?? this.isResolving,
    lastCode: clearResult ? null : (lastCode ?? this.lastCode),
    match: clearResult ? null : (match ?? this.match),
    unmatchedCode: clearResult ? null : (unmatchedCode ?? this.unmatchedCode),
    isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    mode,
    torchOn,
    isResolving,
    lastCode,
    match,
    unmatchedCode,
    isPermissionDenied,
  ];
}

/// The scanner's ViewModel (spec §13).
///
/// Owns only the *resolution* of a scanned payload. Starting the camera and
/// reading frames belongs to the `mobile_scanner` widget; keeping that out of
/// here is what lets the whole lookup path be tested without a camera.
class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit(this._resolveCode) : super(const ScannerState());

  final ResolveScannedCode _resolveCode;

  /// Handles one detection from the camera.
  ///
  /// Ignores a repeat of the code already on screen: a scanner fires many
  /// times a second while a code is in frame, and without this the same asset
  /// would be looked up on every frame.
  Future<void> onDetected(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || state.isResolving) return;
    if (trimmed == state.lastCode && state.hasResult) return;

    emit(
      state.copyWith(isResolving: true, clearResult: true, clearFailure: true),
    );

    final result = await _resolveCode(trimmed);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(
          isResolving: false,
          status: ViewStatus.failure,
          failure: failure,
          lastCode: trimmed,
        ),
        (asset) => state.copyWith(
          isResolving: false,
          status: ViewStatus.success,
          lastCode: trimmed,
          match: asset,
          unmatchedCode: asset == null ? trimmed : null,
          clearFailure: true,
        ),
      ),
    );
  }

  void setMode(ScanMode mode) =>
      emit(state.copyWith(mode: mode, clearResult: true));

  void toggleTorch() => emit(state.copyWith(torchOn: !state.torchOn));

  /// Clears the result sheet so the next code is read fresh.
  void reset() => emit(state.copyWith(clearResult: true, clearFailure: true));

  void reportPermissionDenied() =>
      emit(state.copyWith(isPermissionDenied: true));

  void reportPermissionGranted() =>
      emit(state.copyWith(isPermissionDenied: false));
}
