import '../../utils/typedefs.dart';

/// Fluent builder for Odoo search domains (Builder pattern).
///
/// Odoo domains are prefix-notation lists that are painful to assemble by
/// hand and easy to get wrong. This type keeps that syntax in one place and
/// gives the filter/search feature a readable API:
///
/// ```dart
/// OdooDomainBuilder()
///     .equals('category_id', categoryId)
///     .isSet('employee_id')
///     .contains('name', query)
///     .build();
/// ```
///
/// Conditions added at the top level are AND-ed, matching Odoo's implicit
/// behaviour. Use [or] / [and] for explicit grouping.
class OdooDomainBuilder {
  OdooDomainBuilder();

  final List<Object?> _conditions = [];

  bool get isEmpty => _conditions.isEmpty;

  OdooDomainBuilder condition(String field, String operator, Object? value) {
    _conditions.add(<Object?>[field, operator, value]);
    return this;
  }

  OdooDomainBuilder equals(String field, Object? value) =>
      value == null ? this : condition(field, '=', value);

  OdooDomainBuilder notEquals(String field, Object? value) =>
      value == null ? this : condition(field, '!=', value);

  OdooDomainBuilder contains(String field, String? value) =>
      (value == null || value.trim().isEmpty)
      ? this
      : condition(field, 'ilike', value.trim());

  OdooDomainBuilder inList(String field, List<Object?>? values) =>
      (values == null || values.isEmpty)
      ? this
      : condition(field, 'in', values);

  OdooDomainBuilder notInList(String field, List<Object?>? values) =>
      (values == null || values.isEmpty)
      ? this
      : condition(field, 'not in', values);

  OdooDomainBuilder greaterOrEqual(String field, Object? value) =>
      value == null ? this : condition(field, '>=', value);

  OdooDomainBuilder lessOrEqual(String field, Object? value) =>
      value == null ? this : condition(field, '<=', value);

  /// `field != false` — the relational field is populated.
  OdooDomainBuilder isSet(String field) => condition(field, '!=', false);

  /// `field = false` — the relational field is empty.
  OdooDomainBuilder isNotSet(String field) => condition(field, '=', false);

  /// Includes archived records alongside active ones.
  OdooDomainBuilder includeArchived() =>
      condition('active', 'in', <Object?>[true, false]);

  /// Adds a raw, already-built condition. Escape hatch for exotic operators
  /// (`child_of`, `parent_of`, …).
  OdooDomainBuilder raw(List<Object?> condition) {
    _conditions.add(condition);
    return this;
  }

  /// OR-combines the domains produced by [branches].
  ///
  /// Odoo's prefix notation needs `n - 1` `'|'` markers before `n` operands.
  OdooDomainBuilder or(List<OdooDomain> branches) {
    final nonEmpty = branches.where((b) => b.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return this;
    if (nonEmpty.length == 1) {
      _conditions.addAll(nonEmpty.first);
      return this;
    }
    for (var i = 0; i < nonEmpty.length - 1; i++) {
      _conditions.add('|');
    }
    for (final branch in nonEmpty) {
      _conditions.addAll(_flatten(branch));
    }
    return this;
  }

  /// AND-combines the domains produced by [branches] explicitly.
  OdooDomainBuilder and(List<OdooDomain> branches) {
    final nonEmpty = branches.where((b) => b.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return this;
    if (nonEmpty.length == 1) {
      _conditions.addAll(nonEmpty.first);
      return this;
    }
    for (var i = 0; i < nonEmpty.length - 1; i++) {
      _conditions.add('&');
    }
    for (final branch in nonEmpty) {
      _conditions.addAll(_flatten(branch));
    }
    return this;
  }

  /// Negates a single sub-domain.
  OdooDomainBuilder not(OdooDomain branch) {
    if (branch.isEmpty) return this;
    _conditions.add('!');
    _conditions.addAll(_flatten(branch));
    return this;
  }

  /// Free-text search across several fields, OR-ed together.
  ///
  /// Powers the assets search bar (spec §11).
  OdooDomainBuilder searchAcross(List<String> fields, String? query) {
    if (query == null || query.trim().isEmpty || fields.isEmpty) return this;
    final term = query.trim();
    return or(
      fields
          .map(
            (f) => <Object?>[
              <Object?>[f, 'ilike', term],
            ],
          )
          .toList(),
    );
  }

  OdooDomain build() => List<Object?>.unmodifiable(_conditions);

  static List<Object?> _flatten(OdooDomain domain) => domain;

  /// The domain that matches everything.
  static OdooDomain get all => const <Object?>[];
}
