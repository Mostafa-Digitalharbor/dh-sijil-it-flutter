import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/pagination/paginated_result.dart';
import 'package:sijil_it/core/utils/typedefs.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_query.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assets/domain/usecases/asset_usecases.dart';
import 'package:sijil_it/features/employees/domain/entities/employee.dart';
import 'package:sijil_it/features/employees/domain/repositories/employee_repository.dart';
import 'package:sijil_it/features/employees/domain/usecases/employee_usecases.dart';
import 'package:sijil_it/features/handover/domain/entities/handover.dart';
import 'package:sijil_it/features/handover/domain/repositories/handover_repository.dart';
import 'package:sijil_it/features/handover/domain/usecases/handover_usecases.dart';
import 'package:sijil_it/features/handover/presentation/cubit/handover_cubit.dart';

/// The rules the screen enforces before it will let anything be written.
void main() {
  Asset asset(int id) =>
      Asset(id: id, name: 'Asset $id', status: AssetStatus.available);

  const recipient = Employee(id: 5, name: 'Nour Adel');

  HandoverCubit cubitWith({HandoverRepository? handovers}) => HandoverCubit(
    searchEmployees: SearchEmployees(_NoEmployees()),
    getAssets: GetAssetsPage(_NoAssets()),
    submitHandover: SubmitHandover(handovers ?? _AcceptsEverything()),
    clock: () => DateTime(2026, 8, 25, 9, 41),
  );

  group('what blocks the confirm button', () {
    test('nothing chosen at all asks for the recipient first', () {
      const state = HandoverState();

      expect(state.canSubmit, isFalse);
      expect(state.blocker, HandoverBlocker.recipient);
    });

    test('a recipient with an empty bundle asks for assets', () {
      final state = HandoverState(
        recipient: recipient,
        handedOverOn: DateTime(2026, 8, 25),
      );

      expect(state.blocker, HandoverBlocker.assets);
    });

    test('a full bundle still needs the signature', () {
      // The whole point of the flow. Without this gate it is the per-asset
      // assign screen with extra steps.
      final state = HandoverState(
        recipient: recipient,
        bundle: <Asset>[asset(1)],
        handedOverOn: DateTime(2026, 8, 25),
      );

      expect(state.blocker, HandoverBlocker.signature);
      expect(state.canSubmit, isFalse);
    });

    test(
      'signed, chosen and dated is submittable, with nothing left to say',
      () {
        final state = HandoverState(
          recipient: recipient,
          bundle: <Asset>[asset(1)],
          handedOverOn: DateTime(2026, 8, 25),
          isSigned: true,
        );

        expect(state.canSubmit, isTrue);
        expect(state.blocker, isNull);
      },
    );

    test('a submission in flight cannot be started twice', () {
      final state = HandoverState(
        recipient: recipient,
        bundle: <Asset>[asset(1)],
        handedOverOn: DateTime(2026, 8, 25),
        isSigned: true,
        isSubmitting: true,
      );

      expect(state.canSubmit, isFalse);
    });
  });

  group('the bundle', () {
    test('defaults the date to today, so the usual case needs no input', () {
      final cubit = cubitWith()..start();

      expect(cubit.state.handedOverOn, DateTime(2026, 8, 25));
      addTearDown(cubit.close);
    });

    test('the same asset added twice appears once', () {
      // What happens when someone is not sure the first tap registered. Twice
      // on the receipt is twice in the note and twice in the count.
      final cubit = cubitWith()..start();
      cubit
        ..addToBundle(asset(1))
        ..addToBundle(asset(1));

      expect(cubit.state.bundle.length, 1);
      addTearDown(cubit.close);
    });

    test('stops accepting assets at the cap', () {
      final cubit = cubitWith()..start();
      for (var id = 1; id <= HandoverBundle.maxAssets + 3; id++) {
        cubit.addToBundle(asset(id));
      }

      expect(cubit.state.bundle.length, HandoverBundle.maxAssets);
      expect(cubit.state.isFull, isTrue);
      addTearDown(cubit.close);
    });

    test('removing takes out the one asked for and nothing else', () {
      final cubit = cubitWith()..start();
      cubit
        ..addToBundle(asset(1))
        ..addToBundle(asset(2))
        ..addToBundle(asset(3))
        ..removeFromBundle(2);

      expect(cubit.state.bundle.map((a) => a.id), <int>[1, 3]);
      addTearDown(cubit.close);
    });
  });

  group('after a partial handover', () {
    test('retrying carries only what Odoo refused', () async {
      // Retrying the whole bundle would hand the accepted assets over twice.
      final cubit = cubitWith(handovers: const _Refuses(<int>{2}))..start();
      cubit
        ..addToBundle(asset(1))
        ..addToBundle(asset(2))
        ..chooseRecipient(recipient)
        ..setSigned(isSigned: true);

      await cubit.submit(Uint8List.fromList(<int>[1, 2, 3]));
      expect(cubit.state.receipt?.failed.map((a) => a.id), <int>[2]);

      cubit.retryFailed();

      expect(cubit.state.bundle.map((a) => a.id), <int>[2]);
      expect(cubit.state.receipt, isNull, reason: 'back to the form');
      expect(
        cubit.state.isSigned,
        isFalse,
        reason: 'a new handover needs a new signature',
      );
      expect(cubit.state.recipient, recipient, reason: 'same person');
      addTearDown(cubit.close);
    });

    test('a complete handover has nothing to retry', () async {
      final cubit = cubitWith()..start();
      cubit
        ..addToBundle(asset(1))
        ..chooseRecipient(recipient)
        ..setSigned(isSigned: true);

      await cubit.submit(Uint8List.fromList(<int>[1]));
      final receipt = cubit.state.receipt;
      cubit.retryFailed();

      expect(receipt?.isComplete, isTrue);
      expect(cubit.state.receipt, same(receipt), reason: 'nothing happened');
      addTearDown(cubit.close);
    });
  });

  test(
    'submitting without a signature is refused before it reaches Odoo',
    () async {
      final handovers = _AcceptsEverything();
      final cubit = cubitWith(handovers: handovers)..start();
      cubit
        ..addToBundle(asset(1))
        ..chooseRecipient(recipient);

      await cubit.submit(null);

      expect(handovers.submitted, isEmpty);
      expect(cubit.state.receipt, isNull);
      addTearDown(cubit.close);
    },
  );
}

