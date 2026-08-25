import 'package:equatable/equatable.dart';

import '../utils/typedefs.dart';

/// Template Method for a single unit of application behaviour.
///
/// One use case = one verb the product can perform. Cubits depend on use
/// cases, never on repositories directly, so business rules stay testable in
/// isolation from Flutter.
abstract class UseCase<T, Params> {
  const UseCase();

  ResultFuture<T> call(Params params);
}

/// Use case that needs no input.
abstract class UseCaseWithoutParams<T> {
  const UseCaseWithoutParams();

  ResultFuture<T> call();
}

/// Marker for a parameterless use case invoked through [UseCase].
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
