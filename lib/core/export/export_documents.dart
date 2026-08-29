import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../features/assets/domain/entities/asset.dart';
import '../../features/audit/domain/entities/audit_session.dart';
import '../../features/employees/domain/entities/employee.dart';
import '../../features/handover/domain/entities/handover.dart';
import 'csv_writer.dart';
import 'pdf_document.dart';

/// Every label a generated document needs, resolved by the screen asking for
/// it.
///
/// A record rather than an `AppL10n`: this layer builds documents and has no
/// business knowing which of four hundred strings exist. It also makes the
/// builders testable without loading localizations.
class ExportCopy {
  const ExportCopy({
    required this.product,
    required this.generatedOn,
    required this.title,
    required this.subtitle,
    required this.columns,
    this.sections = const <String, String>{},
    this.facts = const <String, String>{},
  });

  /// "Sijil IT", in the corner of every page.
  final String product;

  /// "Generated 29 Aug 2026, 14:12".
  final String generatedOn;

  final String title;
  final String subtitle;

  /// Table headers, in order.
  final List<String> columns;

  /// Headings inside the document, by a key the builder knows.
  final Map<String, String> sections;

  /// Label/value pairs printed above the table.
  final Map<String, String> facts;
}

/// The asset list, as the user filtered it.
///
/// CSV rather than PDF: this is the export somebody opens in a spreadsheet to
/// sort, pivot and send on, and a PDF of two hundred rows is a worse version
/// of the screen they already have.
abstract final class AssetListExport {
  /// The columns, in the order an IT manager reads them.
  static List<List<String>> rows(List<Asset> assets, ExportCopy copy) =>
      <List<String>>[
        copy.columns,
        for (final asset in assets)
          <String>[
            asset.assetTag ?? '',
            asset.name,
            asset.category?.name ?? '',
            asset.manufacturer ?? '',
            asset.model ?? '',
            asset.serialNumber ?? '',
            asset.status.name,
            asset.assignedEmployee?.name ?? '',
            asset.department?.name ?? '',
            _date(asset.assignmentDate),
            _date(asset.warranty.endDate),
          ],
      ];

  static String csv(List<Asset> assets, ExportCopy copy) =>
      CsvWriter.rows(rows(assets, copy));

  /// ISO, not the user's locale.
  ///
  /// A spreadsheet parses `2026-08-29` in every locale and sorts it as text
  /// correctly; `29/08/2026` is read as August in one place and as a string
  /// in another. The screen shows the localised form — a file that another
  /// program will parse is a different audience.
  static String _date(DateTime? value) => value == null
      ? ''
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
}

/// The handover receipt: who took what, when, and their signature.
///
/// The one document in the app that is *evidence*. It already existed as a
/// screen and a chatter note; what was missing was the copy the recipient
/// keeps and the copy that goes in a folder.
abstract final class HandoverReceiptExport {
  static Future<Uint8List> build({
    required HandoverReceipt receipt,
    required Employee recipient,
    required DateTime handedOverOn,
    required String handedOverOnLabel,
    required ExportCopy copy,
    required PdfTheme theme,
    Uint8List? signature,
    String? notes,
  }) => PdfParts.build(
    theme: theme,
    generatedOn: copy.generatedOn,
    body: (context) => <pw.Widget>[
      PdfParts.header(
        title: copy.title,
        subtitle: copy.subtitle,
        product: copy.product,
      ),
      pw.SizedBox(height: 16),

      for (final entry in copy.facts.entries)
        PdfParts.fact(entry.key, entry.value),
      PdfParts.fact(copy.sections['recipient'] ?? '', recipient.name),
      PdfParts.fact(copy.sections['date'] ?? '', handedOverOnLabel),

      PdfParts.sectionTitle(copy.sections['assets'] ?? ''),
      PdfParts.table(
        headers: copy.columns,
        rows: <List<String>>[
          for (final asset in receipt.handedOver)
            <String>[
              asset.assetTag ?? asset.serialNumber ?? '',
              asset.name,
              asset.category?.name ?? '',
            ],
        ],
      ),

      if (notes != null && notes.trim().isNotEmpty) ...<pw.Widget>[
        PdfParts.sectionTitle(copy.sections['notes'] ?? ''),
        pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
      ],

      pw.SizedBox(height: 24),
      _signatureBlock(
        label: copy.sections['signature'] ?? '',
        name: recipient.name,
        signature: signature,
      ),
    ],
  );

  /// The signature, over a rule, over the name.
  ///
  /// Rendered even when the image is missing: the receipt is still the record
  /// of what was handed over, and a blank line to sign on paper is a usable
  /// fallback. Silently dropping the block would leave a document that looks
  /// complete and proves less than it appears to.
  static pw.Widget _signatureBlock({
    required String label,
    required String name,
    Uint8List? signature,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(
        label,
        style: const pw.TextStyle(color: PdfParts.faint, fontSize: 9),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        width: 200,
        height: 70,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfParts.line)),
        ),
        child: signature == null
            ? pw.SizedBox.shrink()
            : pw.Image(pw.MemoryImage(signature), fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(height: 4),
      pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
    ],
  );
}

/// What a stock count found, and what it did not.
///
/// A PDF because this one is read rather than sorted: the number that matters
/// is "four missing", and the list under it is the evidence for it.
abstract final class AuditReportExport {
  static Future<Uint8List> build({
    required AuditSession session,
    required ExportCopy copy,
    required PdfTheme theme,
  }) => PdfParts.build(
    theme: theme,
    generatedOn: copy.generatedOn,
    body: (context) => <pw.Widget>[
      PdfParts.header(
        title: copy.title,
        subtitle: copy.subtitle,
        product: copy.product,
      ),
      pw.SizedBox(height: 16),

      for (final entry in copy.facts.entries)
        PdfParts.fact(entry.key, entry.value),

      // Missing first. The reason somebody runs a count is to find out what
      // is not there, and burying it under two hundred rows that were is how
      // a report gets filed unread.
      if (session.missing.isNotEmpty) ...<pw.Widget>[
        PdfParts.sectionTitle(copy.sections['missing'] ?? ''),
        PdfParts.table(headers: copy.columns, rows: _rows(session.missing)),
      ],

      if (session.unexpectedCount > 0) ...<pw.Widget>[
        PdfParts.sectionTitle(copy.sections['unexpected'] ?? ''),
        PdfParts.table(
          headers: copy.columns,
          rows: _rows(<Asset>[
            for (final entry in session.feed)
              if (entry.outcome == AuditOutcome.unexpected) entry.asset,
          ]),
        ),
      ],

      PdfParts.sectionTitle(copy.sections['found'] ?? ''),
      PdfParts.table(
        headers: copy.columns,
        rows: _rows(<Asset>[
          for (final entry in session.feed)
            if (entry.outcome == AuditOutcome.found) entry.asset,
        ]),
      ),
    ],
  );

  static List<List<String>> _rows(List<Asset> assets) => <List<String>>[
    for (final asset in assets)
      <String>[
        asset.assetTag ?? asset.serialNumber ?? '',
        asset.name,
        asset.assignedEmployee?.name ?? '',
      ],
  ];
}
