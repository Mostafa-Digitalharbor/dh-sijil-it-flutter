import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/network/odoo/odoo_connection.dart';

/// The authenticated user, plus what their instance can do.
///
/// Bundled into one entity because every screen that needs one needs the
/// other: the dashboard shows the user's company *and* hides the maintenance
/// tile, from a single piece of state.
class SignedInUser extends Equatable {
  const SignedInUser({
    required this.session,
    required this.displayName,
    required this.login,
    required this.capabilities,
    this.email,
    this.companyName,
    this.avatar,
  });

  final OdooSession session;

  /// `res.users.name` — what the user is called, not their login.
  final String displayName;

  final String login;
  final String? email;
  final String? companyName;

  /// The user's photo, decoded. Null when they never set one, which is the
  /// common case — the avatar then falls back to their initials.
  final Uint8List? avatar;

  /// Which optional Odoo apps this instance has (spec §17).
  final OdooCapabilities capabilities;

  int get userId => session.userId;

  OdooConnection get connection => session.connection;

  String? get serverVersion => session.serverVersion;

  SignedInUser copyWith({OdooCapabilities? capabilities}) => SignedInUser(
    session: session,
    displayName: displayName,
    login: login,
    email: email,
    companyName: companyName,
    capabilities: capabilities ?? this.capabilities,
  );

  @override
  List<Object?> get props => [
    session,
    displayName,
    login,
    email,
    companyName,
    capabilities,
  ];
}
