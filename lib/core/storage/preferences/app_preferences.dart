import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/storage_keys.dart';
import '../../network/odoo/odoo_connection.dart';

/// Non-secret settings: connection details, theme, locale.
///
/// Deliberately separate from [CredentialVault] so it is structurally
/// impossible to write a password here by accident (spec §25).
class AppPreferences {
  const AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppPreferences> create() async =>
      AppPreferences(await SharedPreferences.getInstance());

  // ── Odoo connection ──────────────────────────────────────────────────────

  /// The saved connection, or null when the app has never been configured.
  OdooConnection? readConnection() {
    final url = _prefs.getString(PrefKeys.odooBaseUrl);
    final database = _prefs.getString(PrefKeys.odooDatabase);
    final username = _prefs.getString(PrefKeys.odooUsername);

    if (url == null || database == null || username == null) return null;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    return OdooConnection(
      baseUrl: uri,
      database: database,
      username: username,
      authMode: OdooAuthMode.fromName(_prefs.getString(PrefKeys.authMode)),
    );
  }

  Future<void> saveConnection(OdooConnection connection) async {
    await _prefs.setString(PrefKeys.odooBaseUrl, connection.baseUrl.toString());
    await _prefs.setString(PrefKeys.odooDatabase, connection.database);
    await _prefs.setString(PrefKeys.odooUsername, connection.username);
    await _prefs.setString(PrefKeys.authMode, connection.authMode.name);
  }

  Future<void> clearConnection() async {
    await _prefs.remove(PrefKeys.odooBaseUrl);
    await _prefs.remove(PrefKeys.odooDatabase);
    await _prefs.remove(PrefKeys.odooUsername);
    await _prefs.remove(PrefKeys.authMode);
    await _prefs.remove(PrefKeys.odooUserId);
    await _prefs.remove(PrefKeys.odooServerVersion);
  }

  // ── Warranty reminders ───────────────────────────────────────────────────

  /// Off until the user turns it on.
  ///
  /// Default-off because turning it on is what asks the OS for the
  /// notification permission, and a permission prompt nobody expected is a
  /// permission denied for good.
  bool get remindersEnabled =>
      _prefs.getBool(PrefKeys.remindersEnabled) ?? false;

  Future<void> setRemindersEnabled({required bool value}) =>
      _prefs.setBool(PrefKeys.remindersEnabled, value);

  /// How many days before a warranty ends the reminder fires.
  int get reminderLeadDays =>
      _prefs.getInt(PrefKeys.reminderLeadDays) ?? defaultReminderLeadDays;

  Future<void> setReminderLeadDays(int days) =>
      _prefs.setInt(PrefKeys.reminderLeadDays, days);

  /// A month: long enough to raise a renewal, short enough to still be true.
  static const int defaultReminderLeadDays = 30;

  /// The windows the settings screen offers.
  static const List<int> reminderLeadOptions = <int>[7, 30, 60];

  int? get userId => _prefs.getInt(PrefKeys.odooUserId);

  Future<void> setUserId(int? value) async {
    if (value == null) {
      await _prefs.remove(PrefKeys.odooUserId);
    } else {
      await _prefs.setInt(PrefKeys.odooUserId, value);
    }
  }

  String? get serverVersion => _prefs.getString(PrefKeys.odooServerVersion);

  Future<void> setServerVersion(String? value) async {
    if (value == null) {
      await _prefs.remove(PrefKeys.odooServerVersion);
    } else {
      await _prefs.setString(PrefKeys.odooServerVersion, value);
    }
  }

  // ── App lock ─────────────────────────────────────────────────────────────

  /// Whether the device's own unlock is asked for before the app opens.
  ///
  /// Off by default, and stays a *preference* rather than a secret: it records
  /// a choice, and the thing it guards — the Odoo credential — is in the
  /// keychain either way. Nothing here is worth encrypting.
  bool get appLockEnabled => _prefs.getBool(PrefKeys.appLockEnabled) ?? false;

  Future<void> setAppLockEnabled({required bool value}) =>
      _prefs.setBool(PrefKeys.appLockEnabled, value);

  // ── Appearance ───────────────────────────────────────────────────────────

  ThemeMode get themeMode => switch (_prefs.getString(PrefKeys.themeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(PrefKeys.themeMode, mode.name);

  String? get localeCode => _prefs.getString(PrefKeys.locale);

  Future<void> setLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove(PrefKeys.locale);
    } else {
      await _prefs.setString(PrefKeys.locale, code);
    }
  }

  // ── Metadata sync bookkeeping ────────────────────────────────────────────

  DateTime? get lastMetadataSync {
    final raw = _prefs.getString(PrefKeys.lastMetadataSync);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastMetadataSync(DateTime value) =>
      _prefs.setString(PrefKeys.lastMetadataSync, value.toIso8601String());
}
