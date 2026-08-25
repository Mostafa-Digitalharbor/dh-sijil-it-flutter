import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/handover.dart';
import '../repositories/handover_repository.dart';

/// Records a signed handover of several assets to one person.
class SubmitHandover extends UseCase<HandoverReceipt, HandoverBundle> {
  const SubmitHandover(this._repository);

  final HandoverRepository _repository;

  @override
  ResultFuture<HandoverReceipt> call(HandoverBundle params) =>
      _repository.submit(params);
}
