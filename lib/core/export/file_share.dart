import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../error/exceptions.dart';
import '../utils/logger.dart';

/// Writes a generated file somewhere the OS share sheet can read it, and
/// opens the sheet.
///
/// The temporary directory, not Documents: these are derived artefacts — the
/// asset list is in Odoo, the receipt is in the chatter — and leaving copies
/// of company data in a user-visible folder is a data-retention decision
/// nobody asked for. The OS clears the cache directory on its own.
class FileShare {
  const FileShare();

  /// Shares [bytes] as [filename], returning false when the user dismissed
  /// the sheet without choosing anything.
  Future<bool> shareBytes({
    required Uint8List bytes,
    required String filename,
    required String subject,
    String? mimeType,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: mimeType)],
          subject: subject,
        ),
      );

      return result.status == ShareResultStatus.success;
    } on Object catch (error, stackTrace) {
      AppLogger.error('Share failed', error, stackTrace);
      throw const FileAccessException('Could not prepare the file.');
    }
  }

  /// Shares text as a UTF-8 file.
  Future<bool> shareText({
    required String content,
    required String filename,
    required String subject,
    String? mimeType,
  }) => shareBytes(
    bytes: Uint8List.fromList(utf8.encode(content)),
    filename: filename,
    subject: subject,
    mimeType: mimeType,
  );

  /// A filename that survives every filesystem the file may land on.
  ///
  /// An asset called `DH/LAP 0027` would otherwise produce a path separator
  /// in the middle of a filename, and Arabic names are kept — the recipient
  /// reads them, and every platform the app targets stores UTF-8 names.
  static String safeName(String base, String extension) {
    final cleaned = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp('-+'), '-')
        // A name that was only spaces collapses to a bare "-", which is
        // not empty and so slipped past the fallback below, producing a
        // file called "-".
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final trimmed = cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
    final stem = trimmed.isEmpty ? 'sijil' : trimmed;
    return '$stem.$extension';
  }
}
