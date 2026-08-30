import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/core/constants/storage_keys.dart';
import 'package:sijil_it/core/security/app_lock.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_lock_cubit.dart';

/// The device unlock: when it covers the app, and when it gets out of the way.
///
/// The interesting cases are all about *not* asking. A lock that prompts every
/// time the photo picker opens is a lock somebody turns off, and a lock that
/// re-prompts in response to its own dialog is one nobody gets past — so the
/// grace period and the prompting guard are the two rules worth pinning down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAppLock lock;
  late AppPreferences preferences;
  late DateTime now;

  /// A clock the test advances by hand, so the grace period is exercised
  /// rather than waited out.
  DateTime clock() => now;

  Future<AppLockCubit> cubitWith({required bool enabled}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefKeys.appLockEnabled: enabled,
    });
    preferences = await AppPreferences.create();
    return AppLockCubit(lock: lock, preferences: preferences, clock: clock);
  }

  setUp(() {
    lock = _FakeAppLock();
    now = DateTime(2026, 8, 30, 9);
  });

  group('at launch', () {
    test('nothing is claimed about the device before the OS answers', () async {
      // Three-valued on purpose. A plain `false` default made the settings
      // screen state, for as long as the platform channel took to answer,
      // that this phone has no screen lock — a claim, not an absence, and the
      // wrong one on most phones.
      final cubit = await cubitWith(enabled: true);

      expect(cubit.state.isAvailable, isNull);
      expect(cubit.state.isProbed, isFalse);
      expect(cubit.state.hasDeviceLock, isFalse);

      await cubit.start();

      expect(cubit.state.isProbed, isTrue);
      await cubit.close();
    });

    test('starting twice registers one observer, not two', () async {
      // The Cubit is an app-wide singleton and the widget that provides it can
      // be rebuilt. A second `start` would add a second lifecycle observer to
      // the same object, and every pause would then be counted twice.
      final cubit = await cubitWith(enabled: true);

      await cubit.start();
      await cubit.start();

      expect(lock.availabilityChecks, 1);
      await cubit.close();
    });

    test('a device with no screen lock is never locked out', () async {
      // There would be nothing left to unlock it with. Honouring the stored
      // setting here would brick the app for anybody who removed their PIN.
      lock.available = false;
      final cubit = await cubitWith(enabled: true);

      await cubit.start();

      expect(cubit.state.status, AppLockStatus.disabled);
      expect(cubit.state.isBlocking, isFalse);
      await cubit.close();
    });

    test('the setting off means the app opens as it always did', () async {
      final cubit = await cubitWith(enabled: false);

      await cubit.start();

      expect(cubit.state.isBlocking, isFalse);
      await cubit.close();
    });

    test('the setting on covers the app before anything is asked', () async {
      // Locked, not prompting. The prompt needs a translated reason and is
      // asked for by the gate widget — which is also the first frame there is
      // anything worth covering.
      final cubit = await cubitWith(enabled: true);

      await cubit.start();

      expect(cubit.state.status, AppLockStatus.locked);
      expect(cubit.state.isBlocking, isTrue);
      expect(lock.prompts, 0);
      await cubit.close();
    });
  });

  group('unlocking', () {
    test('an answered prompt lets the user through', () async {
      final cubit = await cubitWith(enabled: true);
      await cubit.start();

      await cubit.unlock('Unlock Sijil IT');

      expect(cubit.state.status, AppLockStatus.unlocked);
      expect(cubit.state.isBlocking, isFalse);
      await cubit.close();
    });

    test('a refused prompt says so and stays put', () async {
      lock.grants = false;
      final cubit = await cubitWith(enabled: true);
      await cubit.start();

      await cubit.unlock('Unlock Sijil IT');

      // A distinct state from `locked`, because the screen says something
      // different: one invites, the other explains that the last attempt did
      // not work.
      expect(cubit.state.status, AppLockStatus.refused);
      expect(cubit.state.wasRefused, isTrue);
      expect(cubit.state.isBlocking, isTrue);
      await cubit.close();
    });

    test('a second prompt is not stacked on the first', () async {
      lock.hold = true;
      final cubit = await cubitWith(enabled: true);
      await cubit.start();

      final first = cubit.unlock('Unlock Sijil IT');
      await cubit.unlock('Unlock Sijil IT');

      expect(lock.prompts, 1);
      lock.release();
      await first;
      await cubit.close();
    });
  });

  group('coming back to the app', () {
    test('a short trip away does not re-lock it', () async {
      // The camera permission dialog, the photo picker and the OS share sheet
      // all pause the app. Locking on every pause would put the prompt in
      // front of somebody who never left the room.
      final cubit = await cubitWith(enabled: true);
      await cubit.start();
      await cubit.unlock('Unlock Sijil IT');

      cubit.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(AppConstants.appLockGrace - const Duration(seconds: 1));
      cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(cubit.state.isBlocking, isFalse);
      await cubit.close();
    });

    test('a phone left on a desk comes back locked', () async {
      final cubit = await cubitWith(enabled: true);
      await cubit.start();
      await cubit.unlock('Unlock Sijil IT');

      cubit.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(AppConstants.appLockGrace + const Duration(seconds: 1));
      cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(cubit.state.status, AppLockStatus.locked);
      await cubit.close();
    });

    test('the unlock prompt does not re-lock the app behind itself', () async {
      // Android backgrounds the app to show the system dialog. Treating that
      // as "the user left" is a loop nobody gets out of: the prompt causes the
      // lock that causes the prompt.
      lock.hold = true;
      final cubit = await cubitWith(enabled: true);
      await cubit.start();

      final pending = cubit.unlock('Unlock Sijil IT');
      cubit.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 5));
      cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);

      lock.release();
      await pending;

      expect(cubit.state.status, AppLockStatus.unlocked);
      await cubit.close();
    });
  });

  group('the setting', () {
    test('turning it on is refused unless the prompt is answered', () async {
      // The user finds out now whether their device will let them back in,
      // rather than at the next launch from behind a lock screen.
      lock.grants = false;
      final cubit = await cubitWith(enabled: false);
      await cubit.start();

      final applied = await cubit.setEnabled(
        value: true,
        reason: 'Unlock Sijil IT',
      );

      expect(applied, isFalse);
      expect(preferences.appLockEnabled, isFalse);
      await cubit.close();
    });

    test('an answered prompt stores it and leaves the app open', () async {
      final cubit = await cubitWith(enabled: false);
      await cubit.start();

      final applied = await cubit.setEnabled(
        value: true,
        reason: 'Unlock Sijil IT',
      );

      expect(applied, isTrue);
      expect(preferences.appLockEnabled, isTrue);
      // Not locked on the spot: the user is standing in Settings, and they
      // just proved who they are.
      expect(cubit.state.isBlocking, isFalse);
      await cubit.close();
    });

    test('turning it off asks for nothing', () async {
      final cubit = await cubitWith(enabled: true);
      await cubit.start();
      await cubit.unlock('Unlock Sijil IT');
      lock.prompts = 0;

      final applied = await cubit.setEnabled(
        value: false,
        reason: 'Unlock Sijil IT',
      );

      expect(applied, isTrue);
      expect(preferences.appLockEnabled, isFalse);
      expect(lock.prompts, 0);
      await cubit.close();
    });

    test('a device with no screen lock cannot switch it on', () async {
      lock.available = false;
      final cubit = await cubitWith(enabled: false);
      await cubit.start();

      final applied = await cubit.setEnabled(
        value: true,
        reason: 'Unlock Sijil IT',
      );

      expect(applied, isFalse);
      expect(lock.prompts, 0);
      await cubit.close();
    });
  });
}

/// An [AppLock] a test drives, standing in for the OS prompt.
///
/// Extends rather than reimplements, so the production constructor and the
/// method signatures the Cubit calls are the ones under test.
class _FakeAppLock extends AppLock {
  bool available = true;
  bool grants = true;

  /// How many times the system prompt was shown.
  int prompts = 0;

  /// Holds the prompt open, so a test can act while it is on screen — which
  /// is exactly when Android backgrounds the app.
  bool hold = false;

  Completer<bool>? _pending;

  void release() {
    _pending?.complete(grants);
    _pending = null;
  }

  /// How many times the OS was asked whether this device has a lock.
  int availabilityChecks = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<bool> authenticate(String reason) {
    prompts++;
    if (!hold) return Future<bool>.value(grants);
    return (_pending = Completer<bool>()).future;
  }
}
