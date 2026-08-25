/// Keys for secure storage, Hive boxes and preferences.
///
/// Secrets live **only** under [SecureKeys] (flutter_secure_storage, backed by
/// the Keychain / EncryptedSharedPreferences). Nothing under [CacheBoxes] or
/// [PrefKeys] may ever hold a password or API key (spec §25).
abstract final class SecureKeys {
  static const String odooPassword = 'odoo_password';
  static const String odooApiKey = 'odoo_api_key';
  static const String hiveEncryptionKey = 'hive_cipher_key';

  const SecureKeys._();
}

/// Non-secret connection details and user preferences.
abstract final class PrefKeys {
  static const String odooBaseUrl = 'odoo_base_url';
  static const String odooDatabase = 'odoo_database';
  static const String odooUsername = 'odoo_username';
  static const String odooUserId = 'odoo_uid';
  static const String odooServerVersion = 'odoo_server_version';
  static const String authMode = 'odoo_auth_mode'; // password | apiKey
  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String lastMetadataSync = 'last_metadata_sync';

  const PrefKeys._();
}

/// Hive box names for the offline cache. Odoo remains the source of truth
/// (spec §24) — everything here is disposable and rebuilt on refresh.
abstract final class CacheBoxes {
  static const String metadata = 'cache_metadata';
  static const String categories = 'cache_categories';
  static const String employees = 'cache_employees';
  static const String departments = 'cache_departments';
  static const String assets = 'cache_assets';
  static const String userProfile = 'cache_user_profile';

  /// Locally-maintained asset states that standard Odoo cannot express
  /// (Reserved / Damaged / Lost). Documented in docs/ARCHITECTURE.md.
  static const String localAssetState = 'local_asset_state';

  static const List<String> all = <String>[
    metadata,
    categories,
    employees,
    departments,
    assets,
    userProfile,
    localAssetState,
  ];

  const CacheBoxes._();
}
