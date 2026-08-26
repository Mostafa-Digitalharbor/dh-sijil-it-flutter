import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/audit/domain/entities/audit_session.dart';

/// The count is the only number an audit produces, so the arithmetic behind it
/// is the part that has to be right. These are the cases a walk actually hits:
/// the same sticker scanned twice, something scanned that was never in scope,
/// and the moment "missing" becomes knowable.
void main() {
  Asset asset(int id, [String? name]) =>
      Asset(id: id, name: name ?? 'Asset $id', status: AssetStatus.available);

  AuditSession sessionOf(List<int> expected) => AuditSession(
    startedAt: DateTime(2026, 8, 24, 9),
    scope: AuditScope.all,
    expected: <int, Asset>{for (final id in expected) id: asset(id)},
  );

  final at = DateTime(2026, 8, 24, 9, 5);

  group('counting', () {
    test('a fresh session has found nothing and is missing everything', () {
      final session = sessionOf([1, 2, 3]);

      expect(session.expectedCount, 3);
      expect(session.foundCount, 0);
      expect(session.missingCount, 3);
      expect(session.progress, 0);
    });

    test('scanning something in scope counts it found', () {
      final session = sessionOf([1, 2]).record(asset(1), at);

      expect(session.foundCount, 1);
      expect(session.missingCount, 1);
      expect(session.progress, 0.5);
    });

    test('scanning the same sticker twice does not count it twice', () {
      // What people do when they are not sure the first beep registered.
      final session = sessionOf([1, 2])
          .record(asset(1), at)
          .record(asset(1), at.add(const Duration(seconds: 3)));

      expect(session.foundCount, 1);
      expect(session.results.length, 1);
    });

    test('scanning something outside the scope is a finding, not progress', () {
      final session = sessionOf([1, 2]).record(asset(99), at);

      expect(session.unexpectedCount, 1);
      expect(session.foundCount, 0, reason: 'it was never expected here');
      expect(session.missingCount, 2);
      expect(
        session.progress,
        0,
        reason: 'an out-of-scope scan must not push the ring toward done',
      );
    });

    test('progress cannot exceed one however many strays are scanned', () {
      var session = sessionOf([1]);
      for (var id = 90; id < 96; id++) {
        session = session.record(asset(id), at);
      }
      session = session.record(asset(1), at);

      expect(session.progress, 1.0);
    });

    test(
      'an empty scope reports zero progress rather than dividing by zero',
      () {
        expect(sessionOf(const <int>[]).progress, 0);
      },
    );
  });

  group('missing', () {
    test('is everything unscanned, and only meaningful at the end', () {
      final session = sessionOf([1, 2, 3]).record(asset(2), at);

      expect(session.missing.map((a) => a.id), <int>[1, 3]);
    });

    test('excludes out-of-scope scans, which were never expected', () {
      final session = sessionOf([1]).record(asset(50), at);

      expect(session.missing.map((a) => a.id), <int>[1]);
    });

    test('is empty once every expected asset has been seen', () {
      final session = sessionOf([
        1,
        2,
      ]).record(asset(1), at).record(asset(2), at);

      expect(session.missing, isEmpty);
      expect(session.missingCount, 0);
    });
  });

  group('feed', () {
    test('is newest first, so the last scan is the one on screen', () {
      final session = sessionOf([1, 2, 3])
          .record(asset(1), at)
          .record(asset(2), at.add(const Duration(seconds: 10)))
          .record(asset(3), at.add(const Duration(seconds: 20)));

      expect(session.feed.map((e) => e.asset.id), <int>[3, 2, 1]);
    });
  });

  group('finishing', () {
    test('a session is not finished until it is', () {
      expect(sessionOf([1]).isFinished, isFalse);
      expect(
        sessionOf([
          1,
        ]).copyWith(finishedAt: DateTime(2026, 8, 24, 10)).isFinished,
        isTrue,
      );
    });

    test('finishing keeps the results it had', () {
      final finished = sessionOf([
        1,
        2,
      ]).record(asset(1), at).copyWith(finishedAt: DateTime(2026, 8, 24, 10));

      expect(finished.foundCount, 1);
      expect(finished.missing.single.id, 2);
    });
  });
}
