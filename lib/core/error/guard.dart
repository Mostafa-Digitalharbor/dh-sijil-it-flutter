import 'package:dartz/dartz.dart';

import '../utils/logger.dart';
import '../utils/typedefs.dart';
import 'error_mapper.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Turns thrown exceptions into `Either.left(Failure)` at the data boundary.
///
/// Every repository needs the identical five lines, and every repository had
/// written them out. Sharing it is not only less code — it is the only way to
/// guarantee that a new repository cannot forget the `on Object` arm and leak
/// a raw `TypeError` from a malformed Odoo row all the way to a Cubit, which
/// is the one failure mode that reaches the user as a blank screen instead of
/// a sentence.
mixin RepositoryGuard {
  /// Named in the log line when an unexpected error escapes, so a report says
  /// which repository produced it.
  String get guardLabel;

  ResultFuture<T> guard<T>(Future<T> Function() body) async {
    try {
      return Right<Failure, T>(await body());
    } on AppException catch (error, stackTrace) {
      return Left<Failure, T>(ErrorMapper.map(error, stackTrace));
    } on Object catch (error, stackTrace) {
      AppLogger.error('Unexpected $guardLabel error', error, stackTrace);
      return Left<Failure, T>(ErrorMapper.map(error, stackTrace));
    }
  }
}
