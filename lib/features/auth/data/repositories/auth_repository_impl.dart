import 'dart:typed_data';

import '../../../../core/constants/odoo_models.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/connectivity/network_info.dart';
import '../../../../core/network/odoo/odoo_auth_service.dart';
import '../../../../core/network/odoo/odoo_binary.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_connection.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/network/odoo/odoo_session_manager.dart';
import '../../../../core/security/credential_vault.dart';
import '../../../../core/storage/preferences/app_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../connection/domain/entities/connection_probe.dart';
import '../../domain/entities/signed_in_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Turns the Odoo services into the four operations the UI actually performs.
///
/// Every method funnels its exceptions through [ErrorMapper], so nothing above
/// this class has to know that Odoo exists, let alone that it speaks XML-RPC.
class AuthRepositoryImpl with RepositoryGuard implements AuthRepository {
  const AuthRepositoryImpl({
    required OdooAuthService authService,
    required OdooObjectService objectService,
    required OdooSessionManager sessionManager,
    required OdooCapabilityService capabilityService,
    required CredentialVault vault,
    required AppPreferences preferences,
    required NetworkInfo networkInfo,
  }) : _authService = authService,
       _objectService = objectService,
       _sessionManager = sessionManager,
       _capabilityService = capabilityService,
       _vault = vault,
       _preferences = preferences,
       _networkInfo = networkInfo;

  final OdooAuthService _authService;
  final OdooObjectService _objectService;
  final OdooSessionManager _sessionManager;
  final OdooCapabilityService _capabilityService;
  final CredentialVault _vault;
  final AppPreferences _preferences;
  final NetworkInfo _networkInfo;

  @override
  OdooConnection? savedConnection() => _preferences.readConnection();

  @override
  ResultFuture<ConnectionProbe> probe(OdooConnection connection) async {
    return guard(() async {
      await _requireNetwork();

      final info = await _authService.version(connection);
      // Optional and commonly disabled; a null list is a normal outcome.
      final databases = await _authService.listDatabases(connection);

      return ConnectionProbe(
        serverVersion: info.serverVersion,
        isSecure: connection.isSecure,
        databases: databases,
      );
    });
  }

  @override
  ResultFuture<SignedInUser> signIn({
    required OdooConnection connection,
    required String secret,
  }) async {
    return guard(() async {
      await _requireNetwork();

      final info = await _authService.version(connection);
      final userId = await _authService.authenticate(
        connection: connection,
        secret: secret,
      );

      // The credential must be in the vault before the first execute_kw:
      // OdooObjectService reads it from there per call rather than holding it.
      await _vault.writeSecret(secret, connection.authMode);

      final session = OdooSession(
        connection: connection,
        userId: userId,
        serverVersion: info.serverVersion,
      );
      _sessionManager.start(session);

      try {
        final user = await _loadProfile(session);
        await _persist(connection, session);
        return user;
      } on Object {
        // Never leave a half-open session behind: if the profile read fails,
        // the user is not signed in and the credential should not linger.
        await _sessionManager.end();
        rethrow;
      }
    });
  }

  @override
  ResultFuture<SignedInUser?> restoreSession() async {
    return guard(() async {
      final connection = _preferences.readConnection();
      final userId = _preferences.userId;
      if (connection == null || userId == null) return null;

      if (!await _vault.hasSecret()) return null;

      // Trust the stored uid optimistically and let the first real call prove
      // it. Re-authenticating on every cold start would cost a round trip and
      // would fail offline, where the cache could still serve the user.
      final session = OdooSession(
        connection: connection,
        userId: userId,
        serverVersion: _preferences.serverVersion,
      );
      _sessionManager.start(session);

      try {
        return await _loadProfile(session);
      } on AppException catch (e) {
        AppLogger.warn('Session restore failed: ${e.message}');
        await _sessionManager.end(forgetCredential: false);
        rethrow;
      }
    });
  }

  @override
  ResultFuture<void> signOut({bool forgetCredential = true}) async {
    return guard(() async {
      await _sessionManager.end(forgetCredential: forgetCredential);
      await _capabilityService.invalidate();
      if (forgetCredential) await _preferences.setUserId(null);
    });
  }

  @override
  ResultFuture<OdooCapabilities> refreshCapabilities() async {
    return guard(() async {
      await _capabilityService.invalidate();
      final capabilities = await _capabilityService.probeAll();
      await _preferences.setLastMetadataSync(DateTime.now());
      return capabilities;
    });
  }

  /// Reads `res.users` for the signed-in uid and probes capabilities.
  Future<SignedInUser> _loadProfile(OdooSession session) async {
    final fields = await _capabilityService.supportedFields(
      OdooModels.resUsers,
      UserFields.readSet,
    );

    final records = await _objectService.read(
      model: OdooModels.resUsers,
      ids: [session.userId],
      fields: fields,
    );

    if (records.isEmpty) {
      throw const AuthenticationException(
        'The signed-in user could not be read.',
        technicalDetails: 'res.users.read returned no record for the uid.',
      );
    }

    final record = records.first;
    final capabilities = await _capabilityService.probeAll();

    return SignedInUser(
      session: session,
      displayName:
          _string(record[UserFields.name]) ?? session.connection.username,
      login: _string(record[UserFields.login]) ?? session.connection.username,
      email: _string(record[UserFields.email]),
      companyName: OdooNameRef.fromPair(record[UserFields.companyId])?.name,
      avatar: _decodeImage(record[UserFields.image]),
      capabilities: capabilities,
    );
  }

  /// Decodes a base64 image field.
  ///
  /// Odoo sends `false` for an unset image, and a corrupt value is possible
  /// on an instance that has been through a bad migration. Neither is worth
  /// failing a sign-in over, so both become "no photo".
  static Uint8List? _decodeImage(Object? value) => OdooBinary.tryDecode(value);

  Future<void> _persist(OdooConnection connection, OdooSession session) async {
    await _preferences.saveConnection(connection);
    await _preferences.setUserId(session.userId);
    await _preferences.setServerVersion(session.serverVersion);
    await _preferences.setLastMetadataSync(DateTime.now());
  }

  /// Fails fast when the device is offline, so the user gets "you're offline"
  /// instead of waiting out a 20-second connect timeout.
  Future<void> _requireNetwork() async {
    if (!await _networkInfo.isConnected) {
      throw const NoInternetException();
    }
  }

  /// Odoo returns `false` for an unset character field, which decodes to a
  /// bool rather than a string.
  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  @override
  String get guardLabel => 'AuthRepository';
}
