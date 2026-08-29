import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/security/log_sanitizer.dart';

/// Spec §25 makes these non-negotiable: a regression here leaks a customer's
/// Odoo credentials into a log file, so every pattern gets its own test.
void main() {
  group('LogSanitizer.scrub', () {
    test('redacts a password in a map dump', () {
      final result = LogSanitizer.scrub(
        '{db: prod, login: admin@company.com, password: hunter2}',
      );

      expect(result, isNot(contains('hunter2')));
      expect(result, contains('admin@company.com'));
    });

    test('redacts a quoted JSON api key', () {
      final result = LogSanitizer.scrub('{"api_key": "9f8a7b6c5d4e"}');

      expect(result, isNot(contains('9f8a7b6c5d4e')));
    });

    test('redacts an XML-RPC password element', () {
      final result = LogSanitizer.scrub(
        '<password>super-secret-value</password>',
      );

      expect(result, isNot(contains('super-secret-value')));
    });

    test('redacts basic-auth credentials embedded in a URL', () {
      final result = LogSanitizer.scrub(
        'POST https://admin:p4ssw0rd@company.odoo.com/xmlrpc/2/object',
      );

      expect(result, isNot(contains('p4ssw0rd')));
      expect(result, contains('company.odoo.com'));
    });

    test('leaves ordinary log lines untouched', () {
      const line = 'XML-RPC -> /xmlrpc/2/object :: execute_kw';

      expect(LogSanitizer.scrub(line), line);
    });
  });
}
