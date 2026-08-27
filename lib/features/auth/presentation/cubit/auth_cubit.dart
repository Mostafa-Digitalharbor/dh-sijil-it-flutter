import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_connection.dart';
import '../../domain/entities/signed_in_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Where the app is in the sign-in lifecycle.
enum AuthStatus {
  /// Bootstrap has not finished; the splash screen is showing.
  unknown,

  /// The server screen owns the user: either nothing has ever been
  /// configured, or they stepped back to change the URL or database.
  ///
  /// Named for where the user *is* rather than for what is missing, because
  /// both routes lead to the same screen and only one of them means "no
  /// connection". [AuthState.connection] tells them apart, and is what the
  /// screen prefills from.
  configuring,

  /// The server is known and the app is waiting for a sign-in — go to the
  /// login screen.
  signedOut,

  busy,
  signedIn,
}

/// App-wide session state.
///
/// The single source of truth for "who is signed in and what can their Odoo
/// do". The router reads it, the shell reads it, and features read
/// `capabilities` from it rather than probing again.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.failure,
    this.connection,
  });

  final AuthStatus status;
  final SignedInUser? user;
  final Failure? failure;

  /// The saved connection, known even while signed out — the login screen
  /// shows which server it is about to sign into.
  final OdooConnection? connection;

  bool get isSignedIn => status == AuthStatus.signedIn && user != null;
  bool get isBusy => status == AuthStatus.busy;

  /// Capabilities of the connected instance, or a conservative all-off set
  /// before sign-in. Never null, so callers never need a fallback.
  OdooCapabilities get capabilities =>
      user?.capabilities ?? const OdooCapabilities.unknown();

  AuthState copyWith({
    AuthStatus? status,
    SignedInUser? user,
    Failure? failure,
    OdooConnection? connection,
    bool clearFailure = false,
    bool clearUser = false,
  }) => AuthState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    failure: clearFailure ? null : (failure ?? this.failure),
    connection: connection ?? this.connection,
  );

  @override
  List<Object?> get props => [status, user, failure, connection];
}

/// Owns sign-in, sign-out and session restore.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  /// Called once from the splash screen.
  ///
  /// Resolves to exactly one of three destinations, so the router never has to
  /// guess: configuring, signed out, or signed in.
  Future<void> restore() async {
    final saved = _repository.savedConnection();

    if (saved == null) {
      emit(const AuthState(status: AuthStatus.configuring));
      return;
    }

    emit(AuthState(status: AuthStatus.busy, connection: saved));

    final result = await _repository.restoreSession();

    emit(
      result.fold(
        // A restore failure is not fatal: the connection is still valid, the
        // user just needs to sign in again. The reason travels with the state
        // so the login screen can explain it.
        (failure) => AuthState(
          status: AuthStatus.signedOut,
          connection: saved,
          failure: failure,
        ),
        (user) => user == null
            ? AuthState(status: AuthStatus.signedOut, connection: saved)
            : AuthState(
                status: AuthStatus.signedIn,
                user: user,
                connection: user.connection,
              ),
      ),
    );
  }

  Future<void> signIn({
    required OdooConnection connection,
    required String secret,
  }) async {
    emit(state.copyWith(status: AuthStatus.busy, clearFailure: true));

    final result = await _repository.signIn(
      connection: connection,
      secret: secret,
    );

    emit(
      result.fold(
        (failure) => state.copyWith(
          status: AuthStatus.signedOut,
          connection: connection,
          failure: failure,
        ),
        (user) => AuthState(
          status: AuthStatus.signedIn,
          user: user,
          connection: user.connection,
        ),
      ),
    );
  }

  Future<void> signOut() async {
    emit(state.copyWith(status: AuthStatus.busy, clearFailure: true));

    await _repository.signOut();

    // The connection survives a sign-out on purpose: signing back in should
    // not mean retyping the server URL.
    emit(
      AuthState(
        status: AuthStatus.signedOut,
        connection: _repository.savedConnection(),
      ),
    );
  }

  /// The server screen is done: carry these details to the login screen.
  ///
  /// No round trip and nothing written to storage. The connection is only
  /// worth persisting once a sign-in has proved it works, and until then it
  /// holds an empty username — a half-filled record that a later restore
  /// would have to special-case.
  void useConnection(OdooConnection connection) =>
      emit(AuthState(status: AuthStatus.signedOut, connection: connection));

  /// Back to the server screen, with what is on file kept for the fields.
  ///
  /// Non-destructive on purpose. The old "forget the connection" behaviour
  /// emptied the form, so a user who came back to fix one character in the URL
  /// had to retype the whole thing — and a `FailureView` that sent them here
  /// because the *saved* address was wrong showed them a blank screen with no
  /// clue what it had been.
  ///
  /// The session itself does end. Every path to this screen means the server
  /// details are in question, and a stale session against the old server would
  /// otherwise be restored on the next launch.
  Future<void> editConnection() async {
    await _repository.signOut();
    emit(
      AuthState(status: AuthStatus.configuring, connection: state.connection),
    );
  }

  /// Settings → "Refresh Odoo metadata" (spec §23).
  Future<Failure?> refreshCapabilities() async {
    final result = await _repository.refreshCapabilities();

    return result.fold((failure) => failure, (capabilities) {
      final user = state.user;
      if (user != null) {
        emit(state.copyWith(user: user.copyWith(capabilities: capabilities)));
      }
      return null;
    });
  }

  /// Clears a failure the user has read, so it does not reappear on rebuild.
  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));
}
