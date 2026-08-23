import 'package:equatable/equatable.dart';

/// A user-facing, sanitized description of something that went wrong.
///
/// Repositories return `Either<Failure, T>`; Cubits render [userMessage] and
/// never inspect the underlying exception.
sealed class Failure extends Equatable {
  const Failure({
    required this.userMessage,
    this.technicalDetails,
    this.isRetryable = false,
  });

  /// Safe to show in the UI. Contains no credentials, URLs or stack traces.
  final String userMessage;

  /// Shown only inside Settings → Debug log.
  final String? technicalDetails;

  /// Whether offering a "Retry" action makes sense.
  final bool isRetryable;

  @override
  List<Object?> get props => [userMessage, technicalDetails, isRetryable];
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.userMessage = 'No internet connection. Check your network and try '
        'again.',
    super.technicalDetails,
  }) : super(isRetryable: true);
}

class ServerUnreachableFailure extends Failure {
  const ServerUnreachableFailure({
    super.userMessage = 'We could not reach the Odoo server. Verify the server '
        'URL and that the instance is online.',
    super.technicalDetails,
  }) : super(isRetryable: true);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.userMessage = 'The server took too long to respond. Please try '
        'again.',
    super.technicalDetails,
  }) : super(isRetryable: true);
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure({
    super.userMessage = 'Incorrect username, password or API key. Please check '
        'your credentials.',
    super.technicalDetails,
  });
}

class DatabaseUnavailableFailure extends Failure {
  const DatabaseUnavailableFailure({
    super.userMessage = 'The specified Odoo database is unavailable. Confirm '
        'the database name.',
    super.technicalDetails,
  });
}

class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure({
    super.userMessage = 'Your session has expired. Please sign in again.',
    super.technicalDetails,
  });
}

class AccessDeniedFailure extends Failure {
  const AccessDeniedFailure({
    super.userMessage = "You don't have permission to perform this action. "
        'Please contact your Odoo administrator.',
    this.model,
    this.operation,
    super.technicalDetails,
  });

  final String? model;
  final String? operation;

  @override
  List<Object?> get props => [...super.props, model, operation];
}

class OdooBusinessRuleFailure extends Failure {
  /// Odoo's own `UserError` / `ValidationError` text is already meant for end
  /// users, so it is forwarded verbatim.
  const OdooBusinessRuleFailure({
    required super.userMessage,
    super.technicalDetails,
  });
}

class ModelNotAvailableFailure extends Failure {
  const ModelNotAvailableFailure({
    required this.model,
    super.userMessage = 'This feature is not available on your Odoo instance.',
    super.technicalDetails,
  });

  final String model;

  @override
  List<Object?> get props => [...super.props, model];
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.userMessage = 'The Odoo server reported an error. Please try again '
        'or contact your administrator.',
    super.technicalDetails,
  }) : super(isRetryable: true);
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.userMessage = 'Could not read locally stored data.',
    super.technicalDetails,
  });
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.userMessage});
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.userMessage = 'Something went wrong. Please try again.',
    super.technicalDetails,
  }) : super(isRetryable: true);
}
