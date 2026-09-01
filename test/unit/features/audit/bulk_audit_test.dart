import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/audit/domain/entities/audit_session.dart';
import 'package:sijil_it/features/audit/presentation/cubit/audit_cubit.dart';

import '../../../fake_odoo/fake_odoo_data.dart';
import '../../../fake_odoo/test_app_harness.dart';
import '../../../fake_odoo/test_doubles.dart';

/// Counting a room full of assets at the speed somebody can point a camera.
///
/// ## What was slow, and why it mattered
///
/// Every scan used to be a network lookup — by id for a printed QR, by serial
/// for anything else — and while one was in flight every other detection was
/// dropped on the floor. On a stock-room connection that turned a count of
/// fifty into fifty pauses: scan, wait for the beep, scan. Worse, the drops
/// were silent, so a technician saw no confirmation, assumed a bad read, and
/// scanned the same sticker again.
///
/// The expected set is read once at the start precisely so the answer for
/// anything in scope is already on the device. These tests pin that: in-scope
/// scans resolve locally and instantly, out-of-scope ones still ask Odoo
/// because only Odoo knows what they are, and nothing is lost in between.
void main() {
  late FakeOdooData data;
  late InProcessOdooClient client;
  late AuditCubit cubit;

  setUp(() async {
    data = FakeOdooData.seeded();
    client = await configureTestDependencies(data: data);
    await signInForTest(data);
    cubit = sl<AuditCubit>();
  });

  tearDown(() async {
    await cubit.close();
    await sl.reset();
  });

  /// Starts a whole-fleet walk.
  Future<void> startWalk() async {
    await cubit.loadScopes();
    cubit.setScope(AuditScope.all);
    await cubit.start();
    expect(cubit.state.phase, AuditPhase.counting);
  }

  /// Serial numbers the fixture's assets actually carry.
  List<String> serialsInScope({int take = 3}) {
    final session = cubit.state.session!;
    return session.expected.values
        .map((a) => a.serialNumber)
        .whereType<String>()
        .take(take)
        .toList();
  }

  group('matching a code against the expected set', () {
    test('an asset:// payload resolves to the record it names', () async {
      await startWalk();
      final session = cubit.state.session!;
      final asset = session.expected.values.first;

      expect(session.matchLocally(asset.qrPayload)?.id, asset.id);
    });

    test('a printed serial resolves too', () async {
      await startWalk();
      final session = cubit.state.session!;
      final asset = session.expected.values.firstWhere(
        (a) => a.serialNumber != null,
      );

      expect(session.matchLocally(asset.serialNumber!)?.id, asset.id);
    });

    test('and does so whatever case the scanner reports', () async {
      // Some barcode readers upper-case everything and some do not. An audit
      // that misses an asset over a letter case is worse than no audit.
      await startWalk();
      final session = cubit.state.session!;
      final asset = session.expected.values.firstWhere(
        (a) => a.serialNumber != null,
      );

      expect(
        session.matchLocally(asset.serialNumber!.toLowerCase())?.id,
        asset.id,
      );
      expect(
        session.matchLocally(asset.serialNumber!.toUpperCase())?.id,
        asset.id,
      );
    });

    test('a code for nothing in scope does not match', () async {
      await startWalk();

      expect(cubit.state.session!.matchLocally('NOT-A-REAL-CODE'), isNull);
    });

    test('an empty code does not match', () async {
      await startWalk();

      expect(cubit.state.session!.matchLocally('   '), isNull);
    });

    test('a malformed payload is not read as an id', () async {
      await startWalk();

      expect(cubit.state.session!.matchLocally('asset://not-a-number'), isNull);
      expect(AuditSession.assetIdFromQrPayload('asset://12'), 12);
      expect(AuditSession.assetIdFromQrPayload('https://example.com'), isNull);
    });
  });

  group('walking a shelf', () {
    test('an in-scope scan is counted without asking Odoo', () async {
      await startWalk();
      final serial = serialsInScope(take: 1).single;

      client.calls.clear();
      await cubit.onDetected(serial);

      expect(cubit.state.session!.foundCount, 1);
      expect(
        client.calls,
        isEmpty,
        reason:
            'the expected set was read at the start precisely so this needs '
            'no round trip',
      );
    });

    test(
      'and is recorded the moment it is scanned, not after a wait',
      () async {
        await startWalk();
        final serial = serialsInScope(take: 1).single;

        // No `await` on a network call means the state is already right when
        // `onDetected` returns — which is what makes a fast walk possible.
        final pending = cubit.onDetected(serial);
        await pending;

        expect(cubit.state.isResolving, isFalse);
        expect(cubit.state.lastScan, isNotNull);
      },
    );

    test('several in a row all land', () async {
      await startWalk();
      final serials = serialsInScope(take: 3);

      for (final serial in serials) {
        await cubit.onDetected(serial);
      }

      expect(cubit.state.session!.foundCount, serials.length);
    });

    test('scanning the same sticker twice counts it once', () async {
      await startWalk();
      final serial = serialsInScope(take: 1).single;

      await cubit.onDetected(serial);
      cubit.clearLastCode();
      await cubit.onDetected(serial);

      expect(
        cubit.state.session!.foundCount,
        1,
        reason: 'rescanning is what people do when they are unsure of the beep',
      );
    });

    test('the camera repeating one code in frame is ignored', () async {
      await startWalk();
      final serial = serialsInScope(take: 1).single;

      await cubit.onDetected(serial);
      await cubit.onDetected(serial);
      await cubit.onDetected(serial);

      expect(cubit.state.session!.foundCount, 1);
    });

    test('progress advances with every distinct asset', () async {
      await startWalk();
      final before = cubit.state.session!.progress;

      for (final serial in serialsInScope(take: 2)) {
        await cubit.onDetected(serial);
      }

      expect(cubit.state.session!.progress, greaterThan(before));
    });
  });

  group('a code that is not in scope', () {
    test('still reaches Odoo, because only Odoo knows what it is', () async {
      await startWalk();

      client.calls.clear();
      await cubit.onDetected('NOT-IN-THIS-FLEET');

      expect(
        client.calls,
        isNotEmpty,
        reason: 'an unexpected asset is a finding the audit has to name',
      );
    });

    test('and an unmatched one is surfaced rather than swallowed', () async {
      await startWalk();

      await cubit.onDetected('NOT-IN-THIS-FLEET');

      expect(cubit.state.unknownCode, 'NOT-IN-THIS-FLEET');
    });
  });

  group('the whole walk', () {
    test('finishing turns everything unscanned into missing', () async {
      await startWalk();
      final expectedCount = cubit.state.session!.expectedCount;
      final serials = serialsInScope(take: 2);

      for (final serial in serials) {
        await cubit.onDetected(serial);
      }
      cubit.finish();

      final session = cubit.state.session!;
      expect(session.isFinished, isTrue);
      expect(session.foundCount, serials.length);
      expect(session.missingCount, expectedCount - serials.length);
      expect(session.missing, hasLength(expectedCount - serials.length));
    });

    test('the report can be reopened and counting resumed', () async {
      await startWalk();
      await cubit.onDetected(serialsInScope(take: 1).single);
      cubit.finish();

      cubit.resume();

      expect(cubit.state.phase, AuditPhase.counting);
      expect(cubit.state.session!.isFinished, isFalse);
      expect(
        cubit.state.session!.foundCount,
        1,
        reason: 'reopening must not throw away what was already counted',
      );
    });

    test('a scan after finishing is ignored', () async {
      await startWalk();
      cubit.finish();

      await cubit.onDetected(serialsInScope(take: 1).single);

      expect(cubit.state.session!.foundCount, 0);
    });
  });
}
