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

  bool get isSecure => baseUrl.scheme == 'https';

  Uri _endpoint(String path) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base$path');
  }

  /// Normalises whatever the user typed into a usable base [Uri].
  ///
  /// Accepts `company.odoo.com`, `https://company.odoo.com/`, or a host with a
  /// port or sub-path. Defaults to HTTPS (spec §25).
  static Uri parseBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const InputValidationException('Enter your Odoo server URL.');
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);

    if (uri == null || uri.host.isEmpty) {
      throw const InputValidationException(
        'That does not look like a valid server URL.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const InputValidationException(
        'The server URL must start with https://',
      );
    }

    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;

    return uri.replace(path: path, query: '', fragment: '');
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
