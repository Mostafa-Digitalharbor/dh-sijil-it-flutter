import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/record_photo.dart';
import '../repositories/attachment_repository.dart';

/// Identifies an Odoo record without naming which feature owns it.
class RecordRef extends Equatable {
  const RecordRef({required this.model, required this.id});

  final String model;
  final int id;

  @override
  List<Object?> get props => <Object?>[model, id];
}

class AddPhotoParams extends Equatable {
  const AddPhotoParams({
    required this.model,
    required this.recordId,
    required this.path,
  });

  final String model;
  final int recordId;

  /// Absolute path from the picker.
  final String path;

  @override
  List<Object?> get props => <Object?>[model, recordId, path];
}

class AddPhotoBytesParams extends Equatable {
  const AddPhotoBytesParams({
    required this.model,
    required this.recordId,
    required this.filename,
    required this.data,
  });

  final String model;
  final int recordId;
  final String filename;
  final Uint8List data;

  @override
  List<Object?> get props => <Object?>[model, recordId, filename, data.length];
}

class GetRecordPhotos extends UseCase<List<RecordPhoto>, RecordRef> {
  const GetRecordPhotos(this._repository);

  final AttachmentRepository _repository;

  @override
  ResultFuture<List<RecordPhoto>> call(RecordRef params) =>
      _repository.photosFor(model: params.model, recordId: params.id);
}

class LoadPhotoData extends UseCase<Uint8List?, int> {
  const LoadPhotoData(this._repository);

  final AttachmentRepository _repository;

  @override
  ResultFuture<Uint8List?> call(int params) => _repository.load(params);
}

class AddRecordPhoto extends UseCase<RecordPhoto, AddPhotoParams> {
  const AddRecordPhoto(this._repository);

  final AttachmentRepository _repository;

  @override
  ResultFuture<RecordPhoto> call(AddPhotoParams params) => _repository.addFile(
    model: params.model,
    recordId: params.recordId,
    path: params.path,
  );
}

/// Uploads bytes the app produced rather than a file the user picked — the
/// captured handover signature.
class AddRecordPhotoBytes extends UseCase<RecordPhoto, AddPhotoBytesParams> {
  const AddRecordPhotoBytes(this._repository);

  final AttachmentRepository _repository;

  @override
  ResultFuture<RecordPhoto> call(AddPhotoBytesParams params) =>
      _repository.addBytes(
        model: params.model,
        recordId: params.recordId,
        filename: params.filename,
        data: params.data,
      );
}

class RemoveRecordPhoto extends UseCase<void, int> {
  const RemoveRecordPhoto(this._repository);

  final AttachmentRepository _repository;

  @override
  ResultFuture<void> call(int params) => _repository.remove(params);
}
