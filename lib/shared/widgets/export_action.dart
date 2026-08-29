import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/di/injector.dart';
import '../../core/error/exceptions.dart';
import '../../core/export/export_documents.dart';
import '../../core/export/file_share.dart';
import '../../core/export/pdf_document.dart';
import '../../core/utils/logger.dart';
import '../../l10n/generated/app_localizations.dart';
import '../utils/app_date_format.dart';
import 'app_button.dart';

/// Everything a screen needs to hand a generated file to the OS share sheet.
///
/// A mixin-free helper rather than a Cubit: an export has no state worth
/// modelling — it is a button, a file, and a sheet the OS owns from there —
/// and putting it behind a ViewModel would mean four screens each growing a
/// second one.
abstract final class ExportAction {
  /// The furniture every document shares, filled in from the current locale.
  static ExportCopy copyFor(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> columns,
    Map<String, String> sections = const <String, String>{},
    Map<String, String> facts = const <String, String>{},
  }) {
    final l10n = AppL10n.of(context);

    return ExportCopy(
      product: l10n.appName,
      generatedOn: l10n.exportGeneratedOn(
        context.dates.dateAndTime(DateTime.now()),
      ),
      title: title,
      subtitle: subtitle,
      columns: columns,
      sections: sections,
      facts: facts,
    );
  }

  /// The document theme, in the direction the user is reading.
  static Future<PdfTheme> themeFor(BuildContext context) =>
      PdfTheme.load(isRtl: Directionality.of(context) == TextDirection.rtl);

  /// Runs [build] and shares the result, reporting failure in one line rather
  /// than on a whole error screen.
  ///
  /// An export is a side errand: the user is looking at a list they still
  /// want. Replacing it with a failure view because a share sheet did not
  /// open would cost them the thing they came for.
  static Future<void> share({
    required BuildContext context,
    required String filename,
    required String subject,
    required String mimeType,
    required Future<Uint8List> Function() build,
  }) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bytes = await build();
      await sl<FileShare>().shareBytes(
        bytes: bytes,
        filename: filename,
        subject: subject,
        mimeType: mimeType,
      );
    } on FileAccessException catch (error) {
      AppLogger.warn('Export failed — ${error.message}');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    }
  }
}

/// A share button, in the shape the rest of the app's actions use.
class ExportButton extends StatefulWidget {
  const ExportButton({
    required this.label,
    required this.onExport,
    this.icon = Icons.ios_share_rounded,
    this.expand = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool expand;

  /// Runs the export. Awaited so the button can show it is working — building
  /// a two-hundred-row PDF is not instant on a mid-range phone.
  final Future<void> Function() onExport;

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onExport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppButton.outlined(
    label: widget.label,
    icon: widget.icon,
    isBusy: _busy,
    expand: widget.expand,
    onPressed: _run,
  );
}
