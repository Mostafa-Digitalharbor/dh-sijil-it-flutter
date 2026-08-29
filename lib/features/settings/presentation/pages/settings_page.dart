import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/app_date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/app_sheets.dart';
import '../../../../shared/widgets/app_tiles.dart';
import '../../../../shared/widgets/key_value.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/app_settings_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../widgets/reminders_card.dart';

/// Connection, account, appearance and cache (spec §23).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => sl<SettingsCubit>()..load(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  Future<void> _confirmClearCache(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final cubit = context.read<SettingsCubit>();

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.settingsClearCacheConfirm,
      message: l10n.settingsClearCacheBody,
      confirmLabel: l10n.settingsClearCache,
    );
    if (!confirmed) return;

    await cubit.clearCache();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final auth = context.read<AuthCubit>();

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.settingsSignOutConfirm,
      message: l10n.settingsSignOutBody,
      confirmLabel: l10n.settingsSignOut,
      isDestructive: true,
    );
    if (!confirmed) return;

    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice ||
          previous.failure != current.failure,
      listener: (context, state) {
        final cubit = context.read<SettingsCubit>();

        final failure = state.failure;
        if (failure != null) {
          AppSnack.failure(context, failure);
          cubit.acknowledgeFailure();
          return;
        }

        final notice = state.notice;
        if (notice != null) {
          AppSnack.success(context, _noticeText(l10n, notice, state));
          cubit.acknowledgeNotice();
        }
      },
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();

        return AppScaffold(
          title: l10n.settingsTitle,
          showBack: true,
          onBack: () => context.go(AppRoutes.more),
          body: AppPageBody(
            gap: AppSpacing.cozy,
            children: <Widget>[
              _ConnectionCard(state: state, onTest: cubit.testConnection),
              const _CapabilitiesCard(),
              const _AppearanceCard(),
              const _LanguageCard(),
              const RemindersCard(),
              _DataCard(
                state: state,
                onClearCache: () => _confirmClearCache(context),
                onRefreshMetadata: cubit.refreshMetadata,
                onDiagnostics: () => context.go(AppRoutes.debugLogPath),
              ),
              AppButton.danger(
                label: l10n.settingsSignOut,
                icon: Icons.logout_rounded,
                isCompact: true,
                onPressed: () => _confirmSignOut(context),
              ),
              _VersionFooter(state: state),
            ],
          ),
        );
      },
    );
  }

  static String _noticeText(
    AppL10n l10n,
    SettingsNotice notice,
    SettingsState state,
  ) => switch (notice) {
    SettingsNotice.cacheCleared => l10n.settingsClearCacheDone,
    SettingsNotice.metadataRefreshed => l10n.settingsMetadataRefreshed,
    SettingsNotice.connectionOk => l10n.connectionReachable(
      state.probe?.serverVersion ?? '',
    ),
  };
}

/// Server, database, version, signed-in user, and a reachability check.
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.state, required this.onTest});

  final SettingsState state;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final auth = context.watch<AuthCubit>().state;
    final connection = auth.connection;

    return SectionCard(
      title: l10n.settingsConnection,
      trailing: AppChip(
        label: auth.isSignedIn
            ? l10n.settingsConnected
            : l10n.settingsDisconnected,
        tone: auth.isSignedIn ? AppColors.success : AppColors.navy300,
        leadingDot: true,
        dense: true,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KeyValueGrid(
            items: <KeyValue>[
              // Host, database and version are technical identifiers, so they
              // keep their reading order inside an Arabic layout. Without
              // this, bidi reorders a version like "19.0+e" into "e+19.0",
              // because it opens with digits and carries a sign.
              KeyValue(
                label: l10n.labelServer,
                value: connection?.baseUrl.host,
                isMonospace: true,
              ),
              KeyValue(
                label: l10n.fieldDatabase,
                value: connection?.database,
                isMonospace: true,
              ),
              KeyValue(
                label: l10n.labelOdooVersion,
                value: state.probe?.serverVersion ?? auth.user?.serverVersion,
                isMonospace: true,
              ),
              KeyValue(
                label: l10n.labelSignedInAs,
                value: auth.user?.displayName ?? connection?.username,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.outlined(
            label: l10n.actionTestConnection,
            icon: Icons.refresh_rounded,
            isCompact: true,
            isBusy: state.isTestingConnection,
            onPressed: state.isBusy ? null : onTest,
          ),
        ],
      ),
    );
  }
}

