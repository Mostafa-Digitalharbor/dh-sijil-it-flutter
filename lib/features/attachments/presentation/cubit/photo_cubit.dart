import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/photo_picker.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/record_photo.dart';
import '../../domain/usecases/attachment_usecases.dart';

/// What just happened to the photo set, for the one-line confirmation.
///
/// A signal of its own rather than something the widget infers from the list
/// growing or shrinking: a rebuild caused by anything else would re-announce
/// it, and a photo that arrives from a refresh is not something the user did.
///
/// It mirrors how [PhotoState.failure] works — raised by the Cubit, shown
/// once, then acknowledged — so both halves of "tell the user what happened"
/// have the same shape.
enum PhotoOutcome { added, removed }

/// What the photo section renders.
class PhotoState extends ViewState {
  const PhotoState({
    super.status,
    super.failure,
    this.photos = const <RecordPhoto>[],
    this.isUploading = false,
    this.busyId,
    this.outcome,
  });

  final List<RecordPhoto> photos;

  /// An upload is in flight. The add tile shows a spinner rather than
  /// disappearing, so the row does not reflow under the user's finger.
  final bool isUploading;

  /// The photo currently being deleted, if any.
  final int? busyId;

  /// Set for exactly one rebuild after a successful add or remove.
  final PhotoOutcome? outcome;

  bool get isEmpty => photos.isEmpty;
  int get count => photos.length;

  PhotoState copyWith({
    ViewStatus? status,
    Failure? failure,
    List<RecordPhoto>? photos,
    bool? isUploading,
    int? busyId,
    PhotoOutcome? outcome,
    bool clearBusy = false,
    bool clearFailure = false,
    bool clearOutcome = false,
  }) {
    return PhotoState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      photos: photos ?? this.photos,
      isUploading: isUploading ?? this.isUploading,
      busyId: clearBusy ? null : (busyId ?? this.busyId),
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    ...super.props,
    photos,
    isUploading,
    busyId,
    outcome,
  ];
}

/// ViewModel for the photographs on one Odoo record.
///
/// Model-agnostic on purpose: an asset and a maintenance request differ only
/// in the model string, so one Cubit serves both and there is a single place
/// where "uploading a photo" is defined.
///
/// Image data is fetched **per photo, after the list arrives**. Listing is one
/// cheap call; the bytes are megabytes each. Loading them lazily is what keeps
/// opening a repair with six photos from stalling on a server-room connection.
class PhotoCubit extends Cubit<PhotoState> {
  PhotoCubit({
    required String model,
    required int recordId,
    required GetRecordPhotos getPhotos,
    required LoadPhotoData loadData,
    required AddRecordPhoto addPhoto,
    required RemoveRecordPhoto removePhoto,
    required PhotoPicker picker,
    this.canEdit = true,
  }) : _model = model,
       _recordId = recordId,
       _getPhotos = getPhotos,
       _loadData = loadData,
       _addPhoto = addPhoto,
       _removePhoto = removePhoto,
       _picker = picker,
       super(const PhotoState());

  final String _model;
  final int _recordId;
  final GetRecordPhotos _getPhotos;
  final LoadPhotoData _loadData;
  final AddRecordPhoto _addPhoto;
  final RemoveRecordPhoto _removePhoto;
  final PhotoPicker _picker;

  /// Hides the add and remove controls when the user's ACLs forbid writing —
  /// better than offering a button that fails on tap.
  final bool canEdit;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, clearFailure: true));

    final result = await _getPhotos(RecordRef(model: _model, id: _recordId));

    result.fold(
      (failure) =>
          emit(state.copyWith(status: ViewStatus.failure, failure: failure)),
      (photos) {
        emit(state.copyWith(status: ViewStatus.success, photos: photos));
        for (final photo in photos) {
          unawaited(_hydrate(photo.id));
        }
      },
    );
  }

  /// Pulls one photo's bytes and swaps it into the list in place.
  ///
  /// A failure here is deliberately silent: the tile keeps its placeholder.
  /// One unreadable thumbnail is not worth an error banner over a screen whose
  /// actual content — the repair, the asset — loaded fine.
  Future<void> _hydrate(int photoId) async {
    final result = await _loadData(photoId);

    result.fold((_) {}, (bytes) {
      if (bytes == null || isClosed) return;
      emit(
        state.copyWith(
          photos: <RecordPhoto>[
            for (final photo in state.photos)
              if (photo.id == photoId) photo.withBytes(bytes) else photo,
          ],
        ),
      );
    });
  }

  Future<void> add(PhotoSource source) async {
    if (!canEdit || state.isUploading) return;

    final path = await _picker.pick(source);
    // Backing out of the camera is not an error and must not produce one.
    if (path == null || isClosed) return;

    emit(
      state.copyWith(isUploading: true, clearFailure: true, clearOutcome: true),
    );

    final result = await _addPhoto(
      AddPhotoParams(model: _model, recordId: _recordId, path: path),
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(
          isUploading: false,
          status: ViewStatus.failure,
          failure: failure,
        ),
        (photo) => state.copyWith(
          isUploading: false,
          status: ViewStatus.success,
          outcome: PhotoOutcome.added,
          // Newest first, matching the order the list call returns.
          photos: <RecordPhoto>[photo, ...state.photos],
        ),
      ),
    );
  }

  Future<void> remove(int photoId) async {
    if (!canEdit || state.busyId != null) return;

    emit(
      state.copyWith(busyId: photoId, clearFailure: true, clearOutcome: true),
    );
    final result = await _removePhoto(photoId);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(
          clearBusy: true,
          status: ViewStatus.failure,
          failure: failure,
        ),
        (_) => state.copyWith(
          clearBusy: true,
          status: ViewStatus.success,
          outcome: PhotoOutcome.removed,
          photos: state.photos
              .where((photo) => photo.id != photoId)
              .toList(growable: false),
        ),
      ),
    );
  }

  /// Clears a failure the UI has already shown, so the next rebuild does not
  /// re-raise the same snackbar.
  void acknowledgeFailure() {
    if (state.failure == null) return;
    emit(state.copyWith(status: ViewStatus.success, clearFailure: true));
  }

  /// Clears an outcome the UI has already confirmed, so the next rebuild does
  /// not repeat the snackbar.
  void acknowledgeOutcome() {
    if (state.outcome == null) return;
    emit(state.copyWith(clearOutcome: true));
  }
}
