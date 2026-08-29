import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/export/csv_writer.dart';
import 'package:sijil_it/core/export/export_documents.dart';
import 'package:sijil_it/core/export/file_share.dart';
import 'package:sijil_it/core/network/odoo/odoo_name_ref.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';

/// An export leaves the app, so it is read by software and people this code
/// will never see: a spreadsheet in another locale, a mail client, somebody's
/// laptop. Everything here is about what survives that trip.
void main() {
  const copy = ExportCopy(
    product: 'Sijil IT',
    generatedOn: 'Generated 29 Aug 2026',
    title: 'Asset list',
    subtitle: '2 assets',
    columns: <String>['Tag', 'Name'],
  );

  group('CsvWriter', () {
    test('an ordinary cell is left alone', () {
      expect(CsvWriter.cell('MacBook Pro'), 'MacBook Pro');
    });

    test('a comma in an asset name does not become a new column', () {
      // "Dell UltraSharp, 27 inch" is not an edge case in this data.
      expect(
        CsvWriter.cell('Dell UltraSharp, 27 inch'),
        '"Dell UltraSharp, 27 inch"',
      );
    });

    test('a quote is doubled, not dropped', () {
      expect(CsvWriter.cell('27" monitor'), '"27"" monitor"');
    });

    test('a newline inside a note stays inside its cell', () {
      expect(CsvWriter.cell('line one\nline two'), '"line one\nline two"');
    });

    test('a cell that looks like a formula is defused', () {
      // A spreadsheet runs `=cmd|...` on open. An asset name is not code, and
      // the fix belongs here rather than in every caller.
      expect(CsvWriter.cell('=1+1'), "'=1+1");
      expect(CsvWriter.cell('+41 79 000'), "'+41 79 000");
      expect(CsvWriter.cell('@handle'), "'@handle");
      expect(CsvWriter.cell('-lead'), "'-lead");
    });

    test('rows are CRLF-separated, as the format says', () {
      final text = CsvWriter.rows(<List<String>>[
        <String>['a', 'b'],
        <String>['c', 'd'],
      ], withBom: false);

      expect(text, 'a,b\r\nc,d');
    });

    test('the file starts with a BOM, or Excel mangles Arabic', () {
      // Without it, Windows Excel reads UTF-8 as the system codepage — on the
      // one platform an IT manager is most likely to open this with.
      final text = CsvWriter.rows(<List<String>>[
        <String>['حاسوب محمول'],
      ]);

      expect(text.startsWith(CsvWriter.bom), isTrue);
      expect(text, contains('حاسوب محمول'));
    });
  });

  group('AssetListExport', () {
    Asset assetWith({
      int id = 1,
      String name = 'MacBook Pro',
      String? tag,
      DateTime? assignedOn,
      DateTime? warrantyEnd,
      OdooNameRef? holder,
    }) => Asset(
      id: id,
      name: name,
      status: AssetStatus.assigned,
      assetTag: tag,
      assignedEmployee: holder,
      assignmentDate: assignedOn,
      warranty: warrantyEnd == null
          ? Warranty.unknown
          : Warranty.evaluate(endDate: warrantyEnd),
    );

    test('the header row is the columns it was given', () {
      final rows = AssetListExport.rows(<Asset>[], copy);
      expect(rows.first, copy.columns);
    });

    test('a missing field is an empty cell, not the word null', () {
      final rows = AssetListExport.rows(<Asset>[assetWith()], copy);

      expect(rows[1], isNot(contains('null')));
      expect(rows[1].where((c) => c.isEmpty), isNotEmpty);
    });

    test('dates are ISO, so a spreadsheet in any locale reads them', () {
      // `29/08/2026` is read as August in one place and as text in another.
      final rows = AssetListExport.rows(<Asset>[
        assetWith(assignedOn: DateTime(2026, 8, 29)),
      ], copy);

      expect(rows[1], contains('2026-08-29'));
    });

    test('a single-digit month keeps its leading zero', () {
      final rows = AssetListExport.rows(<Asset>[
        assetWith(assignedOn: DateTime(2026, 3, 4)),
      ], copy);

      expect(rows[1], contains('2026-03-04'));
    });

    test('the holder is named, because that is the column people sort on', () {
      final rows = AssetListExport.rows(<Asset>[
        assetWith(holder: const OdooNameRef(11, 'Ahmed Mohamed')),
      ], copy);

      expect(rows[1], contains('Ahmed Mohamed'));
    });

    test('the whole file is valid UTF-8 with Arabic in it', () {
      final csv = AssetListExport.csv(<Asset>[
        assetWith(name: 'حاسوب ماك بوك برو', tag: 'DH-LAP-0027'),
      ], copy);

      final bytes = utf8.encode(csv);
      expect(utf8.decode(bytes), contains('حاسوب ماك بوك برو'));
      expect(csv, contains('DH-LAP-0027'));
    });
  });

  group('FileShare.safeName', () {
    test('a path separator in an asset name does not become a folder', () {
      expect(FileShare.safeName('DH/LAP 0027', 'csv'), 'DH-LAP-0027.csv');
    });

    test('Arabic survives, because the recipient reads it', () {
      expect(FileShare.safeName('إيصال تسليم', 'pdf'), 'إيصال-تسليم.pdf');
    });

    test('a very long name is trimmed rather than rejected', () {
      final name = FileShare.safeName('a' * 200, 'pdf');
      expect(name.length, lessThan(80));
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('a name of nothing still produces a file', () {
      expect(FileShare.safeName('   ', 'csv'), 'sijil.csv');
    });
  });
}
