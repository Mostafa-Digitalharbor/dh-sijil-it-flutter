import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_connection.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../connection/domain/entities/connection_probe.dart';
import '../entities/signed_in_user.dart';

/// Everything the app needs to get from "a URL in a text field" to "an
/// authenticated session".
///
/// Declared in the domain layer so the Cubits depend on this contract and not
/// on `OdooAuthService`, which is what lets the whole flow be tested against a
/// fake with no server.
abstract interface class AuthRepository {
  /// Reachability and version, without credentials.
  ///
  /// Backs the "Test connection" button. Never throws: an unreachable server
  /// is a [Failure], not an exception.
  ResultFuture<ConnectionProbe> probe(OdooConnection connection);

  /// Exchanges credentials for a session and stores them securely.
  ///
  /// On success the session is live, the connection is persisted, and the
  /// capability probe has run — so the first screen after login already knows
  /// which features to show.
  ResultFuture<SignedInUser> signIn({
    required OdooConnection connection,
    required String secret,
  });

  /// Re-establishes a session from the stored connection and credential.
  ///
  /// Returns `null` inside the right side when there is nothing stored — that
  /// is the ordinary first-run case, not a failure.
  ResultFuture<SignedInUser?> restoreSession();

  /// Clears the session. [forgetCredential] also wipes the keychain entry.
  ResultFuture<void> signOut({bool forgetCredential = true});

  /// The saved connection, if the app has been configured.
  OdooConnection? savedConnection();

  /// Re-runs the capability probe and drops the cached metadata (spec §23).
  ResultFuture<OdooCapabilities> refreshCapabilities();
}
