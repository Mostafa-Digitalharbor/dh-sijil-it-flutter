// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get actionAdd => 'Add';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionAssign => 'Assign';

  @override
  String get actionCall => 'Call';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionChange => 'Change';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionClose => 'Close';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionDetectDatabases => 'Detect databases';

  @override
  String get actionDone => 'Done';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionEmail => 'Email';

  @override
  String get actionGoToDashboard => 'Go to dashboard';

  @override
  String get actionMaintain => 'Maintain';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionOpenSettings => 'Open settings';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionReturn => 'Return';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSigningIn => 'Signing in…';

  @override
  String get actionTestConnection => 'Test connection';

  @override
  String get actionToday => 'Today';

  @override
  String get appName => 'Sijil IT';

  @override
  String get appTagline => 'IT Asset Management';

  @override
  String get assetActionHistory => 'History';

  @override
  String get assetActionsTitle => 'Asset actions';

  @override
  String get assetDeleteBody =>
      'It is removed from Odoo for everyone. This cannot be undone.';

  @override
  String get assetDeleteConfirm => 'Delete this asset?';

  @override
  String assetDeleted(String asset) {
    return '$asset deleted';
  }

  @override
  String get assetDetailTitle => 'Asset details';

  @override
  String get assetEditTitle => 'Edit asset';

  @override
  String get assetLocalStateNote =>
      'Standard Odoo has no field for this state, so it is recorded in the asset\'s log — where everyone can see it.';

  @override
  String get assetMarkAvailable => 'Mark as available';

  @override
  String get assetMarkDamaged => 'Mark as damaged';

  @override
  String get assetMarkLost => 'Mark as lost';

  @override
  String get assetMarkReserved => 'Mark as reserved';

  @override
  String get assetNewTitle => 'New asset';

  @override
  String assetSaved(String asset) {
    return '$asset saved';
  }

  @override
  String get assetShowQr => 'Show QR code';

  @override
  String get assetsSearchHint => 'Name, tag, serial, model…';

  @override
  String assetsShowingOf(int shown, int total) {
    final intl.NumberFormat shownNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String shownString = shownNumberFormat.format(shown);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Showing $shownString of $totalString';
  }

  @override
  String get assetsTitle => 'Assets';

  @override
  String get assignAllDepartments => 'All departments';

  @override
  String get assignConfirm => 'Confirm assignment';

  @override
  String get assignDueClear => 'Remove the date';

  @override
  String get assignDueHint =>
      'Leave this empty unless the asset is a loan somebody has to bring back.';

  @override
  String get assignDueNotSet => 'No return date';

  @override
  String get assignNotesHint => 'Handed over with charger and USB-C hub…';

  @override
  String get assignSearchHint => 'Search employees…';

  @override
  String get assignStepDate => 'Assignment date';

  @override
  String get assignStepDue => 'Expected return date';

  @override
  String get assignStepEmployee => 'Select employee';

  @override
  String get assignStepNotes => 'Notes';

  @override
  String assignSuccess(String asset, String employee) {
    return '$asset assigned to $employee';
  }

  @override
  String get assignTitle => 'Assign asset';

  @override
  String get auditBegin => 'Start counting';

  @override
  String get auditCounting => 'Counting';

  @override
  String get auditDiscardBody =>
      'The scans so far are on this phone only. Leaving loses them.';

  @override
  String get auditDiscardConfirm => 'Leave';

  @override
  String get auditDiscardTitle => 'Leave the count?';

  @override
  String get auditFinish => 'Finish';

  @override
  String get auditFound => 'Found';

  @override
  String get auditJustScanned => 'Just scanned';

  @override
  String get auditKeepScanning => 'Keep scanning — no need to stop';

  @override
  String get auditMissing => 'Not found';

  @override
  String get auditNothingMissing => 'Everything in scope was found.';

  @override
  String auditOf(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString';
  }

  @override
  String get auditOutOfScope => 'Here, but recorded elsewhere';

  @override
  String get auditPickCategory => 'Pick a category';

  @override
  String get auditPickDepartment => 'Pick a department';

  @override
  String get auditReportExpected => 'Expected';

  @override
  String get auditReportFound => 'Counted';

  @override
  String get auditReportMissing => 'Not found';

  @override
  String get auditReportScope => 'Scope';

  @override
  String get auditReportShare => 'Share report';

  @override
  String get auditReportTitle => 'Stock count';

  @override
  String get auditReportUnexpected => 'Found out of scope';

  @override
  String get auditResume => 'Keep counting';

  @override
  String get auditSaveToOdoo => 'Save findings to Odoo';

  @override
  String get auditSaved => 'Findings saved to Odoo';

  @override
  String get auditSavedNone => 'Nothing to record — no findings.';

  @override
  String get auditScopeAll => 'Everything';

  @override
  String get auditScopeCategory => 'One category';

  @override
  String get auditScopeDepartment => 'One department';

  @override
  String get auditStartBody =>
      'A narrow scope gets counted. Everything at once does not.';

  @override
  String get auditStartTitle => 'What are you counting?';

  @override
  String get auditTitle => 'Audit';

  @override
  String get auditUnexpected => 'Not in scope';

  @override
  String get auditUnknownCode => 'That code matches no asset';

  @override
  String get auditWhereExpected => 'Where expected';

  @override
  String get authModeApiKey => 'API key';

  @override
  String get authModePassword => 'Password';

  @override
  String get bulkMoveDepartment => 'Move to department';

  @override
  String bulkMoveDone(int count, String department) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString assets moved to $department',
      one: '1 asset moved to $department',
    );
    return '$_temp0';
  }

  @override
  String get bulkMoveNoDepartments =>
      'This Odoo has no departments to move assets to.';

  @override
  String get bulkMoveTitle => 'Which department?';

  @override
  String get bulkPrintLabels => 'Label sheet';

  @override
  String get capabilityActivityLog => 'Activity log';

  @override
  String get capabilityEmployees => 'Employees';

  @override
  String get capabilityInventory => 'Inventory';

  @override
  String get capabilityMaintenance => 'Maintenance';

  @override
  String get conditionDamaged => 'Damaged';

  @override
  String get conditionDamagedEffect => 'Marks as damaged';

  @override
  String get conditionGood => 'Good';

  @override
  String get conditionGoodEffect => 'Back to available';

  @override
  String get conditionMinorDamage => 'Minor damage';

  @override
  String get conditionNeedsMaintenance => 'Needs service';

  @override
  String get conditionNeedsMaintenanceEffect => 'Opens a request';

  @override
  String get connectSubtitle =>
      'Point Sijil IT at your Odoo instance. Nothing is installed on the server — no addon, no middleware.';

  @override
  String get connectTitle => 'Connect to Odoo';

  @override
  String connectionReachable(String version) {
    return 'Reachable — Odoo $version';
  }

  @override
  String get connectionTesting => 'Checking the server…';

  @override
  String get credentialStorageNote =>
      'Stored in your device keychain, never as plain text';

  @override
  String get dashboardAssetsUnit => 'ASSETS';

  @override
  String get dashboardByCategory => 'Assets by category';

  @override
  String dashboardInService(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString in service';
  }

  @override
  String get dashboardOpenMaintenance => 'Open maintenance';

  @override
  String get dashboardRareStatuses => 'Reserved, damaged or lost';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardTrendTitle => 'In service, last 12 months';

  @override
  String get dashboardWarrantyDue => 'Warranty ends <30 days';

  @override
  String detectFoundCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $countString databases',
      one: 'Found 1 database',
    );
    return '$_temp0';
  }

  @override
  String get detectPickTitle => 'Select a database';

  @override
  String get detectUnsupportedBody =>
      'Most production instances disable database listing. Type the name instead — your Odoo administrator can confirm it.';

  @override
  String get detectUnsupportedTitle =>
      'This server keeps its database list private';

  @override
  String get diagnosticsCopied => 'Copied to clipboard';

  @override
  String get diagnosticsCopy => 'Copy';

  @override
  String get diagnosticsCrashDetail =>
      'Reports never include your password, API key or name.';

  @override
  String get diagnosticsCrashOff => 'Off — nothing leaves this device';

  @override
  String get diagnosticsCrashOn => 'On — anonymous crash reports are sent';

  @override
  String get diagnosticsCrashReporting => 'Crash reporting';

  @override
  String get diagnosticsEmpty => 'No problems recorded';

  @override
  String get diagnosticsEmptyBody =>
      'Technical details appear here when something fails.';

  @override
  String get dueChipOverdue => 'Overdue';

  @override
  String get dueChipSoon => 'Due soon';

  @override
  String dueInDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Due back in $daysString days',
      one: 'Due back tomorrow',
      zero: 'Due back today',
    );
    return '$_temp0';
  }

  @override
  String dueOverdueBy(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get employeeAssetsHeld => 'Assets held';

  @override
  String get employeeAssignedAssets => 'Assigned assets';

  @override
  String get employeeInService => 'In service';

  @override
  String employeeItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get employeeSearchHint => 'Name, department, email…';

  @override
  String employeeSince(String date) {
    return 'since $date';
  }

  @override
  String get employeeTitle => 'Employee';

  @override
  String get employeeWarrantyDue => 'Warranty due';

  @override
  String get employeesTitle => 'Employees';

  @override
  String get emptyActivityBody =>
      'Assignments and returns you record appear here.';

  @override
  String get emptyAssetsBody =>
      'Assets you add or import into Odoo will appear here.';

  @override
  String get emptyAssetsTitle => 'No assets yet';

  @override
  String get emptyEmployeeAssetsBody =>
      'This employee is not holding any assets.';

  @override
  String get emptyEmployeeAssetsTitle => 'Nothing assigned';

  @override
  String get emptyEmployeesBody =>
      'Employees come from the Odoo Employees app.';

  @override
  String get emptyEmployeesTitle => 'No employees';

  @override
  String get emptyMaintenanceBody =>
      'Requests you open from an asset appear here.';

  @override
  String get emptyMaintenanceTitle => 'No maintenance requests';

  @override
  String get emptySearchBody =>
      'Try a different search term or clear your filters.';

  @override
  String get emptySearchTitle => 'No matches';

  @override
  String get errorAccessDeniedBody =>
      'Your Odoo user is not allowed to do this.';

  @override
  String errorAccessDeniedBodyDetailed(String operation, String model) {
    return 'Your Odoo user is not allowed to $operation $model records.';
  }

  @override
  String get errorAccessDeniedFix =>
      'Ask your Odoo administrator to grant access. Sijil IT never works around Odoo permissions.';

  @override
  String get errorAccessDeniedTitle => 'You don\'t have permission';

  @override
  String get errorActionEditConnection => 'Edit connection';

  @override
  String get errorActionSignIn => 'Sign in again';

  @override
  String get errorBusinessRuleFix =>
      'This rule comes from your Odoo configuration, not from Sijil IT.';

  @override
  String get errorBusinessRuleTitle => 'Odoo blocked this';

  @override
  String get errorCacheBody =>
      'The offline copy on this device could not be opened.';

  @override
  String get errorCacheFix =>
      'Clearing the cache from Settings usually fixes this. Nothing in Odoo is affected.';

  @override
  String get errorCacheTitle => 'Couldn\'t read local data';

  @override
  String get errorDatabaseUnavailableBody =>
      'This server has no database with that name.';

  @override
  String get errorDatabaseUnavailableFix =>
      'Database names are case-sensitive. Your Odoo administrator can confirm the exact name.';

  @override
  String get errorDatabaseUnavailableTitle => 'Database not found';

  @override
  String get errorFieldUnavailableBody =>
      'This screen asked Odoo for a field your instance does not have. Nothing was changed.';

  @override
  String errorFieldUnavailableBodyDetailed(String field) {
    return 'This screen asked Odoo for the field “$field”, which your instance does not have. Nothing was changed.';
  }

  @override
  String get errorFieldUnavailableFix =>
      'Retrying will not help — the field has to exist first. Sign out and back in if it was just added; otherwise ask your Odoo administrator.';

  @override
  String get errorFieldUnavailableTitle => 'A field is missing on your Odoo';

  @override
  String get errorFileUnavailableBody =>
      'The phone released the file before it finished uploading. This usually happens when the camera app is closed by the system while another app is in the foreground.';

  @override
  String get errorFileUnavailableFix =>
      'Take the photo again and stay in the app until the upload finishes.';

  @override
  String get errorFileUnavailableTitle => 'Photo could not be read';

  @override
  String get errorHowToFix => 'What to do';

  @override
  String get errorInsecureConnectionBody =>
      'Sijil IT only connects over HTTPS, so your Odoo password is never sent in the clear. The saved address starts with http://.';

  @override
  String get errorInsecureConnectionFix =>
      'Change the address to https://. If your Odoo has no certificate yet, your administrator can add one — a self-hosted instance on the office network needs it too.';

  @override
  String get errorInsecureConnectionTitle => 'This address is not encrypted';

  @override
  String get errorInvalidCredentialsBody =>
      'Odoo did not accept this username with this password or API key.';

  @override
  String get errorInvalidCredentialsFix =>
      'Check the username, and note that an API key is not the same as your password.';

  @override
  String get errorInvalidCredentialsTitle => 'Sign-in was rejected';

  @override
  String get errorModelUnavailableBody =>
      'This feature needs an Odoo app that is not installed.';

  @override
  String errorModelUnavailableBodyDetailed(String model) {
    return 'This feature needs the Odoo model $model, which this instance does not have.';
  }

  @override
  String get errorModelUnavailableFix =>
      'Your Odoo administrator can install the matching app. Everything else in Sijil IT keeps working.';

  @override
  String get errorModelUnavailableTitle => 'Not available on your Odoo';

  @override
  String get errorNoInternetBody =>
      'This device has no internet connection right now.';

  @override
  String get errorNoInternetFix =>
      'Turn on Wi-Fi or mobile data, then try again.';

  @override
  String get errorNoInternetTitle => 'You\'re offline';

  @override
  String get errorNotAnOdooServerBody =>
      'The address answered, but not with an Odoo XML-RPC response.';

  @override
  String get errorNotAnOdooServerFix =>
      'Use the base URL of the instance, without a path — for example https://company.odoo.com';

  @override
  String get errorNotAnOdooServerTitle => 'That doesn\'t look like Odoo';

  @override
  String get errorRateLimitedBody =>
      'The Odoo server is limiting how often this app may ask for data. Nothing is wrong with your connection or your account.';

  @override
  String get errorRateLimitedFix =>
      'Wait a moment and try again. If it keeps happening, ask your Odoo administrator to raise the rate limit for this app.';

  @override
  String errorRateLimitedFixSeconds(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Wait $secondsString seconds and try again.',
      one: 'Wait 1 second and try again.',
    );
    return '$_temp0';
  }

  @override
  String get errorRateLimitedTitle => 'Too many requests';

  @override
  String get errorRecordNotFoundBody =>
      'It was deleted in Odoo, or it is outside what your user can see.';

  @override
  String get errorRecordNotFoundFix =>
      'Go back and refresh the list to see the current records.';

  @override
  String get errorRecordNotFoundTitle => 'This record is gone';

  @override
  String get errorRouteNotFoundBody =>
      'The link you followed points somewhere Sijil IT has no screen for.';

  @override
  String get errorRouteNotFoundTitle => 'That screen doesn\'t exist';

  @override
  String get errorServerBody => 'The server failed while handling the request.';

  @override
  String get errorServerFix =>
      'Try again. If it persists, send the details from Settings → Diagnostics to your administrator.';

  @override
  String get errorServerTitle => 'Odoo reported an error';

  @override
  String get errorServerUnreachableBody =>
      'The address responded to nothing. The server may be offline, or the URL may be wrong.';

  @override
  String get errorServerUnreachableFix =>
      'Check the server URL, and confirm the instance opens in a browser from this network.';

  @override
  String get errorServerUnreachableTitle => 'Can\'t reach your Odoo server';

  @override
  String get errorSessionExpiredBody =>
      'Odoo no longer recognises this session.';

  @override
  String get errorSessionExpiredFix =>
      'Sign in again to continue where you left off.';

  @override
  String get errorSessionExpiredTitle => 'Your session ended';

  @override
  String get errorTimeoutBody =>
      'Odoo did not answer in time. It may be busy or the connection slow.';

  @override
  String get errorTimeoutFix =>
      'Try again in a moment. If it keeps happening, tell your Odoo administrator.';

  @override
  String get errorTimeoutTitle => 'The server took too long';

  @override
  String get errorUnknownBody => 'Sijil IT hit a problem it did not expect.';

  @override
  String get errorUnknownFix =>
      'Try again. The technical detail is saved under Settings → Diagnostics.';

  @override
  String get errorUnknownTitle => 'Something went wrong';

  @override
  String get errorValidationFix => 'Fix the highlighted field and try again.';

  @override
  String get errorValidationTitle => 'Check what you entered';

  @override
  String exportAssetsSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString assets',
      one: '1 asset',
    );
    return '$_temp0';
  }

  @override
  String get exportAssetsTitle => 'Asset list';

  @override
  String get exportColumnAssignedOn => 'Assigned on';

  @override
  String get exportColumnCategory => 'Category';

  @override
  String get exportColumnDepartment => 'Department';

  @override
  String get exportColumnDueBack => 'Due back';

  @override
  String get exportColumnHolder => 'Assigned to';

  @override
  String get exportColumnManufacturer => 'Manufacturer';

  @override
  String get exportColumnModel => 'Model';

  @override
  String get exportColumnName => 'Name';

  @override
  String get exportColumnSerial => 'Serial number';

  @override
  String get exportColumnStatus => 'Status';

  @override
  String get exportColumnTag => 'Tag';

  @override
  String get exportColumnWarrantyEnd => 'Warranty ends';

  @override
  String get exportFailed => 'The file could not be prepared.';

  @override
  String exportGeneratedOn(String date) {
    return 'Generated $date';
  }

  @override
  String get exportNothingToShare => 'There is nothing to export yet.';

  @override
  String get exportShare => 'Share';

  @override
  String get fieldApiKeyHint => 'Your Odoo API key';

  @override
  String get fieldCredential => 'Credential';

  @override
  String get fieldDatabase => 'Database';

  @override
  String get fieldDatabaseHint => 'company-production';

  @override
  String get fieldPasswordHint => 'Your Odoo password';

  @override
  String get fieldServerUrl => 'Server URL';

  @override
  String get fieldServerUrlHint => 'https://company.odoo.com';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldUsernameHint => 'you@company.com';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterClearAll => 'Clear all';

  @override
  String get filterDepartment => 'Department';

  @override
  String get filterIncludeRetired => 'Include retired';

  @override
  String get filterManufacturer => 'Manufacturer';

  @override
  String get filterOverdue => 'Overdue only';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterWarranty => 'Warranty';

  @override
  String get filtersLabel => 'Filters';

  @override
  String filtersLabelActive(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Filters ($countString)';
  }

  @override
  String get filtersTitle => 'Filter assets';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get handoverAddAssets => 'Add assets';

  @override
  String handoverAddCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Add $countString';
  }

  @override
  String get handoverBundleEmpty => 'Nothing added yet.';

  @override
  String handoverBundleFull(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$maxString is the most one handover can carry';
  }

  @override
  String get handoverConfirm => 'Confirm handover';

  @override
  String handoverDone(String employee) {
    return 'Handed over to $employee';
  }

  @override
  String get handoverNeedsAssets => 'Add at least one asset';

  @override
  String get handoverNeedsRecipient => 'Choose who is receiving';

  @override
  String get handoverNeedsSignature => 'The recipient has to sign';

  @override
  String get handoverNoAssignableAssets =>
      'Nothing available to hand over right now.';

  @override
  String get handoverNotesHint =>
      'Onboarding kit, replacement for a failed laptop…';

  @override
  String get handoverNothingRecorded => 'Nothing was recorded';

  @override
  String get handoverNothingRecordedBody =>
      'Odoo accepted none of the bundle, so no asset changed hands.';

  @override
  String handoverPartial(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString recorded';
  }

  @override
  String get handoverPickAssets => 'Add to the handover';

  @override
  String get handoverPickAssetsBody =>
      'Only assets nobody is holding are shown.';

  @override
  String get handoverProofSaved => 'The signature is on every asset in Odoo.';

  @override
  String get handoverRecorded => 'Recorded';

  @override
  String get handoverRefused => 'Odoo refused these';

  @override
  String handoverRemoveFromBundle(String asset) {
    return 'Remove $asset';
  }

  @override
  String get handoverRetryRefused => 'Try these again';

  @override
  String get handoverSearchAssets => 'Search assets';

  @override
  String get handoverSearchPeople => 'Search people';

  @override
  String get handoverSignHint => 'Sign above';

  @override
  String get handoverSignatureIncomplete =>
      'Recorded, but the signature did not reach every asset.';

  @override
  String get handoverSignatureRequired => 'Sign to confirm receipt';

  @override
  String get handoverStepBundle => 'What they are receiving';

  @override
  String get handoverStepDate => 'Handover date';

  @override
  String get handoverStepNotes => 'Note';

  @override
  String get handoverStepRecipient => 'Who is receiving';

  @override
  String get handoverStepSignature => 'Recipient\'s signature';

  @override
  String get handoverSubtitle => 'Several assets, one signature';

  @override
  String get handoverTitle => 'Handover';

  @override
  String get historyEmptyBody =>
      'Assignments, returns and repairs appear here as they happen.';

  @override
  String get historyEmptyTitle => 'Nothing recorded yet';

  @override
  String historyHolders(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString holders',
      one: '1 holder',
      zero: 'No holders yet',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadOlder => 'Show older';

  @override
  String get historyRegistered => 'Registered';

  @override
  String historySince(String date) {
    return 'In service since $date';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get labelAll => 'All';

  @override
  String get labelAssetName => 'Asset name';

  @override
  String get labelAssetTag => 'Asset tag';

  @override
  String get labelAssignedOn => 'Assigned';

  @override
  String get labelCategory => 'Category';

  @override
  String get labelDueBack => 'Due back';

  @override
  String labelHeldDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get labelManufacturer => 'Manufacturer';

  @override
  String get labelModel => 'Model';

  @override
  String get labelNone => 'None';

  @override
  String get labelNotes => 'Notes';

  @override
  String get labelOdooVersion => 'Odoo version';

  @override
  String get labelOptional => 'optional';

  @override
  String get labelPurchaseDate => 'Purchase date';

  @override
  String get labelPurchaseValue => 'Purchase value';

  @override
  String get labelSerialNumber => 'Serial number';

  @override
  String get labelServer => 'Server';

  @override
  String labelSheetSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString labels',
      one: '1 label',
    );
    return '$_temp0';
  }

  @override
  String get labelSheetTitle => 'Asset labels';

  @override
  String get labelSignedInAs => 'Signed in as';

  @override
  String get labelUnassigned => 'Unassigned';

  @override
  String get labelUnknown => 'Not recorded';

  @override
  String get labelVendor => 'Vendor';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'System';

  @override
  String get launchNoMailApp => 'No email app is set up on this device.';

  @override
  String get launchNoPhoneApp => 'This device cannot place calls.';

  @override
  String lifecycleAge(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'In service $monthsString months',
      one: 'In service 1 month',
      zero: 'In service less than a month',
    );
    return '$_temp0';
  }

  @override
  String get lifecycleAgeing => 'Due for replacement';

  @override
  String get lifecycleCostPerYear => 'Cost per year so far';

  @override
  String get lifecycleOverdue => 'Past its expected life';

  @override
  String lifecycleOverdueBy(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString months past its expected life',
      one: '1 month past its expected life',
    );
    return '$_temp0';
  }

  @override
  String lifecycleRemaining(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString months left of its expected life',
      one: '1 month left of its expected life',
    );
    return '$_temp0';
  }

  @override
  String get lifecycleTitle => 'Service life';

  @override
  String get lifecycleUnknown => 'No purchase date recorded';

  @override
  String get lifecycleUnknownHint =>
      'Add a purchase date to see how much life this asset has left and what it has cost per year.';

  @override
  String get loadingLabel => 'Loading…';

  @override
  String get lockBody =>
      'Anyone holding an unlocked phone could reassign company equipment. Unlock to carry on.';

  @override
  String get lockFailed => 'That did not unlock. Try again.';

  @override
  String get lockReason => 'Unlock Sijil IT';

  @override
  String get lockSettingsSubtitle =>
      'Ask for this device’s fingerprint, face or passcode before Sijil IT opens.';

  @override
  String get lockSettingsTitle => 'Require unlock';

  @override
  String get lockTitle => 'Sijil IT is locked';

  @override
  String get lockUnavailable =>
      'This device has no screen lock set up, so there is nothing to ask for.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get loginAclNotice =>
      'Sijil IT works inside your Odoo permissions. You will only see and change what your Odoo user is allowed to.';

  @override
  String get loginBackToServer => 'Back to server settings';

  @override
  String get loginKeepSignedIn => 'Keep me signed in';

  @override
  String get loginNeedApiKey => 'Need an API key?';

  @override
  String get loginSubtitle => 'Sign in with your Odoo credentials.';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String maintenanceClosed(String date) {
    return 'Closed $date';
  }

  @override
  String get maintenanceDuration => 'Duration';

  @override
  String maintenanceHours(String hours) {
    return '$hours h';
  }

  @override
  String get maintenanceNewRequest => 'New request';

  @override
  String get maintenanceNextScheduled => 'Next preventive check';

  @override
  String get maintenanceOnlyOpen => 'Open only';

  @override
  String get maintenanceOverdue => 'Overdue';

  @override
  String get maintenancePriorityHigh => 'High';

  @override
  String get maintenancePriorityLow => 'Low';

  @override
  String get maintenancePriorityNormal => 'Normal';

  @override
  String get maintenancePriorityVeryLow => 'Very low';

  @override
  String maintenanceRequestCreated(String asset) {
    return 'Request opened for $asset';
  }

  @override
  String get maintenanceRequestHint => 'What needs fixing?';

  @override
  String get maintenanceRequestTitle => 'Maintenance request';

  @override
  String get maintenanceRequestedOn => 'Requested';

  @override
  String get maintenanceScheduled => 'Scheduled';

  @override
  String get maintenanceSearchHint => 'Request or asset…';

  @override
  String get maintenanceStage => 'Stage';

  @override
  String get maintenanceTechnician => 'Technician';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get maintenanceTypeCorrective => 'Corrective';

  @override
  String get maintenanceTypeField => 'Type';

  @override
  String get maintenanceTypePreventive => 'Preventive';

  @override
  String get moreAuditSubtitle => 'Count what is really there';

  @override
  String get moreHandoverSubtitle => 'Hand several assets to one person';

  @override
  String get moreMaintenanceSubtitle => 'Requests and history for your assets';

  @override
  String get moreSettingsSubtitle =>
      'Connection, account, appearance and cache';

  @override
  String get moreTitle => 'More';

  @override
  String get moreToolsLabel => 'Tools';

  @override
  String get navAssets => 'Assets';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navEmployees => 'Employees';

  @override
  String get navMore => 'More';

  @override
  String get navScan => 'Scan';

  @override
  String get operationCreate => 'create';

  @override
  String get operationDelete => 'delete';

  @override
  String get operationRead => 'view';

  @override
  String get operationWrite => 'change';

  @override
  String overdueCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString assets are late',
      one: '1 asset is late',
    );
    return '$_temp0';
  }

  @override
  String get overdueEmptyBody =>
      'Every asset with a return date is still within it. Set a date when you hand something over and it will be watched here.';

  @override
  String get overdueEmptyTitle => 'Nothing is late';

  @override
  String get overdueSubtitle => 'Assets past the date they were promised back';

  @override
  String get overdueTitle => 'Overdue returns';

  @override
  String photoCount(int used, int max) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$usedString of $maxString';
  }

  @override
  String get photosAdd => 'Add';

  @override
  String get photosAdded => 'Photo saved';

  @override
  String get photosCamera => 'Camera';

  @override
  String get photosEmpty => 'No photos yet';

  @override
  String get photosEmptyHint =>
      'Photograph the fault before you start, and the repair when you finish.';

  @override
  String get photosGallery => 'Gallery';

  @override
  String photosPosition(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString of $totalString';
  }

  @override
  String get photosRemoveAction => 'Remove';

  @override
  String get photosRemoveBody => 'It will be deleted from Odoo for everyone.';

  @override
  String get photosRemoveTitle => 'Remove this photo?';

  @override
  String get photosRemoved => 'Photo removed';

  @override
  String get photosSavedToOdoo => 'Saved to Odoo';

  @override
  String get photosTitle => 'Photos';

  @override
  String get qrHint =>
      'Print this and stick it on the device. It carries only the asset id.';

  @override
  String get qrTitle => 'Asset QR code';

  @override
  String get receiptAssets => 'Assets';

  @override
  String get receiptDate => 'Handed over on';

  @override
  String get receiptNotes => 'Notes';

  @override
  String get receiptRecipient => 'Received by';

  @override
  String get receiptShare => 'Share receipt';

  @override
  String get receiptSignature => 'Signature';

  @override
  String get receiptTitle => 'Handover receipt';

  @override
  String reminderMaintenanceDue(String request) {
    return '$request is scheduled for today.';
  }

  @override
  String reminderMaintenanceOverdue(String request, int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$request is $daysString days overdue.',
      one: '$request is 1 day overdue.',
    );
    return '$_temp0';
  }

  @override
  String get reminderMaintenanceTitle => 'Maintenance due';

  @override
  String reminderNotificationBody(String asset, int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days left',
      one: '1 day left',
    );
    return '$asset — $_temp0';
  }

  @override
  String get reminderNotificationTitle => 'A warranty is running out';

  @override
  String get remindersDenied =>
      'Notifications are switched off for Sijil IT in your device settings.';

  @override
  String remindersLeadDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get remindersLeadLabel => 'Warn me';

  @override
  String remindersScheduled(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString reminders scheduled',
      one: '1 reminder scheduled',
      zero: 'Nothing scheduled',
    );
    return '$_temp0';
  }

  @override
  String get remindersSubtitle => 'Be told before a warranty runs out';

  @override
  String get remindersTitle => 'Warranty reminders';

  @override
  String get returnCondition => 'Condition on return';

  @override
  String get returnConfirm => 'Confirm return';

  @override
  String get returnDate => 'Return date';

  @override
  String returnHeldFor(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'held $daysString days',
      one: 'held 1 day',
    );
    return '$_temp0';
  }

  @override
  String get returnNotesHint => 'Any damage or missing accessories…';

  @override
  String returnOutcome(String status) {
    return 'Returns to $status and the note is posted to Odoo.';
  }

  @override
  String get returnPhotos => 'Photos';

  @override
  String returnSuccess(String asset) {
    return '$asset returned';
  }

  @override
  String get returnTitle => 'Return asset';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get scanCameraErrorBody =>
      'Another app may be using the camera, or this device did not hand it over.';

  @override
  String get scanCameraErrorFix =>
      'Close any other app using the camera, then reopen this screen. Restarting the device clears it if that does not.';

  @override
  String get scanCameraErrorTitle => 'The camera could not start';

  @override
  String get scanCreateAsset => 'Create asset';

  @override
  String get scanEnterCode => 'Type a code';

  @override
  String get scanEnterCodeBody =>
      'For a label the camera cannot read — scratched, in the dark, or behind a desk.';

  @override
  String get scanEnterCodeHint => 'Serial number or asset tag';

  @override
  String get scanEnterCodeTitle => 'Type the asset code';

  @override
  String get scanInstruction => 'Point at an asset code';

  @override
  String get scanInstructionDetail =>
      'QR codes, equipment barcodes and printed serial numbers all work.';

  @override
  String scanMatched(String payload) {
    return 'Matched $payload';
  }

  @override
  String get scanModeBarcode => 'Barcode';

  @override
  String get scanModeQr => 'QR code';

  @override
  String scanNoMatchBody(String code) {
    return 'Nothing in Odoo matches $code.';
  }

  @override
  String get scanNoMatchTitle => 'No asset for that code';

  @override
  String get scanPermissionBody =>
      'Sijil IT needs the camera to read asset codes.';

  @override
  String get scanPermissionFix =>
      'Turn on camera access for Sijil IT in your device settings.';

  @override
  String get scanPermissionTitle => 'Camera access is off';

  @override
  String get scanTitle => 'Scan asset';

  @override
  String get scanTorch => 'Torch';

  @override
  String get sectionActivity => 'Activity';

  @override
  String get sectionDeviceInformation => 'Device information';

  @override
  String get sectionMaintenance => 'Maintenance';

  @override
  String get sectionOwnership => 'Ownership';

  @override
  String get sectionPurchase => 'Purchase & vendor';

  @override
  String get sectionWarranty => 'Warranty';

  @override
  String get selectionAll => 'Select all loaded';

  @override
  String get selectionCancel => 'Leave selection';

  @override
  String selectionCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString selected',
      one: '1 selected',
      zero: 'Nothing selected',
    );
    return '$_temp0';
  }

  @override
  String selectionLimitReached(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You can act on $countString assets at a time.';
  }

  @override
  String get selectionNone => 'Clear selection';

  @override
  String get selectionStart => 'Select assets';

  @override
  String sessionExpiresOn(String date) {
    return 'Signs out on $date unless the app is opened.';
  }

  @override
  String get sessionExplain =>
      'The window counts from the last time you opened the app, so daily use never signs you out. A device left unused is signed out and the saved credential is deleted.';

  @override
  String sessionMaxAgeDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days',
      one: '1 day',
      zero: 'No limit',
    );
    return '$_temp0';
  }

  @override
  String get sessionNeverExpiresNote =>
      'The saved sign-in never expires on this device.';

  @override
  String get sessionSubtitle =>
      'How long this device may reuse your Odoo sign-in without you typing it again.';

  @override
  String get sessionTitle => 'Saved sign-in';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsCacheKeepStates => 'Keep local asset states';

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsClearCacheBody =>
      'Odoo keeps everything. Only the offline copy on this device is removed.';

  @override
  String get settingsClearCacheConfirm => 'Clear cached data?';

  @override
  String get settingsClearCacheDone => 'Cache cleared';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsConnection => 'Odoo connection';

  @override
  String get settingsDetected => 'Detected on your Odoo';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsDetail => 'Technical log, credentials redacted';

  @override
  String get settingsDisconnected => 'Not connected';

  @override
  String get settingsLanguage => 'Language';

  @override
  String settingsLastChecked(String time) {
    return 'Last checked $time';
  }

  @override
  String get settingsMetadataRefreshed => 'Odoo metadata refreshed';

  @override
  String get settingsNeverChecked => 'Not checked yet';

  @override
  String get settingsRefreshMetadata => 'Refresh Odoo metadata';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutBody =>
      'Your stored credential is removed from this device.';

  @override
  String get settingsSignOutConfirm => 'Sign out of Sijil IT?';

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsVersion(String version, String build) {
    return 'Sijil IT $version (build $build)';
  }

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNameAsc => 'Name A–Z';

  @override
  String get sortNameDesc => 'Name Z–A';

  @override
  String get sortRecent => 'Recently updated';

  @override
  String get splashRestoring => 'Restoring your session…';

  @override
  String get statusAssigned => 'Assigned';

  @override
  String get statusAvailable => 'Available';

  @override
  String get statusDamaged => 'Damaged';

  @override
  String get statusKeptInLog => 'Recorded in the log';

  @override
  String get statusLost => 'Lost';

  @override
  String get statusMaintenance => 'Maintenance';

  @override
  String get statusReserved => 'Reserved';

  @override
  String get statusRetired => 'Retired';

  @override
  String syncAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString attempts',
      one: '1 attempt',
    );
    return '$_temp0';
  }

  @override
  String get syncBlocked => 'Odoo refused this. It will not be retried.';

  @override
  String get syncDiscard => 'Discard queue';

  @override
  String get syncDiscardBody =>
      'These were never sent to Odoo. Discarding them cannot be undone.';

  @override
  String get syncDiscardConfirm => 'Discard the waiting changes?';

  @override
  String get syncDiscardFailedAll => 'Discard all';

  @override
  String get syncDiscardFailedAllBody =>
      'These changes will be forgotten. Odoo never received them, so they cannot be recovered. Anything still waiting to send is left alone.';

  @override
  String get syncDiscardFailedAllConfirm => 'Discard everything that failed?';

  @override
  String get syncDiscardOne => 'Discard';

  @override
  String syncDiscardOneBody(String subject) {
    return '$subject will be forgotten. Odoo never received it, so it cannot be recovered.';
  }

  @override
  String get syncDiscardOneConfirm => 'Discard this change?';

  @override
  String syncFailedBanner(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString changes could not be sent — tap to review',
      one: '1 change could not be sent — tap to review',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedBody =>
      'Odoo refused these. They are still saved here, so nothing you did is lost — but they will not send on their own.';

  @override
  String syncFailedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString changes could not be sent',
      one: '1 change could not be sent',
    );
    return '$_temp0';
  }

  @override
  String syncFailedReason(String reason) {
    return 'Odoo said: $reason';
  }

  @override
  String get syncFailedSection => 'Could not be sent';

  @override
  String get syncNow => 'Send now';

  @override
  String get syncOfflineBanner => 'Offline';

  @override
  String syncPendingBanner(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString changes waiting to send',
      one: '1 change waiting to send',
    );
    return '$_temp0';
  }

  @override
  String get syncPendingChip => 'Not sent yet';

  @override
  String get syncQueueEmptyBody =>
      'Changes you make without a connection wait here until there is one.';

  @override
  String get syncQueueEmptyTitle => 'Everything is on Odoo';

  @override
  String syncQueuedAssign(String employee) {
    return 'Hand over to $employee';
  }

  @override
  String get syncQueuedNotice =>
      'Saved on this device. It will go to Odoo when there is a connection.';

  @override
  String get syncQueuedReturn => 'Take back';

  @override
  String syncQueuedStatus(String status) {
    return 'Mark as $status';
  }

  @override
  String get syncRetryOne => 'Try again';

  @override
  String get syncSending => 'Sending…';

  @override
  String syncSentCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString changes sent',
      one: '1 change sent',
    );
    return '$_temp0';
  }

  @override
  String syncStaleBanner(String time) {
    return 'Showing the copy from $time';
  }

  @override
  String get syncSubtitle => 'Writes waiting for a connection';

  @override
  String get syncTitle => 'Sync';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String timeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString d ago';
  }

  @override
  String timeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString h ago';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString min ago';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String get tooltipToggleLanguage => 'Switch language';

  @override
  String get tooltipToggleTheme => 'Switch appearance';

  @override
  String get validationEnterAssetName => 'Enter a name for this asset.';

  @override
  String get validationEnterCredential => 'Enter your password or API key.';

  @override
  String get validationEnterDatabase => 'Enter your Odoo database name.';

  @override
  String get validationEnterServerUrl => 'Enter your Odoo server URL.';

  @override
  String get validationEnterUsername => 'Enter your Odoo username.';

  @override
  String get validationHttpsRequired =>
      'The server URL must start with https://';

  @override
  String get validationInvalidUrl =>
      'That doesn\'t look like a valid server address.';

  @override
  String get voiceHeardNothing =>
      'Nothing was heard. Try again, closer to the phone.';

  @override
  String get voiceSearchStart => 'Search by voice';

  @override
  String get voiceSearchStop => 'Stop listening';

  @override
  String warrantyEnds(String date) {
    return 'Ends $date';
  }

  @override
  String warrantyExpiredAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expired $daysString days ago',
      one: 'Expired 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String warrantyExpiresIn(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $daysString days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get warrantyFilterCritical => 'Ends within 30 days';

  @override
  String get warrantyFilterExpired => 'Expired';

  @override
  String get warrantyFilterSoon => 'Ends within 90 days';

  @override
  String get warrantyFilterValid => 'Valid';

  @override
  String warrantyStarted(String date) {
    return 'Started $date';
  }

  @override
  String get warrantyUnknown => 'No warranty date';

  @override
  String get warrantyValid => 'Warranty valid';
}
