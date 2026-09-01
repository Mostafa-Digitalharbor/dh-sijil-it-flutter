import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/core/error/error_mapper.dart';
import 'package:sijil_it/core/error/exceptions.dart';
import 'package:sijil_it/core/error/failure_presenter.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/network/xmlrpc/xml_rpc_client.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../../../fake_odoo/fake_odoo_server.dart';

/// Being throttled is the one 4xx whose fix is the opposite of the others.
///
/// Every other 4xx means something is wrong with what the app sent — a bad
/// path, a proxy refusing it, a URL pointing somewhere that is not Odoo — and
/// all of them route the user to the connection screen. A 429 means the app
/// sent something *correct*, just too often. Sending that user to re-check a
/// URL that is already right is worse than saying nothing: they change a
/// working setting to fix a problem it did not cause.
///
/// The app is a plausible trigger rather than a theoretical one. Odoo Online
/// sits behind a rate limiter, a page of assets fans out into a chatter scan,
/// and an audit walks a fleet a page at a time.
void main() {
  late FakeOdooServer server;

  setUp(() async {
    server = FakeOdooServer();
    await server.start();
  });

  tearDown(() async => server.stop());

  Future<Object?> call() => DioXmlRpcClient.createDefault().call(
    endpoint: server.baseUrl.resolve(AppConstants.xmlRpcCommonPath),
    methodName: 'version',
    params: const [],
  );

  group('the transport recognises a throttled request', () {
    test('a 429 is not reported as an unreachable server', () async {
      server.httpStatus = 429;

      await expectLater(
        call(),
        throwsA(isA<RateLimitedException>()),
        reason:
            'a 429 used to fall through to ConnectionException, which sends '
            'the user to the connection screen to fix a correct URL',
      );
    });

    test('Retry-After in seconds is carried through', () async {
      server
        ..httpStatus = 429
        ..responseHeaders['Retry-After'] = '30';

      await expectLater(
        call(),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('a 429 with no Retry-After leaves the wait unquoted', () async {
      server.httpStatus = 429;

      await expectLater(
        call(),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            isNull,
          ),
        ),
      );
    });

    test(
      'a malformed Retry-After is treated as absent, never as zero',
      () async {
        server
          ..httpStatus = 429
          ..responseHeaders['Retry-After'] = 'soon-ish';

        await expectLater(
          call(),
          throwsA(
            isA<RateLimitedException>().having(
              (e) => e.retryAfter,
              'retryAfter',
              isNull,
            ),
          ),
          reason:
              '"try again now" against a server that just refused is the one '
              'answer guaranteed to be wrong',
        );
      },
    );

    test('an implausibly long wait is dropped rather than quoted', () async {
      server
        ..httpStatus = 429
        ..responseHeaders['Retry-After'] = '3600';

      await expectLater(
        call(),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            isNull,
          ),
        ),
        reason: 'an hour is true and useless on a screen somebody is holding',
      );
    });

    test(
      'a 503 carrying Retry-After is throttling, not a broken server',
      () async {
        // Some proxies shed load this way instead of with a 429. The advice is
        // the same, and "the server failed" would be a lie.
        server
          ..httpStatus = 503
          ..responseHeaders['Retry-After'] = '15';

        await expectLater(
          call(),
          throwsA(
            isA<RateLimitedException>().having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 15),
            ),
          ),
        );
      },
    );

    test('a plain 503 is still a server failure', () async {
      server.httpStatus = 503;

      await expectLater(call(), throwsA(isA<ServerException>()));
    });
  });

  group('the failure reaches the user as advice they can act on', () {
    late AppL10n en;
    late AppL10n ar;

    setUpAll(() async {
      en = await AppL10n.delegate.load(const Locale('en'));
      ar = await AppL10n.delegate.load(const Locale('ar'));
    });

    test('it maps to its own kind, not to serverUnreachable', () {
      final failure = ErrorMapper.map(
        const RateLimitedException(
          'throttled',
          retryAfter: Duration(seconds: 30),
        ),
      );

      expect(failure.kind, FailureKind.rateLimited);
      expect(failure.retryAfter, const Duration(seconds: 30));
    });

    test('the offered action is retry, never edit-connection', () {
      const failure = Failure(kind: FailureKind.rateLimited);

      expect(
        failure.action,
        FailureAction.retry,
        reason: 'the URL is correct — waiting is the fix',
      );
      expect(failure.isRetryable, isTrue);
    });

    test('the quoted wait names the number of seconds', () {
      final presented = FailurePresenter.present(
        en,
        const Failure(
          kind: FailureKind.rateLimited,
          retryAfter: Duration(seconds: 30),
        ),
      );

      expect(presented.fix, contains('30'));
    });

    test('one second is singular', () {
      expect(en.errorRateLimitedFixSeconds(1), 'Wait 1 second and try again.');
      expect(
        en.errorRateLimitedFixSeconds(30),
        'Wait 30 seconds and try again.',
      );
    });

    test('Arabic agrees with the number', () {
      // CLDR gives Arabic five categories; 3-10 is `few`, and it is the range
      // a Retry-After actually lands in.
      expect(ar.errorRateLimitedFixSeconds(1), contains('ثانية واحدة'));
      expect(ar.errorRateLimitedFixSeconds(2), contains('ثانيتين'));
      expect(ar.errorRateLimitedFixSeconds(5), contains('ثوانٍ'));
    });

    test('without a quoted wait it still says what to do', () {
      final presented = FailurePresenter.present(
        en,
        const Failure(kind: FailureKind.rateLimited),
      );

      expect(presented.fix, isNotEmpty);
      expect(presented.title, isNotEmpty);
      expect(presented.body, isNotEmpty);
      expect(
        presented.body.toLowerCase(),
        isNot(contains('url')),
        reason: 'the connection is fine and the copy must not imply otherwise',
      );
    });

    test('both languages have copy for the kind', () {
      for (final l10n in [en, ar]) {
        final presented = FailurePresenter.present(
          l10n,
          const Failure(kind: FailureKind.rateLimited),
        );
        expect(presented.title, isNotEmpty);
        expect(presented.fix, isNotEmpty);
      }
    });
  });

  group(
    "Odoo's own throttle, which arrives as a fault rather than a status",
    () {
      test('a login lockout is not reported as a generic server error', () {
        // Repeated bad passwords produce this with no HTTP status attached.
        // It used to read as "server error, try again", which is exactly the
        // advice that extends the lockout.
        final failure = ErrorMapper.map(
          const OdooFaultException(
            'Too many login attempts, please try again later',
          ),
        );

        expect(failure.kind, FailureKind.rateLimited);
      });

      test('an explicit rate-limit fault is classified too', () {
        final failure = ErrorMapper.map(
          const OdooFaultException('429: rate limit exceeded for this client'),
        );

        expect(failure.kind, FailureKind.rateLimited);
      });
    },
  );
}
