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
            // Blank for the overwhelming majority, which is the point: a
            // populated cell in this column is a loan somebody is waiting on.
            _date(asset.dueBack.date),
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

/// A printable sheet of asset QR labels.
///
/// ## Why a sheet and not a screen
///
/// The app has been able to show one asset's QR code since the first release,
/// which is the right answer for a device already on a shelf and the wrong one
/// for a delivery of thirty laptops: printing those meant opening thirty
/// screens and photographing each. This is the same payload — `asset://<id>`,
/// and nothing else — laid out on A4 so a batch gets labelled in one pass.
///
/// The grid is three across, on a row tall enough for a code that still scans
/// at 100% plus the two lines a human reads when the sticker is too scuffed to
/// scan. How many rows land on a page is whatever fits under the header —
/// `MultiPage` flows the rest onto the next sheet, which is why the labels sit
/// in a `Wrap` rather than in a fixed grid that would have to be told.
///
/// Drawn dark on white whatever the app's theme, for the same reason the
/// single-code screen is: a code rendered in the dark palette does not scan
/// once it is printed, and printing is the entire point.
abstract final class AssetLabelSheetExport {
  static Future<Uint8List> build({
    required List<Asset> assets,
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
      pw.SizedBox(height: PdfMetrics.block),
      // A single wrap rather than a table: the labels are uniform, and a wrap
      // flows the last, short row correctly instead of padding it with empty
      // bordered cells that look like labels somebody forgot to fill in.
      pw.Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: <pw.Widget>[for (final asset in assets) _label(asset)],
      ),
    ],
  );

  /// One label: the code, the name, and the identifier a human reads when the
  /// sticker is too scuffed to scan.
  ///
  /// The identifier is the same fallback chain the list row uses — tag, then
  /// serial — so the printed sticker and the screen agree about what this
  /// device is called.
  static pw.Widget _label(Asset asset) => pw.Container(
    width: _labelWidth,
    height: _labelHeight,
    padding: const pw.EdgeInsets.all(PdfMetrics.badgePadding),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfParts.line),
      borderRadius: pw.BorderRadius.circular(PdfMetrics.badgeRadius),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: asset.qrPayload,
          width: _codeSize,
          height: _codeSize,
          drawText: false,
          color: PdfParts.navy,
        ),
        pw.SizedBox(width: PdfMetrics.snug),
        pw.Expanded(
          // Left-to-right whatever the document's direction: an asset tag is
          // an identifier, and bidi would reorder "DH-LAP-0027" on an Arabic
          // sheet into something that does not match the sticker's own text.
          child: pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Text(
                  asset.name,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: PdfMetrics.captionSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (asset.subtitle != null) ...<pw.Widget>[
                  pw.SizedBox(height: PdfMetrics.hair),
                  pw.Text(
                    asset.subtitle!,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: const pw.TextStyle(
                      fontSize: PdfMetrics.microSize,
                      color: PdfParts.faint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  /// A4 minus the document's own 28-pt margins, divided three ways with two
  /// gaps between: (595 - 56 - 12) / 3, rounded down so a printer's own
  /// unprintable margin cannot push the third column onto a fourth.
  ///
  /// Spelled out rather than measured at runtime because `MultiPage` hands a
  /// `Wrap` the full content width, and a sheet whose grid depended on that
  /// would shift the moment the header grew a line.
  static const double _gap = 6;
  static const double _labelWidth = 173;
  static const double _labelHeight = 62;
  static const double _codeSize = 46;

  const AssetLabelSheetExport._();
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
      pw.SizedBox(height: PdfMetrics.section),

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
        pw.Text(
          notes,
          style: const pw.TextStyle(fontSize: PdfMetrics.bodySize),
        ),
      ],

      pw.SizedBox(height: PdfMetrics.major),
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
        style: const pw.TextStyle(
          color: PdfParts.faint,
          fontSize: PdfMetrics.labelSize,
        ),
      ),
      pw.SizedBox(height: PdfMetrics.tight),
      pw.Container(
        width: PdfMetrics.signatureLineWidth,
        height: 70,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfParts.line)),
        ),
        child: signature == null
            ? pw.SizedBox.shrink()
            : pw.Image(pw.MemoryImage(signature), fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(height: PdfMetrics.tight),
      pw.Text(name, style: const pw.TextStyle(fontSize: PdfMetrics.bodySize)),
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
      pw.SizedBox(height: PdfMetrics.section),

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
