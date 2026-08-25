import '../../l10n/generated/app_localizations.dart';

/// Resolves a validation key emitted by a Cubit into localized text.
///
/// Cubits decide *what* is wrong and publish a stable key; only the widget
/// layer turns that into words. This keeps business logic free of localized
/// strings — a Cubit test asserts on `validationEnterDatabase`, not on an
/// English sentence that a translator might later change.
extension L10nLookup on AppL10n {
  /// Returns null for a null key, so it drops straight into an `errorText`.
  ///
  /// An unrecognised key returns the generic validation message rather than
  /// the raw key: a mistyped constant must never surface to a user.
  String? lookup(String? key) {
    if (key == null) return null;

    return switch (key) {
      'validationEnterServerUrl' => validationEnterServerUrl,
      'validationInvalidUrl' => validationInvalidUrl,
      'validationHttpsRequired' => validationHttpsRequired,
      'validationEnterDatabase' => validationEnterDatabase,
      'validationEnterUsername' => validationEnterUsername,
      'validationEnterCredential' => validationEnterCredential,
      'validationEnterAssetName' => validationEnterAssetName,
      _ => errorValidationFix,
    };
  }
}