/// What was detected on the connected instance (spec §17).
///
/// Shown as present/absent rather than hidden when absent: a user wondering
/// why there is no Employees tab needs to see that HR was looked for and not
/// found, not an empty space.
class _CapabilitiesCard extends StatelessWidget {
  const _CapabilitiesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final capabilities = context.watch<AuthCubit>().state.capabilities;

    return SectionCard(
      title: l10n.settingsDetected,
      child: AppChipWrap(
        children: <Widget>[
          _CapabilityChip(
            label: l10n.capabilityMaintenance,
            present: capabilities.hasMaintenance,
          ),
          _CapabilityChip(
            label: l10n.capabilityEmployees,
            present: capabilities.hasHrEmployees,
          ),
          _CapabilityChip(
            label: l10n.capabilityInventory,
            present: capabilities.hasInventory,
          ),
          _CapabilityChip(
            label: l10n.capabilityActivityLog,
            present: capabilities.hasActivityLog,
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label, required this.present});

  final String label;
  final bool present;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label,
      icon: present ? Icons.check_rounded : Icons.close_rounded,
      tone: present ? AppColors.success : null,
      dense: true,
      semanticSuffix: present
          ? AppL10n.of(context).settingsConnected
          : AppL10n.of(context).settingsDisconnected,
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final settings = context.watch<AppSettingsCubit>();

    return SectionCard(
      title: l10n.settingsAppearance,
      child: AppSegmented<ThemeMode>(
        value: settings.state.themeMode,
        semanticLabel: l10n.settingsAppearance,
        onChanged: settings.setThemeMode,
        options: <SegmentOption<ThemeMode>>[
          SegmentOption<ThemeMode>(
            value: ThemeMode.system,
            label: l10n.themeSystem,
          ),
          SegmentOption<ThemeMode>(
            value: ThemeMode.light,
            label: l10n.themeLight,
          ),
          SegmentOption<ThemeMode>(
            value: ThemeMode.dark,
            label: l10n.themeDark,
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  /// `null` means "follow the device", which is the default and needs its own
  /// segment rather than being implied by neither language being selected.
  static const List<Locale?> _values = <Locale?>[
    null,
    Locale('en'),
    Locale('ar'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final settings = context.watch<AppSettingsCubit>();

    return SectionCard(
      title: l10n.settingsLanguage,
      child: AppSegmented<String>(
        value: settings.state.locale?.languageCode ?? '',
        semanticLabel: l10n.settingsLanguage,
        onChanged: (code) => settings.setLocale(
          _values.firstWhere(
            (locale) => (locale?.languageCode ?? '') == code,
            orElse: () => null,
          ),
        ),
        options: <SegmentOption<String>>[
          SegmentOption<String>(value: '', label: l10n.languageSystem),
          SegmentOption<String>(value: 'en', label: l10n.languageEnglish),
          SegmentOption<String>(value: 'ar', label: l10n.languageArabic),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.state,
    required this.onClearCache,
    required this.onRefreshMetadata,
    required this.onDiagnostics,
  });

  final SettingsState state;
  final VoidCallback onClearCache;
  final VoidCallback onRefreshMetadata;
  final VoidCallback onDiagnostics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppCard(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSettingTile(
            icon: Icons.storage_rounded,
            title: l10n.settingsClearCache,
            subtitle: l10n.settingsCacheKeepStates,
            onTap: state.isBusy ? null : onClearCache,
          ),
          AppSettingTile(
            icon: Icons.refresh_rounded,
            title: l10n.settingsRefreshMetadata,
            subtitle: state.lastMetadataSync == null
                ? l10n.settingsNeverChecked
                : l10n.settingsLastChecked(
                    context.dates.relative(state.lastMetadataSync),
                  ),
            onTap: state.isBusy ? null : onRefreshMetadata,
          ),
          AppSettingTile(
            icon: Icons.bug_report_outlined,
            title: l10n.settingsDiagnostics,
            subtitle: l10n.settingsDiagnosticsDetail,
            showDivider: false,
            onTap: onDiagnostics,
          ),
        ],
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    if (state.appVersion == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
      child: Text(
        l10n.settingsVersion(state.appVersion!, state.buildNumber ?? ''),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
