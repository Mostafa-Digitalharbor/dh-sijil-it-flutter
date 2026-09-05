/// Keys for secure storage, Hive boxes and preferences.
///
/// Secrets live **only** under [SecureKeys] (flutter_secure_storage, backed by
/// the Keychain / EncryptedSharedPreferences). Nothing under [CacheBoxes] or
/// [PrefKeys] may ever hold a password or API key (spec §25).
abstract final class SecureKeys {
  static const String odooPassword = 'odoo_password';
  static const String odooApiKey = 'odoo_api_key';

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
  static const String lastMetadataSync = 'last_metadata_sync';

  /// Warranty reminders: whether they are on, and how far ahead they fire.
  static const String remindersEnabled = 'reminders_enabled';
  static const String reminderLeadDays = 'reminder_lead_days';

  /// Whether the app asks for the device's own unlock before it opens.
  ///
  /// A preference and not a secret: it records a *choice*, and the thing it
  /// protects — the Odoo credential — is in the keychain either way. Storing
  /// the flag here keeps [SecureKeys] to the three values that are actually
  /// secret.
  static const String appLockEnabled = 'app_lock_enabled';

  /// When the stored credential last proved itself against Odoo, and how long
  /// it may go on doing so unattended.
  ///
  /// Not secrets: they are a timestamp and a number of days. What they guard
  /// *is* a secret, and it is in the keychain — these decide when the app
  /// throws it away.
  static const String lastAuthenticated = 'last_authenticated_at';
  static const String sessionMaxAgeDays = 'session_max_age_days';

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

  /// Expected return dates, mirrored from the chatter notes that record them.
  ///
  /// Separate from [localAssetState] rather than sharing the box: they are
  /// keyed the same way but hold different types, and one box holding two
  /// unrelated value shapes is how a read comes back as the wrong thing.
  static const String localAssetDue = 'local_asset_due';

  /// The last page and detail read for every list, kept so a technician with
  /// no signal sees the fleet they were looking at upstairs rather than an
  /// error screen.
  static const String assetPages = 'cache_asset_pages';
  static const String assetDetails = 'cache_asset_details';

  /// Writes made while offline, waiting for a connection (docs/OFFLINE.md).
  ///
  /// Not a cache: everything else under here is disposable and rebuilt on the
  /// next refresh, and this is the one box whose contents exist nowhere else.
  /// It is deliberately excluded from Settings → Clear cache.
  static const String outbox = 'outbox';

  static const List<String> all = <String>[
    metadata,
    categories,
    employees,
    departments,
    assets,
    userProfile,
    localAssetState,
    localAssetDue,
    assetPages,
    assetDetails,
    outbox,
  ];

  /// The boxes Settings → Clear cache is allowed to wipe.
  ///
  /// [outbox] is not among them, and neither is [localAssetState]: one holds
  /// writes Odoo has never seen, the other holds three states Odoo cannot
  /// express. Clearing either loses data rather than freeing space.
  static const List<String> disposable = <String>[
    metadata,
    categories,
    employees,
    departments,
    assets,
    userProfile,
    assetPages,
    assetDetails,
  ];

  const CacheBoxes._();
}
