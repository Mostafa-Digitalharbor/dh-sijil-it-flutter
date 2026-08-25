import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/di/injector.dart';
import 'app/observers/app_bloc_observer.dart';
import 'core/utils/logger.dart';

/// Single startup path shared by every flavour (dev / staging / prod).
///
/// [builder] supplies the root widget so a flavour entry point can wrap the
/// app differently without duplicating any of this setup.
Future<void> bootstrap(Widget Function() builder) async {
  // `runZonedGuarded` catches async errors that escape the widget tree;
  // `FlutterError.onError` catches synchronous framework ones. Together they
  // guarantee nothing reaches the user as a red screen with a stack trace
  // (spec §22).
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppLogger.error(
          'Flutter framework error',
          details.exception,
          details.stack,
        );
        if (kDebugMode) FlutterError.presentError(details);
      };

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      Bloc.observer = const AppBlocObserver();

      await configureDependencies();

      runApp(builder());
    },
    (error, stackTrace) =>
        AppLogger.error('Uncaught zone error', error, stackTrace),
  );
}
