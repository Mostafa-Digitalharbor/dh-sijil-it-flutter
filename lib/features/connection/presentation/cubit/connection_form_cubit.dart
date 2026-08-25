import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_connection.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/connection_probe.dart';

/// Which field a validation message belongs to.
///
/// The form keeps errors per field rather than one message at the top, so the
/// user is pointed at the box to fix rather than left to work it out.
enum ConnectionField { serverUrl, database, username, credential }

/// What the last "Detect databases" attempt found.
///
/// Three outcomes, not two: a server that refuses to list its databases is
/// the *normal* production setting, not an error, and the UI has to say so
/// differently from a server that could not be reached at all.
enum DetectOutcome {
  /// Not attempted yet.
  idle,

  /// The server published a list.
  found,

  /// The server answered but keeps its database list private.
  unsupported,
}

class ConnectionFormState extends Equatable {
  const ConnectionFormState({
    this.serverUrl = '',
    this.database = '',
    this.username = '',
    this.authMode = OdooAuthMode.password,
    this.fieldErrors = const {},
    this.isProbing = false,
    this.isDetecting = false,
    this.detectOutcome = DetectOutcome.idle,
    this.probe,
    this.failure,
  });

  final String serverUrl;
  final String database;
  final String username;
  final OdooAuthMode authMode;

  /// Client-side validation messages, keyed by field.
  final Map<ConnectionField, String> fieldErrors;

  final bool isProbing;

  /// A database detection is in flight.
  final bool isDetecting;

  /// Result of the last detection attempt.
  final DetectOutcome detectOutcome;

  /// Result of the last successful "Test connection".
  final ConnectionProbe? probe;

  /// Result of the last failed probe.
  final Failure? failure;

  bool get hasProbed => probe != null;

  /// Enough is filled in to attempt a sign-in. Deliberately does not require a
  /// successful probe: an admin who knows their server should not be forced
  /// through an extra tap.
  bool get canSubmit =>
      serverUrl.trim().isNotEmpty &&
      database.trim().isNotEmpty &&
      username.trim().isNotEmpty;

  String? errorFor(ConnectionField field) => fieldErrors[field];

  ConnectionFormState copyWith({
    String? serverUrl,
    String? database,
    String? username,
    OdooAuthMode? authMode,
    Map<ConnectionField, String>? fieldErrors,
    bool? isProbing,
    bool? isDetecting,
    DetectOutcome? detectOutcome,
    ConnectionProbe? probe,
    Failure? failure,
    bool clearProbe = false,
    bool clearFailure = false,
  }) => ConnectionFormState(
    serverUrl: serverUrl ?? this.serverUrl,
    database: database ?? this.database,
    username: username ?? this.username,
    authMode: authMode ?? this.authMode,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    isProbing: isProbing ?? this.isProbing,
    isDetecting: isDetecting ?? this.isDetecting,
    detectOutcome: detectOutcome ?? this.detectOutcome,
    probe: clearProbe ? null : (probe ?? this.probe),
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    serverUrl,
    database,
    username,
    authMode,
    fieldErrors,
    isProbing,
    isDetecting,
    detectOutcome,
    probe,
    failure,
  ];
}

/// Drives the Odoo connection form (spec §3).
///
/// Owns validation and the reachability probe. Sign-in itself belongs to
/// `AuthCubit`, so there is exactly one place that creates a session.
class ConnectionFormCubit extends Cubit<ConnectionFormState> {
  ConnectionFormCubit(this._repository, {OdooConnection? initial})
    : super(
        initial == null
            ? const ConnectionFormState()
            : ConnectionFormState(
                serverUrl: initial.baseUrl.toString(),
                database: initial.database,
                username: initial.username,
                authMode: initial.authMode,
              ),
      );

  final AuthRepository _repository;

  /// Editing any field invalidates the previous probe result — otherwise a
  /// green "Reachable" badge could sit above a URL the user has since changed.
  void setServerUrl(String value) => emit(
    state.copyWith(
      serverUrl: value,
      fieldErrors: _without(ConnectionField.serverUrl),
      detectOutcome: DetectOutcome.idle,
      clearProbe: true,
      clearFailure: true,
    ),
  );

  void setDatabase(String value) => emit(
    state.copyWith(
      database: value,
      fieldErrors: _without(ConnectionField.database),
      clearFailure: true,
    ),
  );

  void setUsername(String value) => emit(
    state.copyWith(
      username: value,
      fieldErrors: _without(ConnectionField.username),
      clearFailure: true,
    ),
  );

  void setAuthMode(OdooAuthMode mode) => emit(
    state.copyWith(
      authMode: mode,
      fieldErrors: _without(ConnectionField.credential),
    ),
  );

