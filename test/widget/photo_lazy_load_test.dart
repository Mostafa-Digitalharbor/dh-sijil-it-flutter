import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/features/attachments/domain/entities/record_photo.dart';
import 'package:sijil_it/features/attachments/domain/usecases/attachment_usecases.dart';
import 'package:sijil_it/features/attachments/presentation/widgets/record_photo_image.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';
import '../fake_odoo/test_doubles.dart';

/// Where a photograph's megabytes live.
///
/// They used to live in Bloc state: `RecordPhoto` carried a `Uint8List` that
/// the Cubit filled in for **every** photo the moment the list came back. Two
/// costs, both paid whether or not anything drew the photo:
///
/// * A repair with six photos downloaded all six on open, over whatever
///   connection a technician has in a server room.
/// * Those six JPEGs — roughly eighteen megabytes — then sat in state for as
///   long as the screen was open, on top of the decoded bitmaps the image
///   cache was already holding, and nothing evicted them, because state is
///   not a cache.
///
/// They now live behind an [ImageProvider], which fetches on paint and hands
/// the result to `ImageCache`. These tests hold that line from both ends: the
/// entity must not grow a bytes field back, and listing must not fetch.
void main() {
  late FakeOdooData data;
  late InProcessOdooClient client;

  setUp(() async {
    data = FakeOdooData.seeded();
    client = await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// Calls that asked Odoo for an attachment's `datas` field — the megabytes.
  Iterable<({String path, String method, List<Object?> params})> dataReads() =>
      client.calls.where(
        (call) =>
            call.params.any((p) => p == OdooModels.irAttachment) &&
            '${call.params}'.contains(AttachmentFields.datas),
      );

  group('the entity', () {
    test('carries metadata and nothing heavy', () {
      const photo = RecordPhoto(id: 7, name: 'front.jpg', sizeBytes: 2400000);

      // `props` is the whole of it. A bytes field would show up here first.
      expect(photo.props, <Object?>[7, 'front.jpg', 2400000]);
    });

    test('two reads of the same attachment are the same value', () {
      const a = RecordPhoto(id: 7, name: 'front.jpg');
      const b = RecordPhoto(id: 7, name: 'front.jpg');

      expect(a, b);
    });
  });

  group('the image provider', () {
    test('keys on the attachment id, so the cache recognises the same photo '
        'across the strip and the viewer', () {
      final load = sl<LoadPhotoData>();

      expect(RecordPhotoImage(7, load), RecordPhotoImage(7, load));
      expect(
        RecordPhotoImage(7, load).hashCode,
        RecordPhotoImage(7, load).hashCode,
      );
      expect(RecordPhotoImage(7, load), isNot(RecordPhotoImage(8, load)));
    });

    test('a different scale is a different entry, as Flutter expects', () {
      final load = sl<LoadPhotoData>();

      expect(
        RecordPhotoImage(7, load),
        isNot(RecordPhotoImage(7, load, scale: 2)),
      );
    });

    testWidgets('resolves without throwing into the frame callback when the '
        'attachment has no readable data', (tester) async {
      // Odoo will store a file whose mimetype says image and whose bytes do
      // not decode, and a photo can be deleted in the web client between the
      // list call and the tap. Both must reach `errorBuilder`, not the
      // engine.
      var errorShown = false;

      await tester.pumpWidget(
        TestApp(
          child: Center(
            child: Image(
              image: RecordPhotoImage(999999, sl<LoadPhotoData>()),
              errorBuilder: (context, _, _) {
                errorShown = true;
                return const Icon(Icons.broken_image_outlined);
              },
            ),
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(errorShown, isTrue);
      // The failure is the provider's, handled by the widget. Nothing should
      // have escaped to the framework.
      expect(tester.takeException(), isNull);
    });
  });

  group('listing a record\'s photos', () {
    testWidgets('asks Odoo for the metadata and not for the megabytes', (
      tester,
    ) async {
      // The regression this whole change exists to prevent. A Cubit that
      // hydrates on load makes this fail with one read per photo.
      await tester.pumpWidget(const TestApp(child: SizedBox.shrink()));

      final photos = await sl<GetRecordPhotos>()(
        const RecordRef(model: OdooModels.maintenanceRequest, id: 501),
      );

      expect(photos.isRight(), isTrue);
      expect(
        dataReads(),
        isEmpty,
        reason:
            'Listing photos downloaded image data. The bytes belong to '
            'RecordPhotoImage, which fetches them when something paints one.',
      );
    });

    testWidgets('and leaves the PDF quote out of the photo strip', (
      tester,
    ) async {
      // `list` filters on mimetype server-side. A repair whose chatter carries
      // a quote must not put a broken tile among the damage photos.
      await tester.pumpWidget(const TestApp(child: SizedBox.shrink()));

      final result = await sl<GetRecordPhotos>()(
        const RecordRef(model: OdooModels.maintenanceRequest, id: 501),
      );
      final photos = result.getOrElse(() => const <RecordPhoto>[]);

      expect(photos.map((p) => p.id), <int>[9002, 9001]);
      expect(photos.map((p) => p.name), isNot(contains('repair-quote.pdf')));
    });
  });

  group('painting a photo', () {
    testWidgets('fetches its bytes, exactly once, and draws them', (
      tester,
    ) async {
      // End to end through the real repository and the real fake Odoo: the
      // provider asks for `datas`, decodes what comes back, and the second
      // widget showing the same photo is served from the image cache rather
      // than making a second round trip.
      await tester.pumpWidget(
        TestApp(
          child: Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: Image(image: RecordPhotoImage(9001, sl<LoadPhotoData>())),
            ),
          ),
        ),
      );

      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(
        dataReads(),
        hasLength(1),
        reason: 'Painting one photo should be one download.',
      );

      // A second widget on the same attachment: the cache key is the id, so
      // this must not go back to Odoo.
      await tester.pumpWidget(
        TestApp(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < 2; i++)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Image(
                      image: RecordPhotoImage(9001, sl<LoadPhotoData>()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(
        dataReads(),
        hasLength(1),
        reason: 'The same photo was downloaded twice; the cache key is wrong.',
      );
    });
  });
}
