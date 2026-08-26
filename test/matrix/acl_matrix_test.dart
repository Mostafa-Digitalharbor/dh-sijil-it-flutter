import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_detail_page.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';
import 'package:sijil_it/features/assignment/domain/entities/assignment.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_button.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The ACL matrix (spec §21 · acceptance criterion 9).
///
/// ## What this is actually protecting
///
/// Odoo's access rules are not advisory. A technician in the `Maintenance /
/// User` group can read equipment and cannot delete it; a finance viewer can
/// read and cannot write anything. The app has two honest options for each of
/// those users, and one dishonest one:
///
/// * hide the action (honest),
/// * show it and explain the refusal in words (honest),
/// * show it and let it explode into a raw `AccessError` (what ships when
///   nobody writes this file).
///
/// So every row below drives the *real* screens against a server that refuses
/// the same operations a real Odoo would, and asserts the app never reaches
/// the third option. The permissions come from `check_access_rights`, which is
/// what Odoo's own web client uses — not from a group name the app guessed at.
///
/// ## Why the denials are set before sign-in
///
/// `AuthCubit.signIn` probes capabilities and the asset screens probe
/// permissions on first load. Tightening the ACLs afterwards would test a
/// state a real session never reaches. The one test that *does* tighten them
/// late is deliberate, and says so.
void main() {
  /// From the fixture: assigned, available and scrapped respectively.
  const assignedId = 101;
  const availableId = 104;

  late AppL10n l10n;

  setUp(() async => l10n = await loadL10n());
  tearDown(() async => sl.reset());

  /// One row of the matrix.
  ///
  /// [denied] holds `model.operation` pairs exactly as Odoo's ACL table keys
  /// them, so a reader can compare a row against a real `ir.model.access`
  /// record without translating anything.
  Future<FakeOdooData> signInAs(Set<String> denied) async {
    final data = FakeOdooData.seeded()..deniedOperations.addAll(denied);
    await configureTestDependencies(data: data);
    await signInForTest(data);
    return data;
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      RoutedTestApp(
        size: TestSizes.phone,
        child: signedInScreen(const AssetListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(WidgetTester tester, int id) async {
    await tester.pumpWidget(
      RoutedTestApp(
        size: TestSizes.phone,
        child: signedInScreen(AssetDetailPage(assetId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the detail screen's overflow menu and reports what it offered.
  Future<Set<String>> menuLabels(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toSet();

    // Close it again so the next assertion is not looking at an open overlay.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    return labels;
  }

  // ── The matrix ────────────────────────────────────────────────────────────

  const equipment = OdooModels.maintenanceEquipment;

  /// Each entry is (label, denied operations, expected permissions).
  final rows =
      <
        ({
          String name,
          Set<String> denied,
          bool canCreate,
          bool canEdit,
          bool canDelete,
        })
      >[
        (
          name: 'full access',
          denied: <String>{},
          canCreate: true,
          canEdit: true,
          canDelete: true,
        ),
        (
          name: 'read-only user',
          denied: <String>{
            '$equipment.create',
            '$equipment.write',
            '$equipment.unlink',
          },
          canCreate: false,
          canEdit: false,
          canDelete: false,
        ),
        (
          name: 'no-create user',
          denied: <String>{'$equipment.create'},
          canCreate: false,
          canEdit: true,
          canDelete: true,
        ),
        (
          name: 'no-delete user',
          denied: <String>{'$equipment.unlink'},
          canCreate: true,
          canEdit: true,
          canDelete: false,
        ),
        (
          name: 'no-write user',
          denied: <String>{'$equipment.write'},
          canCreate: true,
          canEdit: false,
          canDelete: true,
        ),
      ];

  group('permissions reported by the repository', () {
    for (final row in rows) {
      test('${row.name} — check_access_rights is read, not guessed', () async {
        await signInAs(row.denied);

        final result = await sl<AssetRepository>().permissions();
        final permissions = result.fold(
          (failure) => fail('permissions() failed: ${failure.kind}'),
          (value) => value,
        );

        expect(
          (permissions.canCreate, permissions.canEdit, permissions.canDelete),
          (row.canCreate, row.canEdit, row.canDelete),
          reason: 'ACLs for ${row.name} were not read faithfully.',
        );
      });
    }
  });

  group('the asset list offers only what the user may do', () {
    for (final row in rows) {
      testWidgets('${row.name} — create FAB', (tester) async {
        await signInAs(row.denied);
        await pumpList(tester);

        // Reading is never denied in these rows, so the list must have loaded:
        // a hidden FAB is only meaningful if the screen otherwise works.
        expect(find.byType(AssetRow), findsWidgets);

        expect(
          find.byType(FloatingActionButton),
          row.canCreate ? findsOneWidget : findsNothing,
          reason: row.canCreate
              ? 'A user who may create assets lost the button.'
              : 'A user who may not create assets was offered the button.',
        );
      });
    }
  });

  group('the asset detail offers only what the user may do', () {
    for (final row in rows) {
      testWidgets('${row.name} — edit button and overflow menu', (
        tester,
      ) async {
        await signInAs(row.denied);
        await pumpDetail(tester, availableId);

        final edit = find.widgetWithText(AppButton, l10n.actionEdit);
        expect(
          edit,
          row.canEdit ? findsOneWidget : findsNothing,
          reason: 'Edit button did not match the ACLs for ${row.name}.',
        );

        final labels = await menuLabels(tester);

        // History is deliberately available to everyone: knowing who held a
        // device is a question support asks far more often than anyone edits
        // one, and reading the chatter needs no write right.
        expect(labels, contains(l10n.assetActionHistory));

        expect(
          labels.contains(l10n.actionDelete),
          row.canDelete,
          reason: 'Delete entry did not match the ACLs for ${row.name}.',
        );
        expect(
          labels.contains(l10n.assetActionsTitle),
          row.canEdit,
          reason: 'Status entry did not match the ACLs for ${row.name}.',
        );
      });
    }
  });

  group('assignment actions follow the write right', () {
    testWidgets('a read-only user is offered no Assign on a free asset', (
      tester,
    ) async {
      await signInAs(<String>{
        '$equipment.create',
        '$equipment.write',
        '$equipment.unlink',
      });
      await pumpDetail(tester, availableId);

      expect(find.widgetWithText(AppButton, l10n.actionAssign), findsNothing);
    });

    testWidgets('a read-only user is offered no Return on a held asset', (
      tester,
    ) async {
      await signInAs(<String>{
        '$equipment.create',
        '$equipment.write',
        '$equipment.unlink',
      });
      await pumpDetail(tester, assignedId);

      expect(find.widgetWithText(AppButton, l10n.actionReturn), findsNothing);
    });

    testWidgets('a writer still gets Assign', (tester) async {
      await signInAs(<String>{});
      await pumpDetail(tester, availableId);

      expect(find.widgetWithText(AppButton, l10n.actionAssign), findsOneWidget);
    });
  });

  group('a denial the probe could not predict', () {
    // Odoo record rules are row-level: `check_access_rights` can answer "yes,
    // you may write equipment" and the very next write still fails because
    // *this* record belongs to another company. The UI cannot hide that in
    // advance, so it has to survive it.
    testWidgets(
      'a write refused after the probe reads as a lock, not a crash',
      (tester) async {
        final data = await signInAs(<String>{});
        await pumpDetail(tester, availableId);

        // The probe has already run and said "you may write".
        expect(find.widgetWithText(AppButton, l10n.actionEdit), findsOneWidget);

        // Now the record rule bites.
        data.deniedOperations.add('$equipment.write');

        final result = await sl<AssetRepository>().assign(
          AssignmentRequest(
            assetId: availableId,
            employeeId: 11,
            employeeName: 'Mostafa Bader',
            assignedOn: DateTime(2026, 3, 1),
          ),
        );

        final failure = result.fold<Failure?>((f) => f, (_) => null);
        expect(
          failure?.kind,
          FailureKind.accessDenied,
          reason:
              'A record-rule refusal must map to accessDenied, so the user '
              'reads "you are not allowed to" rather than an Odoo traceback.',
        );
      },
    );

    testWidgets('a read refused outright shows the locked failure view', (
      tester,
    ) async {
      await signInAs(<String>{'$equipment.search_read', '$equipment.read'});
      await pumpList(tester);

      expect(find.byType(AssetRow), findsNothing);
      expect(find.byType(FailureView), findsOneWidget);
      expect(find.text(l10n.errorAccessDeniedTitle), findsOneWidget);
      expect(
        find.byIcon(Icons.lock_outline_rounded),
        findsOneWidget,
        reason: 'A permissions wall should not look like a network error.',
      );
    });
  });
}
