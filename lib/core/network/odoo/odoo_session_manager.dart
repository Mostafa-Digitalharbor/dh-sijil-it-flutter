import 'dart:async';

import '../../error/exceptions.dart';
import '../../security/credential_vault.dart';
import 'odoo_connection.dart';

/// Holds the active [OdooSession] for the lifetime of the process and streams
/// changes to whoever cares (the router's redirect guard, mainly).
///
/// Observer pattern: a single writable source of truth, many read-only
/// listeners. Registered as a lazy singleton in the DI container.
class OdooSessionManager {
  OdooSessionManager(this._vault);

  final CredentialVault _vault;
  final StreamController<OdooSession?> _controller =
      StreamController<OdooSession?>.broadcast();

  OdooSession? _session;

  OdooSession? get session => _session;

  bool get isAuthenticated => _session != null;

  /// Emits on every login, logout and session refresh.
  Stream<OdooSession?> get changes => _controller.stream;

  void start(OdooSession session) {
    _session = session;
    _controller.add(session);
  }

  /// Clears the in-memory session. Whether the stored credential is wiped too
  /// is the caller's decision: an expired session keeps it (so the user can
  /// retry), an explicit sign-out deletes it.
  Future<void> end({bool forgetCredential = true}) async {
    _session = null;
    if (forgetCredential) {
      await _vault.clearSecret();
    }
    _controller.add(null);
  }

  /// The session, or a typed failure if the user is not signed in.
  OdooSession requireSession() {
    final current = _session;
    if (current == null) {
      throw const AuthenticationException(
        'Your session has expired. Please sign in again.',
        technicalDetails: 'No active OdooSession.',
      );
    }
    return current;
  }

  /// Fetches the credential from the OS keystore at call time.
  ///
  /// Deliberately not cached in a field: the secret exists only inside the
  /// stack frame of the RPC call that needs it (spec §25).
  Future<String> requireSecret() async {
    final secret = await _vault.readSecret();
    if (secret == null || secret.isEmpty) {
      throw const AuthenticationException(
        'Your session has expired. Please sign in again.',
        technicalDetails: 'No credential found in secure storage.',
      );
    }
    return secret;
  }

  Future<void> dispose() => _controller.close();
}
