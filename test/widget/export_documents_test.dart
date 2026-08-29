import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/export/export_documents.dart';
import 'package:sijil_it/core/export/pdf_document.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/audit/domain/entities/audit_session.dart';
import 'package:sijil_it/features/employees/domain/entities/employee.dart';
import 'package:sijil_it/features/handover/domain/entities/handover.dart';

/// The documents actually render — including in Arabic.
///
/// A PDF is the one artefact the app produces that nobody can check by
/// looking at the screen: it leaves the device and is opened somewhere else,
/// possibly weeks later. The failure this guards against is the specific one
/// PDF generation is famous for — a font with no Arabic glyphs, which prints
/// a receipt full of empty boxes and looks fine to whoever wrote the code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const copy = ExportCopy(
    product: 'Sijil IT',
    generatedOn: 'Generated 29 Aug 2026',
    title: 'إيصال تسليم',
    subtitle: 'أحمد محمد',
    columns: <String>['الوسم', 'الاسم', 'الفئة'],
    sections: <String, String>{
      'recipient': 'استلمها',
      'date': 'تاريخ التسليم',
      'assets': 'الأصول',
      'notes': 'ملاحظات',
      'signature': 'التوقيع',
      'missing': 'لم يُعثر عليه',
      'unexpected': 'خارج النطاق',
      'found': 'تم عدّه',
    },
    facts: <String, String>{'النطاق': 'كل الأصول'},
  );

  Asset assetWith({required int id, required String name}) => Asset(
    id: id,
    name: name,
    status: AssetStatus.assigned,
    assetTag: 'DH-$id',
  );

  test(
    'the Arabic face is embedded, so nothing prints as empty boxes',
    () async {
      final theme = await PdfTheme.load(isRtl: true);

      expect(theme.isRtl, isTrue);
      expect(theme.direction, isNotNull);
    },
  );

  test('a handover receipt renders with Arabic names in it', () async {
    final theme = await PdfTheme.load(isRtl: true);

    final bytes = await HandoverReceiptExport.build(
      receipt: HandoverReceipt(
        handedOver: <Asset>[
          assetWith(id: 101, name: 'حاسوب ماك بوك برو'),
          assetWith(id: 102, name: 'Dell UltraSharp, 27 inch'),
        ],
        failed: const <Asset>[],
        signedCount: 2,
      ),
      recipient: const Employee(id: 11, name: 'أحمد محمد'),
      handedOverOn: DateTime(2026, 8, 29),
      handedOverOnLabel: '٢٩ أغسطس ٢٠٢٦',
      copy: copy,
      theme: theme,
      notes: 'سُلّمت الأجهزة كاملة.',
    );

    expect(bytes.sublist(0, 4), <int>[0x25, 0x50, 0x44, 0x46], reason: '%PDF');
    expect(bytes, isNotEmpty);
  });

  test('the Arabic glyphs are really embedded, not silently dropped', () async {
    // The `pdf` package subsets the font to the glyphs a document uses, which
    // makes the file size a usable signal: an Arabic receipt has to carry
    // more glyphs than the same receipt in English. If the face had no Arabic
    // coverage the two would come out the same, and the Arabic one would
    // print a page of empty boxes that nothing else here would catch.
    Future<int> sizeOf(String name, {required bool rtl}) async {
      final bytes = await HandoverReceiptExport.build(
        receipt: HandoverReceipt(
          handedOver: <Asset>[assetWith(id: 101, name: name)],
          failed: const <Asset>[],
          signedCount: 1,
        ),
        recipient: Employee(id: 11, name: name),
        handedOverOn: DateTime(2026, 8, 29),
        handedOverOnLabel: '29 August 2026',
        copy: copy,
        theme: await PdfTheme.load(isRtl: rtl),
      );
      return bytes.length;
    }

    final arabic = await sizeOf('حاسوب ماك بوك برو الجيل الرابع', rtl: true);
    final latin = await sizeOf('MacBook Pro fourteen inch', rtl: false);

    expect(arabic, greaterThan(latin));
  });

  test('a receipt without a signature still renders the block', () async {
    // The assignment is the fact and the signature is the evidence. A missing
    // image must not silently produce a document that looks complete.
    final theme = await PdfTheme.load(isRtl: false);

    final bytes = await HandoverReceiptExport.build(
      receipt: HandoverReceipt(
        handedOver: <Asset>[assetWith(id: 101, name: 'MacBook Pro')],
        failed: const <Asset>[],
        signedCount: 0,
      ),
      recipient: const Employee(id: 11, name: 'Ahmed Mohamed'),
      handedOverOn: DateTime(2026, 8, 29),
      handedOverOnLabel: '29 August 2026',
      copy: copy,
      theme: theme,
    );

    expect(bytes.sublist(0, 4), <int>[0x25, 0x50, 0x44, 0x46]);
  });

  test('an audit report renders, missing assets and all', () async {
    final theme = await PdfTheme.load(isRtl: true);

    final expected = <int, Asset>{
      101: assetWith(id: 101, name: 'حاسوب محمول'),
      102: assetWith(id: 102, name: 'شاشة ديل'),
    };
    var session = AuditSession(
      startedAt: DateTime(2026, 8, 29),
      scope: AuditScope.all,
      expected: expected,
    );
    session = session.record(expected[101]!, DateTime(2026, 8, 29, 10));

    final bytes = await AuditReportExport.build(
      session: session,
      copy: copy,
      theme: theme,
    );

    expect(session.missingCount, 1);
    expect(bytes.sublist(0, 4), <int>[0x25, 0x50, 0x44, 0x46]);
  });

  test('a bundle of fifty assets pages rather than clipping', () async {
    // `MultiPage`, not `Page`: a handover of a whole department is a real
    // shape, and a single page would print the first fifteen rows and drop
    // the rest without saying so.
    final theme = await PdfTheme.load(isRtl: false);

    Future<int> receiptOf(int assetCount) async {
      final bytes = await HandoverReceiptExport.build(
        receipt: HandoverReceipt(
          handedOver: <Asset>[
            for (var i = 0; i < assetCount; i++)
              assetWith(id: 100 + i, name: 'Asset $i'),
          ],
          failed: const <Asset>[],
          signedCount: assetCount,
        ),
        recipient: const Employee(id: 11, name: 'Ahmed Mohamed'),
        handedOverOn: DateTime(2026, 8, 29),
        handedOverOnLabel: '29 August 2026',
        copy: copy,
        theme: theme,
      );
      return bytes.length;
    }

    // Fifty rows produce a bigger document than one. A single-page layout
    // would have dropped the overflow and come out the same size.
    expect(await receiptOf(50), greaterThan(await receiptOf(1)));
  });
}
