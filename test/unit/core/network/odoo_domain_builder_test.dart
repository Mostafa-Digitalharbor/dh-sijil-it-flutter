import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/network/odoo/odoo_domain_builder.dart';

void main() {
  group('OdooDomainBuilder', () {
    test('produces an empty domain when nothing is added', () {
      expect(OdooDomainBuilder().build(), isEmpty);
    });

    test('skips null values so optional filters stay optional', () {
      final domain = OdooDomainBuilder()
          .equals('category_id', null)
          .equals('employee_id', 4)
          .build();

      expect(domain, [
        ['employee_id', '=', 4],
      ]);
    });

    test('AND-s top level conditions implicitly', () {
      final domain = OdooDomainBuilder()
          .isSet('employee_id')
          .contains('name', 'macbook')
          .build();

      expect(domain, [
        ['employee_id', '!=', false],
        ['name', 'ilike', 'macbook'],
      ]);
    });

    test('emits n-1 OR markers before n operands', () {
      final domain = OdooDomainBuilder().searchAcross([
        'name',
        'serial_no',
        'model',
      ], 'DH-LAP-0027').build();

      expect(domain, [
        '|',
        '|',
        ['name', 'ilike', 'DH-LAP-0027'],
        ['serial_no', 'ilike', 'DH-LAP-0027'],
        ['model', 'ilike', 'DH-LAP-0027'],
      ]);
    });

    test('does not emit an OR marker for a single branch', () {
      final domain = OdooDomainBuilder().searchAcross([
        'name',
      ], 'laptop').build();

      expect(domain, [
        ['name', 'ilike', 'laptop'],
      ]);
    });

    test('ignores a blank search query', () {
      final domain = OdooDomainBuilder().searchAcross(['name'], '   ').build();

      expect(domain, isEmpty);
    });

    test('combines a search with filters', () {
      final domain = OdooDomainBuilder().equals('category_id', 3).searchAcross([
        'name',
        'serial_no',
      ], 'dell').build();

      expect(domain, [
        ['category_id', '=', 3],
        '|',
        ['name', 'ilike', 'dell'],
        ['serial_no', 'ilike', 'dell'],
      ]);
    });
  });
}
