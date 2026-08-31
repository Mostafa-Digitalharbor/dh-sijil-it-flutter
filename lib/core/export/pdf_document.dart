import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/app_constants.dart';

/// The type and direction a generated PDF is built with.
///
/// Loaded once per document rather than per page: the Arabic face is around a
/// hundred kilobytes and embedding it twice doubles the file for nothing.
class PdfTheme {
  const PdfTheme({
    required this.base,
    required this.bold,
    required this.mono,
    required this.isRtl,
  });

  final pw.Font base;
  final pw.Font bold;
  final pw.Font mono;
  final bool isRtl;

  pw.TextDirection get direction =>
      isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  /// The app's own faces, so a receipt looks like the screen it came from.
  ///
  /// The Arabic face is used for *both* languages rather than switching: a
  /// receipt written in English still carries Arabic asset names, and a font
  /// without those glyphs prints them as empty boxes. IBM Plex Sans Arabic
  /// covers Latin too, so one face renders a mixed document correctly.
  static Future<PdfTheme> load({required bool isRtl}) async {
    Future<pw.Font> ttf(String path) async =>
        pw.Font.ttf(await rootBundle.load(path));

    return PdfTheme(
      base: await ttf(AppAssets.pdfFontRegular),
      bold: await ttf(AppAssets.pdfFontBold),
      // Identifiers stay monospaced on paper for the same reason they do on
      // screen: an asset tag gets compared character by character.
      mono: await ttf(AppAssets.pdfFontMono),
      isRtl: isRtl,
    );
  }

  pw.ThemeData get theme => pw.ThemeData.withFont(
    base: base,
    bold: bold,
    // Arabic asset names inside an English document, and vice versa.
    fontFallback: <pw.Font>[base, mono],
  );
}

/// The print type and spacing scale.
///
/// Paper has its own scale — these are PDF points, not logical pixels, and a
/// 9-pt table cell has no counterpart on screen — so this is deliberately a
/// separate ladder from [AppSpacing] rather than an import of it. The rule is
/// the same one the app follows everywhere else: no bare numbers at a call
/// site, so a document that needs to breathe is one edit rather than a hunt
/// through two builders.
abstract final class PdfMetrics {
  // ── Page ─────────────────────────────────────────────────────────────────
  /// A4 margin. Comfortably inside the unprintable edge of every office
  /// printer we have seen, including the ones that claim 5 mm and lie.
  static const double pageMargin = 28;

  // ── Type ─────────────────────────────────────────────────────────────────
  static const double titleSize = 18;
  static const double headingSize = 11;
  static const double bodySize = 10;
  static const double labelSize = 9;
  static const double captionSize = 8;
  static const double microSize = 7;

  // ── Spacing ──────────────────────────────────────────────────────────────
  static const double hair = 2;
  static const double tight = 4;
  static const double snug = 6;
  static const double compact = 8;
  static const double block = 12;
  static const double section = 16;
  static const double major = 24;

  // ── Blocks ───────────────────────────────────────────────────────────────
  static const double headerPadding = 16;

  /// The label column in a label/value fact row. Wide enough for the longest
  /// Arabic field label at [labelSize] without wrapping to a second line.
  static const double factLabelWidth = 130;
  static const double factRowPadding = 3;

  static const double sectionTitleTop = 14;
  static const double sectionTitleBottom = 6;

  static const double cellPaddingX = 6;
  static const double cellPaddingY = 5;

  static const double badgePadding = 6;
  static const double badgeRadius = 4;

  /// The rule a signature is written above.
  static const double signatureLineWidth = 200;

  const PdfMetrics._();
}

/// Shared page furniture, so a receipt and an audit report are recognisably
/// the same document family.
abstract final class PdfParts {
  static const PdfColor navy = PdfColor.fromInt(0xFF0B1226);
  static const PdfColor mint = PdfColor.fromInt(0xFF0F9E73);
  static const PdfColor faint = PdfColor.fromInt(0xFF8492B4);
  static const PdfColor line = PdfColor.fromInt(0xFFE3E8F2);

  /// Alternating table fill. A row per asset and a bundle can run long; this
  /// is what keeps a printed page readable across its width.
  static const PdfColor zebra = PdfColor.fromInt(0xFFF7F9FC);

  /// Ink on the navy header band.
  static const PdfColor onNavy = PdfColors.white;

  /// The band across the top of every generated document.
  static pw.Widget header({
    required String title,
    required String subtitle,
    required String product,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(PdfMetrics.headerPadding),
    decoration: const pw.BoxDecoration(color: navy),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              title,
              style: pw.TextStyle(
                color: onNavy,
                fontSize: PdfMetrics.titleSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: PdfMetrics.hair),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(
                color: faint,
                fontSize: PdfMetrics.bodySize,
              ),
            ),
          ],
        ),
        pw.Text(
          product,
          style: const pw.TextStyle(color: mint, fontSize: PdfMetrics.bodySize),
        ),
      ],
    ),
  );

  /// A label/value pair, the shape the detail screens use.
  static pw.Widget fact(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: PdfMetrics.factRowPadding),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(
          width: PdfMetrics.factLabelWidth,
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              color: faint,
              fontSize: PdfMetrics.labelSize,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: PdfMetrics.bodySize),
          ),
        ),
      ],
    ),
  );

  static pw.Widget sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(
      top: PdfMetrics.sectionTitleTop,
      bottom: PdfMetrics.sectionTitleBottom,
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: PdfMetrics.headingSize,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  /// A table whose header repeats on every page.
  static pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: null,
    headerStyle: pw.TextStyle(
      fontSize: PdfMetrics.labelSize,
      fontWeight: pw.FontWeight.bold,
    ),
    headerDecoration: const pw.BoxDecoration(color: line),
    cellStyle: const pw.TextStyle(fontSize: PdfMetrics.labelSize),
    cellPadding: const pw.EdgeInsets.symmetric(
      horizontal: PdfMetrics.cellPaddingX,
      vertical: PdfMetrics.cellPaddingY,
    ),
    oddRowDecoration: const pw.BoxDecoration(color: zebra),
  );

  /// The line at the bottom of every page.
  static pw.Widget footer(pw.Context context, String generatedOn) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: PdfMetrics.compact),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          generatedOn,
          style: const pw.TextStyle(
            color: faint,
            fontSize: PdfMetrics.captionSize,
          ),
        ),
        pw.Text(
          _pageLabel(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(
            color: faint,
            fontSize: PdfMetrics.captionSize,
          ),
        ),
      ],
    ),
  );

  /// "3 / 12".
  ///
  /// Deliberately not run through the app's number formatter: a page number
  /// is a position in a document, and "1 / 1,024" is not one.
  static String _pageLabel(int at, int outOf) => '$at / $outOf';

  /// Builds a document with the shared page setup.
  static Future<Uint8List> build({
    required PdfTheme theme,
    required String generatedOn,
    required List<pw.Widget> Function(pw.Context context) body,
  }) async {
    final document = pw.Document(theme: theme.theme);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(PdfMetrics.pageMargin),
        textDirection: theme.direction,
        footer: (context) => footer(context, generatedOn),
        build: body,
      ),
    );

    return document.save();
  }
}
