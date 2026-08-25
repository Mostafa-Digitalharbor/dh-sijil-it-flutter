import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../security/log_sanitizer.dart';

/// How serious a recorded diagnostic entry is.
///
/// Named `Severity` rather than `Level` because Flutter exports its own
/// `DiagnosticLevel` from `foundation`, and a screen importing both would have
/// to disambiguate on every use.
enum DiagnosticSeverity { warning, error }

/// One sanitized line in the diagnostics buffer.
@immutable
class DiagnosticEntry {
  const DiagnosticEntry({
    required this.level,
    required this.message,
    required this.at,
    this.detail,
  });

  final DiagnosticSeverity level;

  /// Already passed through [LogSanitizer] before it got here.
  final String message;

  final String? detail;
  final DateTime at;
}

/// A bounded, in-memory record of what has recently gone wrong.
///
/// Backs Settings → Diagnostics (spec §22): the user never sees a stack trace
/// inline, but a support conversation needs *something* concrete, and asking
/// a non-technical user to reproduce a bug with a debugger attached is not a
/// support process.
///
/// Three deliberate properties:
///
/// - **Memory only.** Nothing is written to disk, so there is no file to leak
///   and nothing survives a restart.
/// - **Bounded.** A ring buffer, so a failing poll cannot grow without limit.
/// - **Already sanitized.** Entries arrive via [AppLogger], which scrubs
///   credentials first — this buffer never sees a secret to redact.
abstract final class DiagnosticsLog {
  /// Enough to cover a session's worth of failures without holding megabytes.
  static const int maxEntries = 100;

  static final List<DiagnosticEntry> _entries = <DiagnosticEntry>[];

  /// Newest first, which is the order the screen reads them in.
  static List<DiagnosticEntry> get entries =>
      List<DiagnosticEntry>.unmodifiable(_entries.reversed);

  static bool get isEmpty => _entries.isEmpty;

  static void record(
    DiagnosticSeverity level,
    String message, {
    String? detail,
  }) {
    _entries.add(
      DiagnosticEntry(
        level: level,
        message: message,
        detail: detail,
        at: DateTime.now(),
      ),
    );
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

  static void clear() => _entries.clear();

  /// The whole buffer as text, for the Copy action.
  static String asText() => _entries.reversed
      .map(
        (e) =>
            '[${e.at.toIso8601String()}] ${e.level.name.toUpperCase()}  '
            '${e.message}${e.detail == null ? '' : '\n    ${e.detail}'}',
      )
      .join('\n');
}

/// App-wide logger.
///
/// Everything passes through [LogSanitizer] first, so passwords, API keys and
/// session identifiers can never be written to a log sink (spec §25).
abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 6, lineLength: 90),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  static void debug(String message) => _logger.d(LogSanitizer.scrub(message));

  static void info(String message) => _logger.i(LogSanitizer.scrub(message));

  static void warn(String message) {
    final scrubbed = LogSanitizer.scrub(message);
    _logger.w(scrubbed);
    DiagnosticsLog.record(DiagnosticSeverity.warning, scrubbed);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    final scrubbed = LogSanitizer.scrub(message);
    final scrubbedError = error == null ? null : LogSanitizer.scrub('$error');

    _logger.e(scrubbed, error: scrubbedError, stackTrace: stackTrace);
    DiagnosticsLog.record(
      DiagnosticSeverity.error,
      scrubbed,
      detail: scrubbedError,
    );
  }
}
