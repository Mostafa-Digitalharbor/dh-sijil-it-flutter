import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/utils/typedefs.dart';
import 'package:sijil_it/features/assets/data/services/asset_note_vocabulary.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_history.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assignment/domain/entities/assignment.dart';
import 'package:sijil_it/features/attachments/domain/entities/record_photo.dart';
import 'package:sijil_it/features/attachments/domain/repositories/attachment_repository.dart';
import 'package:sijil_it/features/employees/domain/entities/employee.dart';
import 'package:sijil_it/features/handover/data/repositories/handover_repository_impl.dart';
import 'package:sijil_it/features/handover/domain/entities/handover.dart';

/// A handover is several writes pretending to be one event, and the case that
/// matters is the one where Odoo accepts some of them.
///
/// Reporting a partial handover as a failure is not a cosmetic problem: the
/// user reruns the bundle and hands over the first three assets a second time.
void main() {
  Asset asset(int id, {String? tag}) => Asset(
    id: id,
    name: 'Asset $id',
    status: AssetStatus.available,
    assetTag: tag,
  );

  const recipient = Employee(id: 5, name: 'Nour Adel');

  final signature = Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10]);

  HandoverBundle bundleOf(List<Asset> assets, {String? notes}) => HandoverBundle(
    recipient: recipient,
    assets: assets,
    handedOverOn: DateTime(2026, 8, 25),
    signature: signature,
    notes: notes,
  );

  group('the bundle', () {
    test('fingerprints the signature, and the same bytes give the same one', () {
      // It is printed on the receipt and written into the note so the two can
      // be matched by eye. Two runs disagreeing would make it worthless.
      final first = bundleOf(<Asset>[asset(1)]).signatureFingerprint;
      final second = bundleOf(<Asset>[asset(1)]).signatureFingerprint;

      expect(first, second);
      expect(first, matches(RegExp(r'^[0-9A-F]{2}:[0-9A-F]{2}$')));
    });

    test('a different signature fingerprints differently', () {
      final other = HandoverBundle(
        recipient: recipient,
        assets: <Asset>[asset(1)],
        handedOverOn: DateTime(2026, 8, 25),
        signature: Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      expect(
        other.signatureFingerprint,
        isNot(bundleOf(<Asset>[asset(1)]).signatureFingerprint),
      );
    });
  });

  group('the note', () {
    test('names every item, so one record explains the whole handover', () {
      final note = AssetNoteVocabulary.handoverDetail(
        items: <String>['Latitude 5440 (SJL-0244)', 'LG 27UP850'],
        fingerprint: '8A:2F',
      );

      expect(note, contains('2 items'));
      expect(note, contains('Latitude 5440 (SJL-0244)'));
      expect(note, contains('LG 27UP850'));
      expect(note, contains('8A:2F'));
    });

    test('says "item" for one, because "1 items" reads as a bug', () {
      final note = AssetNoteVocabulary.handoverDetail(
        items: <String>['Latitude 5440'],
        fingerprint: '8A:2F',
      );

      expect(note, contains('1 item:'));
    });

    test("the user's own note is kept, after the facts", () {
      final note = AssetNoteVocabulary.handoverDetail(
        items: <String>['Latitude 5440'],
        fingerprint: '8A:2F',
        notes: 'Onboarding kit',
      );

      expect(note, endsWith('Onboarding kit'));
    });

    test('reads back as an assignment in the history timeline', () {
      // The handover note rides along as the tail of "Assigned to …", so what
      // the classifier actually sees starts with the assignment prefix.
      final body = AssetNoteVocabulary.compose(
        '${AssetNoteVocabulary.assignedPrefix} Nour Adel on 2026-08-25.',
        AssetNoteVocabulary.handoverDetail(
          items: <String>['Latitude 5440'],
          fingerprint: '8A:2F',
        ),
      );

      expect(AssetNoteVocabulary.classify(body), AssetEventKind.assigned);
    });
  });

  group('submitting', () {
    test('assigns every asset to the recipient and attaches the proof', () async {
      final assets = _RecordingAssets();
      final attachments = _RecordingAttachments();
      final repository = HandoverRepositoryImpl(
        assets: assets,
        attachments: attachments,
        model: 'maintenance.equipment',
      );

      final result = await repository.submit(
        bundleOf(<Asset>[asset(1), asset(2), asset(3)]),
      );

      final receipt = result.getOrElse(() => throw StateError('failed'));
      expect(receipt.handedOver.length, 3);
      expect(receipt.failed, isEmpty);
      expect(receipt.isComplete, isTrue);
      expect(receipt.signedCount, 3, reason: 'every asset carries the receipt');
      expect(
        assets.requests.map((r) => r.employeeId).toSet(),
        <int>{5},
        reason: 'one bundle, one recipient',
      );
    });

    test('every asset gets the same note, naming the whole bundle', () async {
      final assets = _RecordingAssets();
      final repository = HandoverRepositoryImpl(
        assets: assets,
        attachments: _RecordingAttachments(),
        model: 'maintenance.equipment',
      );

      await repository.submit(
        bundleOf(<Asset>[asset(1, tag: 'SJL-0244'), asset(2)]),
      );

      expect(assets.requests.map((r) => r.notes).toSet().length, 1);
      expect(assets.requests.first.notes, contains('SJL-0244'));
    });

    test('a refusal partway through is reported, not hidden', () async {
      // Odoo can accept the first two and refuse the third — an ACL on one
      // category, a record somebody archived while the form was open.
      final assets = _RecordingAssets(refuse: <int>{2});
      final repository = HandoverRepositoryImpl(
        assets: assets,
        attachments: _RecordingAttachments(),
        model: 'maintenance.equipment',
      );

      final result = await repository.submit(
        bundleOf(<Asset>[asset(1), asset(2), asset(3)]),
      );

      final receipt = result.getOrElse(() => throw StateError('failed'));
      expect(
        result.isRight(),
        isTrue,
        reason: 'a partial handover is a result, not an error',
      );
      expect(receipt.handedOver.map((a) => a.id), <int>[1, 3]);
      expect(receipt.failed.map((a) => a.id), <int>[2]);
      expect(receipt.isComplete, isFalse);
    });

    test('a refusal does not stop the assets after it', () async {
      final assets = _RecordingAssets(refuse: <int>{1});
      final repository = HandoverRepositoryImpl(
        assets: assets,
        attachments: _RecordingAttachments(),
        model: 'maintenance.equipment',
      );

      await repository.submit(bundleOf(<Asset>[asset(1), asset(2)]));

      expect(assets.requests.length, 2, reason: 'the second was still tried');
    });

    test('the signature goes only on the assets that changed hands', () async {
      final attachments = _RecordingAttachments();
      final repository = HandoverRepositoryImpl(
        assets: _RecordingAssets(refuse: <int>{2}),
        attachments: attachments,
        model: 'maintenance.equipment',
      );

      await repository.submit(bundleOf(<Asset>[asset(1), asset(2)]));

      expect(attachments.records, <int>[1]);
    });

    test('a failed upload weakens the proof without undoing the record', () async {
      // The assignment is the fact and the image is the evidence. Rolling back
      // a correct record to protect a thumbnail would be the wrong trade.
      final repository = HandoverRepositoryImpl(
        assets: _RecordingAssets(),
        attachments: _RecordingAttachments(failAll: true),
        model: 'maintenance.equipment',
      );

      final result = await repository.submit(
        bundleOf(<Asset>[asset(1), asset(2)]),
      );

      final receipt = result.getOrElse(() => throw StateError('failed'));
      expect(receipt.handedOver.length, 2);
      expect(receipt.signedCount, 0);
      expect(receipt.isPartiallySigned, isTrue);
    });

    test('a bundle Odoo refused entirely is knowable from the receipt', () async {
      final repository = HandoverRepositoryImpl(
        assets: _RecordingAssets(refuse: <int>{1, 2}),
        attachments: _RecordingAttachments(),
        model: 'maintenance.equipment',
      );

      final result = await repository.submit(
        bundleOf(<Asset>[asset(1), asset(2)]),
      );

      final receipt = result.getOrElse(() => throw StateError('failed'));
      expect(receipt.isTotalFailure, isTrue);
      expect(receipt.isComplete, isFalse, reason: 'nothing landed');
    });
  });
}

