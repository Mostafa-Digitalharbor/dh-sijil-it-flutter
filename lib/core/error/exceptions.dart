import 'failures.dart';

/// Low-level exceptions thrown by data sources.
///
/// These never reach the UI: repositories catch them and convert them into
/// [Failure]s through `ErrorMapper`. That keeps raw XML-RPC faults and stack
/// traces out of the presentation layer (spec §22).
sealed class AppException implements Exception {
  const AppException(this.message, {this.technicalDetails});

  /// Short, non-sensitive description.
  final String message;

  /// Verbose detail for the debug log section only. Never rendered in the UI.
  final String? technicalDetails;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device has no usable internet connection.
class NoInternetException extends AppException {
  const NoInternetException([super.message = 'No internet connection']);
}

/// The Odoo host could not be reached, or DNS/TLS failed.
class ConnectionException extends AppException {
  const ConnectionException(super.message, {super.technicalDetails});
}

/// The URL asked for plain HTTP, which the app does not speak.
///
/// Both platforms refuse it before a packet leaves the device — Android
/// through `usesCleartextTraffic="false"`, iOS through App Transport
/// Security — and each phrases the refusal differently and only after the
/// request has been attempted. Raised as its own type so the user is told the
/// one thing that actually fixes it rather than being sent to check whether
/// their server is switched on.
class InsecureConnectionException extends AppException {
  const InsecureConnectionException([
    super.message = 'Sijil IT only connects over HTTPS.',
  ]);
}

/// The request exceeded the configured timeout.
class TimeoutException extends AppException {
  const TimeoutException([super.message = 'The request timed out']);
}

/// Odoo returned `false` from `authenticate`, or the session is no longer
/// valid.
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.technicalDetails});
}

/// Odoo raised `odoo.exceptions.AccessError` / `AccessDenied` — the user's
/// ACLs or record rules forbid the operation.
class AccessDeniedException extends AppException {
  const AccessDeniedException(
    super.message, {
    this.model,
    this.operation,
    super.technicalDetails,
  });

  final String? model;
  final OdooOperation? operation;
}

/// Odoo raised `odoo.exceptions.ValidationError` / `UserError`.
class OdooValidationException extends AppException {
  const OdooValidationException(super.message, {super.technicalDetails});
}

/// A generic XML-RPC `<fault>` we could not classify more precisely.
class OdooFaultException extends AppException {
  const OdooFaultException(
    super.message, {
    this.faultCode,
    super.technicalDetails,
  });

  final int? faultCode;
}

/// The requested model does not exist on this Odoo instance (an optional app
/// such as Maintenance is not installed).
class ModelNotAvailableException extends AppException {
  const ModelNotAvailableException(this.model)
    : super('Model "$model" is not available on this Odoo instance');

  final String model;
}

/// The requested field does not exist on the model in this Odoo version.
class FieldNotAvailableException extends AppException {
  const FieldNotAvailableException(this.model, this.field)
    : super('Field "$field" is not available on "$model"');

  final String model;
  final String field;
}

/// The XML-RPC payload could not be parsed into the expected shape.
class ResponseParsingException extends AppException {
  const ResponseParsingException(super.message, {super.technicalDetails});
}

/// Local cache / secure storage failed.
class CacheException extends AppException {
  const CacheException(super.message, {super.technicalDetails});
}

/// Client-side input validation failed before any request was sent.
///
/// [validationKey] names *which* rule was broken, using the same stable keys
/// the Cubits publish. Without it every rejection collapsed into one message:
/// `http://demo.odoo.com` is a perfectly well-formed URL, and telling the user
/// it "doesn't look like a valid server address" sends them to re-read the
/// host name when the only thing wrong is the scheme. The translated string
/// naming the scheme already existed and nothing could reach it.
class InputValidationException extends AppException {
  const InputValidationException(super.message, {this.validationKey});

  final String? validationKey;
}

/// The record was read by id and Odoo returned nothing.
///
/// Distinct from an empty search result: asking for a specific id and getting
/// none back means the record was deleted, or a record rule hides it from this
/// user. Both read to the user as "this record is gone", which is honest —
/// Odoo deliberately does not distinguish the two.
/// A file the OS handed us is no longer readable.
///
/// Android reclaims camera-intent temp files aggressively under memory
/// pressure, so a path the picker returned a moment ago can be gone by the
/// time the upload starts. Naming it beats letting base64 encoding throw
/// something the user cannot act on.
class FileAccessException extends AppException {
  const FileAccessException(super.message);
}

class RecordNotFoundException extends AppException {
  const RecordNotFoundException(this.model, this.id)
    : super('No "$model" record with id $id is visible to this user');

  final String model;
  final int id;
}
