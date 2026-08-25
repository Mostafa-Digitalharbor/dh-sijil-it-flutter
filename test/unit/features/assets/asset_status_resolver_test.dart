import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/network/odoo/odoo_capability_service.dart';
import 'package:sijil_it/features/assets/data/services/asset_status_resolver.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';

/// The precedence rules from docs/ARCHITECTURE.md §6.
///
/// The order is the whole design: a stale "Damaged" note on one device must
/// never hide the fact that Odoo now has the asset assigned to someone, or the
/// app quietly disagrees with the Odoo web client — the one thing a companion
/// app must not do.
void main() {
  // The resolver's async half needs a capability service; the decision itself
  // is pure, so these drive `resolve` directly with the two facts it needs.
  const resolver = AssetStatusResolver(_UnusedCapabilities());

  Map<String, dynamic> record({
    Object employee = false,
    Object scrapDate = false,
    int openRequests = 0,
    String? nativeStatus,
  }) => <String, dynamic>{
    'id': 1,
    EquipmentFields.employeeId: employee,
    EquipmentFields.scrapDate: scrapDate,
    EquipmentFields.maintenanceOpenCount: openRequests,
    if (nativeStatus != null) AssetStatusField.name: nativeStatus,
  };

  group('derived from standard Odoo fields', () {
    test('nothing set means available', () {
      final result = resolver.resolve(record: record(), hasNativeField: false);

      expect(result.status, AssetStatus.available);
      expect(result.isLocal, isFalse);
    });

    test('an employee means assigned', () {
      final result = resolver.resolve(
        record: record(employee: <Object?>[11, 'Mostafa']),
        hasNativeField: false,
      );

      expect(result.status, AssetStatus.assigned);
    });

    test('an open request outranks the assignment', () {
      final result = resolver.resolve(
        record: record(employee: <Object?>[11, 'Mostafa'], openRequests: 1),
        hasNativeField: false,
      );

      expect(result.status, AssetStatus.underMaintenance);
    });

    test('a scrap date outranks everything Odoo can prove', () {
      final result = resolver.resolve(
        record: record(
          employee: <Object?>[11, 'Mostafa'],
          openRequests: 3,
          scrapDate: '2026-05-11',
        ),
        hasNativeField: false,
      );

      expect(result.status, AssetStatus.retired);
    });
  });

  group('the local overlay', () {
    test('refines an otherwise-available asset', () {
      final result = resolver.resolve(
        record: record(),
        hasNativeField: false,
        overlay: AssetStatus.damaged,
      );

      expect(result.status, AssetStatus.damaged);
      expect(result.isLocal, isTrue, reason: 'the UI must mark it as local');
    });

    test('never contradicts an assignment Odoo can prove', () {
      final result = resolver.resolve(
        record: record(employee: <Object?>[11, 'Mostafa']),
        hasNativeField: false,
        overlay: AssetStatus.damaged,
      );

      expect(result.status, AssetStatus.assigned);
      expect(result.isLocal, isFalse);
    });

    test('never contradicts a scrapped asset', () {
      final result = resolver.resolve(
        record: record(scrapDate: '2026-05-11'),
        hasNativeField: false,
        overlay: AssetStatus.reserved,
      );

      expect(result.status, AssetStatus.retired);
    });

    test('a derivable status in the overlay is ignored', () {
      // `LocalAssetStateStore` refuses to write one, but a value that predates
      // that rule must not resurrect itself as a fake "local assigned".
      final result = resolver.resolve(
        record: record(),
        hasNativeField: false,
        overlay: AssetStatus.assigned,
      );

      expect(result.status, AssetStatus.available);
      expect(result.isLocal, isFalse);
    });
  });

  group('a real Odoo status field', () {
    test('wins outright, and is not marked local', () {
      final result = resolver.resolve(
        record: record(
          employee: <Object?>[11, 'Mostafa'],
          nativeStatus: 'reserved',
        ),
        hasNativeField: true,
      );

      expect(result.status, AssetStatus.reserved);
      expect(result.isLocal, isFalse);
    });

    test('falls back to derivation when the field is present but empty', () {
      final result = resolver.resolve(
        record: record(employee: <Object?>[11, 'Mostafa']),
        hasNativeField: true,
      );

      expect(result.status, AssetStatus.assigned);
    });

    test('an unrecognised value falls back rather than throwing', () {
      final result = resolver.resolve(
        record: record(nativeStatus: 'in_transit'),
        hasNativeField: true,
      );

      expect(result.status, AssetStatus.available);
    });
  });
}

/// The resolver takes a capability service for its async half only.
///
/// `resolve` is pure once its two async facts are in hand, which is the whole
/// reason it is shaped that way — so this double exists to prove it: any call
/// that reaches Odoo from inside `resolve` fails the test loudly.
class _UnusedCapabilities implements OdooCapabilityService {
  const _UnusedCapabilities();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('The pure resolver must not call Odoo.');
}
