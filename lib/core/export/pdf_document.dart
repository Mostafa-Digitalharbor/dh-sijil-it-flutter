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

/// Shared page furniture, so a receipt and an audit report are recognisably
/// the same document family.
abstract final class PdfParts {
  static const PdfColor navy = PdfColor.fromInt(0xFF0B1226);
  static const PdfColor mint = PdfColor.fromInt(0xFF0F9E73);
  static const PdfColor faint = PdfColor.fromInt(0xFF8492B4);
  static const PdfColor line = PdfColor.fromInt(0xFFE3E8F2);

  /// The band across the top of every generated document.
  static pw.Widget header({
    required String title,
    required String subtitle,
    required String product,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(16),
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
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(color: faint, fontSize: 10),
            ),
          ],
        ),
        pw.Text(product, style: const pw.TextStyle(color: mint, fontSize: 10)),
      ],
    ),
  );

  /// A label/value pair, the shape the detail screens use.
  static pw.Widget fact(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            label,
            style: const pw.TextStyle(color: faint, fontSize: 9),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );

  static pw.Widget sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
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
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: line),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    // A row per asset, and a bundle can be long; alternating fill is what
    // keeps a printed page readable across its width.
    oddRowDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF7F9FC),
    ),
  );

  /// The line at the bottom of every page.
  static pw.Widget footer(pw.Context context, String generatedOn) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          generatedOn,
          style: const pw.TextStyle(color: faint, fontSize: 8),
        ),
        pw.Text(
          _pageLabel(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(color: faint, fontSize: 8),
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
        margin: const pw.EdgeInsets.all(28),
        textDirection: theme.direction,
        footer: (context) => footer(context, generatedOn),
        build: body,
      ),
    );

    return document.save();
  }
}
