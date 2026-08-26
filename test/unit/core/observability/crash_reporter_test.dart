import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sijil_it/core/observability/crash_reporter.dart';

/// What the crash reporter is allowed to transmit.
///
/// The app holds an Odoo password or API key, so a crash report is the one
/// path by which a customer's credential could leave their device for a third
/// party. Every test below is a specific way that has happened to real apps:
/// an exception whose own message quotes the failed request, a breadcrumb
/// logging a request body, a `user` block attached automatically, an HTTP
/// context carrying an `Authorization` header.
///
/// These assert on the *outgoing* event rather than on the scrubber's internals
/// on purpose — the question is not "does LogSanitizer work" (covered in
/// log_sanitizer_test.dart), it is "does anything reach the wire without
/// passing through it".
void main() {
  const secret = 'sk-live-9f2b7c41aa';

  /// Fails if [haystack] still contains a credential anywhere in its rendering.
  void expectNoSecret(Object? haystack, {String reason = ''}) {
    expect(
      haystack.toString(),
      isNot(contains(secret)),
      reason: 'A credential survived scrubbing. $reason',
    );
  }

  group('exception messages', () {
    test('a password in an exception value is redacted', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'OdooFault',
            value:
                'AccessDenied while calling authenticate '
                '{"login": "you@company.com", "password": "$secret"}',
          ),
        ],
      );

      final sent = CrashReporter.scrubEvent(event);

      expectNoSecret(sent.exceptions!.single.value);
      expect(
        sent.exceptions!.single.value,
        contains('***REDACTED***'),
        reason: 'The shape of the message should survive; only the value goes.',
      );
      expect(
        sent.exceptions!.single.value,
        contains('you@company.com'),
        reason:
            'Over-scrubbing is its own failure: a report with nothing left in '
            'it cannot be debugged.',
      );
    });

    test('an api key in the event message is redacted', () {
      final event = SentryEvent(
        message: SentryMessage('sign-in failed with api_key=$secret'),
      );

      expectNoSecret(CrashReporter.scrubEvent(event).message?.formatted);
    });

    test('an XML-RPC password element is redacted', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'XmlRpcFault',
            value: '<params><password>$secret</password></params>',
          ),
        ],
      );

      expectNoSecret(CrashReporter.scrubEvent(event).exceptions!.single.value);
    });
  });

  group('breadcrumbs', () {
    test('a credential in a breadcrumb message is redacted', () {
      final event = SentryEvent(
        breadcrumbs: [
          Breadcrumb(message: 'POST /xmlrpc/2/object token=$secret'),
        ],
      );

      expectNoSecret(
        CrashReporter.scrubEvent(event).breadcrumbs!.single.message,
      );
    });

    test('a credential in breadcrumb data is redacted', () {
      final crumb = Breadcrumb(
        message: 'request',
        data: <String, dynamic>{
          'url': 'https://user:$secret@company.odoo.com/xmlrpc/2/object',
          'status': 401,
        },
      );

      final scrubbed = CrashReporter.scrubBreadcrumb(crumb);

      expectNoSecret(scrubbed.data);
      expect(
        scrubbed.data!['status'],
        401,
        reason: 'Non-string values must pass through untouched.',
      );
    });

    test('the breadcrumb hook scrubs on the way in, not only on send', () {
      // Two gates, deliberately. `beforeBreadcrumb` keeps the secret out of the
      // in-memory ring buffer, so a crash report is not the only thing that
      // would have leaked it — a debug dump of the buffer would too.
      final crumb = Breadcrumb(message: 'password: $secret');
      expectNoSecret(CrashReporter.scrubBreadcrumb(crumb).message);
    });
  });

  group('what is never attached', () {
    test('the signed-in user is stripped', () {
      final event = SentryEvent(
        user: SentryUser(
          id: '2',
          username: 'admin@company.com',
          email: 'mostafa.bader@company.com',
        ),
      );

      expect(
        CrashReporter.scrubEvent(event).user,
        isNull,
        reason:
            "A customer's employee identity is not ours to send to a third "
            'party they were never asked about.',
      );
    });

    test('request headers, cookies and query string are dropped', () {
      final event = SentryEvent(
        request: SentryRequest(
          url: 'https://company.odoo.com/xmlrpc/2/object',
          method: 'POST',
          queryString: 'api_key=$secret',
          cookies: 'session_id=$secret',
          headers: <String, String>{'Authorization': 'Basic $secret'},
          data: '<methodCall><password>$secret</password></methodCall>',
        ),
      );

      final sent = CrashReporter.scrubEvent(event).request!;

      expectNoSecret(sent, reason: 'The whole request object was checked.');
      expect(sent.queryString, isNull);
      expect(sent.cookies, isNull);
      expect(sent.headers, isEmpty);
      expect(
        sent.url,
        'https://company.odoo.com/xmlrpc/2/object',
        reason:
            'Which endpoint broke is the one thing worth keeping, so an '
            'allow-list keeps it rather than dropping the request wholesale.',
      );
      expect(sent.method, 'POST');
    });

    test('basic-auth credentials in the URL are redacted', () {
      final event = SentryEvent(
        request: SentryRequest(
          url: 'https://admin:$secret@company.odoo.com/xmlrpc/2/object',
        ),
      );

      expectNoSecret(CrashReporter.scrubEvent(event).request!.url);
    });
  });

  group('configuration', () {
    test('reporting is off when no DSN is compiled in', () {
      // The test binary passes no --dart-define, which is exactly the state a
      // developer's `flutter run` is in. If this ever fails, a DSN was
      // hardcoded and every developer machine started reporting.
      expect(CrashReporter.dsn, isEmpty);
      expect(CrashReporter.isEnabled, isFalse);
    });

    test('capture is a no-op while disabled', () async {
      // Must not throw, and must not need the SDK to be initialised — call
      // sites are not expected to guard.
      await expectLater(
        CrashReporter.capture(Exception('boom'), StackTrace.current),
        completes,
      );
    });
  });
}
