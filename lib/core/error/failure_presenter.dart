import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'failures.dart';

/// A failure, rendered into the exact words a user reads.
///
/// Three parts, always: **what** happened, **why**, and **what to do about
/// it**. The user never sees an exception, a model name they did not ask
/// about, or a stack trace — that is what makes the third part necessary
/// rather than optional.
class PresentedFailure extends Equatable {
  const PresentedFailure({
    required this.title,
    required this.body,
    required this.fix,
    required this.icon,
    required this.action,
    required this.actionLabel,
    this.technicalDetails,
  });

  /// One short line: what happened.
  final String title;

  /// One or two sentences: why it happened.
  final String body;

  /// The concrete next step. Never empty — if there is genuinely nothing the
  /// user can do, it says who to contact.
  final String fix;

  final IconData icon;
  final FailureAction action;

  /// Label for the action button. Empty when [action] is
  /// [FailureAction.none].
  final String actionLabel;

  final String? technicalDetails;

  bool get hasAction => action != FailureAction.none && actionLabel.isNotEmpty;

  @override
  List<Object?> get props => [title, body, fix, action, actionLabel];
}

/// Resolves a [Failure] into localized, actionable copy.
///
/// Every branch is exhaustive over [FailureKind] — adding a kind without
/// wording is a compile error, not a silent "Something went wrong".
abstract final class FailurePresenter {
  static PresentedFailure present(AppL10n l10n, Failure failure) {
    final (title, body, fix) = _copy(l10n, failure);

    return PresentedFailure(
      title: title,
      body: body,
      fix: fix,
      icon: iconFor(failure.kind),
      action: failure.action,
      actionLabel: actionLabel(l10n, failure.action),
      technicalDetails: failure.technicalDetails,
    );
  }

  static (String, String, String) _copy(AppL10n l10n, Failure failure) {
    return switch (failure.kind) {
      FailureKind.noInternet => (
        l10n.errorNoInternetTitle,
        l10n.errorNoInternetBody,
        l10n.errorNoInternetFix,
      ),
      FailureKind.serverUnreachable => (
        l10n.errorServerUnreachableTitle,
        l10n.errorServerUnreachableBody,
        l10n.errorServerUnreachableFix,
      ),
      FailureKind.notAnOdooServer => (
        l10n.errorNotAnOdooServerTitle,
        l10n.errorNotAnOdooServerBody,
        l10n.errorNotAnOdooServerFix,
      ),
      FailureKind.timeout => (
        l10n.errorTimeoutTitle,
        l10n.errorTimeoutBody,
        l10n.errorTimeoutFix,
      ),
      FailureKind.invalidCredentials => (
        l10n.errorInvalidCredentialsTitle,
        l10n.errorInvalidCredentialsBody,
        l10n.errorInvalidCredentialsFix,
      ),
      FailureKind.databaseUnavailable => (
        l10n.errorDatabaseUnavailableTitle,
        l10n.errorDatabaseUnavailableBody,
        l10n.errorDatabaseUnavailableFix,
      ),
      FailureKind.sessionExpired => (
        l10n.errorSessionExpiredTitle,
        l10n.errorSessionExpiredBody,
        l10n.errorSessionExpiredFix,
      ),
      // Names the model and operation when Odoo told us, because
      // "you can't do this" is not enough to take to an administrator.
      FailureKind.accessDenied => (
        l10n.errorAccessDeniedTitle,
        (failure.model != null && failure.operation != null)
            ? l10n.errorAccessDeniedBodyDetailed(
                operationLabel(l10n, failure.operation!),
                failure.model!,
              )
            : l10n.errorAccessDeniedBody,
        l10n.errorAccessDeniedFix,
      ),
      FailureKind.modelUnavailable => (
        l10n.errorModelUnavailableTitle,
        failure.model != null
            ? l10n.errorModelUnavailableBodyDetailed(failure.model!)
            : l10n.errorModelUnavailableBody,
        l10n.errorModelUnavailableFix,
      ),
      // A field rather than a whole app is missing, so the fix is not
      // "install a module" — that would send the user somewhere that cannot
      // help. Names the field when Odoo told us which one.
      FailureKind.fieldUnavailable => (
        l10n.errorFieldUnavailableTitle,
        failure.serverMessage != null
            ? l10n.errorFieldUnavailableBodyDetailed(failure.serverMessage!)
            : l10n.errorFieldUnavailableBody,
        l10n.errorFieldUnavailableFix,
      ),
      // Odoo's own wording is already meant for end users, so it becomes the
      // body verbatim rather than being paraphrased.
      FailureKind.businessRule => (
        l10n.errorBusinessRuleTitle,
        failure.serverMessage ?? l10n.errorUnknownBody,
        l10n.errorBusinessRuleFix,
      ),
      FailureKind.recordNotFound => (
        l10n.errorRecordNotFoundTitle,
        l10n.errorRecordNotFoundBody,
        l10n.errorRecordNotFoundFix,
      ),
      FailureKind.fileUnavailable => (
        l10n.errorFileUnavailableTitle,
        l10n.errorFileUnavailableBody,
        l10n.errorFileUnavailableFix,
      ),
      FailureKind.server => (
        l10n.errorServerTitle,
        l10n.errorServerBody,
        l10n.errorServerFix,
      ),
      FailureKind.cache => (
        l10n.errorCacheTitle,
        l10n.errorCacheBody,
        l10n.errorCacheFix,
      ),
      FailureKind.validation => (
        l10n.errorValidationTitle,
        failure.serverMessage ?? l10n.errorValidationFix,
        l10n.errorValidationFix,
      ),
      FailureKind.unknown => (
        l10n.errorUnknownTitle,
        l10n.errorUnknownBody,
        l10n.errorUnknownFix,
      ),
    };
  }

