import 'dart:convert';
import 'dart:math';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../constants/storage_keys.dart';
import '../../error/exceptions.dart';
import '../../security/credential_vault.dart';
import 'cache_store.dart';

/// Hive-backed [CacheStore].
///
/// Values are stored as JSON strings under a small envelope carrying the write
/// timestamp, which keeps TTL logic out of every call site and avoids needing
/// a generated TypeAdapter per model.
///
/// The boxes are opened with an AES cipher whose key lives in the OS keystore,
/// so a rooted device cannot read the cached asset list off disk.
class HiveCacheStore implements CacheStore {
  HiveCacheStore(this._vault);

  final CredentialVault _vault;
  final Map<String, Box<String>> _boxes = {};

  static const String _valueKey = 'v';
  static const String _timestampKey = 't';

  /// Opens every box declared in [CacheBoxes]. Called once during bootstrap.
  ///
  /// Concurrently, not one after another. `runApp` waits behind this, and each
  /// box is a separate file to read off disk and decrypt.
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
    final cipher = HiveAesCipher(await _resolveEncryptionKey());

    final opened = await Future.wait(<Future<Box<String>>>[
      for (final name in CacheBoxes.all)
        Hive.openBox<String>(name, encryptionCipher: cipher),
    ]);

    for (var i = 0; i < CacheBoxes.all.length; i++) {
      _boxes[CacheBoxes.all[i]] = opened[i];
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

  /// Reads the AES key from the keystore, generating one on first launch.
  Future<List<int>> _resolveEncryptionKey() async {
    final existing = await _vault.readHiveKey();
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _vault.writeHiveKey(base64Encode(key));
    return key;
  }
}
