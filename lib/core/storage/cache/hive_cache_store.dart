import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../constants/storage_keys.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import 'cache_store.dart';

/// Hive-backed [CacheStore].
///
/// Values are stored as JSON strings under a small envelope carrying the write
/// timestamp, which keeps TTL logic out of every call site and avoids needing
/// a generated TypeAdapter per model.
///
/// ## Why this class does not encrypt the boxes
///
/// It used to, with `HiveAesCipher` over a 32-byte key generated per install
/// and kept in the keystore. The protection was real, but it sat at the wrong
/// layer and it cost more than it bought.
///
/// Both platforms already encrypt this file. iOS gives every file in the app
/// container Data Protection class C by default, so the boxes are unreadable
/// until the passcode has been entered once after boot, under a key the
/// Secure Enclave holds rather than one this process can be asked for.
/// Android has had file-based encryption on by default since 10, and the
/// boxes sit in app-private storage with backups turned off in the manifest.
/// A second AES pass on top of that defends against exactly one case: an
/// attacker holding root on an already-unlocked device — who can read the key
/// out of the keystore by the same means.
///
/// Set against that, an AES implementation shipped *inside the app* rather
/// than taken from the operating system is non-exempt encryption under
/// Category 5 Part 2 of the US export regulations. It turns every single
/// release into an export-compliance filing, permanently, for a threat the OS
/// already covers. Dropping it is what lets the answer to App Store Connect's
/// encryption question be "no" — see ITSAppUsesNonExemptEncryption in
/// ios/Runner/Info.plist.
///
/// Nothing that is actually secret lives here in the first place. Passwords
/// and API keys go to the Keychain / EncryptedSharedPreferences through the
/// credential vault, and every value in these boxes is something the
/// signed-in user can already read straight out of Odoo.
class HiveCacheStore implements CacheStore {
  HiveCacheStore();

  final Map<String, Box<String>> _boxes = {};

  static const String _valueKey = 'v';
  static const String _timestampKey = 't';

  /// Opens every box declared in [CacheBoxes]. Called once during bootstrap.
  ///
  /// Concurrently, not one after another. `runApp` waits behind this, and each
  /// box is a separate file to read off disk.
  ///
  /// Measured honestly: on a **first** launch this changes nothing, because
  /// every box is empty and each open is a few hundred microseconds — an A/B
  /// on an emulator put the two within noise of each other. What it bounds is
  /// the case that is not measured on a fresh install and is the one that
  /// matters on a cheap handset: eleven populated boxes, on eMMC storage, on a
  /// device whose flash is the slowest part of it. Independent files, so the
  /// wait is the slowest open rather than the sum of all eleven.
  Future<void> init() async {
    await Hive.initFlutter();

    final opened = await Future.wait(<Future<Box<String>>>[
      for (final name in CacheBoxes.all) _openOrRebuild(name),
    ]);

    for (var i = 0; i < CacheBoxes.all.length; i++) {
      _boxes[CacheBoxes.all[i]] = opened[i];
    }
  }

  /// Opens one box, and rebuilds it from empty if the file will not open.
  ///
  /// A box that cannot be read is not a reason to refuse to launch. `init` is
  /// awaited before `runApp`, so anything thrown here is not a crash on a
  /// screen the user can back out of — it is a phone that shows a blank
  /// window and keeps doing so on every relaunch, with no route to Settings →
  /// Clear cache and no way out but reinstalling.
  ///
  /// The trade is easy for the eleven read caches: Odoo is the source of
  /// truth and the next refresh rebuilds them. It is not free for the outbox,
  /// which is the one box holding writes that exist nowhere else — but a file
  /// Hive cannot open has already lost them, and deleting it at least gets the
  /// technician back to an app that can queue the next one.
  ///
  /// The case that made this necessary was self-inflicted: builds up to and
  /// including the ones already on the team's own devices wrote these boxes
  /// through an AES cipher, and this version opens them without one. Every
  /// such install hits exactly this path, once, and comes back empty rather
  /// than dead.
  Future<Box<String>> _openOrRebuild(String name) async {
    try {
      return await Hive.openBox<String>(name);
    } on Object catch (e) {
      AppLogger.warn(
        'Cache box "$name" would not open (${e.runtimeType}) — '
        'rebuilding it empty.',
      );
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<String>(name);
    }
  }

  @override
  Future<void> put<T>(String box, String key, T value) async {
    try {
      final envelope = jsonEncode(<String, dynamic>{
        _valueKey: value,
        _timestampKey: DateTime.now().toIso8601String(),
      });
      await _box(box).put(key, envelope);
    } on Object catch (e) {
      throw CacheException(
        'Could not save data locally.',
        technicalDetails: '$box/$key: ${e.runtimeType}',
      );
    }
  }

  @override
  Future<CacheEntry<T>?> get<T>(String box, String key) async {
    final raw = _box(box).get(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final storedAt = DateTime.tryParse('${decoded[_timestampKey]}');
      final value = decoded[_valueKey];
      if (storedAt == null || value is! T) return null;

      return CacheEntry<T>(value: value, storedAt: storedAt);
    } on FormatException {
      // A corrupt entry is not an error worth surfacing — drop it and refetch.
      await delete(box, key);
      return null;
    }
  }

  @override
  Future<void> delete(String box, String key) => _box(box).delete(key);

  @override
  Future<void> clearBox(String box) => _box(box).clear();

  @override
  Future<void> clearAll() async {
    for (final box in _boxes.values) {
      await box.clear();
    }
  }

  @override
  Future<List<String>> keys(String box) async =>
      _box(box).keys.map((k) => '$k').toList(growable: false);

  Box<String> _box(String name) {
    final box = _boxes[name];
    if (box == null) {
      throw CacheException(
        'Local storage is not ready.',
        technicalDetails: 'Box "$name" was never opened.',
      );
    }
    return box;
  }
}