/// Records what was asked of the asset repository, and refuses the ids told to.
///
/// `noSuchMethod` covers the rest of the interface deliberately: this test is
/// about two calls, and fifteen `UnimplementedError` stubs would bury them.
class _RecordingAssets implements AssetRepository {
  _RecordingAssets({this.refuse = const <int>{}});

  final Set<int> refuse;
  final List<AssignmentRequest> requests = <AssignmentRequest>[];

  @override
  ResultFuture<Asset> assign(AssignmentRequest request) async {
    requests.add(request);
    if (refuse.contains(request.assetId)) {
      return const Left<Failure, Asset>(
        Failure(kind: FailureKind.accessDenied),
      );
    }
    return Right<Failure, Asset>(
      Asset(
        id: request.assetId,
        name: 'Asset ${request.assetId}',
        status: AssetStatus.assigned,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not part of this test');
}

class _RecordingAttachments implements AttachmentRepository {
  _RecordingAttachments({this.failAll = false});

  final bool failAll;

  /// The record ids the signature was uploaded against.
  final List<int> records = <int>[];

  @override
  ResultFuture<RecordPhoto> addBytes({
    required String model,
    required int recordId,
    required String filename,
    required Uint8List data,
  }) async {
    if (failAll) {
      return const Left<Failure, RecordPhoto>(
        Failure(kind: FailureKind.serverUnreachable),
      );
    }
    records.add(recordId);
    return Right<Failure, RecordPhoto>(
      RecordPhoto(id: recordId, name: filename),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not part of this test');
}
