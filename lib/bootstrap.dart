import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/di/injector.dart';
import 'app/observers/app_bloc_observer.dart';
import 'core/observability/crash_reporter.dart';
import 'core/sync/sync_service.dart';
import 'core/utils/logger.dart';

/// Single startup path shared by every flavour (dev / staging / prod).
///
/// [builder] supplies the root widget so a flavour entry point can wrap the
/// app differently without duplicating any of this setup.
Future<void> bootstrap(Widget Function() builder) {
  // Crash reporting owns the outermost layer because the Sentry SDK must own
  // the zone `runApp` runs in to catch asynchronous errors. When no DSN is
  // compiled in this is a straight pass-through — see [CrashReporter].
  return CrashReporter.runWithReporting(_start(builder));
}

Future<void> Function() _start(Widget Function() builder) => () async {
  // `runZonedGuarded` catches async errors that escape the widget tree;
  // `FlutterError.onError` catches synchronous framework ones. Together they
  // guarantee nothing reaches the user as a red screen with a stack trace
  // (spec §22). Both now also hand the error to [CrashReporter], which is a
  // no-op unless a DSN was compiled in.
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppLogger.error(
          'Flutter framework error',
          details.exception,
          details.stack,
        );
        unawaited(
          CrashReporter.capture(
            details.exception,
            details.stack,
            context: 'FlutterError.onError',
          ),
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

      // Starts watching connectivity, so writes queued in a basement go out
      // by themselves the moment the technician reaches a corridor with
      // signal — without anybody opening the sync screen.
      sl<SyncService>().start();

      runApp(builder());
    },
    (error, stackTrace) {
      AppLogger.error('Uncaught zone error', error, stackTrace);
      unawaited(
        CrashReporter.capture(error, stackTrace, context: 'uncaught zone'),
      );
    },
  );
};
