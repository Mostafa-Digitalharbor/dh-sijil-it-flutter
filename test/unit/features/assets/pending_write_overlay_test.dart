import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/network/odoo/odoo_name_ref.dart';
import 'package:sijil_it/core/sync/outbox_entry.dart';
import 'package:sijil_it/features/assets/data/services/pending_write_overlay.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';

/// What the user sees while a write is still sitting in the queue.
///
/// This used to be a private method on a 777-line repository, reachable only
/// by standing up a fake Odoo, a state store, a due-date store and an outbox,
/// and then asserting on an asset that came back through all four. The rules
/// it encodes are the densest in that file — three outbox kinds, each
/// rewriting a different set of fields, with an ordering constraint between
/// them — and they were the least directly tested thing in it.
///
/// It is a pure function. It deserved to be one out loud.
void main() {
  final now = DateTime(2026, 8, 31, 9);

  Asset shelved({int id = 101}) =>
      Asset(id: id, name: 'MacBook Pro 14', status: AssetStatus.available);

  OutboxEntry entry(
    OutboxKind kind,
    Map<String, dynamic> payload, {
    int subjectId = 101,
    DateTime? queuedAt,
  }) => OutboxEntry(
    id: '${kind.name}-$subjectId-${payload.hashCode}',
    kind: kind,
    subjectId: subjectId,
    subjectName: 'MacBook Pro 14',
    payload: payload,
    queuedAt: queuedAt ?? now,
  );

  group('an empty queue', () {
    test('leaves the asset exactly as it came back from Odoo', () {
      final asset = shelved();

      expect(PendingWriteOverlay.apply(asset, const <OutboxEntry>[]), asset);
    });

    test('and so does a queue about a different asset', () {
      // The screen shows one asset; the queue is global.
      final asset = shelved();
      final other = entry(OutboxKind.assignAsset, <String, dynamic>{
        'employeeId': 7,
      }, subjectId: 999);

      final result = PendingWriteOverlay.apply(asset, <OutboxEntry>[other]);

      expect(result, asset);
      expect(result.hasPendingSync, isFalse);
    });
  });

  group('a queued assignment', () {
    test('shows the asset as assigned to the person it was given to', () {
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.assignAsset, <String, dynamic>{
          'employeeId': 11,
          'employeeName': 'Mostafa Bader',
          'assignedOn': '2026-08-30',
          'dueOn': '2026-09-30',
        }),
      ]);

      expect(result.status, AssetStatus.assigned);
      expect(result.assignedEmployee, const OdooNameRef(11, 'Mostafa Bader'));
      expect(result.assignmentDate, DateTime(2026, 8, 30));
    });

    test('and says so, so nothing claims Odoo has agreed yet', () {
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.assignAsset, <String, dynamic>{'employeeId': 11}),
      ]);

      expect(result.hasPendingSync, isTrue);
      // Assigned is a real Odoo status, not one of the three the app keeps
      // locally, so it must not be flagged as an overlay.
      expect(result.isStatusLocal, isFalse);
    });

    test('evaluates the return date against being assigned, not against the '
        'record Odoo still has', () {
      // The record read back from Odoo does not know the asset is assigned
      // yet, and `ReturnDue` needs that fact to mean anything.
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.assignAsset, <String, dynamic>{
          'employeeId': 11,
          'dueOn': '2020-01-01',
        }),
      ]);

      expect(result.dueBack.isOverdue, isTrue);
    });

    test('survives a payload with nothing in it', () {
      // An entry written by an older build, or one whose payload was
      // truncated. It must still replay rather than wedge the queue.
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.assignAsset, const <String, dynamic>{}),
      ]);

      expect(result.status, AssetStatus.assigned);
      expect(result.assignedEmployee?.id, 0);
      // No date in the payload, so the moment it was queued stands in.
      expect(result.assignmentDate, now);
    });
  });

  group('a queued return', () {
    test('clears the assignment', () {
      final assigned = shelved().copyWith(
        status: AssetStatus.assigned,
        assignedEmployee: const OdooNameRef(11, 'Mostafa Bader'),
      );

      final result = PendingWriteOverlay.apply(assigned, <OutboxEntry>[
        entry(OutboxKind.returnAsset, <String, dynamic>{
          'condition': ReturnCondition.good.name,
        }),
      ]);

      expect(result.status, AssetStatus.available);
      expect(result.assignedEmployee, isNull);
      expect(result.hasPendingSync, isTrue);
    });

    test('carries the condition through to the resulting status', () {
      for (final condition in ReturnCondition.values) {
        final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
          entry(OutboxKind.returnAsset, <String, dynamic>{
            'condition': condition.name,
          }),
        ]);

        expect(
          result.status,
          condition.resultingStatus,
          reason:
              'A ${condition.name} return should land as '
              '${condition.resultingStatus.name}.',
        );
        expect(result.isStatusLocal, condition.resultingStatus.isLocalOnly);
      }
    });

    test(
      'falls back to available for a condition this build does not know',
      () {
        // Renamed upstream, or written by a newer build and replayed by an
        // older one. Losing the nuance beats wedging the queue.
        final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
          entry(OutboxKind.returnAsset, <String, dynamic>{
            'condition': 'chewed_by_a_dog',
          }),
        ]);

        expect(result.status, AssetStatus.available);
      },
    );
  });

  group('a queued status change', () {
    test('applies it and marks it as the local overlay it is', () {
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.setAssetStatus, <String, dynamic>{
          'status': AssetStatus.damaged.name,
        }),
      ]);

      expect(result.status, AssetStatus.damaged);
      expect(result.isStatusLocal, isTrue);
    });

    test('keeps the current status when the payload names an unknown one', () {
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.setAssetStatus, <String, dynamic>{
          'status': 'haunted',
        }),
      ]);

      expect(result.status, AssetStatus.available);
    });
  });

  group('several entries for one asset', () {
    test('land in the order they will land on Odoo', () {
      // Assign then return: the asset ends up back on the shelf, unassigned.
      // Applied the other way round it would end up assigned to somebody who
      // has already given it back — which is what the user would then read.
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.assignAsset, <String, dynamic>{
          'employeeId': 11,
          'employeeName': 'Mostafa Bader',
        }, queuedAt: now),
        entry(OutboxKind.returnAsset, <String, dynamic>{
          'condition': ReturnCondition.good.name,
        }, queuedAt: now.add(const Duration(hours: 1))),
      ]);

      expect(result.status, AssetStatus.available);
      expect(result.assignedEmployee, isNull);
      expect(result.hasPendingSync, isTrue);
    });

    test('and a return followed by a status change keeps the change', () {
      final result = PendingWriteOverlay.apply(shelved(), <OutboxEntry>[
        entry(OutboxKind.returnAsset, <String, dynamic>{
          'condition': ReturnCondition.good.name,
        }, queuedAt: now),
        entry(OutboxKind.setAssetStatus, <String, dynamic>{
          'status': AssetStatus.reserved.name,
        }, queuedAt: now.add(const Duration(minutes: 5))),
      ]);

      expect(result.status, AssetStatus.reserved);
      expect(result.isStatusLocal, isTrue);
    });
  });
}
