import 'exceptions.dart';
import 'failures.dart';

/// Turns anything thrown anywhere into a sanitized [Failure].
///
/// This is the single place in the app that interprets an Odoo fault string.
/// Adding support for a new Odoo error shape means editing one function, and
/// the classification is unit-tested against real recorded fault text.
abstract final class ErrorMapper {
  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    return switch (error) {
      NoInternetException() => Failure(
        kind: FailureKind.noInternet,
        technicalDetails: error.technicalDetails,
      ),
      ConnectionException() => Failure(
        kind: FailureKind.serverUnreachable,
        technicalDetails: error.technicalDetails ?? error.message,
      ),
      InsecureConnectionException() => Failure(
        kind: FailureKind.insecureConnection,
        technicalDetails: error.message,
      ),
      TimeoutException() => Failure(
        kind: FailureKind.timeout,
        technicalDetails: error.technicalDetails,
      ),
      AuthenticationException() => Failure(
        kind: FailureKind.invalidCredentials,
        technicalDetails: error.technicalDetails,
      ),
      SessionExpiredException() => Failure(
        kind: FailureKind.sessionExpired,
        technicalDetails: error.message,
      ),
      AccessDeniedException() => Failure(
        kind: FailureKind.accessDenied,
        model: error.model,
        operation: error.operation,
        technicalDetails: error.technicalDetails ?? error.message,
      ),
      OdooValidationException() => Failure(
        kind: FailureKind.businessRule,
        serverMessage: _tidyOdooMessage(error.message),
        technicalDetails: error.technicalDetails,
      ),
      FileAccessException() => Failure(
        kind: FailureKind.fileUnavailable,
        technicalDetails: error.message,
      ),
      RecordNotFoundException() => Failure(
        kind: FailureKind.recordNotFound,
        model: error.model,
        technicalDetails: error.message,
      ),
      ModelNotAvailableException() => Failure(
        kind: FailureKind.modelUnavailable,
        model: error.model,
        technicalDetails: error.message,
      ),
      FieldNotAvailableException() => Failure(
        kind: FailureKind.fieldUnavailable,
        model: error.model,
        technicalDetails: error.message,
      ),
      RateLimitedException() => Failure(
        kind: FailureKind.rateLimited,
        retryAfter: error.retryAfter,
        technicalDetails: error.technicalDetails ?? error.message,
      ),
      ServerException() => Failure(
        kind: FailureKind.server,
        technicalDetails: error.technicalDetails ?? error.message,
      ),
      OdooFaultException() => _fromFault(error),
      ResponseParsingException() => Failure(
        kind: FailureKind.notAnOdooServer,
        technicalDetails: error.technicalDetails ?? error.message,
      ),
      CacheException() => Failure(
        kind: FailureKind.cache,
        technicalDetails: error.technicalDetails,
      ),
      InputValidationException() => Failure(
        kind: FailureKind.validation,
        serverMessage: error.message,
      ),
      _ => Failure(kind: FailureKind.unknown, technicalDetails: '$error'),
    };
  }

  /// Odoo returns almost every server-side error as one generic XML-RPC fault
  /// whose string embeds the Python exception class and traceback. Classify on
  /// that, and never let the traceback out of [Failure.technicalDetails].
  static Failure _fromFault(OdooFaultException fault) {
    final text = fault.message.toLowerCase();

    // Database first, deliberately. Odoo answers a wrong database name with
    // a message that ALSO contains "AccessDenied", so checking permissions
    // first misreports a typo as a permissions problem -- and sends the user
    // to their administrator instead of to the one field they need to fix.
    if ((text.contains('database') &&
            (text.contains('does not exist') ||
                text.contains('not exist') ||
                text.contains('unknown database'))) ||
        text.contains('databasenotfound')) {
      return Failure(
        kind: FailureKind.databaseUnavailable,
        technicalDetails: fault.message,
      );
    }

    // Permission (spec section 21).
    if (text.contains('accesserror') ||
        text.contains('accessdenied') ||
        text.contains('not allowed to') ||
        text.contains('you are not allowed') ||
        text.contains('sorry, you are not allowed')) {
      return Failure(
        kind: FailureKind.accessDenied,
        model: _extractModel(fault.message),
        operation: _extractOperation(text),
        technicalDetails: fault.message,
      );
    }

    // Odoo's login throttle answers as a fault, not as HTTP 429: repeated bad
    // passwords produce "Too many login attempts" rather than a status code.
    // Without this it read as a generic server error and the user was told to
    // retry immediately, which is what extends the lockout.
    if (text.contains('too many login attempts') ||
        text.contains('too many requests') ||
        text.contains('rate limit')) {
      return Failure(
        kind: FailureKind.rateLimited,
        technicalDetails: fault.message,
      );
    }

    if (text.contains('session expired') ||
        text.contains('sessionexpired') ||
        text.contains('invalid session')) {
      return Failure(
        kind: FailureKind.sessionExpired,
        technicalDetails: fault.message,
      );
    }

    // A model the instance does not have (an optional app is missing).
    if (text.contains('object') && text.contains("doesn't exist") ||
        text.contains('invalid model') ||
        text.contains('keyerror') && text.contains('.')) {
      return Failure(
        kind: FailureKind.modelUnavailable,
        model: _extractModel(fault.message),
        technicalDetails: fault.message,
      );
    }

    // Record gone, or outside the caller's record rules.
    if (text.contains('missingerror') ||
        text.contains('record does not exist') ||
        text.contains('records do not exist')) {
      return Failure(
        kind: FailureKind.recordNotFound,
        technicalDetails: fault.message,
      );
    }

    // A field this instance does not have. Recorded from Odoo 19:
    //   ValueError: Invalid field 'x_sijil_status' on 'maintenance.equipment'
    //   ValueError: Invalid field maintenance.equipment.x_nope in condition …
    //
    // The app probes with `fields_get` before asking for anything unusual, so
    // reaching here means an instance changed under a running session. Saying
    // "server error" sends the user to retry something that cannot succeed.
    if (text.contains('invalid field')) {
      return Failure(
        kind: FailureKind.fieldUnavailable,
        model: _extractModel(fault.message),
        serverMessage: _extractQuoted(fault.message),
        technicalDetails: fault.message,
      );
    }

    // Odoo's own user-facing errors: show its wording, it is better than ours.
    //
    // The marker test came first and is kept for older servers. Odoo 19 sends
    // constraint failures with **no** exception class in the fault at all —
    //   The operation cannot be completed: Missing required value for the
    //   field 'Subjects' (name).
    // — which fell through to a generic server error and hid the one sentence
    // that says what to fix.
    if (text.contains('validationerror') ||
        text.contains('usererror') ||
        text.contains('redirectwarning') ||
        text.contains('the operation cannot be completed') ||
        text.contains('missing required value') ||
        text.contains('constraint')) {
      return Failure(
        kind: FailureKind.businessRule,
        serverMessage: _tidyOdooMessage(fault.message),
        technicalDetails: fault.message,
      );
    }

    return Failure(kind: FailureKind.server, technicalDetails: fault.message);
  }

  /// Strips the Python exception class, module path and traceback from an Odoo
  /// fault so only the sentence a human wrote survives.
  ///
  /// `odoo.exceptions.UserError: Cannot scrap an assigned asset.`
  ///   → `Cannot scrap an assigned asset.`
  static String _tidyOdooMessage(String raw) {
    var text = raw.trim();

    // Drop everything before the last "SomeError: " marker.
    final marker = RegExp(
      r'(?:odoo\.exceptions\.)?\w*(?:Error|Warning|Exception)\s*:\s*',
    );
    final matches = marker.allMatches(text).toList();
    if (matches.isNotEmpty) {
      text = text.substring(matches.last.end);
    }

    // Drop a trailing traceback if the server included one.
    final traceback = text.indexOf('Traceback (most recent call last)');
    if (traceback > 0) text = text.substring(0, traceback);

    // Collapse the whitespace Odoo's multi-line messages carry.
    text = text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

    return text.isEmpty ? raw.trim() : text;
  }

  /// The first quoted token in a fault — the field name Odoo objected to.
  ///
  /// Odoo quotes it in both shapes it uses ("Invalid field 'x' on 'model'" and
  /// "the field 'Subjects'"), and the name is the only part of that sentence
  /// worth showing someone.
  static String? _extractQuoted(String raw) =>
      RegExp(r"'([^']{1,64})'").firstMatch(raw)?.group(1);

  /// Pulls a `some.model` identifier out of a fault string, when present.
  ///
  /// Odoo's AccessError names the model in parentheses — "…this document
  /// (maintenance.equipment)." — so that shape is tried first. The fallback
  /// scan skips Python module paths, which would otherwise win: `odoo.exceptions`
  /// is a dotted lowercase token too, and matching it would tell the user their
  /// administrator must grant them access to "odoo.exceptions".
  static String? _extractModel(String raw) {
    final parenthesised = RegExp(
      r'\(([a-z_]+(?:\.[a-z_]+)+)\)',
    ).firstMatch(raw)?.group(1);
    if (parenthesised != null && !_isPythonPath(parenthesised)) {
      return parenthesised;
    }

    for (final match in RegExp(
      r'\b([a-z_]+(?:\.[a-z_]+)+)\b',
    ).allMatches(raw)) {
      final candidate = match.group(1)!;
      if (!_isPythonPath(candidate)) return candidate;
    }
    return null;
  }

  /// Module paths and file names that look like model identifiers but are not.
  static bool _isPythonPath(String candidate) =>
      candidate.startsWith('odoo.') ||
      candidate.startsWith('werkzeug.') ||
      candidate.startsWith('psycopg2.') ||
      candidate.endsWith('.py');

  /// What Odoo refused, read from either wording it uses.
  ///
  /// A raised `AccessError` carries the ORM verb; the sentence Odoo writes for
  /// a person says "modify", "delete" or "access" instead. Matching only the
  /// ORM verbs meant the human variant — the one users actually hit — never
  /// resolved, so the error fell back to a body that named neither the model
  /// nor what was refused.
  ///
  /// Ordered most-specific first: "create" appears inside "create/update", and
  /// several messages mention more than one verb.
  static OdooOperation? _extractOperation(String lowercased) {
    const wording = <String, OdooOperation>{
      'not allowed to create': OdooOperation.create,
      'not allowed to modify': OdooOperation.write,
      'not allowed to update': OdooOperation.write,
      'not allowed to delete': OdooOperation.delete,
      'not allowed to access': OdooOperation.read,
      'unlink': OdooOperation.delete,
      'create': OdooOperation.create,
      'write': OdooOperation.write,
      'read': OdooOperation.read,
    };

    for (final entry in wording.entries) {
      if (lowercased.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
