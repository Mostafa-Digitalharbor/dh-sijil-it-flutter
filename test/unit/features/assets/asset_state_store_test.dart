import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/network/odoo/odoo_chatter_service.dart';
import 'package:sijil_it/core/storage/cache/cache_store.dart';
import 'package:sijil_it/features/assets/data/services/asset_note_vocabulary.dart';
import 'package:sijil_it/features/assets/data/services/asset_state_store.dart';
import 'package:sijil_it/features/assets/data/services/local_asset_state_store.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';

/// Reserved, Damaged and Lost have no Odoo field, so the note the app posts to
/// the asset's chatter *is* the record of them (docs/ARCHITECTURE.md §6).
///
/// Two things have to hold for that to be true, and both are easy to break
/// without noticing. The note has to parse back into the state it was written
/// from — including notes written by older versions, which are already in the
/// customer's database. And Odoo has to outrank the device: the bug this whole
/// path replaced was a "Damaged" that only one handset could see.
void main() {
  const model = OdooModels.maintenanceEquipment;

  group('the note is the record', () {
    test('every state round-trips through the note it is written as', () {
      for (final status in AssetStatus.values) {
        expect(
          AssetNoteVocabulary.statusIn(AssetNoteVocabulary.statusNote(status)),
          status,
          reason: '${status.name} did not survive the round trip',
        );
      }
    });

    test('a longer label is not read as a shorter one it starts with', () {
      // "Under maintenance" against a table that also holds "Under"-prefixed
      // labels is the classic way a parser silently picks the wrong state.
      final note = AssetNoteVocabulary.statusNote(AssetStatus.underMaintenance);

      expect(AssetNoteVocabulary.statusIn(note), AssetStatus.underMaintenance);
    });

    test('notes written by older versions of the app still parse', () {
      // Retroactive by design: this is the wording shipped before the states
      // moved to Odoo, and it is what is in the customer's database today.
      const legacy =
          'Status set to Damaged from the Sijil IT mobile app. This state has '
          'no standard Odoo field and is kept on the device that recorded it.';

      expect(AssetNoteVocabulary.statusIn(legacy), AssetStatus.damaged);
    });

    test('a note somebody typed in the web client is not a status', () {
      expect(AssetNoteVocabulary.statusIn('Sent to the repair shop'), isNull);
      expect(
        AssetNoteVocabulary.statusIn('Assigned to Sara on 2026-08-01.'),
        isNull,
      );
    });

    test('a status note is classified as a status change in the history', () {
      final kind = AssetNoteVocabulary.classify(
        AssetNoteVocabulary.statusNote(AssetStatus.lost),
      );

      expect(kind.name, 'statusChanged');
    });
  });

  group('reading', () {
    test('Odoo outranks what this device remembers', () async {
      // The bug this replaced: one handset marks an asset Damaged, everybody
      // else keeps seeing what their own box says.
      final mirror = _mirrorWith(<int, AssetStatus>{7: AssetStatus.damaged});
      final store = AssetStateStore(
        mirror: mirror,
        chatter: _ChatterSaying(<int, AssetStatus>{7: AssetStatus.lost}),
      );

      expect(await store.read(model, 7), AssetStatus.lost);
    });

    test('a read that finds no note clears the stale mirror', () async {
      // Absence is an answer: it means the state was cleared in Odoo, and
      // honouring the mirror there is how a "Damaged" outlives its return.
      final mirror = _mirrorWith(<int, AssetStatus>{7: AssetStatus.damaged});
      final store = AssetStateStore(
        mirror: mirror,
        chatter: _ChatterSaying(const <int, AssetStatus>{}),
      );

      expect(await store.read(model, 7), isNull);
      expect(await mirror.read(model, 7), isNull, reason: 'mirror not cleared');
    });

    test('an unreachable Odoo falls back to the mirror', () async {
      // A technician in a basement server room still sees what they recorded
      // upstairs — the one thing the device copy is still for.
      final mirror = _mirrorWith(<int, AssetStatus>{7: AssetStatus.reserved});
      final store = AssetStateStore(mirror: mirror, chatter: _brokenChatter);

      expect(await store.read(model, 7), AssetStatus.reserved);
    });

    test(
      'a note recording a derivable state clears rather than sets',
      () async {
        // "Status set to Available" is how the state gets *removed*; storing it
        // would leave an overlay claiming something Odoo already proves.
        final store = AssetStateStore(
          mirror: _mirrorWith(const <int, AssetStatus>{}),
          chatter: _ChatterSaying(<int, AssetStatus>{7: AssetStatus.available}),
        );

        expect(await store.read(model, 7), isNull);
      },
    );

    test('a page is one query, not one per row', () async {
      final chatter = _ChatterSaying(<int, AssetStatus>{
        2: AssetStatus.reserved,
        5: AssetStatus.lost,
      });
      final store = AssetStateStore(
        mirror: _mirrorWith(const <int, AssetStatus>{}),
        chatter: chatter,
      );

      final states = await store.readAll(model, <int>[1, 2, 3, 4, 5]);

      expect(states, <int, AssetStatus>{
        2: AssetStatus.reserved,
        5: AssetStatus.lost,
      });
      expect(chatter.calls, 1, reason: 'fifty rows would be fifty round trips');
    });

    test(
      'the mirror is refreshed from what Odoo said, for the next flight',
      () async {
        final mirror = _mirrorWith(const <int, AssetStatus>{});
        final store = AssetStateStore(
          mirror: mirror,
          chatter: _ChatterSaying(<int, AssetStatus>{2: AssetStatus.reserved}),
        );

        await store.readAll(model, <int>[1, 2]);

        expect(await mirror.read(model, 2), AssetStatus.reserved);
        expect(await mirror.read(model, 1), isNull);
      },
    );
  });

  group('fleet counts', () {
    test('come from Odoo, so every device totals the same dashboard', () async {
      final store = AssetStateStore(
        mirror: _mirrorWith(<int, AssetStatus>{9: AssetStatus.damaged}),
        chatter: _ChatterSaying(<int, AssetStatus>{
          1: AssetStatus.reserved,
          2: AssetStatus.reserved,
          3: AssetStatus.lost,
        }),
      );

      final statuses = await store.statuses(model);

      expect(statuses.length, 3);
      expect(
        statuses.where((s) => s == AssetStatus.reserved).length,
        2,
        reason: 'the dashboard counts these, so duplicates must survive',
      );
    });

    test('fall back to the mirror when Odoo cannot be reached', () async {
      final store = AssetStateStore(
        mirror: _mirrorWith(<int, AssetStatus>{9: AssetStatus.damaged}),
        chatter: _brokenChatter,
      );

      expect(await store.statuses(model), <AssetStatus>[AssetStatus.damaged]);
    });
  });
}

