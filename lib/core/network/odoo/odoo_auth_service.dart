import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../xmlrpc/xml_rpc_client.dart';
import 'odoo_connection.dart';

/// Wraps `/xmlrpc/2/common` — the endpoint that needs no uid (spec §1).
///
/// Responsibilities: server reachability, version discovery and turning
/// credentials into a `uid`. Nothing else in the app calls `authenticate`.
class OdooAuthService {
  const OdooAuthService(this._client);

  final XmlRpcClient _client;

  /// Reads the server's version banner. Also doubles as the reachability
  /// probe behind the "Test Connection" button, because it is the cheapest
  /// unauthenticated call Odoo exposes.
  Future<OdooServerInfo> version(OdooConnection connection) async {
    final result = await _client.call(
      endpoint: connection.commonEndpoint,
      methodName: 'version',
      params: const <Object?>[],
    );

    if (result is! Map) {
      throw const ResponseParsingException(
        'This does not look like an Odoo server.',
        technicalDetails: 'common.version did not return a struct.',
      );
    }

    return OdooServerInfo(
      serverVersion: '${result['server_version'] ?? ''}',
      serverSerie: '${result['server_serie'] ?? ''}',
      protocolVersion: result['protocol_version'] is int
          ? result['protocol_version'] as int
          : null,
    );
  }

  /// Exchanges credentials for a uid.
  ///
  /// Odoo returns `false` (not a fault) for bad credentials, and faults when
  /// the database name is wrong — both are normalised here.
  Future<int> authenticate({
    required OdooConnection connection,
    required String secret,
  }) async {
    if (connection.database.trim().isEmpty) {
      throw const InputValidationException('Enter your Odoo database name.');
    }
    if (connection.username.trim().isEmpty) {
      throw const InputValidationException('Enter your Odoo username.');
    }
    if (secret.isEmpty) {
      throw const InputValidationException('Enter your password or API key.');
    }

    final result = await _client.call(
      endpoint: connection.commonEndpoint,
      methodName: 'authenticate',
      params: <Object?>[
        connection.database,
        connection.username,
        secret,
        const <String, dynamic>{},
      ],
    );

    if (result is int && result > 0) {
      AppLogger.info('Authenticated against ${connection.baseUrl.host}');
      return result;
    }

    // `false` means the database exists but the credentials were rejected.
    throw const AuthenticationException(
      'Incorrect username, password or API key.',
      technicalDetails: 'common.authenticate returned a falsy uid.',
    );
  }

  /// Lists databases when the server allows it.
  ///
  /// Most production instances disable `db.list` (`list_db = False`), so a
  /// failure here is expected and must not block the connection flow — the UI
  /// falls back to a free-text database field.
  Future<List<String>?> listDatabases(OdooConnection connection) async {
    try {
      final result = await _client.call(
        endpoint: connection.dbEndpoint,
        methodName: 'list',
        params: const <Object?>[],
      );
      if (result is List) {
        return result.map((e) => '$e').toList(growable: false);
      }
      return null;
    } on AppException {
      return null;
    }
  }
}

/// Version banner returned by `common.version`.
class OdooServerInfo {
  const OdooServerInfo({
    required this.serverVersion,
    required this.serverSerie,
    this.protocolVersion,
  });

  final String serverVersion;
  final String serverSerie;
  final int? protocolVersion;

  int? get majorVersion =>
      int.tryParse(serverVersion.split('.').firstOrNull ?? '');

  @override
  String toString() => 'Odoo $serverVersion';
}
