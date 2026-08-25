import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_capability_service.dart';
import '../../../../core/storage/cache/cache_store.dart';
import '../../../../core/storage/preferences/app_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../../../assets/data/services/asset_state_store.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../connection/domain/entities/connection_probe.dart';

/// What the settings screen renders (spec §23).
class SettingsState extends Equatable {
  const SettingsState({
    this.appVersion,
    this.buildNumber,
    this.lastMetadataSync,
    this.isClearingCache = false,
    this.isRefreshingMetadata = false,
    this.isTestingConnection = false,
    this.probe,
    this.notice,
    this.failure,
  });

  final String? appVersion;
  final String? buildNumber;
  final DateTime? lastMetadataSync;

  final bool isClearingCache;
  final bool isRefreshingMetadata;
  final bool isTestingConnection;

  /// The last successful reachability check, for the connection card's badge.
  final ConnectionProbe? probe;

  /// A one-shot confirmation for the UI to show and then acknowledge.
  final SettingsNotice? notice;

  final Failure? failure;

  bool get isBusy =>
      isClearingCache || isRefreshingMetadata || isTestingConnection;

  SettingsState copyWith({
    String? appVersion,
    String? buildNumber,
    DateTime? lastMetadataSync,
    bool? isClearingCache,
    bool? isRefreshingMetadata,
    bool? isTestingConnection,
    ConnectionProbe? probe,
    SettingsNotice? notice,
    Failure? failure,
    bool clearNotice = false,
    bool clearFailure = false,
  }) => SettingsState(
    appVersion: appVersion ?? this.appVersion,
    buildNumber: buildNumber ?? this.buildNumber,
    lastMetadataSync: lastMetadataSync ?? this.lastMetadataSync,
    isClearingCache: isClearingCache ?? this.isClearingCache,
    isRefreshingMetadata: isRefreshingMetadata ?? this.isRefreshingMetadata,
    isTestingConnection: isTestingConnection ?? this.isTestingConnection,
    probe: probe ?? this.probe,
    notice: clearNotice ? null : (notice ?? this.notice),
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    appVersion,
    buildNumber,
    lastMetadataSync,
    isClearingCache,
    isRefreshingMetadata,
    isTestingConnection,
    probe,
    notice,
    failure,
  ];
}

/// Something that finished and is worth a one-line confirmation.
///
/// An enum rather than a message: the wording lives in the ARB files, so the
/// Cubit stays free of translated text.
enum SettingsNotice { cacheCleared, metadataRefreshed, connectionOk }

/// The settings screen's ViewModel.
///
/// Distinct from `AppSettingsCubit`, which owns theme and locale for the whole
/// app and outlives every screen. This one owns the *actions* the settings
/// screen offers and dies with it.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required CacheStore cache,
    required AssetStateStore states,
    required OdooCapabilityService capabilities,
    required AppPreferences preferences,
    required AuthRepository auth,
  }) : _cache = cache,
       _states = states,
       _capabilities = capabilities,
       _preferences = preferences,
       _auth = auth,
       super(const SettingsState());

  final CacheStore _cache;
  final AssetStateStore _states;
  final OdooCapabilityService _capabilities;
  final AppPreferences _preferences;
  final AuthRepository _auth;

  Future<void> load() async {
    emit(state.copyWith(lastMetadataSync: _preferences.lastMetadataSync));

    try {
      final info = await PackageInfo.fromPlatform();
      if (isClosed) return;
      emit(
        state.copyWith(appVersion: info.version, buildNumber: info.buildNumber),
      );
    } on Object catch (error) {
      // A missing version string is a cosmetic gap in a footer, not a reason
      // to fail the screen the user opened to fix something else.
      AppLogger.warn('Package info unavailable — $error');
    }
  }

  /// Clears cached Odoo data.
  ///
  /// [keepLocalStates] defaults to true. It used to guard real user data: the
  /// Reserved / Damaged / Lost box was the only copy that existed. Odoo now
  /// holds those states (docs/ARCHITECTURE.md §6), so keeping the box only
  /// saves the next read a round trip — worth doing, no longer load-bearing.
  Future<void> clearCache({bool keepLocalStates = true}) async {
    if (state.isBusy) return;
    emit(state.copyWith(isClearingCache: true, clearFailure: true));

    try {
      if (keepLocalStates) {
        for (final box in CacheBoxes.all) {
          if (box == CacheBoxes.localAssetState) continue;
          await _cache.clearBox(box);
        }
      } else {
        await _cache.clearAll();
        await _states.clearAll();
      }

      await _capabilities.invalidate();
      if (isClosed) return;

      emit(
        state.copyWith(
          isClearingCache: false,
          notice: SettingsNotice.cacheCleared,
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Clear cache failed', error, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          isClearingCache: false,
          failure: const Failure(kind: FailureKind.cache),
        ),
      );
    }
  }

  /// Settings → "Refresh Odoo metadata" (spec §23).
  Future<void> refreshMetadata() async {
    if (state.isBusy) return;
    emit(state.copyWith(isRefreshingMetadata: true, clearFailure: true));

    try {
      await _capabilities.invalidate();
      await _capabilities.probeAll();

      final now = DateTime.now();
      await _preferences.setLastMetadataSync(now);
      if (isClosed) return;

      emit(
        state.copyWith(
          isRefreshingMetadata: false,
          lastMetadataSync: now,
          notice: SettingsNotice.metadataRefreshed,
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Metadata refresh failed', error, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          isRefreshingMetadata: false,
          failure: const Failure(kind: FailureKind.server),
        ),
      );
    }
  }

  /// Settings → "Test connection" (spec §23).
  ///
  /// Re-probes reachability with the saved connection. Deliberately the
  /// unauthenticated probe: the point is "can this device still reach the
  /// server", which is the question a user asks when something feels stuck.
  Future<void> testConnection() async {
    if (state.isBusy) return;

    final connection = _auth.savedConnection();
    if (connection == null) return;

    emit(state.copyWith(isTestingConnection: true, clearFailure: true));

    final result = await _auth.probe(connection);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) =>
            state.copyWith(isTestingConnection: false, failure: failure),
        (probe) => state.copyWith(
          isTestingConnection: false,
          probe: probe,
          notice: SettingsNotice.connectionOk,
        ),
      ),
    );
  }

  void acknowledgeNotice() => emit(state.copyWith(clearNotice: true));

  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));
}
