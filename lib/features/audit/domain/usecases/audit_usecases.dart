import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assets/domain/entities/asset.dart';
import '../entities/audit_session.dart';
import '../repositories/audit_repository.dart';

class AuditScopeParams extends Equatable {
  const AuditScopeParams({
    required this.scope,
    this.categoryId,
    this.departmentId,
    this.label,
  });

  final AuditScope scope;
  final int? categoryId;
  final int? departmentId;

  /// Human name of the scope, carried into the session so the chatter note
  /// says what was being counted rather than an id.
  final String? label;

  @override
  List<Object?> get props => <Object?>[scope, categoryId, departmentId, label];
}

/// Reads the set the audit expects to find.
class StartAudit extends UseCase<List<Asset>, AuditScopeParams> {
  const StartAudit(this._repository);

  final AuditRepository _repository;

  @override
  ResultFuture<List<Asset>> call(AuditScopeParams params) =>
      _repository.expectedFor(
        scope: params.scope,
        categoryId: params.categoryId,
        departmentId: params.departmentId,
      );
}

/// Writes the findings to Odoo.
class CommitAudit extends UseCase<int, AuditSession> {
  const CommitAudit(this._repository);

  final AuditRepository _repository;

  @override
  ResultFuture<int> call(AuditSession params) => _repository.commit(params);
}