class _AcceptsEverything implements HandoverRepository {
  final List<HandoverBundle> submitted = <HandoverBundle>[];

  @override
  ResultFuture<HandoverReceipt> submit(HandoverBundle bundle) async {
    submitted.add(bundle);
    return Right<Failure, HandoverReceipt>(
      HandoverReceipt(
        handedOver: bundle.assets,
        failed: const <Asset>[],
        signedCount: bundle.assets.length,
      ),
    );
  }
}

class _Refuses implements HandoverRepository {
  const _Refuses(this.ids);

  final Set<int> ids;

  @override
  ResultFuture<HandoverReceipt> submit(HandoverBundle bundle) async {
    final failed = bundle.assets.where((a) => ids.contains(a.id)).toList();
    final ok = bundle.assets.where((a) => !ids.contains(a.id)).toList();

    return Right<Failure, HandoverReceipt>(
      HandoverReceipt(handedOver: ok, failed: failed, signedCount: ok.length),
    );
  }
}

/// The pickers are not what these tests are about; both answer emptily.
class _NoEmployees implements EmployeeRepository {
  @override
  ResultFuture<List<Employee>> search(String term, {int limit = 20}) async =>
      const Right<Failure, List<Employee>>(<Employee>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoAssets implements AssetRepository {
  @override
  ResultFuture<PaginatedResult<Asset>> getAssets(AssetQuery query) async =>
      const Right<Failure, PaginatedResult<Asset>>(
        PaginatedResult<Asset>.empty(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
