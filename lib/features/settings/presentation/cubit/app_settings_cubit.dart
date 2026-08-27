import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/preferences/app_preferences.dart';
import '../../../../shared/utils/app_number.dart';

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
  /// Locales the app resolves to.
  ///
  /// Plain `ar`, with no country variant. There used to be an `ar_EG` ahead of
  /// it — plus an empty `app_ar_EG.arb` whose entire job was to make that
  /// resolve — because CLDR gives `ar_EG` the Arabic-Indic digit set and the
  /// product then wanted counts rendered as `١٢٤`.
  ///
  /// The product now renders every number in Western digits (see [AppNumber]),
  /// so the pin had nothing left to hold and the file it depended on is gone.
  /// Generic `ar` formats numbers in Western digits already, which means the
  /// rule is now the default rather than something two files conspire to
  /// produce.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
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
  /// Still explicit even though the two Arabic entries have collapsed into
  /// one. `MaterialApp.locale` is set from this value directly, so Flutter's
  /// own resolution against [supportedLocales] never runs — a bare
  /// `Locale(code)` built here would be handed straight to `intl`, and a
  /// stored code that is not in the list would resolve to nothing.
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
