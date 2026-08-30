import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/core/constants/storage_keys.dart';
import 'package:sijil_it/core/security/app_lock.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_lock_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_lock_gate.dart';

import '../fake_odoo/test_app_harness.dart';

/// What the lock actually covers.
///
/// The interesting property is not that a lock screen exists — it is that the
/// app underneath is *gone*, not dimmed. A blurred or faded asset register is
/// still the company's asset register, legible to exactly the person holding
/// the unlocked phone this feature exists to stop.
void main() {
  late AppL10n l10n;

  /// A stand-in for the app behind the gate, distinctive enough to find.
  const secret = 'MacBook Pro M4 — Ahmed Mohamed';

  setUp(() async => l10n = await loadL10n());

  Future<AppLockCubit> lockedCubit({bool grants = false}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefKeys.appLockEnabled: true,
    });
    final cubit = AppLockCubit(
      lock: _FakeLock(grants: grants),
      preferences: await AppPreferences.create(),
    );
    await cubit.start();
    return cubit;
  }

  Future<void> pumpGate(WidgetTester tester, AppLockCubit cubit) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: BlocProvider<AppLockCubit>.value(
          value: cubit,
          child: const AppLockGate(
            child: Scaffold(body: Center(child: Text(secret))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a locked app is covered, not merely tinted', (tester) async {
    final cubit = await lockedCubit();
    await pumpGate(tester, cubit);

    expect(find.text(l10n.lockTitle), findsOneWidget);
    // The stack still holds the app — the navigation the user built survives
    // the lock — but nothing of it is on screen.
    expect(find.text(secret), findsOneWidget);
    expect(tester.getSize(find.byType(Scaffold).last), TestSizes.phone);

    await cubit.close();
  });

  testWidgets('an answered unlock hands the app straight back', (tester) async {
    final cubit = await lockedCubit(grants: true);
    await pumpGate(tester, cubit);

    // Prompted on mount and answered, so the gate is already out of the way.
    expect(find.text(l10n.lockTitle), findsNothing);
    expect(find.text(secret), findsOneWidget);

    await cubit.close();
  });

  testWidgets('a refused unlock says so and offers another go', (tester) async {
    final cubit = await lockedCubit();
    await pumpGate(tester, cubit);

    // Not the inviting copy: the user has just been turned down, and repeating
    // "unlock to carry on" reads as though nothing happened.
    expect(find.text(l10n.lockFailed), findsOneWidget);
    expect(find.text(l10n.lockBody), findsNothing);
    expect(find.text(l10n.lockUnlock), findsOneWidget);

    await cubit.close();
  });

  testWidgets('the setting off leaves the app exactly as it was', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefKeys.appLockEnabled: false,
    });
    final cubit = AppLockCubit(
      lock: _FakeLock(),
      preferences: await AppPreferences.create(),
    );
    await cubit.start();

    await pumpGate(tester, cubit);

    expect(find.text(l10n.lockTitle), findsNothing);
    expect(find.text(secret), findsOneWidget);

    await cubit.close();
  });

  testWidgets('it lays out in Arabic without overflowing', (tester) async {
    final cubit = await lockedCubit();

    await tester.pumpWidget(
      TestApp(
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        child: BlocProvider<AppLockCubit>.value(
          value: cubit,
          child: const AppLockGate(child: Scaffold(body: SizedBox.shrink())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectNoOverflow(tester);
    await cubit.close();
  });
}

/// An [AppLock] that answers without an OS prompt.
class _FakeLock extends AppLock {
  _FakeLock({this.grants = false});

  final bool grants;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async => grants;
}
