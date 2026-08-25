import 'package:equatable/equatable.dart';

/// An Odoo many2one value: `[id, "Display Name"]`.
///
/// A pure value object, in its own file rather than beside `OdooObjectService`
/// on purpose. It is the shape a category, a vendor, a department and an
/// employee reference all arrive in, so it travels all the way to the widget
/// that renders the name — and a Cubit importing the XML-RPC *service* just to
/// name a type is the layering violation `conventions_test` exists to catch.
class OdooNameRef extends Equatable {
  const OdooNameRef(this.id, this.name);

  final int id;
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];

  /// Parses `[3, "Laptop"]`. Returns null for Odoo's `false` empty-relation.
  static OdooNameRef? fromPair(Object? raw) {
    if (raw is List && raw.length >= 2 && raw[0] is int) {
      return OdooNameRef(raw[0] as int, '${raw[1]}');
    }
    return null;
  }

  @override
  String toString() => name;
}