  /// "Test connection" — cheap, unauthenticated, and reports what it found.
  Future<void> probe() async {
    final connection = _build();
    if (connection == null) return;

    emit(state.copyWith(isProbing: true, clearFailure: true, clearProbe: true));

    final result = await _repository.probe(connection);

    emit(
      result.fold(
        (failure) => state.copyWith(isProbing: false, failure: failure),
        (probe) => state.copyWith(isProbing: false, probe: probe),
      ),
    );
  }

  /// "Detect databases" — asks the server to publish its database list.
  ///
  /// Shares the probe call with [probe] rather than adding a second endpoint:
  /// `db.list` is optional and most production instances disable it, so the
  /// only honest way to find out is to ask and handle a refusal gracefully.
  Future<void> detectDatabases() async {
    final connection = _build();
    if (connection == null) return;

    emit(
      state.copyWith(
        isDetecting: true,
        detectOutcome: DetectOutcome.idle,
        clearFailure: true,
      ),
    );

    final result = await _repository.probe(connection);

    emit(
      result.fold(
        (failure) => state.copyWith(isDetecting: false, failure: failure),
        (probe) => state.copyWith(
          isDetecting: false,
          probe: probe,
          detectOutcome: probe.canListDatabases
              ? DetectOutcome.found
              : DetectOutcome.unsupported,
        ),
      ),
    );
  }

  /// Marks a detection result as read, so its sheet or notice does not
  /// reappear on the next rebuild.
  void acknowledgeDetection() =>
      emit(state.copyWith(detectOutcome: DetectOutcome.idle));

  /// Validates every field and returns the connection to sign in with, or
  /// null after publishing the messages into [ConnectionFormState.fieldErrors].
  ///
  /// [secret] is passed in rather than held in state: a credential must never
  /// live in an object that Bloc logs, compares or retains.
  OdooConnection? validateForSubmit({required String secret}) {
    final errors = <ConnectionField, String>{};

    if (state.serverUrl.trim().isEmpty) {
      errors[ConnectionField.serverUrl] = _ValidationKeys.serverUrlRequired;
    }
    if (state.database.trim().isEmpty) {
      errors[ConnectionField.database] = _ValidationKeys.databaseRequired;
    }
    if (state.username.trim().isEmpty) {
      errors[ConnectionField.username] = _ValidationKeys.usernameRequired;
    }
    if (secret.isEmpty) {
      errors[ConnectionField.credential] = _ValidationKeys.credentialRequired;
    }

    if (errors.isEmpty) {
      try {
        return _connectionFrom(state.serverUrl);
      } on InputValidationException {
        errors[ConnectionField.serverUrl] = _ValidationKeys.serverUrlInvalid;
      }
    }

    emit(state.copyWith(fieldErrors: errors));
    return null;
  }

  /// Builds a connection for the probe, reporting a bad URL on the field.
  OdooConnection? _build() {
    if (state.serverUrl.trim().isEmpty) {
      emit(
        state.copyWith(
          fieldErrors: {
            ...state.fieldErrors,
            ConnectionField.serverUrl: _ValidationKeys.serverUrlRequired,
          },
        ),
      );
      return null;
    }

    try {
      return _connectionFrom(state.serverUrl);
    } on InputValidationException {
      emit(
        state.copyWith(
          fieldErrors: {
            ...state.fieldErrors,
            ConnectionField.serverUrl: _ValidationKeys.serverUrlInvalid,
          },
        ),
      );
      return null;
    }
  }

  OdooConnection _connectionFrom(String rawUrl) => OdooConnection(
    baseUrl: OdooConnection.parseBaseUrl(rawUrl),
    database: state.database.trim(),
    username: state.username.trim(),
    authMode: state.authMode,
  );

  Map<ConnectionField, String> _without(ConnectionField field) =>
      {...state.fieldErrors}..remove(field);
}

/// Sentinel keys the page resolves through `AppL10n`.
///
/// The Cubit stays free of localized strings — it decides *what* is wrong and
/// the widget decides how to say it, in whichever language is active.
abstract final class _ValidationKeys {
  static const String serverUrlRequired = 'validationEnterServerUrl';
  static const String serverUrlInvalid = 'validationInvalidUrl';
  static const String databaseRequired = 'validationEnterDatabase';
  static const String usernameRequired = 'validationEnterUsername';
  static const String credentialRequired = 'validationEnterCredential';

  const _ValidationKeys._();
}

/// Public view of the validation keys, for the widget that translates them.
abstract final class ConnectionValidationKeys {
  static const String serverUrlRequired = _ValidationKeys.serverUrlRequired;
  static const String serverUrlInvalid = _ValidationKeys.serverUrlInvalid;
  static const String databaseRequired = _ValidationKeys.databaseRequired;
  static const String usernameRequired = _ValidationKeys.usernameRequired;
  static const String credentialRequired = _ValidationKeys.credentialRequired;

  const ConnectionValidationKeys._();
}
