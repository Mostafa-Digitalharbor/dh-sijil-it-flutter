import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/app_lock.dart';
import '../../../../core/storage/preferences/app_preferences.dart';

/// Where the app is between "locked" and "the user is through".
enum AppLockStatus {
  /// The setting is off, or the device has no lock to ask for.
  disabled,

  /// Locked, and nothing has been asked yet.
  locked,

  /// The system prompt is up.
  prompting,

  /// A prompt was answered with something other than a successful unlock.
  ///
  /// Distinct from [locked] because the screen behind it says something
  /// different: the first invites, the second explains that the last attempt
  /// did not work.
  refused,

  unlocked,
}

class AppLockState extends Equatable {
  const AppLockState({this.status = AppLockStatus.disabled, this.isAvailable});

  final AppLockStatus status;

  /// Whether the device has any secure lock, or null before the probe has
  /// answered.
  ///
  /// Three-valued on purpose. Asking the OS is a round trip over a platform
  /// channel, and a plain `false` default made the settings screen state, for
  /// the milliseconds before the answer arrived, that this phone has no screen
  /// lock — which is a claim, not an absence, and the wrong one on most
  /// phones. Null says "not yet", which is what the control shows.
  final bool? isAvailable;

  /// True only once the OS has said yes.
  bool get hasDeviceLock => isAvailable ?? false;

  /// True once the probe has answered, either way.
  bool get isProbed => isAvailable != null;

  /// Whether the lock screen should be covering the app.
  bool get isBlocking => switch (status) {
    AppLockStatus.locked ||
    AppLockStatus.prompting ||
    AppLockStatus.refused => true,
    AppLockStatus.disabled || AppLockStatus.unlocked => false,
  };

  bool get isPrompting => status == AppLockStatus.prompting;

  bool get wasRefused => status == AppLockStatus.refused;

  AppLockState copyWith({AppLockStatus? status, bool? isAvailable}) =>
      AppLockState(
        status: status ?? this.status,
        isAvailable: isAvailable ?? this.isAvailable,
      );

  @override
  List<Object?> get props => <Object?>[status, isAvailable];
}

/// Owns whether the app is locked, and decides when to lock it again.
///
/// ## Why a Cubit above the router
///
/// The lock is a fact about the *app*, not about a screen — like the offline
/// banner and the theme. Routing it as a page would mean every deep link, every
/// tab and every workflow screen had to know how to get behind it, and a
/// navigation stack the user built would be thrown away on every unlock.
/// Instead it renders over whatever is there and lets the stack survive.
///
/// ## When it re-locks
///
/// On resume, if the app was away longer than [AppConstants.appLockGrace].
/// The grace period is doing real work: the camera permission dialog, the
/// photo picker, the OS share sheet and the unlock prompt itself all pause the
/// app, and locking on every pause would put the prompt in front of somebody
/// who has not left the room — twice per return, once for the picker and once
/// for the share.
class AppLockCubit extends Cubit<AppLockState> with WidgetsBindingObserver {
  AppLockCubit({
    required AppLock lock,
    required AppPreferences preferences,
    DateTime Function()? clock,
  }) : _lock = lock,
       _preferences = preferences,
       _now = clock ?? DateTime.now,
       super(const AppLockState());

  final AppLock _lock;
  final AppPreferences _preferences;

  /// Injectable so a test can drive the grace period instead of waiting it out.
  final DateTime Function() _now;

  /// When the app last left the foreground, or null while it is in it.
  DateTime? _leftAt;

  /// Whether [start] has already run.
  ///
  /// This is an app-wide singleton, and the widget that provides it can be
  /// rebuilt — a second `start` would register a second lifecycle observer on
  /// the same object, and every pause would then be counted twice.
  bool _started = false;

  bool get isEnabled => _preferences.appLockEnabled;

  /// Reads the setting and the device's capability, and locks if it should.
  ///
  /// Called once from the root widget before the first frame the user can
  /// touch, so the app never paints a list of company assets and *then* covers
  /// it.
  ///
  /// Deliberately does not prompt. The prompt needs a translated reason, and
  /// the translations are not resolvable this far above `Localizations` — the
  /// gate widget asks for it on its first build instead, which is also the
  /// first moment there is something to cover.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final available = await _lock.isAvailable();
    if (isClosed) return;

    // The switch cannot be honoured on a device that has since had its screen
    // lock removed. Reporting `disabled` rather than locking is the only
    // answer that does not brick the app: there is nothing left to unlock it
    // with.
    final shouldLock = _preferences.appLockEnabled && available;

    emit(
      AppLockState(
        status: shouldLock ? AppLockStatus.locked : AppLockStatus.disabled,
        isAvailable: available,
      ),
    );

    WidgetsBinding.instance.addObserver(this);
  }

  /// Shows the system prompt and lets the user through if it is answered.
  ///
  /// [reason] is the sentence the OS prints inside its own dialog, passed in
  /// already translated: this Cubit has no `BuildContext` and should not grow
  /// one for a single string.
  Future<void> unlock(String reason) async {
    if (state.isPrompting) return;
    emit(state.copyWith(status: AppLockStatus.prompting));

    final granted = await _lock.authenticate(reason);
    if (isClosed) return;

    emit(
      state.copyWith(
        status: granted ? AppLockStatus.unlocked : AppLockStatus.refused,
      ),
    );
    if (granted) _leftAt = null;
  }

  /// Turns the setting on or off.
  ///
  /// Turning it *on* asks for an unlock straight away rather than taking the
  /// user's word for it. Two reasons: they find out immediately whether their
  /// device will actually let them back in, and a switch that silently enrolled
  /// a lock nobody tested is one that strands somebody at the next launch.
  Future<bool> setEnabled({required bool value, required String reason}) async {
    if (!value) {
      await _preferences.setAppLockEnabled(value: false);
      if (!isClosed) emit(state.copyWith(status: AppLockStatus.disabled));
      return true;
    }

    if (!state.hasDeviceLock) return false;

    final granted = await _lock.authenticate(reason);
    if (!granted) return false;

    await _preferences.setAppLockEnabled(value: true);
    if (!isClosed) emit(state.copyWith(status: AppLockStatus.unlocked));
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  /// The lifecycle rule, in a method whose parameter does not shadow this
  /// object's own `state`.
  void _onLifecycle(AppLifecycleState lifecycle) {
    if (!_preferences.appLockEnabled || !state.hasDeviceLock) return;

    // The unlock prompt itself backgrounds the app on Android. Treating that
    // as "the user left" would re-lock the app in response to its own prompt,
    // which is a loop nobody gets out of.
    if (state.isPrompting) return;

    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt ??= _now();
      case AppLifecycleState.resumed:
        final since = _leftAt;
        _leftAt = null;
        if (since == null) return;
        if (_now().difference(since) < AppConstants.appLockGrace) return;
        if (!isClosed) emit(state.copyWith(status: AppLockStatus.locked));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    return super.close();
  }
}
