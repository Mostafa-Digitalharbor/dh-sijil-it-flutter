import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/preferences/app_preferences.dart';

/// The two presentation choices that outlive a screen: theme mode and locale.
///
/// Lives above the router so a change repaints and re-lays-out the whole app —
/// switching to Arabic flips the entire tree to RTL through
/// `MaterialApp.locale`, with no `Directionality` widget anywhere in feature
/// code.
class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit(this._preferences)
    : super(
        AppSettingsState(
          themeMode: _preferences.themeMode,
          locale: _localeFrom(_preferences.localeCode),
        ),
      );

  final AppPreferences _preferences;

  /// Locales the app ships translations for. `null` inside [AppSettingsState]
  /// means "follow the device".
  /// Locales the app resolves to, in preference order.
  ///
  /// Arabic is listed as **ar_EG before plain ar**, and the order is
  /// load-bearing. Flutter picks the first entry whose language matches, so
  /// every Arabic device lands on `ar_EG` — the locale CLDR still gives the
  /// Arabic-Indic digit set. Generic `ar` now formats numbers in Latin, which
  /// would put `124` in a placeholder directly beside the `١٢٤` written into
  /// the copy. `app_ar_EG.arb` is empty; gen_l10n has that class extend the
  /// `ar` one, so this costs no duplicated strings.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar', 'EG'),
    Locale('ar'),
  ];

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;
    emit(state.copyWith(themeMode: mode));
    await _preferences.setThemeMode(mode);
  }

  /// Pass null to follow the device language.
  Future<void> setLocale(Locale? locale) async {
    final resolved = _resolve(locale);
    if (resolved == state.locale) return;
    emit(AppSettingsState(themeMode: state.themeMode, locale: resolved));
    await _preferences.setLocaleCode(resolved?.languageCode);
  }

  static Locale? _localeFrom(String? code) =>
      (code == null || code.isEmpty) ? null : _resolve(Locale(code));

  /// Maps a language choice onto the entry in [supportedLocales] that carries
  /// it, rather than constructing a bare `Locale` from the code.
  ///
  /// The difference is not cosmetic. `Locale('ar')` and `Locale('ar', 'EG')`
  /// are the same language to a reader and two different locales to `intl`:
  /// the first formats numbers in Latin digits, the second in Arabic-Indic.
  /// Building the locale by hand here is what put `0 of 22` inside an
  /// otherwise Arabic-Indic card — `MaterialApp.locale` is set explicitly, so
  /// Flutter's own resolution against [supportedLocales] never runs.
  static Locale? _resolve(Locale? locale) {
    if (locale == null) return null;
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return locale;
  }
}

class AppSettingsState extends Equatable {
  const AppSettingsState({required this.themeMode, this.locale});

  final ThemeMode themeMode;

  /// `null` follows the device locale.
  final Locale? locale;

  bool get isArabic => locale?.languageCode == 'ar';

  AppSettingsState copyWith({ThemeMode? themeMode, Locale? locale}) =>
      AppSettingsState(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );

  @override
  List<Object?> get props => [themeMode, locale];
}