LocalAssetStateStore _mirrorWith(Map<int, AssetStatus> seed) {
  final cache = _MemoryCache();
  for (final entry in seed.entries) {
    cache.box['${OdooModels.maintenanceEquipment}:${entry.key}'] =
        entry.value.name;
  }
  return LocalAssetStateStore(cache);
}

_ChatterSaying get _brokenChatter =>
    _ChatterSaying(const <int, AssetStatus>{}, fails: true);

/// Answers with the notes the app would have written for [states].
///
/// Composes them through [AssetNoteVocabulary] rather than hand-writing the
/// strings, so a change to the wording is exercised here rather than mocked
/// past.
class _ChatterSaying implements OdooChatterService {
  _ChatterSaying(this.states, {this.fails = false});

  final Map<int, AssetStatus> states;
  final bool fails;

  /// How many round trips this fake was asked for. A page must cost one.
  int calls = 0;

  @override
  Future<Map<int, String>> latestBodies({
    required String model,
    required String contains,
    List<int>? ids,
    int limit = 400,
  }) async {
    if (fails) throw StateError('Odoo unreachable');
    calls++;

    return <int, String>{
      for (final entry in states.entries)
        if (ids == null || ids.contains(entry.key))
          entry.key: AssetNoteVocabulary.statusNote(entry.value),
    };
  }

  @override
  Future<List<ChatterEntry>> history({
    required String model,
    required int id,
    int limit = 60,
  }) async => const <ChatterEntry>[];
}

/// The Hive box, without Hive.
class _MemoryCache implements CacheStore {
  final Map<String, Object?> box = <String, Object?>{};

  @override
  Future<CacheEntry<T>?> get<T>(String boxName, String key) async {
    final value = box[key];
    if (value is! T) return null;
    return CacheEntry<T>(value: value, storedAt: DateTime(2026));
  }

  @override
  Future<void> put<T>(String boxName, String key, T value) async {
    box[key] = value;
  }

  @override
  Future<void> delete(String boxName, String key) async => box.remove(key);

  @override
  Future<void> clearBox(String boxName) async => box.clear();

  @override
  Future<void> clearAll() async => box.clear();

  @override
  Future<List<String>> keys(String boxName) async => box.keys.toList();
}
