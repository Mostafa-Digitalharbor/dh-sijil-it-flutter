import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/security/credential_vault.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/auth/domain/repositories/auth_repository.dart';

import '../../../fake_odoo/fake_odoo_data.dart';
import '../../../fake_odoo/test_app_harness.dart';

/// How long a saved sign-in stays usable on a device nobody is holding.
///
/// ## What this guards
///
/// The credential in the keychain is a working Odoo login, not a token the
/// server can revoke — standard Odoo has nothing to revoke it *with* over
/// XML-RPC. It used to stay valid for as long as the app was installed, so a
/// handset lost in month one was still a way into the asset register in month
/// nine, and the only thing that ended that was somebody noticing and changing
/// the password centrally.
///
/// ## Why the window is idle time
///
/// It runs from the last time the app actually reached Odoo, not from when the
/// password was typed. Measured from sign-in it would have logged out the
/// people using the app most, which is how a security setting gets switched
/// off — so the tests below pin *both* halves: an unused device expires, and a
/// used one never does.
void main() {
  late FakeOdooData data;
  late AppPreferences preferences;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    preferences = sl<AppPreferences>();
  });

  tearDown(() async => sl.reset());

  /// Rewinds the clock on the stored session by [days].
  Future<void> ageSessionBy(int days) => preferences.setLastAuthenticated(
    DateTime.now().subtract(Duration(days: days)),
  );

  group('the policy itself', () {
    test('a fresh session is not expired', () async {
      await preferences.setLastAuthenticated(DateTime.now());

      expect(preferences.isSessionExpired(), isFalse);
    });

    test('one inside the window is not expired', () async {
      await ageSessionBy(AppPreferences.defaultSessionMaxAgeDays - 1);

      expect(preferences.isSessionExpired(), isFalse);
    });

    test('one past the window is', () async {
      await ageSessionBy(AppPreferences.defaultSessionMaxAgeDays + 1);

      expect(preferences.isSessionExpired(), isTrue);
    });

    test('"no limit" switches the check off entirely', () async {
      await preferences.setSessionMaxAgeDays(
        AppPreferences.sessionNeverExpires,
      );
      await ageSessionBy(3650);

      expect(
        preferences.isSessionExpired(),
        isFalse,
        reason:
            'a shared shop-floor device with no other way in must be able to '
            'opt out deliberately',
      );
    });

    test('a shorter window can be chosen and is honoured', () async {
      await preferences.setSessionMaxAgeDays(7);
      await ageSessionBy(8);

      expect(preferences.isSessionExpired(), isTrue);
    });

    test(
      'no timestamp is not expired, so an upgrade signs nobody out',
      () async {
        await preferences.setLastAuthenticated(null);

        expect(
          preferences.isSessionExpired(),
          isFalse,
          reason:
              'sessions predating this setting have no stamp, and a security '
              'feature that logs everyone out on install reads as a bug',
        );
      },
    );

    test('the default is thirty days and it is on', () {
      expect(AppPreferences.defaultSessionMaxAgeDays, 30);
      expect(
        preferences.sessionMaxAgeDays,
        AppPreferences.defaultSessionMaxAgeDays,
        reason: 'a policy nobody switches on protects nobody',
      );
    });
  });

  group('restoring a session', () {
    test('a signed-in user comes back when the window is open', () async {
      await signInForTest(data);
      await sl<AuthRepository>().signOut(forgetCredential: false);

      final restored = await sl<AuthRepository>().restoreSession();

      expect(restored.isRight(), isTrue);
      restored.fold((_) {}, (user) => expect(user, isNotNull));
    });

    test('signing in starts the clock', () async {
      await signInForTest(data);

      expect(preferences.lastAuthenticated, isNotNull);
    });

    test('a stale session is refused, and says why', () async {
      await signInForTest(data);
      await sl<AuthRepository>().signOut(forgetCredential: false);
      await ageSessionBy(AppPreferences.defaultSessionMaxAgeDays + 1);

      final restored = await sl<AuthRepository>().restoreSession();

      restored.fold(
        (failure) => expect(
          failure.kind,
          FailureKind.sessionExpired,
          reason:
              'not invalidCredentials — nothing is wrong with the password, '
              'and the login screen says something different for each',
        ),
        (_) => fail('an expired session must not restore'),
      );
    });

    test('and the credential is deleted, not merely ignored', () async {
      // The whole point. Leaving it in the keychain and declining to use it
      // protects nothing: it is still there for anything that can read the
      // keystore.
      await signInForTest(data);
      await sl<AuthRepository>().signOut(forgetCredential: false);
      expect(await sl<CredentialVault>().hasSecret(), isTrue);

      await ageSessionBy(AppPreferences.defaultSessionMaxAgeDays + 1);
      await sl<AuthRepository>().restoreSession();

      expect(await sl<CredentialVault>().hasSecret(), isFalse);
      expect(preferences.userId, isNull);
      expect(preferences.lastAuthenticated, isNull);
    });

    test(
      'the server details survive it, so signing back in is one field',
      () async {
        await signInForTest(data);
        await sl<AuthRepository>().signOut(forgetCredential: false);
        await ageSessionBy(AppPreferences.defaultSessionMaxAgeDays + 1);

        await sl<AuthRepository>().restoreSession();

        expect(
          sl<AuthRepository>().savedConnection(),
          isNotNull,
          reason: 'expiring a session must not mean retyping the server URL',
        );
      },
    );

    test('using the app renews the window', () async {
      // The half that keeps the setting switched on: somebody who opens the
      // app inside the window is never asked to sign in again.
      await signInForTest(data);
      await sl<AuthRepository>().signOut(forgetCredential: false);
      await ageSessionBy(AppPreferences.defaultSessionMaxAgeDays - 1);

      final before = preferences.lastAuthenticated!;
      await sl<AuthRepository>().restoreSession();
      final after = preferences.lastAuthenticated!;

      expect(after.isAfter(before), isTrue);
      expect(preferences.isSessionExpired(), isFalse);
    });

    test('with no limit set, an ancient session still restores', () async {
      await signInForTest(data);
      await sl<AuthRepository>().signOut(forgetCredential: false);
      await preferences.setSessionMaxAgeDays(
        AppPreferences.sessionNeverExpires,
      );
      await ageSessionBy(3650);

      final restored = await sl<AuthRepository>().restoreSession();

      expect(restored.isRight(), isTrue);
      expect(await sl<CredentialVault>().hasSecret(), isTrue);
    });
  });

  group('the setting survives a restart', () {
    test('a chosen window is remembered', () async {
      await preferences.setSessionMaxAgeDays(7);

      final reloaded = AppPreferences(await SharedPreferences.getInstance());
      expect(reloaded.sessionMaxAgeDays, 7);
    });
  });
}
