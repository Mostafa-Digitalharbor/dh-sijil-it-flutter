import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/logger.dart';

/// Observes every Cubit in the app (Observer pattern, built into bloc).
///
/// Gives one place to trace state transitions during development and to
/// forward unhandled Cubit errors to crash reporting later. All output goes
/// through [AppLogger], so it is sanitized and silenced in release builds.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    AppLogger.debug('${bloc.runtimeType} -> ${change.nextState.runtimeType}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLogger.error('${bloc.runtimeType} threw', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
