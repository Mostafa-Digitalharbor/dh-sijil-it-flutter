import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';
import '../error/exceptions.dart';
import '../network/odoo/odoo_connection.dart';

/// The only place in the app allowed to touch a password or API key.
///
/// Backed by the iOS Keychain and Android EncryptedSharedPreferences. Secrets
/// are never written to Hive, SharedPreferences, a log, or an app state object
/// (spec §25).
class CredentialVault {
  const CredentialVault(this._storage);

  final FlutterSecureStorage _storage;

  factory CredentialVault.createDefault() => const CredentialVault(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );

  /// Stores the credential under the key matching its [mode], so switching
  /// between a password and an API key never leaves the old one behind.
  Future<void> writeSecret(String secret, OdooAuthMode mode) async {
    try {
      await _clearAllSecretKeys();
      await _storage.write(key: _keyFor(mode), value: secret);
    } on Object catch (e) {
      throw CacheException(
        'Could not securely store your credentials on this device.',
        technicalDetails: '${e.runtimeType}',
      );
    }
  }

  /// Reads whichever credential is present.
  Future<String?> readSecret() async {
    try {
      final password = await _storage.read(key: SecureKeys.odooPassword);
      if (password != null && password.isNotEmpty) return password;
      return await _storage.read(key: SecureKeys.odooApiKey);
    } on Object catch (e) {
      throw CacheException(
        'Could not read your stored credentials.',
        technicalDetails: '${e.runtimeType}',
      );
    }
  }

  Future<bool> hasSecret() async {
    final secret = await readSecret();
    return secret != null && secret.isNotEmpty;
  }

  Future<void> clearSecret() => _clearAllSecretKeys();

  /// Wipes every stored secret. Used by "Sign out" and by
  /// Settings → Clear data.
  Future<void> wipe() => _storage.deleteAll();

  Future<void> _clearAllSecretKeys() async {
    await _storage.delete(key: SecureKeys.odooPassword);
    await _storage.delete(key: SecureKeys.odooApiKey);
  }

  String _keyFor(OdooAuthMode mode) => switch (mode) {
    OdooAuthMode.password => SecureKeys.odooPassword,
    OdooAuthMode.apiKey => SecureKeys.odooApiKey,
  };
}
