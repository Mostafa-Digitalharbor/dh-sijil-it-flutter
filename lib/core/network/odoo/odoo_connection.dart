import 'package:equatable/equatable.dart';

import '../../constants/app_constants.dart';
import '../../error/exceptions.dart';

/// How the user authenticates against Odoo.
enum OdooAuthMode {
  password,
  apiKey;

  static OdooAuthMode fromName(String? value) => OdooAuthMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => OdooAuthMode.password,
  );
}

/// Non-secret connection settings (spec §3).
///
/// The secret itself is **never** a field here — it is read on demand from
/// `flutter_secure_storage` at call time, so it cannot be captured in a state
/// object, a log line or a crash report.
class OdooConnection extends Equatable {
  const OdooConnection({
    required this.baseUrl,
    required this.database,
    required this.username,
    this.authMode = OdooAuthMode.password,
  });

  final Uri baseUrl;
  final String database;
  final String username;
  final OdooAuthMode authMode;

  Uri get commonEndpoint => _endpoint(AppConstants.xmlRpcCommonPath);
  Uri get objectEndpoint => _endpoint(AppConstants.xmlRpcObjectPath);
  Uri get dbEndpoint => _endpoint(AppConstants.xmlRpcDbPath);

  /// The web client's own database list, used only when [dbEndpoint] refuses.
  ///
  /// Not an XML-RPC endpoint and deliberately not named like one: it is the
  /// JSON route the Odoo login page calls to fill its dropdown, and it is the
  /// only way to read the list on a hosted instance, where `/xmlrpc/2/db` is
  /// switched off.
  Uri get databaseListEndpoint => _endpoint(AppConstants.webDatabaseListPath);

  bool get isSecure => baseUrl.scheme == 'https';

  Uri _endpoint(String path) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base$path');
  }

  /// The rules [parseBaseUrl] enforces, as the stable keys the widget layer
  /// translates. Declared here beside the checks that raise them so the two
  /// cannot drift.
  static const String validationServerUrlRequired = 'validationEnterServerUrl';
  static const String validationUrlInvalid = 'validationInvalidUrl';
  static const String validationHttpsRequired = 'validationHttpsRequired';

  /// Normalises whatever the user typed into a usable base [Uri].
  ///
  /// Accepts `company.odoo.com`, `https://company.odoo.com/`, or a host with a
  /// port or sub-path. Defaults to HTTPS (spec §25).
  static Uri parseBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const InputValidationException(
        'Enter your Odoo server URL.',
        validationKey: OdooConnection.validationServerUrlRequired,
      );
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);

    if (uri == null || uri.host.isEmpty) {
      throw const InputValidationException(
        'That does not look like a valid server URL.',
        validationKey: OdooConnection.validationUrlInvalid,
      );
    }
    // `http` is rejected here rather than accepted and left to fail later.
    // Neither platform will send it — Android blocks cleartext, iOS blocks it
    // through App Transport Security — so a connection saved with it can only
    // ever produce a confusing "server unreachable" after a full timeout.
    // Saying so at the keyboard costs the user seconds instead of minutes.
    if (uri.scheme != 'https') {
      throw const InputValidationException(
        'The server URL must start with https://',
        validationKey: OdooConnection.validationHttpsRequired,
      );
    }

    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;

    // Rebuilt rather than `replace`d.
    //
    // `uri.replace(query: '', fragment: '')` does not drop those components,
    // it sets them to empty — and an empty-but-present query serialises. Every
    // saved connection was therefore stored as `https://host?#`, and every
    // XML-RPC endpoint built from it carried the same tail. Harmless in
    // practice, which is why it survived: servers ignore it, so the only place
    // it showed was the URL echoed back on the connection screen.
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  OdooConnection copyWith({
    Uri? baseUrl,
    String? database,
    String? username,
    OdooAuthMode? authMode,
  }) {
    return OdooConnection(
      baseUrl: baseUrl ?? this.baseUrl,
      database: database ?? this.database,
      username: username ?? this.username,
      authMode: authMode ?? this.authMode,
    );
  }

  @override
  List<Object?> get props => [baseUrl, database, username, authMode];

  @override
  String toString() =>
      'OdooConnection(${baseUrl.host}, db: $database, user: $username)';
}

/// An authenticated Odoo session: the connection plus the resolved user id.
///
/// Holding the uid separately from the credential keeps the secret out of
/// every object that gets passed around the app.
class OdooSession extends Equatable {
  const OdooSession({
    required this.connection,
    required this.userId,
    this.serverVersion,
  });

  final OdooConnection connection;

  /// The `uid` returned by `/xmlrpc/2/common.authenticate`.
  final int userId;

  /// e.g. `'18.0'`, used for capability heuristics only — feature detection
  /// always wins over version sniffing (spec §28).
  final String? serverVersion;

  int? get majorVersion {
    final raw = serverVersion?.split('.').firstOrNull;
    return raw == null ? null : int.tryParse(raw);
  }

  @override
  List<Object?> get props => [connection, userId, serverVersion];
}
