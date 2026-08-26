import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../security/log_sanitizer.dart';
import '../utils/logger.dart';

/// Crash reporting, on the app's own terms.
///
/// ## Why this file exists rather than a bare `SentryFlutter.init`
///
/// This app holds an Odoo password or API key. It has a [LogSanitizer] and a
/// `CredentialVault` precisely so that a secret never reaches a log line or a
/// screen. Wiring a crash reporter with default settings would undo that in
/// one step: a Sentry event carries breadcrumbs, exception messages, HTTP
/// request metadata and — with `sendDefaultPii` on — headers and user
/// identifiers. An `AccessDenied` raised while retrying a sign-in can carry
/// the credential in its own message.
///
/// So every event goes through the same scrubber the logs already use, on the
/// way out, and the switches that would send more than we mean to are set
/// explicitly rather than left at their defaults. Writing them out is the
/// point: a future SDK upgrade that changes a default then shows up as a
/// conflict in review instead of quietly changing what this app transmits.
///
/// ## Off unless a DSN is compiled in
///
/// [dsn] comes from `--dart-define=SENTRY_DSN=…`. Empty means the SDK is never
/// initialised at all — not initialised-and-silent — so:
///
/// * `flutter run` reports nothing,
/// * a test reports nothing,
/// * a customer who does not want telemetry gets a build with no DSN, and the
///   claim "this app talks to your Odoo and nothing else" stays literally true
///   for that build.
abstract final class CrashReporter {
  /// Compiled in at build time; empty in any build that does not pass it.
  static const String dsn = String.fromEnvironment('SENTRY_DSN');

  /// Which deployment this build reports as. Lets one Sentry project separate
  /// a pilot instance from production without a second project.
  static const String environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  static bool get isEnabled => dsn.isNotEmpty;

  /// Runs [action] with crash reporting attached, or plain when no DSN is set.
  ///
  /// Takes the app body as a callback rather than exposing an `init`, because
  /// the SDK must own the zone `runApp` runs in for it to catch asynchronous
  /// errors. Splitting that across two calls is how an integration ends up
  /// reporting synchronous crashes only — and looking healthy while doing it.
  static Future<void> runWithReporting(Future<void> Function() action) async {
    if (!isEnabled) {
      AppLogger.debug('Crash reporting: off (no DSN compiled in)');
      return action();
    }

    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..environment = environment
        // ── What this build deliberately does not send ─────────────────────
        //
        // Each of these overrides or pins a default. They are spelled out so
        // that turning one back on is a visible decision.
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..attachViewHierarchy = false
        // Every tap on a labelled widget would otherwise become a breadcrumb.
        // On this app that means a trail of asset names and employee names.
        ..enableUserInteractionBreadcrumbs = false
        // Odoo request bodies are XML-RPC payloads whose third positional
        // parameter is the password or API key. Never attach one.
        ..maxRequestBodySize = MaxRequestBodySize.never
        // ── Volume ─────────────────────────────────────────────────────────
        //
        // Errors are sampled in full: a crash that hits three people is the
        // one worth seeing. Traces are not — performance data from a fleet of
        // handsets is a great many events for a question nobody is asking yet.
        ..tracesSampleRate = 0.0
        ..enableAutoSessionTracking = true
        ..debug = false
        // ── The scrubbing gate ─────────────────────────────────────────────
        //
        // Named rather than inlined: a cascade inside an arrow lambda binds to
        // the lambda's result, not to `options`, and the compiler accepts the
        // wrong one when the types happen to line up.
        ..beforeSend = _beforeSend
        ..beforeBreadcrumb = _beforeBreadcrumb;
    }, appRunner: action);
  }

  static SentryEvent _beforeSend(SentryEvent event, Hint hint) =>
      scrubEvent(event);

  static Breadcrumb? _beforeBreadcrumb(Breadcrumb? crumb, Hint hint) =>
      crumb == null ? null : scrubBreadcrumb(crumb);

  /// Last stop before an event leaves the device.
  ///
  /// Mutates in place: the v9 SDK removed `copyWith` from the protocol classes
  /// in favour of assignment, and rebuilding an event by hand would silently
  /// drop any field added by a future SDK version — the opposite of what a
  /// scrubber should do when it does not recognise something.
  @visibleForTesting
  static SentryEvent scrubEvent(SentryEvent event) {
    final message = event.message;
    if (message != null) {
      event.message = SentryMessage(
        LogSanitizer.scrub(message.formatted),
        template: message.template,
        params: message.params,
      );
    }

    for (final exception in event.exceptions ?? const <SentryException>[]) {
      final value = exception.value;
      if (value != null) exception.value = LogSanitizer.scrub(value);
    }

    for (final crumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
      scrubBreadcrumb(crumb);
    }

    // The signed-in Odoo user is not attached. Knowing which technician hit a
    // crash would be useful; it is not useful enough to send a customer's
    // employee identity to a third party who was never asked about it.
    event.user = null;
    event.request = _strippedRequest(event.request);
    // ignore: deprecated_member_use
    event.extra = _scrubMap(event.extra);

    return event;
  }

  @visibleForTesting
  static Breadcrumb scrubBreadcrumb(Breadcrumb crumb) {
    final message = crumb.message;
    if (message != null) crumb.message = LogSanitizer.scrub(message);
    crumb.data = _scrubMap(crumb.data);
    return crumb;
  }

  /// Keeps the URL's shape and drops everything else.
  ///
  /// A rebuilt [SentryRequest] rather than field assignment, because `headers`
  /// and `cookies` are read-only on the instance — and because for this one
  /// class an allow-list is the right shape: host and path answer "which
  /// endpoint broke", while the query string, headers and cookies answer
  /// nothing this app needs and can each carry a credential.
  static SentryRequest? _strippedRequest(SentryRequest? request) {
    if (request == null) return null;
    final url = request.url;
    return SentryRequest(
      url: url == null ? null : LogSanitizer.scrub(url),
      method: request.method,
    );
  }

  static Map<String, dynamic>? _scrubMap(Map<String, dynamic>? source) {
    if (source == null) return null;
    return <String, dynamic>{
      for (final entry in source.entries)
        entry.key: entry.value is String
            ? LogSanitizer.scrub(entry.value as String)
            : entry.value,
    };
  }

  /// Reports an error the app caught but could not handle.
  ///
  /// A no-op when reporting is off, so a call site never needs to guard.
  static Future<void> capture(
    Object error,
    StackTrace? stackTrace, {
    String? context,
  }) async {
    if (!isEnabled) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: context == null
          ? null
          : (scope) => scope.setContexts('sijil', <String, String>{
              'where': LogSanitizer.scrub(context),
            }),
    );
  }
}
