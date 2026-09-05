import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get actionAssign;

  /// No description provided for @actionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get actionCall;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionDetectDatabases.
  ///
  /// In en, this message translates to:
  /// **'Detect databases'**
  String get actionDetectDatabases;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get actionEmail;

  /// No description provided for @actionGoToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to dashboard'**
  String get actionGoToDashboard;

  /// No description provided for @actionMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get actionMaintain;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// Button on the camera-permission screen. Opens this app's page in the device settings, which is the only place the permission can be turned back on once it has been denied.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get actionReturn;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get actionSigningIn;

  /// No description provided for @actionTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get actionTestConnection;

  /// No description provided for @actionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get actionToday;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'IT Asset Management'**
  String get appTagline;

  /// Menu entry on the asset detail screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get assetActionHistory;

  /// No description provided for @assetActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset actions'**
  String get assetActionsTitle;

  /// No description provided for @assetDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from Odoo for everyone. This cannot be undone.'**
  String get assetDeleteBody;

  /// No description provided for @assetDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this asset?'**
  String get assetDeleteConfirm;

  /// No description provided for @assetDeleted.
  ///
  /// In en, this message translates to:
  /// **'{asset} deleted'**
  String assetDeleted(String asset);

  /// No description provided for @assetDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset details'**
  String get assetDetailTitle;

  /// No description provided for @assetEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit asset'**
  String get assetEditTitle;

  /// No description provided for @assetLocalStateNote.
  ///
  /// In en, this message translates to:
  /// **'Standard Odoo has no field for this state, so it is recorded in the asset\'s log — where everyone can see it.'**
  String get assetLocalStateNote;

  /// No description provided for @assetMarkAvailable.
  ///
  /// In en, this message translates to:
  /// **'Mark as available'**
  String get assetMarkAvailable;

  /// No description provided for @assetMarkDamaged.
  ///
  /// In en, this message translates to:
  /// **'Mark as damaged'**
  String get assetMarkDamaged;

  /// No description provided for @assetMarkLost.
  ///
  /// In en, this message translates to:
  /// **'Mark as lost'**
  String get assetMarkLost;

  /// No description provided for @assetMarkReserved.
  ///
  /// In en, this message translates to:
  /// **'Mark as reserved'**
  String get assetMarkReserved;

  /// No description provided for @assetNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New asset'**
  String get assetNewTitle;

  /// No description provided for @assetSaved.
  ///
  /// In en, this message translates to:
  /// **'{asset} saved'**
  String assetSaved(String asset);

  /// No description provided for @assetShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get assetShowQr;

  /// No description provided for @assetsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, tag, serial, model…'**
  String get assetsSearchHint;

  /// No description provided for @assetsShowingOf.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String assetsShowingOf(int shown, int total);

  /// No description provided for @assetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsTitle;

  /// No description provided for @assignAllDepartments.
  ///
  /// In en, this message translates to:
  /// **'All departments'**
  String get assignAllDepartments;

  /// No description provided for @assignConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm assignment'**
  String get assignConfirm;

  /// No description provided for @assignDueClear.
  ///
  /// In en, this message translates to:
  /// **'Remove the date'**
  String get assignDueClear;

  /// No description provided for @assignDueHint.
  ///
  /// In en, this message translates to:
  /// **'Leave this empty unless the asset is a loan somebody has to bring back.'**
  String get assignDueHint;

  /// No description provided for @assignDueNotSet.
  ///
  /// In en, this message translates to:
  /// **'No return date'**
  String get assignDueNotSet;

  /// No description provided for @assignNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Handed over with charger and USB-C hub…'**
  String get assignNotesHint;

  /// No description provided for @assignSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search employees…'**
  String get assignSearchHint;

  /// No description provided for @assignStepDate.
  ///
  /// In en, this message translates to:
  /// **'Assignment date'**
  String get assignStepDate;

  /// No description provided for @assignStepDue.
  ///
  /// In en, this message translates to:
  /// **'Expected return date'**
  String get assignStepDue;

  /// No description provided for @assignStepEmployee.
  ///
  /// In en, this message translates to:
  /// **'Select employee'**
  String get assignStepEmployee;

  /// No description provided for @assignStepNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get assignStepNotes;

  /// No description provided for @assignSuccess.
  ///
  /// In en, this message translates to:
  /// **'{asset} assigned to {employee}'**
  String assignSuccess(String asset, String employee);

  /// No description provided for @assignTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign asset'**
  String get assignTitle;

  /// No description provided for @auditBegin.
  ///
  /// In en, this message translates to:
  /// **'Start counting'**
  String get auditBegin;

  /// No description provided for @auditCounting.
  ///
  /// In en, this message translates to:
  /// **'Counting'**
  String get auditCounting;

  /// No description provided for @auditDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The scans so far are on this phone only. Leaving loses them.'**
  String get auditDiscardBody;

  /// No description provided for @auditDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get auditDiscardConfirm;

  /// No description provided for @auditDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the count?'**
  String get auditDiscardTitle;

  /// No description provided for @auditFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get auditFinish;

  /// No description provided for @auditFound.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get auditFound;

  /// No description provided for @auditJustScanned.
  ///
  /// In en, this message translates to:
  /// **'Just scanned'**
  String get auditJustScanned;

  /// No description provided for @auditKeepScanning.
  ///
  /// In en, this message translates to:
  /// **'Keep scanning — no need to stop'**
  String get auditKeepScanning;

  /// No description provided for @auditMissing.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get auditMissing;

  /// No description provided for @auditNothingMissing.
  ///
  /// In en, this message translates to:
  /// **'Everything in scope was found.'**
  String get auditNothingMissing;

  /// No description provided for @auditOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String auditOf(int done, int total);

  /// No description provided for @auditOutOfScope.
  ///
  /// In en, this message translates to:
  /// **'Here, but recorded elsewhere'**
  String get auditOutOfScope;

  /// No description provided for @auditPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get auditPickCategory;

  /// No description provided for @auditPickDepartment.
  ///
  /// In en, this message translates to:
  /// **'Pick a department'**
  String get auditPickDepartment;

  /// No description provided for @auditReportExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get auditReportExpected;

  /// No description provided for @auditReportFound.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get auditReportFound;

  /// No description provided for @auditReportMissing.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get auditReportMissing;

  /// No description provided for @auditReportScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get auditReportScope;

  /// No description provided for @auditReportShare.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get auditReportShare;

  /// No description provided for @auditReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock count'**
  String get auditReportTitle;

  /// No description provided for @auditReportUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Found out of scope'**
  String get auditReportUnexpected;

  /// No description provided for @auditResume.
  ///
  /// In en, this message translates to:
  /// **'Keep counting'**
  String get auditResume;

  /// No description provided for @auditSaveToOdoo.
  ///
  /// In en, this message translates to:
  /// **'Save findings to Odoo'**
  String get auditSaveToOdoo;

  /// No description provided for @auditSaved.
  ///
  /// In en, this message translates to:
  /// **'Findings saved to Odoo'**
  String get auditSaved;

  /// No description provided for @auditSavedNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to record — no findings.'**
  String get auditSavedNone;

  /// No description provided for @auditScopeAll.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get auditScopeAll;

  /// No description provided for @auditScopeCategory.
  ///
  /// In en, this message translates to:
  /// **'One category'**
  String get auditScopeCategory;

  /// No description provided for @auditScopeDepartment.
  ///
  /// In en, this message translates to:
  /// **'One department'**
  String get auditScopeDepartment;

  /// No description provided for @auditStartBody.
  ///
  /// In en, this message translates to:
  /// **'A narrow scope gets counted. Everything at once does not.'**
  String get auditStartBody;

  /// No description provided for @auditStartTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you counting?'**
  String get auditStartTitle;

  /// No description provided for @auditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get auditTitle;

  /// No description provided for @auditUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Not in scope'**
  String get auditUnexpected;

  /// No description provided for @auditUnknownCode.
  ///
  /// In en, this message translates to:
  /// **'That code matches no asset'**
  String get auditUnknownCode;

  /// No description provided for @auditWhereExpected.
  ///
  /// In en, this message translates to:
  /// **'Where expected'**
  String get auditWhereExpected;

  /// No description provided for @authModeApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get authModeApiKey;

  /// No description provided for @authModePassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authModePassword;

  /// No description provided for @bulkMoveDepartment.
  ///
  /// In en, this message translates to:
  /// **'Move to department'**
  String get bulkMoveDepartment;

  /// Confirmation after a bulk department move.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 asset moved to {department}} other{{count} assets moved to {department}}}'**
  String bulkMoveDone(int count, String department);

  /// No description provided for @bulkMoveNoDepartments.
  ///
  /// In en, this message translates to:
  /// **'This Odoo has no departments to move assets to.'**
  String get bulkMoveNoDepartments;

  /// No description provided for @bulkMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Which department?'**
  String get bulkMoveTitle;

  /// No description provided for @bulkPrintLabels.
  ///
  /// In en, this message translates to:
  /// **'Label sheet'**
  String get bulkPrintLabels;

  /// No description provided for @capabilityActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get capabilityActivityLog;

  /// No description provided for @capabilityEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get capabilityEmployees;

  /// No description provided for @capabilityInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get capabilityInventory;

  /// No description provided for @capabilityMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get capabilityMaintenance;

  /// No description provided for @conditionDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get conditionDamaged;

  /// No description provided for @conditionDamagedEffect.
  ///
  /// In en, this message translates to:
  /// **'Marks as damaged'**
  String get conditionDamagedEffect;

  /// No description provided for @conditionGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get conditionGood;

  /// No description provided for @conditionGoodEffect.
  ///
  /// In en, this message translates to:
  /// **'Back to available'**
  String get conditionGoodEffect;

  /// No description provided for @conditionMinorDamage.
  ///
  /// In en, this message translates to:
  /// **'Minor damage'**
  String get conditionMinorDamage;

  /// No description provided for @conditionNeedsMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Needs service'**
  String get conditionNeedsMaintenance;

  /// No description provided for @conditionNeedsMaintenanceEffect.
  ///
  /// In en, this message translates to:
  /// **'Opens a request'**
  String get conditionNeedsMaintenanceEffect;

  /// No description provided for @connectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Point Sijil IT at your Odoo instance. Nothing is installed on the server — no addon, no middleware.'**
  String get connectSubtitle;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to Odoo'**
  String get connectTitle;

  /// No description provided for @connectionReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable — Odoo {version}'**
  String connectionReachable(String version);

  /// No description provided for @connectionTesting.
  ///
  /// In en, this message translates to:
  /// **'Checking the server…'**
  String get connectionTesting;

  /// No description provided for @credentialStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Stored in your device keychain, never as plain text'**
  String get credentialStorageNote;

  /// Label under the total inside the donut.
  ///
  /// In en, this message translates to:
  /// **'ASSETS'**
  String get dashboardAssetsUnit;

  /// No description provided for @dashboardByCategory.
  ///
  /// In en, this message translates to:
  /// **'Assets by category'**
  String get dashboardByCategory;

  /// No description provided for @dashboardInService.
  ///
  /// In en, this message translates to:
  /// **'{count} in service'**
  String dashboardInService(int count);

  /// No description provided for @dashboardOpenMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Open maintenance'**
  String get dashboardOpenMaintenance;

  /// One legend row grouping the three rare statuses.
  ///
  /// In en, this message translates to:
  /// **'Reserved, damaged or lost'**
  String get dashboardRareStatuses;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// Header of the trend chart. Avoids a separator next to the digits: in Arabic a middot beside Arabic-Indic numerals reorders and reads as part of the number.
  ///
  /// In en, this message translates to:
  /// **'In service, last 12 months'**
  String get dashboardTrendTitle;

  /// No description provided for @dashboardWarrantyDue.
  ///
  /// In en, this message translates to:
  /// **'Warranty ends <30 days'**
  String get dashboardWarrantyDue;

  /// No description provided for @detectFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{Found 1 database} other{Found {count} databases}}'**
  String detectFoundCount(int count);

  /// No description provided for @detectPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a database'**
  String get detectPickTitle;

  /// No description provided for @detectUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'Most production instances disable database listing. Type the name instead — your Odoo administrator can confirm it.'**
  String get detectUnsupportedBody;

  /// No description provided for @detectUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'This server keeps its database list private'**
  String get detectUnsupportedTitle;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get diagnosticsCopy;

  /// No description provided for @diagnosticsCrashDetail.
  ///
  /// In en, this message translates to:
  /// **'Reports never include your password, API key or name.'**
  String get diagnosticsCrashDetail;

  /// No description provided for @diagnosticsCrashOff.
  ///
  /// In en, this message translates to:
  /// **'Off — nothing leaves this device'**
  String get diagnosticsCrashOff;

  /// No description provided for @diagnosticsCrashOn.
  ///
  /// In en, this message translates to:
  /// **'On — anonymous crash reports are sent'**
  String get diagnosticsCrashOn;

  /// No description provided for @diagnosticsCrashReporting.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting'**
  String get diagnosticsCrashReporting;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No problems recorded'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Technical details appear here when something fails.'**
  String get diagnosticsEmptyBody;

  /// No description provided for @dueChipOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dueChipOverdue;

  /// No description provided for @dueChipSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get dueChipSoon;

  /// How long is left before an asset is expected back.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =0{Due back today} =1{Due back tomorrow} other{Due back in {days} days}}'**
  String dueInDays(int days);

  /// How far past its expected return date an asset is.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{1 day overdue} other{{days} days overdue}}'**
  String dueOverdueBy(int days);

  /// No description provided for @employeeAssetsHeld.
  ///
  /// In en, this message translates to:
  /// **'Assets held'**
  String get employeeAssetsHeld;

  /// No description provided for @employeeAssignedAssets.
  ///
  /// In en, this message translates to:
  /// **'Assigned assets'**
  String get employeeAssignedAssets;

  /// No description provided for @employeeInService.
  ///
  /// In en, this message translates to:
  /// **'In service'**
  String get employeeInService;

  /// No description provided for @employeeItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{No items} =1{1 item} other{{count} items}}'**
  String employeeItemCount(int count);

  /// No description provided for @employeeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, department, email…'**
  String get employeeSearchHint;

  /// No description provided for @employeeSince.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String employeeSince(String date);

  /// No description provided for @employeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employeeTitle;

  /// No description provided for @employeeWarrantyDue.
  ///
  /// In en, this message translates to:
  /// **'Warranty due'**
  String get employeeWarrantyDue;

  /// No description provided for @employeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesTitle;

  /// No description provided for @emptyActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Assignments and returns you record appear here.'**
  String get emptyActivityBody;

  /// No description provided for @emptyAssetsBody.
  ///
  /// In en, this message translates to:
  /// **'Assets you add or import into Odoo will appear here.'**
  String get emptyAssetsBody;

  /// No description provided for @emptyAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'No assets yet'**
  String get emptyAssetsTitle;

  /// No description provided for @emptyEmployeeAssetsBody.
  ///
  /// In en, this message translates to:
  /// **'This employee is not holding any assets.'**
  String get emptyEmployeeAssetsBody;

  /// No description provided for @emptyEmployeeAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing assigned'**
  String get emptyEmployeeAssetsTitle;

  /// No description provided for @emptyEmployeesBody.
  ///
  /// In en, this message translates to:
  /// **'Employees come from the Odoo Employees app.'**
  String get emptyEmployeesBody;

  /// No description provided for @emptyEmployeesTitle.
  ///
  /// In en, this message translates to:
  /// **'No employees'**
  String get emptyEmployeesTitle;

  /// No description provided for @emptyMaintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'Requests you open from an asset appear here.'**
  String get emptyMaintenanceBody;

  /// No description provided for @emptyMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'No maintenance requests'**
  String get emptyMaintenanceTitle;

  /// No description provided for @emptySearchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or clear your filters.'**
  String get emptySearchBody;

  /// No description provided for @emptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get emptySearchTitle;

  /// No description provided for @errorAccessDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Your Odoo user is not allowed to do this.'**
  String get errorAccessDeniedBody;

  /// No description provided for @errorAccessDeniedBodyDetailed.
  ///
  /// In en, this message translates to:
  /// **'Your Odoo user is not allowed to {operation} {model} records.'**
  String errorAccessDeniedBodyDetailed(String operation, String model);

  /// No description provided for @errorAccessDeniedFix.
  ///
  /// In en, this message translates to:
  /// **'Ask your Odoo administrator to grant access. Sijil IT never works around Odoo permissions.'**
  String get errorAccessDeniedFix;

  /// No description provided for @errorAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission'**
  String get errorAccessDeniedTitle;

  /// No description provided for @errorActionEditConnection.
  ///
  /// In en, this message translates to:
  /// **'Edit connection'**
  String get errorActionEditConnection;

  /// No description provided for @errorActionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get errorActionSignIn;

  /// No description provided for @errorBusinessRuleFix.
  ///
  /// In en, this message translates to:
  /// **'This rule comes from your Odoo configuration, not from Sijil IT.'**
  String get errorBusinessRuleFix;

  /// No description provided for @errorBusinessRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Odoo blocked this'**
  String get errorBusinessRuleTitle;

  /// No description provided for @errorCacheBody.
  ///
  /// In en, this message translates to:
  /// **'The offline copy on this device could not be opened.'**
  String get errorCacheBody;

  /// No description provided for @errorCacheFix.
  ///
  /// In en, this message translates to:
  /// **'Clearing the cache from Settings usually fixes this. Nothing in Odoo is affected.'**
  String get errorCacheFix;

  /// No description provided for @errorCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read local data'**
  String get errorCacheTitle;

  /// No description provided for @errorDatabaseUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This server has no database with that name.'**
  String get errorDatabaseUnavailableBody;

  /// No description provided for @errorDatabaseUnavailableFix.
  ///
  /// In en, this message translates to:
  /// **'Database names are case-sensitive. Your Odoo administrator can confirm the exact name.'**
  String get errorDatabaseUnavailableFix;

  /// No description provided for @errorDatabaseUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Database not found'**
  String get errorDatabaseUnavailableTitle;

  /// No description provided for @errorFieldUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This screen asked Odoo for a field your instance does not have. Nothing was changed.'**
  String get errorFieldUnavailableBody;

  /// No description provided for @errorFieldUnavailableBodyDetailed.
  ///
  /// In en, this message translates to:
  /// **'This screen asked Odoo for the field “{field}”, which your instance does not have. Nothing was changed.'**
  String errorFieldUnavailableBodyDetailed(String field);

  /// No description provided for @errorFieldUnavailableFix.
  ///
  /// In en, this message translates to:
  /// **'Retrying will not help — the field has to exist first. Sign out and back in if it was just added; otherwise ask your Odoo administrator.'**
  String get errorFieldUnavailableFix;

  /// No description provided for @errorFieldUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'A field is missing on your Odoo'**
  String get errorFieldUnavailableTitle;

  /// Shown when a picked photo cannot be read back from disk.
  ///
  /// In en, this message translates to:
  /// **'The phone released the file before it finished uploading. This usually happens when the camera app is closed by the system while another app is in the foreground.'**
  String get errorFileUnavailableBody;

  /// Shown when a picked photo cannot be read back from disk.
  ///
  /// In en, this message translates to:
  /// **'Take the photo again and stay in the app until the upload finishes.'**
  String get errorFileUnavailableFix;

  /// Shown when a picked photo cannot be read back from disk.
  ///
  /// In en, this message translates to:
  /// **'Photo could not be read'**
  String get errorFileUnavailableTitle;

  /// No description provided for @errorHowToFix.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get errorHowToFix;

  /// Cause line for a plain-HTTP server URL.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT only connects over HTTPS, so your Odoo password is never sent in the clear. The saved address starts with http://.'**
  String get errorInsecureConnectionBody;

  /// The concrete next step for a plain-HTTP server URL.
  ///
  /// In en, this message translates to:
  /// **'Change the address to https://. If your Odoo has no certificate yet, your administrator can add one — a self-hosted instance on the office network needs it too.'**
  String get errorInsecureConnectionFix;

  /// Shown when the saved server URL uses http:// rather than https://.
  ///
  /// In en, this message translates to:
  /// **'This address is not encrypted'**
  String get errorInsecureConnectionTitle;

  /// No description provided for @errorInvalidCredentialsBody.
  ///
  /// In en, this message translates to:
  /// **'Odoo did not accept this username with this password or API key.'**
  String get errorInvalidCredentialsBody;

  /// No description provided for @errorInvalidCredentialsFix.
  ///
  /// In en, this message translates to:
  /// **'Check the username, and note that an API key is not the same as your password.'**
  String get errorInvalidCredentialsFix;

  /// No description provided for @errorInvalidCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was rejected'**
  String get errorInvalidCredentialsTitle;

  /// No description provided for @errorModelUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This feature needs an Odoo app that is not installed.'**
  String get errorModelUnavailableBody;

  /// No description provided for @errorModelUnavailableBodyDetailed.
  ///
  /// In en, this message translates to:
  /// **'This feature needs the Odoo model {model}, which this instance does not have.'**
  String errorModelUnavailableBodyDetailed(String model);

  /// No description provided for @errorModelUnavailableFix.
  ///
  /// In en, this message translates to:
  /// **'Your Odoo administrator can install the matching app. Everything else in Sijil IT keeps working.'**
  String get errorModelUnavailableFix;

  /// No description provided for @errorModelUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available on your Odoo'**
  String get errorModelUnavailableTitle;

  /// No description provided for @errorNoInternetBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no internet connection right now.'**
  String get errorNoInternetBody;

  /// No description provided for @errorNoInternetFix.
  ///
  /// In en, this message translates to:
  /// **'Turn on Wi-Fi or mobile data, then try again.'**
  String get errorNoInternetFix;

  /// No description provided for @errorNoInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get errorNoInternetTitle;

  /// No description provided for @errorNotAnOdooServerBody.
  ///
  /// In en, this message translates to:
  /// **'The address answered, but not with an Odoo XML-RPC response.'**
  String get errorNotAnOdooServerBody;

  /// No description provided for @errorNotAnOdooServerFix.
  ///
  /// In en, this message translates to:
  /// **'Use the base URL of the instance, without a path — for example https://company.odoo.com'**
  String get errorNotAnOdooServerFix;

  /// No description provided for @errorNotAnOdooServerTitle.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like Odoo'**
  String get errorNotAnOdooServerTitle;

  /// No description provided for @errorRateLimitedBody.
  ///
  /// In en, this message translates to:
  /// **'The Odoo server is limiting how often this app may ask for data. Nothing is wrong with your connection or your account.'**
  String get errorRateLimitedBody;

  /// No description provided for @errorRateLimitedFix.
  ///
  /// In en, this message translates to:
  /// **'Wait a moment and try again. If it keeps happening, ask your Odoo administrator to raise the rate limit for this app.'**
  String get errorRateLimitedFix;

  /// No description provided for @errorRateLimitedFixSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds,plural, =1{Wait 1 second and try again.} other{Wait {seconds} seconds and try again.}}'**
  String errorRateLimitedFixSeconds(int seconds);

  /// No description provided for @errorRateLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many requests'**
  String get errorRateLimitedTitle;

  /// No description provided for @errorRecordNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It was deleted in Odoo, or it is outside what your user can see.'**
  String get errorRecordNotFoundBody;

  /// No description provided for @errorRecordNotFoundFix.
  ///
  /// In en, this message translates to:
  /// **'Go back and refresh the list to see the current records.'**
  String get errorRecordNotFoundFix;

  /// No description provided for @errorRecordNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This record is gone'**
  String get errorRecordNotFoundTitle;

  /// No description provided for @errorRouteNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The link you followed points somewhere Sijil IT has no screen for.'**
  String get errorRouteNotFoundBody;

  /// No description provided for @errorRouteNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'That screen doesn\'t exist'**
  String get errorRouteNotFoundTitle;

  /// No description provided for @errorServerBody.
  ///
  /// In en, this message translates to:
  /// **'The server failed while handling the request.'**
  String get errorServerBody;

  /// No description provided for @errorServerFix.
  ///
  /// In en, this message translates to:
  /// **'Try again. If it persists, send the details from Settings → Diagnostics to your administrator.'**
  String get errorServerFix;

  /// No description provided for @errorServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Odoo reported an error'**
  String get errorServerTitle;

  /// No description provided for @errorServerUnreachableBody.
  ///
  /// In en, this message translates to:
  /// **'The address responded to nothing. The server may be offline, or the URL may be wrong.'**
  String get errorServerUnreachableBody;

  /// No description provided for @errorServerUnreachableFix.
  ///
  /// In en, this message translates to:
  /// **'Check the server URL, and confirm the instance opens in a browser from this network.'**
  String get errorServerUnreachableFix;

  /// No description provided for @errorServerUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach your Odoo server'**
  String get errorServerUnreachableTitle;

  /// No description provided for @errorSessionExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Odoo no longer recognises this session.'**
  String get errorSessionExpiredBody;

  /// No description provided for @errorSessionExpiredFix.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue where you left off.'**
  String get errorSessionExpiredFix;

  /// No description provided for @errorSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Your session ended'**
  String get errorSessionExpiredTitle;

  /// No description provided for @errorTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'Odoo did not answer in time. It may be busy or the connection slow.'**
  String get errorTimeoutBody;

  /// No description provided for @errorTimeoutFix.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment. If it keeps happening, tell your Odoo administrator.'**
  String get errorTimeoutFix;

  /// No description provided for @errorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'The server took too long'**
  String get errorTimeoutTitle;

  /// No description provided for @errorUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT hit a problem it did not expect.'**
  String get errorUnknownBody;

  /// No description provided for @errorUnknownFix.
  ///
  /// In en, this message translates to:
  /// **'Try again. The technical detail is saved under Settings → Diagnostics.'**
  String get errorUnknownFix;

  /// No description provided for @errorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknownTitle;

  /// No description provided for @errorValidationFix.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted field and try again.'**
  String get errorValidationFix;

  /// No description provided for @errorValidationTitle.
  ///
  /// In en, this message translates to:
  /// **'Check what you entered'**
  String get errorValidationTitle;

  /// No description provided for @exportAssetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 asset} other{{count} assets}}'**
  String exportAssetsSubtitle(int count);

  /// No description provided for @exportAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset list'**
  String get exportAssetsTitle;

  /// No description provided for @exportColumnAssignedOn.
  ///
  /// In en, this message translates to:
  /// **'Assigned on'**
  String get exportColumnAssignedOn;

  /// No description provided for @exportColumnCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get exportColumnCategory;

  /// No description provided for @exportColumnDepartment.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get exportColumnDepartment;

  /// No description provided for @exportColumnDueBack.
  ///
  /// In en, this message translates to:
  /// **'Due back'**
  String get exportColumnDueBack;

  /// No description provided for @exportColumnHolder.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get exportColumnHolder;

  /// No description provided for @exportColumnManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get exportColumnManufacturer;

  /// No description provided for @exportColumnModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get exportColumnModel;

  /// No description provided for @exportColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get exportColumnName;

  /// No description provided for @exportColumnSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get exportColumnSerial;

  /// No description provided for @exportColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get exportColumnStatus;

  /// No description provided for @exportColumnTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get exportColumnTag;

  /// No description provided for @exportColumnWarrantyEnd.
  ///
  /// In en, this message translates to:
  /// **'Warranty ends'**
  String get exportColumnWarrantyEnd;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be prepared.'**
  String get exportFailed;

  /// No description provided for @exportGeneratedOn.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String exportGeneratedOn(String date);

  /// No description provided for @exportNothingToShare.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to export yet.'**
  String get exportNothingToShare;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get exportShare;

  /// No description provided for @fieldApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your Odoo API key'**
  String get fieldApiKeyHint;

  /// No description provided for @fieldCredential.
  ///
  /// In en, this message translates to:
  /// **'Credential'**
  String get fieldCredential;

  /// No description provided for @fieldDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get fieldDatabase;

  /// No description provided for @fieldDatabaseHint.
  ///
  /// In en, this message translates to:
  /// **'company-production'**
  String get fieldDatabaseHint;

  /// No description provided for @fieldPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Your Odoo password'**
  String get fieldPasswordHint;

  /// No description provided for @fieldServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get fieldServerUrl;

  /// No description provided for @fieldServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://company.odoo.com'**
  String get fieldServerUrlHint;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @fieldUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'you@company.com'**
  String get fieldUsernameHint;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @filterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get filterClearAll;

  /// No description provided for @filterDepartment.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get filterDepartment;

  /// Filter toggle that adds scrapped assets back into the list.
  ///
  /// In en, this message translates to:
  /// **'Include retired'**
  String get filterIncludeRetired;

  /// No description provided for @filterManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get filterManufacturer;

  /// No description provided for @filterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue only'**
  String get filterOverdue;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get filterWarranty;

  /// No description provided for @filtersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersLabel;

  /// The Filters chip when filters are applied, showing how many. A placeholder rather than interpolation so the count follows the locale's numerals.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String filtersLabelActive(int count);

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter assets'**
  String get filtersTitle;

  /// Dashboard greeting from noon to 18:00. Arabic has one word for both afternoon and evening.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// Dashboard greeting after 18:00.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// Dashboard greeting before noon.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @handoverAddAssets.
  ///
  /// In en, this message translates to:
  /// **'Add assets'**
  String get handoverAddAssets;

  /// No description provided for @handoverAddCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String handoverAddCount(int count);

  /// No description provided for @handoverBundleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet.'**
  String get handoverBundleEmpty;

  /// No description provided for @handoverBundleFull.
  ///
  /// In en, this message translates to:
  /// **'{max} is the most one handover can carry'**
  String handoverBundleFull(int max);

  /// No description provided for @handoverConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm handover'**
  String get handoverConfirm;

  /// No description provided for @handoverDone.
  ///
  /// In en, this message translates to:
  /// **'Handed over to {employee}'**
  String handoverDone(String employee);

  /// No description provided for @handoverNeedsAssets.
  ///
  /// In en, this message translates to:
  /// **'Add at least one asset'**
  String get handoverNeedsAssets;

  /// No description provided for @handoverNeedsRecipient.
  ///
  /// In en, this message translates to:
  /// **'Choose who is receiving'**
  String get handoverNeedsRecipient;

  /// No description provided for @handoverNeedsSignature.
  ///
  /// In en, this message translates to:
  /// **'The recipient has to sign'**
  String get handoverNeedsSignature;

  /// No description provided for @handoverNoAssignableAssets.
  ///
  /// In en, this message translates to:
  /// **'Nothing available to hand over right now.'**
  String get handoverNoAssignableAssets;

  /// No description provided for @handoverNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Onboarding kit, replacement for a failed laptop…'**
  String get handoverNotesHint;

  /// No description provided for @handoverNothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing was recorded'**
  String get handoverNothingRecorded;

  /// No description provided for @handoverNothingRecordedBody.
  ///
  /// In en, this message translates to:
  /// **'Odoo accepted none of the bundle, so no asset changed hands.'**
  String get handoverNothingRecordedBody;

  /// No description provided for @handoverPartial.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} recorded'**
  String handoverPartial(int done, int total);

  /// No description provided for @handoverPickAssets.
  ///
  /// In en, this message translates to:
  /// **'Add to the handover'**
  String get handoverPickAssets;

  /// No description provided for @handoverPickAssetsBody.
  ///
  /// In en, this message translates to:
  /// **'Only assets nobody is holding are shown.'**
  String get handoverPickAssetsBody;

  /// No description provided for @handoverProofSaved.
  ///
  /// In en, this message translates to:
  /// **'The signature is on every asset in Odoo.'**
  String get handoverProofSaved;

  /// No description provided for @handoverRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get handoverRecorded;

  /// No description provided for @handoverRefused.
  ///
  /// In en, this message translates to:
  /// **'Odoo refused these'**
  String get handoverRefused;

  /// No description provided for @handoverRemoveFromBundle.
  ///
  /// In en, this message translates to:
  /// **'Remove {asset}'**
  String handoverRemoveFromBundle(String asset);

  /// No description provided for @handoverRetryRefused.
  ///
  /// In en, this message translates to:
  /// **'Try these again'**
  String get handoverRetryRefused;

  /// No description provided for @handoverSearchAssets.
  ///
  /// In en, this message translates to:
  /// **'Search assets'**
  String get handoverSearchAssets;

  /// No description provided for @handoverSearchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get handoverSearchPeople;

  /// No description provided for @handoverSignHint.
  ///
  /// In en, this message translates to:
  /// **'Sign above'**
  String get handoverSignHint;

  /// No description provided for @handoverSignatureIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Recorded, but the signature did not reach every asset.'**
  String get handoverSignatureIncomplete;

  /// No description provided for @handoverSignatureRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign to confirm receipt'**
  String get handoverSignatureRequired;

  /// No description provided for @handoverStepBundle.
  ///
  /// In en, this message translates to:
  /// **'What they are receiving'**
  String get handoverStepBundle;

  /// No description provided for @handoverStepDate.
  ///
  /// In en, this message translates to:
  /// **'Handover date'**
  String get handoverStepDate;

  /// No description provided for @handoverStepNotes.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get handoverStepNotes;

  /// No description provided for @handoverStepRecipient.
  ///
  /// In en, this message translates to:
  /// **'Who is receiving'**
  String get handoverStepRecipient;

  /// No description provided for @handoverStepSignature.
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s signature'**
  String get handoverStepSignature;

  /// No description provided for @handoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Several assets, one signature'**
  String get handoverSubtitle;

  /// No description provided for @handoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Handover'**
  String get handoverTitle;

  /// Explains what will fill the history screen.
  ///
  /// In en, this message translates to:
  /// **'Assignments, returns and repairs appear here as they happen.'**
  String get historyEmptyBody;

  /// Empty state when an asset has no chatter.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get historyEmptyTitle;

  /// How many distinct people have held this asset.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{No holders yet}=1{1 holder}other{{count} holders}}'**
  String historyHolders(int count);

  /// Button at the end of an asset's timeline when Odoo holds entries older than the ones read so far.
  ///
  /// In en, this message translates to:
  /// **'Show older'**
  String get historyLoadOlder;

  /// The final timeline entry: when the asset was created.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get historyRegistered;

  /// Summary line under the timeline.
  ///
  /// In en, this message translates to:
  /// **'In service since {date}'**
  String historySince(String date);

  /// Title of the asset history screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @labelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labelAll;

  /// No description provided for @labelAssetName.
  ///
  /// In en, this message translates to:
  /// **'Asset name'**
  String get labelAssetName;

  /// No description provided for @labelAssetTag.
  ///
  /// In en, this message translates to:
  /// **'Asset tag'**
  String get labelAssetTag;

  /// No description provided for @labelAssignedOn.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get labelAssignedOn;

  /// No description provided for @labelCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get labelCategory;

  /// No description provided for @labelDueBack.
  ///
  /// In en, this message translates to:
  /// **'Due back'**
  String get labelDueBack;

  /// No description provided for @labelHeldDays.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{1 day} other{{days} days}}'**
  String labelHeldDays(int days);

  /// No description provided for @labelManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get labelManufacturer;

  /// No description provided for @labelModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get labelModel;

  /// No description provided for @labelNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get labelNone;

  /// No description provided for @labelNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get labelNotes;

  /// No description provided for @labelOdooVersion.
  ///
  /// In en, this message translates to:
  /// **'Odoo version'**
  String get labelOdooVersion;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get labelOptional;

  /// No description provided for @labelPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get labelPurchaseDate;

  /// No description provided for @labelPurchaseValue.
  ///
  /// In en, this message translates to:
  /// **'Purchase value'**
  String get labelPurchaseValue;

  /// No description provided for @labelSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get labelSerialNumber;

  /// No description provided for @labelServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get labelServer;

  /// Subtitle printed on the label sheet.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 label} other{{count} labels}}'**
  String labelSheetSubtitle(int count);

  /// No description provided for @labelSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset labels'**
  String get labelSheetTitle;

  /// No description provided for @labelSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get labelSignedInAs;

  /// No description provided for @labelUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get labelUnassigned;

  /// No description provided for @labelUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get labelUnknown;

  /// No description provided for @labelVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get labelVendor;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Shown when the Email button cannot open a mail client — a tablet or kiosk with none installed.
  ///
  /// In en, this message translates to:
  /// **'No email app is set up on this device.'**
  String get launchNoMailApp;

  /// Shown when the Call button cannot open a dialler — a Wi-Fi tablet, or an emulator.
  ///
  /// In en, this message translates to:
  /// **'This device cannot place calls.'**
  String get launchNoPhoneApp;

  /// No description provided for @lifecycleAge.
  ///
  /// In en, this message translates to:
  /// **'{months,plural, =0{In service less than a month} =1{In service 1 month} other{In service {months} months}}'**
  String lifecycleAge(int months);

  /// No description provided for @lifecycleAgeing.
  ///
  /// In en, this message translates to:
  /// **'Due for replacement'**
  String get lifecycleAgeing;

  /// No description provided for @lifecycleCostPerYear.
  ///
  /// In en, this message translates to:
  /// **'Cost per year so far'**
  String get lifecycleCostPerYear;

  /// No description provided for @lifecycleOverdue.
  ///
  /// In en, this message translates to:
  /// **'Past its expected life'**
  String get lifecycleOverdue;

  /// No description provided for @lifecycleOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'{months,plural, =1{1 month past its expected life} other{{months} months past its expected life}}'**
  String lifecycleOverdueBy(int months);

  /// No description provided for @lifecycleRemaining.
  ///
  /// In en, this message translates to:
  /// **'{months,plural, =1{1 month left of its expected life} other{{months} months left of its expected life}}'**
  String lifecycleRemaining(int months);

  /// No description provided for @lifecycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Service life'**
  String get lifecycleTitle;

  /// No description provided for @lifecycleUnknown.
  ///
  /// In en, this message translates to:
  /// **'No purchase date recorded'**
  String get lifecycleUnknown;

  /// No description provided for @lifecycleUnknownHint.
  ///
  /// In en, this message translates to:
  /// **'Add a purchase date to see how much life this asset has left and what it has cost per year.'**
  String get lifecycleUnknownHint;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLabel;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone holding an unlocked phone could reassign company equipment. Unlock to carry on.'**
  String get lockBody;

  /// No description provided for @lockFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not unlock. Try again.'**
  String get lockFailed;

  /// No description provided for @lockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Sijil IT'**
  String get lockReason;

  /// No description provided for @lockSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for this device’s fingerprint, face or passcode before Sijil IT opens.'**
  String get lockSettingsSubtitle;

  /// No description provided for @lockSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Require unlock'**
  String get lockSettingsTitle;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT is locked'**
  String get lockTitle;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has no screen lock set up, so there is nothing to ask for.'**
  String get lockUnavailable;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @loginAclNotice.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT works inside your Odoo permissions. You will only see and change what your Odoo user is allowed to.'**
  String get loginAclNotice;

  /// No description provided for @loginBackToServer.
  ///
  /// In en, this message translates to:
  /// **'Back to server settings'**
  String get loginBackToServer;

  /// No description provided for @loginKeepSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get loginKeepSignedIn;

  /// No description provided for @loginNeedApiKey.
  ///
  /// In en, this message translates to:
  /// **'Need an API key?'**
  String get loginNeedApiKey;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Odoo credentials.'**
  String get loginSubtitle;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @maintenanceClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed {date}'**
  String maintenanceClosed(String date);

  /// No description provided for @maintenanceDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get maintenanceDuration;

  /// No description provided for @maintenanceHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String maintenanceHours(String hours);

  /// No description provided for @maintenanceNewRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get maintenanceNewRequest;

  /// No description provided for @maintenanceNextScheduled.
  ///
  /// In en, this message translates to:
  /// **'Next preventive check'**
  String get maintenanceNextScheduled;

  /// No description provided for @maintenanceOnlyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open only'**
  String get maintenanceOnlyOpen;

  /// No description provided for @maintenanceOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get maintenanceOverdue;

  /// No description provided for @maintenancePriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get maintenancePriorityHigh;

  /// No description provided for @maintenancePriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get maintenancePriorityLow;

  /// No description provided for @maintenancePriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get maintenancePriorityNormal;

  /// No description provided for @maintenancePriorityVeryLow.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get maintenancePriorityVeryLow;

  /// No description provided for @maintenanceRequestCreated.
  ///
  /// In en, this message translates to:
  /// **'Request opened for {asset}'**
  String maintenanceRequestCreated(String asset);

  /// No description provided for @maintenanceRequestHint.
  ///
  /// In en, this message translates to:
  /// **'What needs fixing?'**
  String get maintenanceRequestHint;

  /// No description provided for @maintenanceRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance request'**
  String get maintenanceRequestTitle;

  /// No description provided for @maintenanceRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get maintenanceRequestedOn;

  /// No description provided for @maintenanceScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get maintenanceScheduled;

  /// No description provided for @maintenanceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Request or asset…'**
  String get maintenanceSearchHint;

  /// No description provided for @maintenanceStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get maintenanceStage;

  /// No description provided for @maintenanceTechnician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get maintenanceTechnician;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceTypeCorrective.
  ///
  /// In en, this message translates to:
  /// **'Corrective'**
  String get maintenanceTypeCorrective;

  /// Label for a maintenance request's corrective/preventive type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get maintenanceTypeField;

  /// No description provided for @maintenanceTypePreventive.
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get maintenanceTypePreventive;

  /// No description provided for @moreAuditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Count what is really there'**
  String get moreAuditSubtitle;

  /// No description provided for @moreHandoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hand several assets to one person'**
  String get moreHandoverSubtitle;

  /// No description provided for @moreMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests and history for your assets'**
  String get moreMaintenanceSubtitle;

  /// No description provided for @moreSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connection, account, appearance and cache'**
  String get moreSettingsSubtitle;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @moreToolsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get moreToolsLabel;

  /// No description provided for @navAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get navAssets;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get navEmployees;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @operationCreate.
  ///
  /// In en, this message translates to:
  /// **'create'**
  String get operationCreate;

  /// No description provided for @operationDelete.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get operationDelete;

  /// No description provided for @operationRead.
  ///
  /// In en, this message translates to:
  /// **'view'**
  String get operationRead;

  /// No description provided for @operationWrite.
  ///
  /// In en, this message translates to:
  /// **'change'**
  String get operationWrite;

  /// Subtitle of the overdue-returns screen.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 asset is late} other{{count} assets are late}}'**
  String overdueCount(int count);

  /// No description provided for @overdueEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every asset with a return date is still within it. Set a date when you hand something over and it will be watched here.'**
  String get overdueEmptyBody;

  /// No description provided for @overdueEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is late'**
  String get overdueEmptyTitle;

  /// No description provided for @overdueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assets past the date they were promised back'**
  String get overdueSubtitle;

  /// No description provided for @overdueTitle.
  ///
  /// In en, this message translates to:
  /// **'Overdue returns'**
  String get overdueTitle;

  /// No description provided for @photoCount.
  ///
  /// In en, this message translates to:
  /// **'{used} of {max}'**
  String photoCount(int used, int max);

  /// Label on the empty tile that opens the photo picker.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get photosAdd;

  /// Success snackbar.
  ///
  /// In en, this message translates to:
  /// **'Photo saved'**
  String get photosAdded;

  /// Button that opens the device camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get photosCamera;

  /// Empty state of the photo section.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get photosEmpty;

  /// Explains what the photos are for on a maintenance request.
  ///
  /// In en, this message translates to:
  /// **'Photograph the fault before you start, and the repair when you finish.'**
  String get photosEmptyHint;

  /// Button that opens the device photo gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get photosGallery;

  /// Counter in the full-screen photo viewer.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String photosPosition(int current, int total);

  /// Destructive confirm button.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get photosRemoveAction;

  /// Confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'It will be deleted from Odoo for everyone.'**
  String get photosRemoveBody;

  /// Confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove this photo?'**
  String get photosRemoveTitle;

  /// Success snackbar.
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get photosRemoved;

  /// Reassures the user the photo left the phone.
  ///
  /// In en, this message translates to:
  /// **'Saved to Odoo'**
  String get photosSavedToOdoo;

  /// Header of the photo section on a record.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosTitle;

  /// No description provided for @qrHint.
  ///
  /// In en, this message translates to:
  /// **'Print this and stick it on the device. It carries only the asset id.'**
  String get qrHint;

  /// No description provided for @qrTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset QR code'**
  String get qrTitle;

  /// No description provided for @receiptAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get receiptAssets;

  /// No description provided for @receiptDate.
  ///
  /// In en, this message translates to:
  /// **'Handed over on'**
  String get receiptDate;

  /// No description provided for @receiptNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get receiptNotes;

  /// No description provided for @receiptRecipient.
  ///
  /// In en, this message translates to:
  /// **'Received by'**
  String get receiptRecipient;

  /// No description provided for @receiptShare.
  ///
  /// In en, this message translates to:
  /// **'Share receipt'**
  String get receiptShare;

  /// No description provided for @receiptSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get receiptSignature;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Handover receipt'**
  String get receiptTitle;

  /// No description provided for @reminderMaintenanceDue.
  ///
  /// In en, this message translates to:
  /// **'{request} is scheduled for today.'**
  String reminderMaintenanceDue(String request);

  /// No description provided for @reminderMaintenanceOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{{request} is 1 day overdue.} other{{request} is {days} days overdue.}}'**
  String reminderMaintenanceOverdue(String request, int days);

  /// No description provided for @reminderMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance due'**
  String get reminderMaintenanceTitle;

  /// No description provided for @reminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{asset} — {days, plural, =1{1 day left} other{{days} days left}}'**
  String reminderNotificationBody(String asset, int days);

  /// No description provided for @reminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'A warranty is running out'**
  String get reminderNotificationTitle;

  /// No description provided for @remindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off for Sijil IT in your device settings.'**
  String get remindersDenied;

  /// No description provided for @remindersLeadDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day before} other{{days} days before}}'**
  String remindersLeadDays(int days);

  /// No description provided for @remindersLeadLabel.
  ///
  /// In en, this message translates to:
  /// **'Warn me'**
  String get remindersLeadLabel;

  /// No description provided for @remindersScheduled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing scheduled} =1{1 reminder scheduled} other{{count} reminders scheduled}}'**
  String remindersScheduled(int count);

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be told before a warranty runs out'**
  String get remindersSubtitle;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Warranty reminders'**
  String get remindersTitle;

  /// No description provided for @returnCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition on return'**
  String get returnCondition;

  /// No description provided for @returnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm return'**
  String get returnConfirm;

  /// No description provided for @returnDate.
  ///
  /// In en, this message translates to:
  /// **'Return date'**
  String get returnDate;

  /// No description provided for @returnHeldFor.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{held 1 day} other{held {days} days}}'**
  String returnHeldFor(int days);

  /// No description provided for @returnNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Any damage or missing accessories…'**
  String get returnNotesHint;

  /// No description provided for @returnOutcome.
  ///
  /// In en, this message translates to:
  /// **'Returns to {status} and the note is posted to Odoo.'**
  String returnOutcome(String status);

  /// No description provided for @returnPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get returnPhotos;

  /// No description provided for @returnSuccess.
  ///
  /// In en, this message translates to:
  /// **'{asset} returned'**
  String returnSuccess(String asset);

  /// No description provided for @returnTitle.
  ///
  /// In en, this message translates to:
  /// **'Return asset'**
  String get returnTitle;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// Cause line for a camera that failed to start.
  ///
  /// In en, this message translates to:
  /// **'Another app may be using the camera, or this device did not hand it over.'**
  String get scanCameraErrorBody;

  /// The concrete next step for a camera that failed to start.
  ///
  /// In en, this message translates to:
  /// **'Close any other app using the camera, then reopen this screen. Restarting the device clears it if that does not.'**
  String get scanCameraErrorFix;

  /// Shown when the camera fails for a reason other than a denied permission — another app holding it, or hardware the OS would not hand over.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start'**
  String get scanCameraErrorTitle;

  /// No description provided for @scanCreateAsset.
  ///
  /// In en, this message translates to:
  /// **'Create asset'**
  String get scanCreateAsset;

  /// No description provided for @scanEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Type a code'**
  String get scanEnterCode;

  /// No description provided for @scanEnterCodeBody.
  ///
  /// In en, this message translates to:
  /// **'For a label the camera cannot read — scratched, in the dark, or behind a desk.'**
  String get scanEnterCodeBody;

  /// No description provided for @scanEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Serial number or asset tag'**
  String get scanEnterCodeHint;

  /// No description provided for @scanEnterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Type the asset code'**
  String get scanEnterCodeTitle;

  /// No description provided for @scanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Point at an asset code'**
  String get scanInstruction;

  /// No description provided for @scanInstructionDetail.
  ///
  /// In en, this message translates to:
  /// **'QR codes, equipment barcodes and printed serial numbers all work.'**
  String get scanInstructionDetail;

  /// No description provided for @scanMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched {payload}'**
  String scanMatched(String payload);

  /// No description provided for @scanModeBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get scanModeBarcode;

  /// No description provided for @scanModeQr.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get scanModeQr;

  /// No description provided for @scanNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing in Odoo matches {code}.'**
  String scanNoMatchBody(String code);

  /// No description provided for @scanNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No asset for that code'**
  String get scanNoMatchTitle;

  /// No description provided for @scanPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT needs the camera to read asset codes.'**
  String get scanPermissionBody;

  /// No description provided for @scanPermissionFix.
  ///
  /// In en, this message translates to:
  /// **'Turn on camera access for Sijil IT in your device settings.'**
  String get scanPermissionFix;

  /// No description provided for @scanPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get scanPermissionTitle;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan asset'**
  String get scanTitle;

  /// No description provided for @scanTorch.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get scanTorch;

  /// No description provided for @sectionActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get sectionActivity;

  /// No description provided for @sectionDeviceInformation.
  ///
  /// In en, this message translates to:
  /// **'Device information'**
  String get sectionDeviceInformation;

  /// No description provided for @sectionMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get sectionMaintenance;

  /// No description provided for @sectionOwnership.
  ///
  /// In en, this message translates to:
  /// **'Ownership'**
  String get sectionOwnership;

  /// No description provided for @sectionPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase & vendor'**
  String get sectionPurchase;

  /// No description provided for @sectionWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get sectionWarranty;

  /// No description provided for @selectionAll.
  ///
  /// In en, this message translates to:
  /// **'Select all loaded'**
  String get selectionAll;

  /// No description provided for @selectionCancel.
  ///
  /// In en, this message translates to:
  /// **'Leave selection'**
  String get selectionCancel;

  /// Title of the assets screen while selecting.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{Nothing selected} =1{1 selected} other{{count} selected}}'**
  String selectionCount(int count);

  /// Shown when a selection hits its ceiling.
  ///
  /// In en, this message translates to:
  /// **'You can act on {count} assets at a time.'**
  String selectionLimitReached(int count);

  /// No description provided for @selectionNone.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get selectionNone;

  /// No description provided for @selectionStart.
  ///
  /// In en, this message translates to:
  /// **'Select assets'**
  String get selectionStart;

  /// No description provided for @sessionExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Signs out on {date} unless the app is opened.'**
  String sessionExpiresOn(String date);

  /// No description provided for @sessionExplain.
  ///
  /// In en, this message translates to:
  /// **'The window counts from the last time you opened the app, so daily use never signs you out. A device left unused is signed out and the saved credential is deleted.'**
  String get sessionExplain;

  /// No description provided for @sessionMaxAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =0{No limit} =1{1 day} other{{days} days}}'**
  String sessionMaxAgeDays(int days);

  /// No description provided for @sessionNeverExpiresNote.
  ///
  /// In en, this message translates to:
  /// **'The saved sign-in never expires on this device.'**
  String get sessionNeverExpiresNote;

  /// No description provided for @sessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long this device may reuse your Odoo sign-in without you typing it again.'**
  String get sessionSubtitle;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved sign-in'**
  String get sessionTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsCacheKeepStates.
  ///
  /// In en, this message translates to:
  /// **'Keep local asset states'**
  String get settingsCacheKeepStates;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheBody.
  ///
  /// In en, this message translates to:
  /// **'Odoo keeps everything. Only the offline copy on this device is removed.'**
  String get settingsClearCacheBody;

  /// No description provided for @settingsClearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear cached data?'**
  String get settingsClearCacheConfirm;

  /// No description provided for @settingsClearCacheDone.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsClearCacheDone;

  /// No description provided for @settingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsConnected;

  /// No description provided for @settingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Odoo connection'**
  String get settingsConnection;

  /// No description provided for @settingsDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected on your Odoo'**
  String get settingsDetected;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsDetail.
  ///
  /// In en, this message translates to:
  /// **'Technical log, credentials redacted'**
  String get settingsDiagnosticsDetail;

  /// No description provided for @settingsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsDisconnected;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked {time}'**
  String settingsLastChecked(String time);

  /// No description provided for @settingsMetadataRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Odoo metadata refreshed'**
  String get settingsMetadataRefreshed;

  /// No description provided for @settingsNeverChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get settingsNeverChecked;

  /// No description provided for @settingsRefreshMetadata.
  ///
  /// In en, this message translates to:
  /// **'Refresh Odoo metadata'**
  String get settingsRefreshMetadata;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your stored credential is removed from this device.'**
  String get settingsSignOutBody;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Sijil IT?'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Sijil IT {version} (build {build})'**
  String settingsVersion(String version, String build);

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @sortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get sortNameAsc;

  /// No description provided for @sortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get sortNameDesc;

  /// No description provided for @sortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get sortRecent;

  /// No description provided for @splashRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring your session…'**
  String get splashRestoring;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get statusAssigned;

  /// No description provided for @statusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get statusAvailable;

  /// No description provided for @statusDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get statusDamaged;

  /// No description provided for @statusKeptInLog.
  ///
  /// In en, this message translates to:
  /// **'Recorded in the log'**
  String get statusKeptInLog;

  /// No description provided for @statusLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get statusLost;

  /// No description provided for @statusMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get statusMaintenance;

  /// No description provided for @statusReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get statusReserved;

  /// No description provided for @statusRetired.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get statusRetired;

  /// No description provided for @syncAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt} other{{count} attempts}}'**
  String syncAttempts(int count);

  /// No description provided for @syncBlocked.
  ///
  /// In en, this message translates to:
  /// **'Odoo refused this. It will not be retried.'**
  String get syncBlocked;

  /// No description provided for @syncDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard queue'**
  String get syncDiscard;

  /// No description provided for @syncDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'These were never sent to Odoo. Discarding them cannot be undone.'**
  String get syncDiscardBody;

  /// No description provided for @syncDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard the waiting changes?'**
  String get syncDiscardConfirm;

  /// No description provided for @syncDiscardFailedAll.
  ///
  /// In en, this message translates to:
  /// **'Discard all'**
  String get syncDiscardFailedAll;

  /// No description provided for @syncDiscardFailedAllBody.
  ///
  /// In en, this message translates to:
  /// **'These changes will be forgotten. Odoo never received them, so they cannot be recovered. Anything still waiting to send is left alone.'**
  String get syncDiscardFailedAllBody;

  /// No description provided for @syncDiscardFailedAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard everything that failed?'**
  String get syncDiscardFailedAllConfirm;

  /// No description provided for @syncDiscardOne.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get syncDiscardOne;

  /// No description provided for @syncDiscardOneBody.
  ///
  /// In en, this message translates to:
  /// **'{subject} will be forgotten. Odoo never received it, so it cannot be recovered.'**
  String syncDiscardOneBody(String subject);

  /// No description provided for @syncDiscardOneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard this change?'**
  String get syncDiscardOneConfirm;

  /// No description provided for @syncFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 change could not be sent — tap to review} other{{count} changes could not be sent — tap to review}}'**
  String syncFailedBanner(int count);

  /// No description provided for @syncFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Odoo refused these. They are still saved here, so nothing you did is lost — but they will not send on their own.'**
  String get syncFailedBody;

  /// No description provided for @syncFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 change could not be sent} other{{count} changes could not be sent}}'**
  String syncFailedCount(int count);

  /// No description provided for @syncFailedReason.
  ///
  /// In en, this message translates to:
  /// **'Odoo said: {reason}'**
  String syncFailedReason(String reason);

  /// No description provided for @syncFailedSection.
  ///
  /// In en, this message translates to:
  /// **'Could not be sent'**
  String get syncFailedSection;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get syncNow;

  /// No description provided for @syncOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOfflineBanner;

  /// No description provided for @syncPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to send} other{{count} changes waiting to send}}'**
  String syncPendingBanner(int count);

  /// No description provided for @syncPendingChip.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet'**
  String get syncPendingChip;

  /// No description provided for @syncQueueEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Changes you make without a connection wait here until there is one.'**
  String get syncQueueEmptyBody;

  /// No description provided for @syncQueueEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything is on Odoo'**
  String get syncQueueEmptyTitle;

  /// No description provided for @syncQueuedAssign.
  ///
  /// In en, this message translates to:
  /// **'Hand over to {employee}'**
  String syncQueuedAssign(String employee);

  /// No description provided for @syncQueuedNotice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will go to Odoo when there is a connection.'**
  String get syncQueuedNotice;

  /// No description provided for @syncQueuedReturn.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get syncQueuedReturn;

  /// No description provided for @syncQueuedStatus.
  ///
  /// In en, this message translates to:
  /// **'Mark as {status}'**
  String syncQueuedStatus(String status);

  /// No description provided for @syncRetryOne.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get syncRetryOne;

  /// No description provided for @syncSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get syncSending;

  /// No description provided for @syncSentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change sent} other{{count} changes sent}}'**
  String syncSentCount(int count);

  /// No description provided for @syncStaleBanner.
  ///
  /// In en, this message translates to:
  /// **'Showing the copy from {time}'**
  String syncStaleBanner(String time);

  /// No description provided for @syncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes waiting for a connection'**
  String get syncSubtitle;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeMinutesAgo(int count);

  /// Relative time for the previous calendar day.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @tooltipToggleLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get tooltipToggleLanguage;

  /// No description provided for @tooltipToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch appearance'**
  String get tooltipToggleTheme;

  /// No description provided for @validationEnterAssetName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this asset.'**
  String get validationEnterAssetName;

  /// No description provided for @validationEnterCredential.
  ///
  /// In en, this message translates to:
  /// **'Enter your password or API key.'**
  String get validationEnterCredential;

  /// No description provided for @validationEnterDatabase.
  ///
  /// In en, this message translates to:
  /// **'Enter your Odoo database name.'**
  String get validationEnterDatabase;

  /// No description provided for @validationEnterServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter your Odoo server URL.'**
  String get validationEnterServerUrl;

  /// No description provided for @validationEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter your Odoo username.'**
  String get validationEnterUsername;

  /// No description provided for @validationHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'The server URL must start with https://'**
  String get validationHttpsRequired;

  /// No description provided for @validationInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid server address.'**
  String get validationInvalidUrl;

  /// No description provided for @voiceHeardNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing was heard. Try again, closer to the phone.'**
  String get voiceHeardNothing;

  /// No description provided for @voiceSearchStart.
  ///
  /// In en, this message translates to:
  /// **'Search by voice'**
  String get voiceSearchStart;

  /// No description provided for @voiceSearchStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get voiceSearchStop;

  /// No description provided for @warrantyEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String warrantyEnds(String date);

  /// No description provided for @warrantyExpiredAgo.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{Expired 1 day ago} other{Expired {days} days ago}}'**
  String warrantyExpiredAgo(int days);

  /// No description provided for @warrantyExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{Expires in 1 day} other{Expires in {days} days}}'**
  String warrantyExpiresIn(int days);

  /// No description provided for @warrantyFilterCritical.
  ///
  /// In en, this message translates to:
  /// **'Ends within 30 days'**
  String get warrantyFilterCritical;

  /// No description provided for @warrantyFilterExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get warrantyFilterExpired;

  /// No description provided for @warrantyFilterSoon.
  ///
  /// In en, this message translates to:
  /// **'Ends within 90 days'**
  String get warrantyFilterSoon;

  /// No description provided for @warrantyFilterValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get warrantyFilterValid;

  /// No description provided for @warrantyStarted.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String warrantyStarted(String date);

  /// No description provided for @warrantyUnknown.
  ///
  /// In en, this message translates to:
  /// **'No warranty date'**
  String get warrantyUnknown;

  /// No description provided for @warrantyValid.
  ///
  /// In en, this message translates to:
  /// **'Warranty valid'**
  String get warrantyValid;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