  static String actionLabel(AppL10n l10n, FailureAction action) =>
      switch (action) {
        FailureAction.retry => l10n.actionRetry,
        FailureAction.editConnection => l10n.errorActionEditConnection,
        FailureAction.signIn => l10n.errorActionSignIn,
        FailureAction.none => '',
      };

  /// The refused operation, in the user's language and in their words.
  ///
  /// "delete", not "unlink": the sentence it lands in is read by a technician,
  /// not by someone who knows Odoo's ORM.
  static String operationLabel(AppL10n l10n, OdooOperation operation) =>
      switch (operation) {
        OdooOperation.read => l10n.operationRead,
        OdooOperation.create => l10n.operationCreate,
        OdooOperation.write => l10n.operationWrite,
        OdooOperation.delete => l10n.operationDelete,
      };

  static IconData iconFor(FailureKind kind) => switch (kind) {
    FailureKind.noInternet => Icons.wifi_off_rounded,
    FailureKind.serverUnreachable ||
    FailureKind.notAnOdooServer => Icons.cloud_off_rounded,
    FailureKind.timeout => Icons.hourglass_disabled_rounded,
    FailureKind.invalidCredentials ||
    FailureKind.sessionExpired => Icons.key_off_rounded,
    FailureKind.databaseUnavailable => Icons.storage_rounded,
    FailureKind.accessDenied => Icons.lock_outline_rounded,
    FailureKind.modelUnavailable => Icons.extension_off_rounded,
    FailureKind.fieldUnavailable => Icons.label_off_outlined,
    FailureKind.businessRule => Icons.rule_rounded,
    FailureKind.recordNotFound => Icons.search_off_rounded,
    FailureKind.fileUnavailable => Icons.broken_image_outlined,
    FailureKind.server => Icons.dns_rounded,
    FailureKind.cache => Icons.sd_card_alert_rounded,
    FailureKind.validation => Icons.edit_note_rounded,
    FailureKind.unknown => Icons.error_outline_rounded,
  };

  /// One-line form for a snackbar, where there is no room for the fix.
  static String shortMessage(AppL10n l10n, Failure failure) {
    final (title, body, _) = _copy(l10n, failure);
    return failure.kind == FailureKind.businessRule ? body : title;
  }
}
