import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/storage_keys.dart';
import 'package:sijil_it/core/error/exceptions.dart';
import 'package:sijil_it/core/sync/outbox_entry.dart';
import 'package:sijil_it/core/sync/outbox_store.dart';
import 'package:sijil_it/core/sync/write_queue.dart';

import '../../../fake_odoo/test_doubles.dart';

/// The queue is the one place in the app holding data that exists nowhere
/// else. Everything under `cache_*` can be thrown away and re-read from Odoo;
/// this cannot, which is why it is tested at the level of "does a write
/// survive" rather than "does the box round-trip".
void main() {
  late InMemoryCache cache;
  late OutboxStore outbox;

  setUp(() {
    cache = InMemoryCache();
    outbox = OutboxStore(cache);
  });

  tearDown(() => outbox.dispose());

  Future<OutboxEntry> queue({
    OutboxKind kind = OutboxKind.assignAsset,
    int subjectId = 101,
    String subjectName = 'MacBook Pro',
  }) => outbox.add(
    kind: kind,
    subjectId: subjectId,
    subjectName: subjectName,
    payload: <String, dynamic>{'employeeName': 'Ahmed'},
  );

  group('OutboxEntry', () {
    test('survives a round trip through the box', () {
      final entry = OutboxEntry(
        id: 'a',
        kind: OutboxKind.returnAsset,
        subjectId: 7,
        subjectName: 'ThinkPad',
        payload: const <String, dynamic>{'condition': 'damaged'},
        queuedAt: DateTime(2026, 8, 29, 14, 12),
        attempts: 2,
        lastError: 'timeout',
      );

      final restored = OutboxEntry.fromJson(entry.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, OutboxKind.returnAsset);
      expect(restored.subjectName, 'ThinkPad');
      expect(restored.payload['condition'], 'damaged');
      expect(restored.queuedAt, entry.queuedAt);
      expect(restored.attempts, 2);
    });

    test('a row this build cannot read is dropped, not thrown on', () {
      // Written by a newer version, or corrupted on disk. Either way it must
      // not take out the queue every other write is waiting behind.
      expect(
        OutboxEntry.fromJson(<String, dynamic>{'kind': 'teleportAsset'}),
        isNull,
      );
      expect(OutboxEntry.fromJson(<String, dynamic>{}), isNull);
    });

    test('it stops retrying rather than badging forever', () {
      // A queue that never empties is a badge that stops meaning anything.
      final entry = OutboxEntry(
        id: 'a',
        kind: OutboxKind.assignAsset,
        subjectId: 1,
        subjectName: 'x',
        payload: const <String, dynamic>{},
        queuedAt: DateTime(2026),
      );

      expect(entry.isBlocked, isFalse);
      expect(
        entry.copyWith(attempts: OutboxEntry.maxAttempts).isBlocked,
        isTrue,
      );
    });
  });

  group('OutboxStore', () {
    test('a queued write is still there on the next read', () async {
      await queue();

      final pending = await outbox.pending();
      expect(pending, hasLength(1));
      expect(pending.single.subjectName, 'MacBook Pro');
    });

    test('order is the order the technician worked in', () async {
      // Assign-then-return replayed the other way round leaves the asset held
      // by somebody who handed it back.
      final first = await queue(subjectId: 1, subjectName: 'first');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await queue(subjectId: 2, subjectName: 'second');

      final pending = await outbox.pending();
      expect(pending.map((e) => e.id), <String>[first.id, second.id]);
    });

    test('it says which assets it is holding a change for', () async {
      await queue(subjectId: 101);
      await queue(subjectId: 118);

      expect(await outbox.subjectIds(), <int>{101, 118});
    });

    test('the depth stream saves the badge from polling', () async {
      final depths = <int>[];
      final watch = outbox.depthChanged.listen(depths.add);

      final entry = await queue();
      await outbox.remove(entry.id);
      await Future<void>.delayed(Duration.zero);

      expect(depths, <int>[1, 0]);
      await watch.cancel();
    });

    test('an unreadable row is discarded on the way past', () async {
      await queue();
      await cache.put(CacheBoxes.outbox, 'junk', <String, dynamic>{'x': 1});

      expect(await outbox.pending(), hasLength(1));
      expect(await cache.keys(CacheBoxes.outbox), hasLength(1));
    });

    test('an attempt is recorded against the entry, not lost', () async {
      final entry = await queue();
      await outbox.save(entry.copyWith(attempts: 1, lastError: 'timeout'));

      final stored = (await outbox.pending()).single;
      expect(stored.attempts, 1);
      expect(stored.lastError, 'timeout');
    });
  });

  group('WriteQueue', () {
    test('offline, a write goes to the queue without being attempted', () async {
      // Six laptops offline is six socket timeouts if this is not asked first.
      final network = FakeNetworkInfo(connected: false);
      addTearDown(network.dispose);

      expect(await WriteQueue(network).shouldQueue(), isTrue);
    });

    test('online, it is attempted', () async {
      final network = FakeNetworkInfo();
      addTearDown(network.dispose);

      expect(await WriteQueue(network).shouldQueue(), isFalse);
    });

    test('while draining, nothing is queued — however it fails', () async {
      // Otherwise replaying a queued write that still cannot reach Odoo
      // enqueues it a second time, and the queue grows by one on every
      // attempt to empty it.
      final network = FakeNetworkInfo(connected: false);
      addTearDown(network.dispose);
      final queue = WriteQueue(network)..beginDrain();

      expect(await queue.shouldQueue(), isFalse);
      expect(queue.shouldQueueAfter(_unreachable), isFalse);

      queue.endDrain();
      expect(queue.shouldQueueAfter(_unreachable), isTrue);
    });

    test('a refusal is never queued, online or off', () async {
      // "You may not do this" is not a connection problem, and papering over
      // it with a retry hides the one message that explains the failure.
      final network = FakeNetworkInfo(connected: false);
      addTearDown(network.dispose);

      expect(
        WriteQueue(
          network,
        ).shouldQueueAfter(const AccessDeniedException('Odoo said no.')),
        isFalse,
      );
    });
  });
}

/// The shape a dropped connection actually arrives in.
const _unreachable = ConnectionException('Could not reach the Odoo server.');
