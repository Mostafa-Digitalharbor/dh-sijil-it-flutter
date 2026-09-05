import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/notifications/notification_service.dart';
import 'package:sijil_it/core/notifications/reminder_scheduler.dart';
import 'package:sijil_it/core/security/credential_vault.dart';
import 'package:sijil_it/core/services/voice_input.dart';
import 'package:sijil_it/core/storage/cache/hive_cache_store.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/core/sync/outbox_entry.dart';
import 'package:sijil_it/core/sync/outbox_store.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_detail_sections.dart';
import 'package:sijil_it/features/auth/domain/repositories/auth_repository.dart';
import 'package:sijil_it/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:sijil_it/features/settings/presentation/widgets/session_card.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/utils/reminder_copy_l10n.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../test/fake_odoo/fake_odoo_data.dart';
import '../test/fake_odoo/test_app_harness.dart';

/// The six new features, on the only machine that can disprove them.
///
/// Every one of them already has a host-side suite, and every one of those
/// suites runs against a double: an in-memory vault, an in-memory cache, a
/// fake recogniser, no OS scheduler. That is the right way to test the
/// *decisions* — and it is structurally incapable of catching the failure mode
/// these features actually share, which is that the decision is correct and
/// the platform underneath it does nothing.
///
/// Concretely, each group here covers a bug that compiles, installs, launches,
/// and passes all 1487 host tests:
///
/// * **Voice.** `PlatformVoiceInput.isAvailable` catches `on Object` and
///   answers false. A plugin missing from `GeneratedPluginRegistrant` is
///   therefore indistinguishable from a tablet with no microphone — the button
///   just never appears, on every device, forever.
/// * **Reminders.** `NotificationService.reschedule` catches `on Object` too,
///   for a good reason (a device that will not schedule must not fail the sync
///   that produced the list). So a maintenance reminder that the OS rejects is
///   silent. Only the OS's own pending list can say it was accepted.
/// * **Quarantine.** `quarantinedAt` round-trips through JSON in the host
///   suite. On a device that JSON goes through an AES cipher whose key lives
///   in the keystore, and a field that fails to survive that is a write the
///   app has given up on and will now retry forever.
/// * **Session expiry.** The whole point of the feature is that a stolen
///   device's credential stops working. That promise is kept by
///   `flutter_secure_storage` actually deleting from EncryptedSharedPreferences
///   — which an `InMemoryVault` proves exactly nothing about.
///
/// Run with:
/// `flutter test integration_test/new_features_device_test.dart -d <id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeOdooData data;
  late AppL10n l10n;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
  });

  tearDown(() async => sl.reset());

  // ── 1. Voice search ────────────────────────────────────────────────────────

  group('voice search', () {
    // Nothing in this group calls `initialize`, and that is deliberate.
    //
    // Initialising the recogniser raises the system microphone dialog on a
    // fresh install, and `flutter test` reinstalls the package every run — so
    // a suite that initialises is a suite that stops dead waiting for a human
    // to tap Allow. The first draft of this file did exactly that and sat on
    // the dialog for nine minutes. Every assertion below reaches the same
    // plugin over the same channel without asking the user for anything.

    testWidgets('the recogniser plugin answers over a real channel', (
      tester,
    ) async {
      // `hasPermission` is a genuine round trip to the platform side of
      // `speech_to_text` — the same reasoning as the `local_auth` check in
      // device_features_test.dart, and the same failure it is looking for. A
      // `MissingPluginException` means the plugin never made it into
      // `GeneratedPluginRegistrant`, which `PlatformVoiceInput`'s `on Object`
      // guard would otherwise report as "this device cannot dictate" on every
      // phone in the field.
      try {
        final granted = await SpeechToText().hasPermission;
        expect(
          granted,
          isA<bool>(),
          reason: 'an answer either way means the platform side is wired',
        );
      } on MissingPluginException catch (error) {
        fail('speech_to_text is not registered in this build: $error');
      }
    });

    testWidgets('the wrapper starts idle', (tester) async {
      expect(PlatformVoiceInput().isListening, isFalse);
    });

    testWidgets('asking whether to offer the button does not block on a user', (
      tester,
    ) async {
      // The device-side half of the bug this suite found. `canOffer` must
      // answer from what the OS already knows; `isAvailable` initialises the
      // recogniser and waits on a permission dialog, and a run of this file
      // sat on that dialog for nine minutes before anyone granted it.
      //
      // A prompt would suspend this future until it was answered, so the
      // deadline *is* the assertion — there is no in-process way to ask
      // "was a system dialog shown".
      final answered = await PlatformVoiceInput().canOffer().timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            fail('canOffer blocked — it is waiting on a permission dialog'),
      );

      expect(answered, isA<bool>());
    });

    testWidgets('stopping a recogniser that never started is harmless', (
      tester,
    ) async {
      // The dispose path. `VoiceSearchButton` stops the microphone in
      // `dispose`, which runs whether or not listening ever began — and on a
      // device that call reaches a real plugin rather than a no-op fake.
      await expectLater(PlatformVoiceInput().stop(), completes);
    });
  });

  // ── 2. Maintenance reminders ───────────────────────────────────────────────

  group('maintenance reminders reach the OS', () {
    late NotificationService notifications;

    setUp(() {
      notifications = NotificationService.createDefault();
    });

    tearDown(() async => notifications.cancelAll());

    MaintenanceRequest request({
      required int id,
      required String name,
      required DateTime? on,
      bool done = false,
    }) => MaintenanceRequest(
      id: id,
      name: name,
      priority: MaintenancePriority.normal,
      scheduledFor: on,
      isDone: done,
    );

    testWidgets('the scheduler initialises against the real timezone db', (
      tester,
    ) async {
      // `flutter_timezone` is a plugin and `initialise` swallows its failure,
      // so this is the assertion that separates "set up" from "gave up".
      expect(
        await notifications.initialise(),
        isTrue,
        reason: 'channels and the tz database are what scheduling needs',
      );
    });

    testWidgets('an overdue repair is accepted by the OS scheduler', (
      tester,
    ) async {
      final planned = ReminderScheduler.planMaintenance(<MaintenanceRequest>[
        request(
          id: 41,
          name: 'Laptop screen replacement',
          on: DateTime.now().subtract(const Duration(days: 9)),
        ),
      ], l10n.reminderCopy);

      expect(planned, hasLength(1));
      // Overdue re-arms for the next morning rather than firing on a date
      // that has passed, which is also what makes it schedulable at all.
      expect(planned.single.at.isAfter(DateTime.now()), isTrue);

      await notifications.reschedule(planned);

      expect(
        await notifications.scheduledCount(),
        1,
        reason: 'reschedule swallows platform errors; the OS list is the proof',
      );
    });

    testWidgets('a repair booked for the future is scheduled too', (
      tester,
    ) async {
      final planned = ReminderScheduler.planMaintenance(<MaintenanceRequest>[
        request(
          id: 42,
          name: 'Preventive service',
          on: DateTime.now().add(const Duration(days: 12)),
        ),
      ], l10n.reminderCopy);

      await notifications.reschedule(planned);

      expect(await notifications.scheduledCount(), 1);
    });

    testWidgets('a closed request is not scheduled at all', (tester) async {
      final planned = ReminderScheduler.planMaintenance(<MaintenanceRequest>[
        request(
          id: 43,
          name: 'Already fixed',
          on: DateTime.now().subtract(const Duration(days: 3)),
          done: true,
        ),
      ], l10n.reminderCopy);

      await notifications.reschedule(planned);

      expect(
        await notifications.scheduledCount(),
        0,
        reason: 'nobody is waiting on a repair that is finished',
      );
    });

    testWidgets('a warranty and a repair sharing an id both survive', (
      tester,
    ) async {
      // The reason `maintenanceIdOffset` exists. Notification ids are one flat
      // namespace *owned by the OS*, so this is the only place the collision
      // could ever have been observed: with a shared id the second
      // `zonedSchedule` silently replaces the first and the count is 1.
      // Sixty days out against a thirty-day lead, so the warning itself lands
      // thirty days from now. An expiry *inside* the lead window has a
      // notification date that has already passed and `plan` drops it — which
      // is correct behaviour, and cost this test a red run before the dates
      // were right.
      const leadDays = 30;
      final expiry = DateTime.now().add(const Duration(days: 60));

      final warranty = ReminderScheduler.plan(
        <Asset>[
          Asset(
            id: 7,
            name: 'ThinkPad X1',
            status: AssetStatus.assigned,
            warranty: Warranty.evaluate(endDate: expiry),
          ),
        ],
        l10n.reminderCopy,
        leadDays,
      );

      final repair = ReminderScheduler.planMaintenance(<MaintenanceRequest>[
        request(
          id: 7,
          name: 'Battery swap',
          on: DateTime.now().add(const Duration(days: 12)),
        ),
      ], l10n.reminderCopy);

      expect(
        warranty,
        isNotEmpty,
        reason: 'the fixture must actually plan one',
      );
      expect(repair, hasLength(1));
      expect(
        warranty.single.id,
        isNot(repair.single.id),
        reason: 'same Odoo id, different notification id',
      );

      await notifications.reschedule(<ScheduledReminder>[
        ...warranty,
        ...repair,
      ]);

      expect(
        await notifications.scheduledCount(),
        2,
        reason: 'both are still with the OS, so neither overwrote the other',
      );
    });

    testWidgets('rescheduling replaces rather than accumulates', (
      tester,
    ) async {
      // Rebuilt on every dashboard load. Without `cancelAll` first, a
      // technician who opens the app ten times has ten copies of the same
      // warning queued — and that is only observable against a real scheduler.
      final planned = ReminderScheduler.planMaintenance(<MaintenanceRequest>[
        request(
          id: 44,
          name: 'Fan noise',
          on: DateTime.now().add(const Duration(days: 4)),
        ),
      ], l10n.reminderCopy);

      await notifications.reschedule(planned);
      await notifications.reschedule(planned);
      await notifications.reschedule(planned);

      expect(await notifications.scheduledCount(), 1);
    });
  });

  // ── 3. Outbox quarantine, through the on-disk store ────────────────────────

  group('quarantine survives real on-disk storage', () {
    late HiveCacheStore cache;
    late OutboxStore outbox;

    setUp(() async {
      // The real store, writing real Hive files to the device's own app
      // container — not the harness's `InMemoryCache`. This is the whole
      // point of the group.
      cache = HiveCacheStore();
      await cache.init();
      outbox = OutboxStore(cache);
      // The emulator carries whatever the app itself last queued.
      await outbox.clear();
    });

    tearDown(() async {
      await outbox.clear();
      await outbox.dispose();
    });

    Future<OutboxEntry> queue(String name) => outbox.add(
      kind: OutboxKind.assignAsset,
      subjectId: 501,
      subjectName: name,
      payload: <String, dynamic>{'employeeId': 3},
    );

    testWidgets('a live write is pending, counted and overlaid', (
      tester,
    ) async {
      await queue('Dell Latitude');

      expect(await outbox.pending(), hasLength(1));
      expect(await outbox.depth(), 1);
      expect(await outbox.subjectIds(), <int>{501});
      expect(await outbox.quarantined(), isEmpty);
    });

    testWidgets('a quarantined write stops counting, and says why', (
      tester,
    ) async {
      final entry = await queue('Dell Latitude');

      await outbox.quarantine(
        entry.copyWith(attempts: 1),
        reason: FailureKind.validation.name,
      );

      // Re-read from disk rather than from the object just written: the
      // encrypted round trip is the thing under test.
      final held = await outbox.quarantined();
      expect(held, hasLength(1));
      expect(held.single.isQuarantined, isTrue);
      expect(held.single.quarantinedAt, isNotNull);
      expect(held.single.lastError, FailureKind.validation.name);
      expect(
        held.single.attempts,
        1,
        reason: 'the attempt that failed still happened',
      );

      // And the three consequences the feature exists for.
      expect(await outbox.pending(), isEmpty, reason: 'the banner stops');
      expect(await outbox.depth(), 0, reason: 'the queue can reach zero');
      expect(
        await outbox.subjectIds(),
        isEmpty,
        reason: 'the asset stops being overlaid with a change Odoo refused',
      );
      expect(await outbox.all(), hasLength(1), reason: 'but it is not lost');
    });

    testWidgets('retrying puts it back with a clean slate', (tester) async {
      final entry = await queue('Dell Latitude');
      await outbox.quarantine(
        entry.copyWith(attempts: OutboxEntry.maxAttempts),
        reason: FailureKind.accessDenied.name,
      );

      await outbox.retry(entry.id);

      final back = await outbox.pending();
      expect(back, hasLength(1));
      expect(back.single.isQuarantined, isFalse);
      expect(
        back.single.attempts,
        0,
        reason: 'five spent attempts would re-quarantine on the first hiccup',
      );
      expect(back.single.isBlocked, isFalse);
      expect(await outbox.depth(), 1);
    });

    testWidgets('clearing the quarantine leaves live writes alone', (
      tester,
    ) async {
      final doomed = await queue('Refused');
      final live = await queue('Still going');

      await outbox.quarantine(doomed, reason: FailureKind.validation.name);
      await outbox.clearQuarantined();

      final remaining = await outbox.all();
      expect(remaining, hasLength(1));
      expect(remaining.single.id, live.id);
      expect(await outbox.depth(), 1);
    });

    testWidgets('the queue replays in the order it was written', (
      tester,
    ) async {
      // Load-bearing after a quarantine, not only before one: assign-then-
      // return must not come back as return-then-assign because one of them
      // spent a while in quarantine.
      final first = await queue('First');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await queue('Second');

      await outbox.quarantine(first, reason: FailureKind.validation.name);
      await outbox.retry(first.id);

      final order = (await outbox.pending()).map((e) => e.id).toList();
      expect(order, <String>[first.id, second.id]);
    });
  });

  // ── 4. Session expiry, against the real keystore ───────────────────────────

  group('session expiry clears the real credential', () {
    late CredentialVault vault;
    late AppPreferences preferences;

    setUp(() async {
      // Swapped in before anything resolves `AuthRepository`, so the real
      // graph is built on top of the device's own EncryptedSharedPreferences.
      await sl.unregister<CredentialVault>();
      vault = CredentialVault.createDefault();
      sl.registerSingleton<CredentialVault>(vault);

      preferences = sl<AppPreferences>();
      await signInForTest(data);
    });

    tearDown(() async {
      // `clearSecret`, never `wipe`: the latter also deletes the Hive cipher
      // key, which would make the store the group above just wrote unreadable.
      await vault.clearSecret();
    });

    testWidgets('signing in really does write to the keystore', (tester) async {
      expect(
        await vault.hasSecret(),
        isTrue,
        reason: 'everything below is vacuous if this never landed',
      );
      expect(preferences.lastAuthenticated, isNotNull);
    });

    testWidgets('a session inside the window restores and is extended', (
      tester,
    ) async {
      final stamped = DateTime.now().subtract(const Duration(days: 3));
      await preferences.setSessionMaxAgeDays(30);
      await preferences.setLastAuthenticated(stamped);

      final result = await sl<AuthRepository>().restoreSession();

      expect(result.isRight(), isTrue);
      expect(await vault.hasSecret(), isTrue);
      expect(
        preferences.lastAuthenticated!.isAfter(stamped),
        isTrue,
        reason: 'a proven session restarts the idle window',
      );
    });

    testWidgets('a stale session deletes the credential from the device', (
      tester,
    ) async {
      // The promise the feature makes about a stolen phone.
      await preferences.setSessionMaxAgeDays(30);
      await preferences.setLastAuthenticated(
        DateTime.now().subtract(const Duration(days: 60)),
      );

      final result = await sl<AuthRepository>().restoreSession();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.kind, FailureKind.sessionExpired),
        (_) => fail('an expired session must not restore'),
      );

      expect(
        await vault.hasSecret(),
        isFalse,
        reason: 'gone from EncryptedSharedPreferences, not just from memory',
      );
      expect(preferences.lastAuthenticated, isNull);
      expect(preferences.userId, isNull);
    });

    testWidgets('"no limit" keeps a very old session alive', (tester) async {
      await preferences.setSessionMaxAgeDays(
        AppPreferences.sessionNeverExpires,
      );
      await preferences.setLastAuthenticated(
        DateTime.now().subtract(const Duration(days: 400)),
      );

      final result = await sl<AuthRepository>().restoreSession();

      expect(result.isRight(), isTrue);
      expect(await vault.hasSecret(), isTrue);
    });

    testWidgets('an upgrade with no timestamp does not sign anyone out', (
      tester,
    ) async {
      // The regression this is guarding: a security feature that reads as a
      // bug because every existing install was logged out by the update.
      await preferences.setSessionMaxAgeDays(30);
      await preferences.setLastAuthenticated(null);

      final result = await sl<AuthRepository>().restoreSession();

      expect(result.isRight(), isTrue);
      expect(await vault.hasSecret(), isTrue);
    });
  });

  // ── 5 & 6. The new surfaces, with real fonts and real ICU ──────────────────

  group('the new cards paint on a real device', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      Locale locale = const Locale('en'),
      double textScale = 1,
    }) async {
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          locale: locale,
          textScale: textScale,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the lifecycle card formats money with real locale data', (
      tester,
    ) async {
      // `NumberFormat.currency` reads ICU data that a host VM and a phone do
      // not necessarily agree about, and this is the one number in the app
      // that argues for spending money.
      final asset = Asset(
        id: 1,
        name: 'MacBook Pro',
        status: AssetStatus.available,
        purchaseDate: DateTime.now().subtract(const Duration(days: 4 * 365)),
        purchaseValue: 2400,
        currencySymbol: r'$',
      );

      await pump(tester, AssetLifecycleSection(asset: asset));

      expect(find.text(l10n.lifecycleTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.lifecycleCostPerYear), findsOneWidget);
      expect(find.textContaining(r'$'), findsWidgets);
      expectNoOverflow(tester);
    });

    testWidgets('an asset past its life says so on the device too', (
      tester,
    ) async {
      await pump(
        tester,
        AssetLifecycleSection(
          asset: Asset(
            id: 2,
            name: 'Old tower',
            status: AssetStatus.available,
            purchaseDate: DateTime.now().subtract(
              const Duration(days: 7 * 365),
            ),
          ),
        ),
      );

      expect(find.text(l10n.lifecycleOverdue), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('the session card opens on the stored window', (tester) async {
      await pump(tester, const SessionCard());

      expect(find.text(l10n.sessionTitle.toUpperCase()), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('both fit Arabic at the largest text the OS offers', (
      tester,
    ) async {
      // The combination that produced the `SectionCard` overflow: a long
      // Arabic label, a trailing chip, and the accessibility ceiling — laid
      // out here by the device's own text engine rather than the test one.
      const arabic = Locale('ar', 'EG');

      await pump(
        tester,
        Column(
          children: [
            AssetLifecycleSection(
              asset: Asset(
                id: 3,
                name: 'حاسوب محمول',
                status: AssetStatus.assigned,
                purchaseDate: DateTime.now().subtract(
                  const Duration(days: 7 * 365),
                ),
                purchaseValue: 18500,
                currencySymbol: 'ج.م',
              ),
            ),
            const SessionCard(),
          ],
        ),
        locale: arabic,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });
}
