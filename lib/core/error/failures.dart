import 'package:equatable/equatable.dart';

/// What kind of thing went wrong.
///
/// The failure carries a *kind*, never an English sentence. Wording lives in
/// the ARB files and is resolved at render time by `FailurePresenter`, so the
/// same failure reads correctly in Arabic and English and so a copy change is
/// a translation edit rather than a code change.
/// The thing Odoo refused to let the user do.
///
/// An enum rather than the raw ORM verb, because it is rendered *inside a
/// sentence* the user reads: "Your Odoo user is not allowed to {operation}
/// {model} records." Passing `unlink` through produced an English ORM keyword
/// in the middle of an Arabic sentence, which is both untranslated and
/// jargon — the user does not know what `unlink` is.
enum OdooOperation { read, create, write, delete }

enum FailureKind {
  /// The device itself has no connectivity.
  noInternet,

  /// DNS, TLS or the host refused the connection.
  serverUnreachable,

  /// The XML-RPC endpoint answered, but not with XML-RPC (wrong URL, a proxy
  /// login page, a parked domain).
  notAnOdooServer,

  /// The request exceeded the timeout.
  timeout,

  /// Odoo rejected the username/password/API key.
  invalidCredentials,

  /// The database name does not exist on this server.
  databaseUnavailable,

  /// The stored session is no longer valid.
  sessionExpired,

  /// Odoo's ACLs or record rules forbid the operation.
  accessDenied,

  /// An optional Odoo app (Maintenance, HR) is not installed.
  modelUnavailable,

  /// The model exists but a field the app asked for does not.
  ///
  /// Distinct from [modelUnavailable]: the Odoo app *is* installed, and the
  /// difference is one customised field. Telling the user to install a module
  /// would send them somewhere that cannot fix it.
  fieldUnavailable,

  /// Odoo raised a `UserError`/`ValidationError`. Its own text is already
  /// written for end users and is shown verbatim.
  businessRule,

  /// The record was deleted or is outside the user's record rules.
  recordNotFound,

  /// A photo the OS handed the app could not be read back.
  fileUnavailable,

  /// Odoo returned a 5xx or an unclassifiable fault.
  server,

  /// Local storage failed.
  cache,

  /// Client-side input validation failed before anything was sent.
  validation,

  /// Nothing above matched.
  unknown,
}

/// What the user can do about a failure. Drives the button on the error view.
enum FailureAction {
  /// Re-run the same request.
  retry,

  /// Go back to the connection screen to fix the URL or database.
  editConnection,

  /// Sign in again.
  signIn,

  /// Nothing actionable in-app — the message explains who to contact.
  none,
}

/// A sanitized, user-presentable description of something that went wrong.
///
/// Repositories return `Either<Failure, T>`; Cubits store it; the UI renders
/// it through `FailurePresenter`. No layer above `data/` ever sees an
/// exception, a stack trace, or a raw XML-RPC fault (spec §22).
class Failure extends Equatable {
  const Failure({
    required this.kind,
    this.technicalDetails,
    this.serverMessage,
    this.model,
    this.operation,
  });

  const Failure.noInternet({String? technicalDetails})
    : this(kind: FailureKind.noInternet, technicalDetails: technicalDetails);

  const Failure.unknown({String? technicalDetails})
    : this(kind: FailureKind.unknown, technicalDetails: technicalDetails);

  final FailureKind kind;

  /// Verbose detail for Settings → Diagnostics only. Never rendered inline.
  final String? technicalDetails;

  /// Odoo's own message, when it is already meant for end users
  /// ([FailureKind.businessRule]). Null for every other kind.
  final String? serverMessage;

  /// The Odoo model involved, for permission and availability messages.
  final String? model;

  /// What was refused, when Odoo said. Translated by the presenter.
  final OdooOperation? operation;

  /// Whether offering "Try again" makes sense for this kind.
  bool get isRetryable => switch (kind) {
    FailureKind.noInternet ||
    FailureKind.serverUnreachable ||
    FailureKind.timeout ||
    FailureKind.server ||
    FailureKind.unknown => true,
    _ => false,
  };

  /// The single action the error view should offer.
  FailureAction get action => switch (kind) {
    FailureKind.noInternet ||
    FailureKind.timeout ||
    FailureKind.server ||
    FailureKind.unknown ||
    // Retake-and-retry is exactly the fix, and the button is the shortest way
    // back to it.
    FailureKind.fileUnavailable ||
    FailureKind.cache => FailureAction.retry,
    FailureKind.serverUnreachable ||
    FailureKind.notAnOdooServer ||
    FailureKind.databaseUnavailable => FailureAction.editConnection,
    FailureKind.invalidCredentials ||
    FailureKind.sessionExpired => FailureAction.signIn,
    FailureKind.accessDenied ||
    FailureKind.modelUnavailable ||
    FailureKind.fieldUnavailable ||
    FailureKind.businessRule ||
    FailureKind.recordNotFound ||
    FailureKind.validation => FailureAction.none,
  };

  /// Whether this failure warrants a full-screen treatment rather than a
  /// snackbar. Blocking problems take over; incidental ones do not.
  bool get isBlocking => switch (kind) {
    FailureKind.validation || FailureKind.businessRule => false,
    _ => true,
  };

  Failure copyWith({
    String? technicalDetails,
    String? model,
    OdooOperation? operation,
  }) => Failure(
    kind: kind,
    technicalDetails: technicalDetails ?? this.technicalDetails,
    serverMessage: serverMessage,
    model: model ?? this.model,
    operation: operation ?? this.operation,
  );

  @override
  List<Object?> get props => [
    kind,
    technicalDetails,
    serverMessage,
    model,
    operation,
  ];

  @override
  String toString() =>
      'Failure(${kind.name}${model == null ? '' : ', $model'})';
}
