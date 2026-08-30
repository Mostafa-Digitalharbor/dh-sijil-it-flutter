import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/storage/preferences/app_preferences.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/settings/presentation/cubit/app_lock_cubit.dart';
import '../features/settings/presentation/cubit/app_settings_cubit.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/cubit/sync_cubit.dart';
import '../shared/widgets/app_lock_gate.dart';
import 'di/injector.dart';
import 'router/app_router.dart';
import 'theme/app_dimens.dart';
import 'theme/app_theme.dart';

/// Root widget.
///
/// Owns exactly three things: the router, the themes, and the settings Cubit
/// that drives theme mode and locale. Everything else is provided per feature,
/// so this file stays stable as the app grows.
class SijilApp extends StatefulWidget {
  const SijilApp({super.key});

  @override
  State<SijilApp> createState() => _SijilAppState();
}

class _SijilAppState extends State<SijilApp> {
  late final GoRouter _router;
  late final AppSettingsCubit _settings;
  late final AuthCubit _auth;
  late final SyncCubit _sync;
  late final AppLockCubit _lock;

  @override
  void initState() {
    super.initState();
    _settings = AppSettingsCubit(sl<AppPreferences>());
    _auth = sl<AuthCubit>();
    _router = AppRouter.create(auth: _auth);

    // Started before the first frame, so a locked app is covered from the
    // moment it has anything worth covering rather than a frame later.
    _lock = sl<AppLockCubit>();
    unawaited(_lock.start());

    // Above the router, because being offline outlives any one screen: the
    // banner has to survive the navigation a technician does on the way back
    // into signal.
    _sync = sl<SyncCubit>()..start();
  }

  @override
  void dispose() {
    _settings.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>.value(value: _settings),
        BlocProvider<AuthCubit>.value(value: _auth),
        BlocProvider<SyncCubit>.value(value: _sync),
        BlocProvider<AppLockCubit>.value(value: _lock),
      ],
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          return MaterialApp.router(
            onGenerateTitle: (context) => AppL10n.of(context).appName,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,

            // Dark mode is a product requirement, not an afterthought
            // (spec §26). Both themes are built from the same brand tokens.
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,

            // Arabic and English. A null locale follows the device; selecting
            // Arabic flips the whole tree to RTL through Flutter's own
            // directionality resolution — no feature code touches it.
            locale: settings.locale,
            supportedLocales: AppSettingsCubit.supportedLocales,
            localizationsDelegates: const [
              AppL10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            builder: (context, child) {
              // Caps system font scaling so dense asset rows stay readable at
              // the extremes without clipping.
              final scale = MediaQuery.textScalerOf(context).clamp(
                minScaleFactor: AppTextScale.min,
                maxScaleFactor: AppTextScale.max,
              );
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scale),
                // Inside the builder rather than around `MaterialApp`, because
                // the lock screen needs the theme and the translations — both
                // of which this widget is above — and because covering the
                // router here leaves the navigation stack behind it intact.
                child: AppLockGate(child: child ?? const SizedBox.shrink()),
              );
            },
          );
        },
      ),
    );
  }
}
