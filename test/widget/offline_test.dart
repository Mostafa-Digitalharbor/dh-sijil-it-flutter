import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/sync/outbox_entry.dart';
import 'package:sijil_it/core/sync/outbox_store.dart';
import 'package:sijil_it/core/sync/sync_service.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_query.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/assignment/domain/entities/assignment.dart';
import 'package:sijil_it/features/employees/domain/entities/employee.dart';
import 'package:sijil_it/features/employees/domain/repositories/employee_repository.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/cubit/sync_cubit.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// The technician in the basement.
///
/// The scenario this whole feature exists for: someone walks into a server
/// room, the signal goes, they hand over six laptops anyway, and they walk
/// back out. Nothing they did may be lost, nothing may be silently pretended,
/// and the moment there is signal it all goes to Odoo without being asked.
void main() {
  late FakeOdooData data;
  late InProcessOdooClient client;
  late FakeNetworkInfo network;
  late AppL10n en;

  setUpAll(() async => en = await loadL10n());

  setUp(() async {
    data = FakeOdooData.seeded();
    network = FakeNetworkInfo();
    client = await configureTestDependencies(data: data, network: network);
    await signInForTest(data);
  });

  tearDown(() async {
    await network.dispose();
    await sl.reset();
  });

  /// An asset the fixture actually holds, read while there is still signal.
  Future<int> anAvailableAsset() async {
    final page = await sl<AssetRepository>().getAssets(const AssetQuery());
    return page.fold(
      (failure) => throw StateError('fixture unreadable: ${failure.kind}'),
      (page) =>
          page.items.firstWhere((a) => a.status == AssetStatus.available).id,
    );
  }

  /// Cuts the connection the way a basement does: the device knows, and the
  /// socket would fail too.
  void goOffline() {
    network.connected = false;
    client.unreachable = true;
  }

  void comeBack() {
    client.unreachable = false;
    network.connected = true;
  }

  group('reading', () {
    testWidgets('the list a technician left open is still there downstairs', (
      tester,
    ) async {
      // Before: an error screen, and the fleet they were looking at upstairs
      // was gone.
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const AssetListPage()),
        ),
      );
      await tester.pumpAndSettle();
      final live = find.byType(AssetRow).evaluate().length;
      expect(live, greaterThanOrEqualTo(1));

      goOffline();
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: signedInScreen(const AssetListPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.errorNoInternetTitle), findsNothing);
      expect(
        find.byType(AssetRow).evaluate().length,
        live,
        reason: 'the fleet they were looking at upstairs is still here',
      );
    });

    testWidgets('the recipient picker still has people in it', (tester) async {
      // The half that was missing: an asset list a technician can browse and
      // a picker they cannot, which stops a handover one field short of being
      // queueable.
      final repository = sl<EmployeeRepository>();
      final live = await repository.search('');
      expect(live.getOrElse(() => const <Employee>[]), isNotEmpty);

      goOffline();

      final cached = await repository.search('');
      expect(
        cached.getOrElse(() => const <Employee>[]),
        isNotEmpty,
        reason: 'the people the picker opens with have to survive the walk',
      );
    });

    test('a list the device has never seen still fails honestly', () async {
      // "Try again" is the only useful answer for a question never asked.
      goOffline();

      final result = await sl<AssetRepository>().getAssets(
        const AssetQuery(filters: AssetFilters(query: 'never-searched-before')),
      );

      expect(result.isLeft(), isTrue);
    });

    test('a refusal is never papered over with yesterday\'s copy', () async {
      // Read it once so a copy exists, then have Odoo refuse.
      final id = await anAvailableAsset();
      client.faults['maintenance.equipment.read'] = (
        code: 1,
        message: 'AccessError: you may not read this record',
      );

      final result = await sl<AssetRepository>().getAsset(id);
      expect(
        result.isLeft(),
        isTrue,
        reason: 'an ACL is not a connection problem',
      );
    });
  });

  group('writing', () {
    test('six handovers in a basement are all kept', () async {
      final assets = await sl<AssetRepository>().getAssets(const AssetQuery());
      final ids = assets.fold(
        (_) => <int>[],
        (page) => page.items.take(3).map((a) => a.id).toList(),
      );
      expect(ids, isNotEmpty);

      goOffline();

      for (final id in ids) {
        final result = await sl<AssetRepository>().assign(
          AssignmentRequest(
            assetId: id,
            employeeId: 11,
            employeeName: 'Ahmed Mohamed',
            assignedOn: DateTime(2026, 8, 29),
          ),
        );
        expect(result.isRight(), isTrue, reason: 'asset $id was refused');
      }

      expect(await sl<OutboxStore>().depth(), ids.length);
    });

    test('the result says the handover happened, and that Odoo has not '
        'heard', () async {
      final id = await anAvailableAsset();
      goOffline();

      final result = await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      final asset = result.getOrElse(() => throw StateError('refused'));
      expect(asset.status, AssetStatus.assigned);
      expect(asset.assignedEmployee?.name, 'Ahmed Mohamed');
      expect(
        asset.hasPendingSync,
        isTrue,
        reason: 'nothing may claim Odoo agrees yet',
      );
    });

    test(
      'and the screen behind it agrees, not just the one that acted',
      () async {
        // Two stories at once is the failure this guards: the banner saying a
        // handover is waiting while the detail underneath still shows the
        // laptop on the shelf, because the cached record it re-read predates
        // the handover.
        final id = await anAvailableAsset();
        goOffline();

        await sl<AssetRepository>().assign(
          AssignmentRequest(
            assetId: id,
            employeeId: 11,
            employeeName: 'Ahmed Mohamed',
            assignedOn: DateTime(2026, 8, 29),
          ),
        );

        final reread = await sl<AssetRepository>().getAsset(id);
        final asset = reread.getOrElse(() => throw StateError('gone'));
        expect(asset.status, AssetStatus.assigned);
        expect(asset.assignedEmployee?.name, 'Ahmed Mohamed');
        expect(asset.hasPendingSync, isTrue);

        // And in the list, which reads a different code path.
        final page = await sl<AssetRepository>().getAssets(const AssetQuery());
        final row = page
            .getOrElse(() => throw StateError('gone'))
            .items
            .firstWhere((a) => a.id == id);
        expect(row.status, AssetStatus.assigned);
        expect(row.hasPendingSync, isTrue);
      },
    );

    test('a queued return shows the asset back on the shelf', () async {
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().unassign(
        ReturnRequest(
          assetId: id,
          condition: ReturnCondition.damaged,
          returnedOn: DateTime(2026, 8, 29),
        ),
      );

      final asset = (await sl<AssetRepository>().getAsset(
        id,
      )).getOrElse(() => throw StateError('gone'));
      expect(asset.status, AssetStatus.damaged);
      expect(asset.assignedEmployee, isNull);
      expect(asset.hasPendingSync, isTrue);
    });

    test('once the queue is sent, the marker goes with it', () async {
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      comeBack();
      await sl<SyncService>().drain();

      final asset = (await sl<AssetRepository>().getAsset(
        id,
      )).getOrElse(() => throw StateError('gone'));
      expect(asset.assignedEmployee?.id, 11);
      expect(
        asset.hasPendingSync,
        isFalse,
        reason: 'a badge that outlives the queue means nothing',
      );
    });

    test('a queued asset is marked as such everywhere it appears', () async {
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      final reread = await sl<AssetRepository>().getAsset(id);
      expect(
        reread.getOrElse(() => throw StateError('gone')).hasPendingSync,
        isTrue,
      );
    });

    test('a return is queued with the condition the user chose', () async {
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().unassign(
        ReturnRequest(
          assetId: id,
          condition: ReturnCondition.damaged,
          returnedOn: DateTime(2026, 8, 29),
        ),
      );

      final entry = (await sl<OutboxStore>().pending()).single;
      expect(entry.kind, OutboxKind.returnAsset);
      expect(entry.payload['condition'], ReturnCondition.damaged.name);
    });

    test('a refusal is reported, not queued', () async {
      // Odoo is reachable and says no. Queueing that would hide the one
      // message that explains it and retry it four more times.
      final id = await anAvailableAsset();
      client.faults['maintenance.equipment.write'] = (
        code: 1,
        message: 'AccessError: you may not modify this record',
      );

      final result = await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(await sl<OutboxStore>().depth(), 0);
    });
  });

  group('coming back into signal', () {
    test('the queue empties by itself', () async {
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed Mohamed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );
      expect(await sl<OutboxStore>().depth(), 1);

      comeBack();
      final report = await sl<SyncService>().drain();

      expect(report.sent, 1);
      expect(report.remaining, 0);

      // And it actually landed: Odoo now holds the assignment.
      final asset = await sl<AssetRepository>().getAsset(id);
      expect(
        asset.getOrElse(() => throw StateError('gone')).assignedEmployee?.id,
        11,
      );
    });

    test('a queue written yesterday goes out on the next launch', () async {
      // Connectivity only *emits* on a change. The walk back into signal
      // happened while the app was closed, so nothing was listening for it —
      // and the queue would have sat there until the next time the wifi
      // happened to flicker.
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );
      expect(await sl<OutboxStore>().depth(), 1);

      // A fresh launch on a desk: online from the first frame, no transition.
      comeBack();
      sl<SyncService>().start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await sl<OutboxStore>().depth(), 0);
    });

    test('a drain that cannot connect leaves the queue as it was', () async {
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      // The device thinks it is online; the server is still unreachable. This
      // is the case that used to double the queue on every attempt.
      network.connected = true;
      final report = await sl<SyncService>().drain();

      expect(report.sent, 0);
      expect(
        await sl<OutboxStore>().depth(),
        1,
        reason: 'a failed replay must not enqueue itself again',
      );
    });

    test('a write Odoo refuses outright leaves the queue at once', () async {
      // Not after five attempts. An `AccessError` says the answer will be the
      // same every time, and the four extra round trips only keep the asset
      // wrongly overlaid for longer.
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      comeBack();
      client.faults['maintenance.equipment.write'] = (
        code: 1,
        message: 'AccessError: you may not modify this record',
      );

      await sl<SyncService>().drain();

      final outbox = sl<OutboxStore>();
      expect(
        await outbox.pending(),
        isEmpty,
        reason: 'a badge that never clears stops meaning anything',
      );

      final given = (await outbox.quarantined()).single;
      expect(given.isQuarantined, isTrue);
      expect(
        given.attempts,
        1,
        reason: 'one attempt was enough to learn the answer',
      );
      expect(
        given.lastError,
        FailureKind.accessDenied.name,
        reason: 'the screen shows why, so the user can ask for the right thing',
      );
    });

    test('and stops overlaying the asset it could not change', () async {
      // The reason quarantine exists. While the entry was pending, the overlay
      // kept rewriting the asset to the state the failed write intended — so
      // the detail screen showed a handover Odoo had rejected and would never
      // accept, for ever, with no way back short of discarding every other
      // queued write with it.
      final id = await anAvailableAsset();
      goOffline();

      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );

      final outbox = sl<OutboxStore>();
      expect(await outbox.subjectIds(), contains(id));

      comeBack();
      client.faults['maintenance.equipment.write'] = (
        code: 1,
        message: 'AccessError: you may not modify this record',
      );
      await sl<SyncService>().drain();

      expect(
        await outbox.subjectIds(),
        isNot(contains(id)),
        reason: 'the record on screen goes back to what Odoo actually holds',
      );
    });

    test(
      'a retryable failure still spends its attempts before giving up',
      () async {
        // The other route into quarantine, and it must not be the fast one: a
        // server that is briefly unwell should be retried, not written off.
        final id = await anAvailableAsset();
        goOffline();

        await sl<AssetRepository>().assign(
          AssignmentRequest(
            assetId: id,
            employeeId: 11,
            employeeName: 'Ahmed',
            assignedOn: DateTime(2026, 8, 29),
          ),
        );

        comeBack();
        client.faults['maintenance.equipment.write'] = (
          code: 1,
          message: 'Internal Server Error',
        );

        final outbox = sl<OutboxStore>();
        for (
          var attempt = 0;
          attempt < OutboxEntry.maxAttempts - 1;
          attempt++
        ) {
          await sl<SyncService>().drain();
          expect(
            await outbox.pending(),
            hasLength(1),
            reason: 'still worth retrying after ${attempt + 1} attempts',
          );
        }

        await sl<SyncService>().drain();
        expect(await outbox.pending(), isEmpty);
        expect(await outbox.quarantined(), hasLength(1));
      },
    );

    test(
      'a quarantined write can be sent once the refusal is lifted',
      () async {
        final id = await anAvailableAsset();
        goOffline();

        await sl<AssetRepository>().assign(
          AssignmentRequest(
            assetId: id,
            employeeId: 11,
            employeeName: 'Ahmed',
            assignedOn: DateTime(2026, 8, 29),
          ),
        );

        comeBack();
        client.faults['maintenance.equipment.write'] = (
          code: 1,
          message: 'AccessError: you may not modify this record',
        );
        await sl<SyncService>().drain();

        final outbox = sl<OutboxStore>();
        final given = (await outbox.quarantined()).single;

        // The administrator grants the permission.
        client.faults.remove('maintenance.equipment.write');
        await outbox.retry(given.id);

        expect(
          (await outbox.pending()).single.attempts,
          0,
          reason: 'carrying spent attempts forward sends it straight back',
        );

        await sl<SyncService>().drain();

        expect(await outbox.pending(), isEmpty);
        expect(await outbox.quarantined(), isEmpty);
        final row = data
            .tableOf('maintenance.equipment')
            .firstWhere((r) => r['id'] == id);
        expect(
          row['employee_id'],
          isNot(false),
          reason: 'the work the technician did finally reached Odoo',
        );
      },
    );
  });

  group('what the user is told', () {
    testWidgets('the banner appears with something waiting, and says how '
        'many', (tester) async {
      final id = await anAvailableAsset();
      final cubit = sl<SyncCubit>();
      await cubit.start();

      goOffline();
      await sl<AssetRepository>().assign(
        AssignmentRequest(
          assetId: id,
          employeeId: 11,
          employeeName: 'Ahmed',
          assignedOn: DateTime(2026, 8, 29),
        ),
      );
      await tester.pump();

      expect(cubit.state.pending, hasLength(1));
      expect(cubit.state.shouldWarn, isTrue);
    });

    testWidgets('and stays quiet when there is nothing to say', (tester) async {
      final cubit = sl<SyncCubit>();
      await cubit.start();
      await tester.pump();

      expect(
        cubit.state.shouldWarn,
        isFalse,
        reason: 'a banner that is always there is a banner nobody reads',
      );
    });
  });
}
