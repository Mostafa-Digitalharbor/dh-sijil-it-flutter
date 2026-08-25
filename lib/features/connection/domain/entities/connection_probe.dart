import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_capability_service.dart';

/// What a "Test connection" tap discovered.
///
/// Deliberately more than a boolean: the connection screen shows the Odoo
/// version and which optional apps were found, so the user learns what the
/// app will be able to do *before* signing in rather than by finding a tab
/// missing later.
class ConnectionProbe extends Equatable {
  const ConnectionProbe({
    required this.serverVersion,
    required this.isSecure,
    this.databases,
    this.capabilities,
  });

  /// e.g. `18.0`.
  final String serverVersion;

  /// False when the user insisted on plain HTTP.
  final bool isSecure;

  /// Populated only when the server allows `db.list`. Most production
  /// instances do not, and that is not an error (spec §3).
  final List<String>? databases;

  /// Only known after a successful sign-in — a capability probe needs a uid.
  final OdooCapabilities? capabilities;

  bool get canListDatabases => databases != null && databases!.isNotEmpty;

  int? get majorVersion => int.tryParse(serverVersion.split('.').first);

  ConnectionProbe copyWith({OdooCapabilities? capabilities}) => ConnectionProbe(
    serverVersion: serverVersion,
    isSecure: isSecure,
    databases: databases,
    capabilities: capabilities ?? this.capabilities,
  );

  @override
  List<Object?> get props => [serverVersion, isSecure, databases, capabilities];
}
