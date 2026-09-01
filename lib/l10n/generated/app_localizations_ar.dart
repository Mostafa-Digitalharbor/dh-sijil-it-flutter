// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppL10nAr extends AppL10n {
  AppL10nAr([String locale = 'ar']) : super(locale);

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionApply => 'تطبيق';

  @override
  String get actionAssign => 'تسليم';

  @override
  String get actionCall => 'اتصال';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionChange => 'تغيير';

  @override
  String get actionClear => 'مسح';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionDetectDatabases => 'اكتشاف قواعد البيانات';

  @override
  String get actionDone => 'تم';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionEmail => 'بريد';

  @override
  String get actionGoToDashboard => 'الذهاب إلى لوحة المعلومات';

  @override
  String get actionMaintain => 'صيانة';

  @override
  String get actionOpen => 'فتح';

  @override
  String get actionOpenSettings => 'فتح الإعدادات';

  @override
  String get actionRefresh => 'تحديث';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionReturn => 'استرجاع';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionSeeAll => 'عرض الكل';

  @override
  String get actionSignIn => 'تسجيل الدخول';

  @override
  String get actionSigningIn => 'جارٍ تسجيل الدخول…';

  @override
  String get actionTestConnection => 'اختبار الاتصال';

  @override
  String get actionToday => 'اليوم';

  @override
  String get appName => 'سِجل IT';

  @override
  String get appTagline => 'إدارة أصول تقنية المعلومات';

  @override
  String get assetActionHistory => 'سجل الحركة';

  @override
  String get assetActionsTitle => 'إجراءات الأصل';

  @override
  String get assetDeleteBody =>
      'سيُحذف من أودو للجميع. لا يمكن التراجع عن هذا.';

  @override
  String get assetDeleteConfirm => 'حذف هذا الأصل؟';

  @override
  String assetDeleted(String asset) {
    return 'تم حذف $asset';
  }

  @override
  String get assetDetailTitle => 'تفاصيل الأصل';

  @override
  String get assetEditTitle => 'تعديل أصل';

  @override
  String get assetLocalStateNote =>
      'أودو القياسي ما فيهوش حقل للحالة دي، فبتتسجّل في سجل الأصل — والكل يشوفها.';

  @override
  String get assetMarkAvailable => 'تحديد كمتاح';

  @override
  String get assetMarkDamaged => 'تحديد كتالف';

  @override
  String get assetMarkLost => 'تحديد كمفقود';

  @override
  String get assetMarkReserved => 'تحديد كمحجوز';

  @override
  String get assetNewTitle => 'أصل جديد';

  @override
  String assetSaved(String asset) {
    return 'تم حفظ $asset';
  }

  @override
  String get assetShowQr => 'عرض رمز QR';

  @override
  String get assetsSearchHint => 'الاسم أو الرمز أو الرقم التسلسلي…';

  @override
  String assetsShowingOf(int shown, int total) {
    final intl.NumberFormat shownNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String shownString = shownNumberFormat.format(shown);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'عرض $shownString من $totalString';
  }

  @override
  String get assetsTitle => 'الأصول';

  @override
  String get assignAllDepartments => 'كل الأقسام';

  @override
  String get assignConfirm => 'تأكيد التسليم';

  @override
  String get assignDueClear => 'شيل التاريخ';

  @override
  String get assignDueHint => 'سيبه فاضي إلا لو الأصل إعارة لازم ترجع.';

  @override
  String get assignDueNotSet => 'بدون تاريخ إرجاع';

  @override
  String get assignNotesHint => 'سُلِّم مع الشاحن وموزّع USB-C…';

  @override
  String get assignSearchHint => 'ابحث عن موظف…';

  @override
  String get assignStepDate => 'تاريخ التسليم';

  @override
  String get assignStepDue => 'تاريخ الإرجاع المتوقع';

  @override
  String get assignStepEmployee => 'اختر الموظف';

  @override
  String get assignStepNotes => 'ملاحظات';

  @override
  String assignSuccess(String asset, String employee) {
    return 'تم تسليم $asset إلى $employee';
  }

  @override
  String get assignTitle => 'تسليم أصل';

  @override
  String get auditBegin => 'ابدأ الجرد';

  @override
  String get auditCounting => 'جاري الجرد';

  @override
  String get auditDiscardBody =>
      'ما جرى مسحه حتى الآن محفوظ على هذا الهاتف فقط، وسيضيع إن خرجت.';

  @override
  String get auditDiscardConfirm => 'اخرج';

  @override
  String get auditDiscardTitle => 'تسيب الجرد؟';

  @override
  String get auditFinish => 'إنهاء الجرد';

  @override
  String get auditFound => 'موجود';

  @override
  String get auditJustScanned => 'آخر ما تم مسحه';

  @override
  String get auditKeepScanning => 'واصل المسح — لا داعي للتوقف';

  @override
  String get auditMissing => 'غير موجود';

  @override
  String get auditNothingMissing => 'كل الأصول في النطاق اتلقت.';

  @override
  String auditOf(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString من $totalString';
  }

  @override
  String get auditOutOfScope => 'موجود هنا، ومسجّل في مكان تاني';

  @override
  String get auditPickCategory => 'اختر الفئة';

  @override
  String get auditPickDepartment => 'اختر القسم';

  @override
  String get auditReportExpected => 'المتوقع';

  @override
  String get auditReportFound => 'تم عدّه';

  @override
  String get auditReportMissing => 'لم يُعثر عليه';

  @override
  String get auditReportScope => 'النطاق';

  @override
  String get auditReportShare => 'مشاركة التقرير';

  @override
  String get auditReportTitle => 'جرد المخزون';

  @override
  String get auditReportUnexpected => 'عُثر عليه خارج النطاق';

  @override
  String get auditResume => 'واصل الجرد';

  @override
  String get auditSaveToOdoo => 'حفظ النتيجة في أودو';

  @override
  String get auditSaved => 'اتحفظت النتيجة في أودو';

  @override
  String get auditSavedNone => 'مفيش نتايج تتسجل.';

  @override
  String get auditScopeAll => 'كل الأصول';

  @override
  String get auditScopeCategory => 'فئة واحدة';

  @override
  String get auditScopeDepartment => 'قسم واحد';

  @override
  String get auditStartBody =>
      'النطاق المحدود يكتمل. أما جرد كل شيء دفعة واحدة فلا يكتمل.';

  @override
  String get auditStartTitle => 'بتجرد إيه؟';

  @override
  String get auditTitle => 'الجرد';

  @override
  String get auditUnexpected => 'خارج النطاق';

  @override
  String get auditUnknownCode => 'هذا الرمز لا يطابق أي أصل';

  @override
  String get auditWhereExpected => 'في مكانه المتوقع';

  @override
  String get authModeApiKey => 'مفتاح API';

  @override
  String get authModePassword => 'كلمة المرور';

  @override
  String get bulkMoveDepartment => 'نقل إلى قسم';

  @override
  String bulkMoveDone(int count, String department) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم نقل $countString أصلًا إلى $department',
      few: 'تم نقل $countString أصول إلى $department',
      two: 'تم نقل أصلين إلى $department',
      one: 'تم نقل أصل واحد إلى $department',
    );
    return '$_temp0';
  }

  @override
  String get bulkMoveNoDepartments => 'أودو ده مفيهوش أقسام تنقل ليها الأصول.';

  @override
  String get bulkMoveTitle => 'أي قسم؟';

  @override
  String get bulkPrintLabels => 'ورقة ملصقات';

  @override
  String get capabilityActivityLog => 'سجل النشاط';

  @override
  String get capabilityEmployees => 'الموظفون';

  @override
  String get capabilityInventory => 'المخزون';

  @override
  String get capabilityMaintenance => 'الصيانة';

  @override
  String get conditionDamaged => 'تالف';

  @override
  String get conditionDamagedEffect => 'يُعلَّم كتالف';

  @override
  String get conditionGood => 'سليم';

  @override
  String get conditionGoodEffect => 'يعود إلى متاح';

  @override
  String get conditionMinorDamage => 'تلف بسيط';

  @override
  String get conditionNeedsMaintenance => 'يحتاج صيانة';

  @override
  String get conditionNeedsMaintenanceEffect => 'يفتح طلب صيانة';

  @override
  String get connectSubtitle =>
      'وجّه سِجل IT إلى نسخة أودو لديك. لا يُثبَّت أي شيء على الخادم — لا إضافة ولا وسيط.';

  @override
  String get connectTitle => 'الاتصال بأودو';

  @override
  String connectionReachable(String version) {
    return 'متصل — أودو $version';
  }

  @override
  String get connectionTesting => 'جارٍ فحص الخادم…';

  @override
  String get credentialStorageNote =>
      'محفوظة في مخزن مفاتيح جهازك، لا كنص صريح';

  @override
  String get dashboardAssetsUnit => 'أصل';

  @override
  String get dashboardByCategory => 'الأصول حسب الفئة';

  @override
  String dashboardInService(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString في الخدمة';
  }

  @override
  String get dashboardOpenMaintenance => 'صيانة مفتوحة';

  @override
  String get dashboardRareStatuses => 'محجوز · تالف · مفقود';

  @override
  String get dashboardRecentActivity => 'النشاط الأخير';

  @override
  String get dashboardTitle => 'الرئيسية';

  @override
  String get dashboardTrendTitle => 'في الخدمة خلال 12 شهر';

  @override
  String get dashboardWarrantyDue => 'ضمان ينتهي خلال 30 يومًا';

  @override
  String detectFoundCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $countString قاعدة بيانات',
      few: 'تم العثور على $countString قواعد بيانات',
      two: 'تم العثور على قاعدتي بيانات',
      one: 'تم العثور على قاعدة بيانات واحدة',
    );
    return '$_temp0';
  }

  @override
  String get detectPickTitle => 'اختر قاعدة بيانات';

  @override
  String get detectUnsupportedBody =>
      'أغلب النسخ الإنتاجية تعطّل عرض القائمة. اكتب الاسم يدويًا — ويمكن لمسؤول أودو تأكيده.';

  @override
  String get detectUnsupportedTitle => 'هذا الخادم لا يعلن قائمة قواعد بياناته';

  @override
  String get diagnosticsCopied => 'نُسخ إلى الحافظة';

  @override
  String get diagnosticsCopy => 'نسخ';

  @override
  String get diagnosticsCrashDetail =>
      'لا تتضمن التقارير كلمة المرور أو مفتاح الـ API أو اسمك.';

  @override
  String get diagnosticsCrashOff => 'مُعطَّل — لا شيء يغادر هذا الجهاز';

  @override
  String get diagnosticsCrashOn => 'مُفعَّل — تُرسل تقارير أعطال مجهولة الهوية';

  @override
  String get diagnosticsCrashReporting => 'تقارير الأعطال';

  @override
  String get diagnosticsEmpty => 'لم تُسجَّل أي مشاكل';

  @override
  String get diagnosticsEmptyBody =>
      'تظهر هنا التفاصيل التقنية عند حدوث أي إخفاق.';

  @override
  String get dueChipOverdue => 'متأخر';

  @override
  String get dueChipSoon => 'قرب موعده';

  @override
  String dueInDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'الإرجاع بعد $daysString يومًا',
      few: 'الإرجاع بعد $daysString أيام',
      two: 'الإرجاع بعد يومين',
      one: 'الإرجاع بكرة',
      zero: 'الإرجاع النهاردة',
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
      other: 'متأخر $daysString يومًا',
      few: 'متأخر $daysString أيام',
      two: 'متأخر يومين',
      one: 'متأخر يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get employeeAssetsHeld => 'في العهدة';

  @override
  String get employeeAssignedAssets => 'الأصول المُسلَّمة';

  @override
  String get employeeInService => 'في الخدمة';

  @override
  String employeeItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString عنصرًا',
      few: '$countString عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا توجد عناصر',
    );
    return '$_temp0';
  }

  @override
  String get employeeSearchHint => 'الاسم أو القسم أو البريد…';

  @override
  String employeeSince(String date) {
    return 'منذ $date';
  }

  @override
  String get employeeTitle => 'الموظف';

  @override
  String get employeeWarrantyDue => 'ضمان يوشك';

  @override
  String get employeesTitle => 'الموظفون';

  @override
  String get emptyActivityBody =>
      'تظهر هنا عمليات التسليم والاستلام التي تسجلها.';

  @override
  String get emptyAssetsBody =>
      'ستظهر هنا الأصول التي تضيفها أو تستوردها إلى أودو.';

  @override
  String get emptyAssetsTitle => 'لا توجد أصول بعد';

  @override
  String get emptyEmployeeAssetsBody => 'لا يحمل هذا الموظف أي أصول.';

  @override
  String get emptyEmployeeAssetsTitle => 'لا توجد عهدة';

  @override
  String get emptyEmployeesBody => 'يأتي الموظفون من تطبيق الموظفين في أودو.';

  @override
  String get emptyEmployeesTitle => 'لا يوجد موظفون';

  @override
  String get emptyMaintenanceBody =>
      'تظهر هنا الطلبات التي تفتحها من صفحة الأصل.';

  @override
  String get emptyMaintenanceTitle => 'لا توجد طلبات صيانة';

  @override
  String get emptySearchBody => 'جرّب كلمة بحث أخرى أو امسح الفلاتر.';

  @override
  String get emptySearchTitle => 'لا توجد نتائج';

  @override
  String get errorAccessDeniedBody =>
      'حسابك في أودو غير مصرّح له بهذا الإجراء.';

  @override
  String errorAccessDeniedBodyDetailed(String operation, String model) {
    return 'حسابك في أودو غير مصرّح له بـ$operation على سجلات $model.';
  }

  @override
  String get errorAccessDeniedFix =>
      'اطلب من مسؤول أودو منحك الصلاحية. لا يتجاوز سِجل IT صلاحيات أودو أبدًا.';

  @override
  String get errorAccessDeniedTitle => 'لا تملك الصلاحية';

  @override
  String get errorActionEditConnection => 'تعديل الاتصال';

  @override
  String get errorActionSignIn => 'تسجيل الدخول';

  @override
  String get errorBusinessRuleFix =>
      'هذه القاعدة من إعدادات أودو لديك وليست من سِجل IT.';

  @override
  String get errorBusinessRuleTitle => 'أوقف أودو هذا الإجراء';

  @override
  String get errorCacheBody => 'تعذّر فتح النسخة المحفوظة على هذا الجهاز.';

  @override
  String get errorCacheFix =>
      'غالبًا يحل مسح الذاكرة المؤقتة من الإعدادات هذه المشكلة، ولا يتأثر شيء في أودو.';

  @override
  String get errorCacheTitle => 'تعذّرت قراءة البيانات المحلية';

  @override
  String get errorDatabaseUnavailableBody =>
      'لا توجد على هذا الخادم قاعدة بيانات بهذا الاسم.';

  @override
  String get errorDatabaseUnavailableFix =>
      'أسماء قواعد البيانات حساسة لحالة الأحرف. يمكن لمسؤول أودو تأكيد الاسم بدقة.';

  @override
  String get errorDatabaseUnavailableTitle => 'قاعدة البيانات غير موجودة';

  @override
  String get errorFieldUnavailableBody =>
      'طلبت هذه الشاشة من أودو حقلًا غير موجود في نسختك. لم يتغيّر شيء.';

  @override
  String errorFieldUnavailableBodyDetailed(String field) {
    return 'طلبت هذه الشاشة من أودو الحقل «$field» وهو غير موجود في نسختك. لم يتغيّر شيء.';
  }

  @override
  String get errorFieldUnavailableFix =>
      'إعادة المحاولة لن تُجدي — يجب أن يوجد الحقل أولًا. إن كان قد أُضيف للتو فسجّل الخروج ثم الدخول، وإلا فراجع مسؤول أودو لديك.';

  @override
  String get errorFieldUnavailableTitle => 'يوجد حقل ناقص في أودو لديك';

  @override
  String get errorFileUnavailableBody =>
      'تخلّى الهاتف عن الملف قبل اكتمال رفعه. يحدث هذا غالبًا عندما يُغلق النظام تطبيق الكاميرا وهو يعمل في الخلفية.';

  @override
  String get errorFileUnavailableFix =>
      'التقط الصورة مرة أخرى وابقَ داخل التطبيق حتى يكتمل الرفع.';

  @override
  String get errorFileUnavailableTitle => 'تعذّر قراءة الصورة';

  @override
  String get errorHowToFix => 'ما العمل';

  @override
  String get errorInsecureConnectionBody =>
      'لا يتصل سِجل IT إلا عبر HTTPS، حتى لا تُرسَل كلمة مرور أودو بنص واضح. والعنوان المحفوظ يبدأ بـ‎http://‎.';

  @override
  String get errorInsecureConnectionFix =>
      'غيّر العنوان ليبدأ بـ‎https://‎. وإن لم تكن نسخة أودو لديك تحمل شهادة بعد، فبإمكان المسؤول إضافتها — وهذا لازم أيضًا للنسخ المستضافة داخل شبكة المكتب.';

  @override
  String get errorInsecureConnectionTitle => 'هذا العنوان غير مُشفَّر';

  @override
  String get errorInvalidCredentialsBody =>
      'لم يقبل أودو اسم المستخدم مع كلمة المرور أو مفتاح API هذا.';

  @override
  String get errorInvalidCredentialsFix =>
      'تحقق من اسم المستخدم، وانتبه أن مفتاح API يختلف عن كلمة المرور.';

  @override
  String get errorInvalidCredentialsTitle => 'رُفض تسجيل الدخول';

  @override
  String get errorModelUnavailableBody =>
      'تحتاج هذه الميزة تطبيق أودو غير مثبَّت.';

  @override
  String errorModelUnavailableBodyDetailed(String model) {
    return 'تحتاج هذه الميزة نموذج أودو $model وهو غير موجود في هذه النسخة.';
  }

  @override
  String get errorModelUnavailableFix =>
      'يمكن لمسؤول أودو تثبيت التطبيق المناسب. وبقية سِجل IT تعمل كالمعتاد.';

  @override
  String get errorModelUnavailableTitle => 'غير متاح في أودو لديك';

  @override
  String get errorNoInternetBody =>
      'لا يوجد اتصال بالإنترنت على هذا الجهاز حاليًا.';

  @override
  String get errorNoInternetFix =>
      'شغّل الواي فاي أو بيانات الهاتف ثم أعد المحاولة.';

  @override
  String get errorNoInternetTitle => 'لا يوجد اتصال';

  @override
  String get errorNotAnOdooServerBody =>
      'استجاب العنوان، لكن ليس برد XML-RPC خاص بأودو.';

  @override
  String get errorNotAnOdooServerFix =>
      'استخدم العنوان الأساسي للنسخة بدون مسار — مثل https://company.odoo.com';

  @override
  String get errorNotAnOdooServerTitle => 'هذا لا يبدو خادم أودو';

  @override
  String get errorRateLimitedBody =>
      'يحدّ خادم أودو من عدد المرات التي يطلب فيها التطبيق البيانات. لا توجد مشكلة في اتصالك ولا في حسابك.';

  @override
  String get errorRateLimitedFix =>
      'انتظر لحظة ثم أعد المحاولة. وإن تكرر الأمر فاطلب من مسؤول أودو لديك رفع حدّ الطلبات لهذا التطبيق.';

  @override
  String errorRateLimitedFixSeconds(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'انتظر $secondsString ثانية ثم أعد المحاولة.',
      few: 'انتظر $secondsString ثوانٍ ثم أعد المحاولة.',
      two: 'انتظر ثانيتين ثم أعد المحاولة.',
      one: 'انتظر ثانية واحدة ثم أعد المحاولة.',
    );
    return '$_temp0';
  }

  @override
  String get errorRateLimitedTitle => 'طلبات كثيرة جدًا';

  @override
  String get errorRecordNotFoundBody =>
      'حُذف من أودو، أو أنه خارج نطاق ما يمكن لحسابك رؤيته.';

  @override
  String get errorRecordNotFoundFix =>
      'ارجع وحدّث القائمة لعرض السجلات الحالية.';

  @override
  String get errorRecordNotFoundTitle => 'هذا السجل غير موجود';

  @override
  String get errorRouteNotFoundBody =>
      'الرابط الذي فتحته يشير إلى مكان لا توجد له شاشة في سجل IT.';

  @override
  String get errorRouteNotFoundTitle => 'هذه الشاشة غير موجودة';

  @override
  String get errorServerBody => 'أخفق الخادم أثناء معالجة الطلب.';

  @override
  String get errorServerFix =>
      'أعد المحاولة. وإن استمر، أرسل التفاصيل من الإعدادات ← التشخيص إلى المسؤول لديك.';

  @override
  String get errorServerTitle => 'أبلغ أودو عن خطأ';

  @override
  String get errorServerUnreachableBody =>
      'لم يستجب العنوان. قد يكون الخادم متوقفًا أو العنوان غير صحيح.';

  @override
  String get errorServerUnreachableFix =>
      'تحقق من عنوان الخادم، وتأكد من أن النسخة تفتح في المتصفح من هذه الشبكة.';

  @override
  String get errorServerUnreachableTitle => 'تعذّر الوصول إلى خادم أودو';

  @override
  String get errorSessionExpiredBody => 'لم يعد أودو يتعرّف على هذه الجلسة.';

  @override
  String get errorSessionExpiredFix =>
      'سجّل الدخول مرة أخرى لتكمل من حيث توقفت.';

  @override
  String get errorSessionExpiredTitle => 'انتهت جلستك';

  @override
  String get errorTimeoutBody =>
      'لم يرد أودو في الوقت المحدد. قد يكون مشغولًا أو الاتصال بطيئًا.';

  @override
  String get errorTimeoutFix =>
      'أعد المحاولة بعد قليل. وإن تكرر الأمر فأبلغ مسؤول أودو لديك.';

  @override
  String get errorTimeoutTitle => 'استغرق الخادم وقتًا طويلًا';

  @override
  String get errorUnknownBody => 'واجه سِجل IT مشكلة غير متوقعة.';

  @override
  String get errorUnknownFix =>
      'أعد المحاولة. التفاصيل التقنية محفوظة في الإعدادات ← التشخيص.';

  @override
  String get errorUnknownTitle => 'حدث خطأ ما';

  @override
  String get errorValidationFix => 'صحّح الحقل المحدَّد ثم أعد المحاولة.';

  @override
  String get errorValidationTitle => 'راجع ما أدخلته';

  @override
  String exportAssetsSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString أصل',
      many: '$countString أصلًا',
      few: '$countString أصول',
      two: 'أصلان',
      one: 'أصل واحد',
      zero: 'لا أصول',
    );
    return '$_temp0';
  }

  @override
  String get exportAssetsTitle => 'قائمة الأصول';

  @override
  String get exportColumnAssignedOn => 'تاريخ التسليم';

  @override
  String get exportColumnCategory => 'الفئة';

  @override
  String get exportColumnDepartment => 'القسم';

  @override
  String get exportColumnDueBack => 'موعد الإرجاع';

  @override
  String get exportColumnHolder => 'مُسلَّم إلى';

  @override
  String get exportColumnManufacturer => 'الشركة المصنّعة';

  @override
  String get exportColumnModel => 'الموديل';

  @override
  String get exportColumnName => 'الاسم';

  @override
  String get exportColumnSerial => 'الرقم التسلسلي';

  @override
  String get exportColumnStatus => 'الحالة';

  @override
  String get exportColumnTag => 'الوسم';

  @override
  String get exportColumnWarrantyEnd => 'نهاية الضمان';

  @override
  String get exportFailed => 'تعذّر تجهيز الملف.';

  @override
  String exportGeneratedOn(String date) {
    return 'أُنشئ في $date';
  }

  @override
  String get exportNothingToShare => 'لا يوجد ما يُصدَّر بعد.';

  @override
  String get exportShare => 'مشاركة';

  @override
  String get fieldApiKeyHint => 'مفتاح API الخاص بأودو';

  @override
  String get fieldCredential => 'بيانات الدخول';

  @override
  String get fieldDatabase => 'قاعدة البيانات';

  @override
  String get fieldDatabaseHint => 'company-production';

  @override
  String get fieldPasswordHint => 'كلمة مرور أودو';

  @override
  String get fieldServerUrl => 'عنوان الخادم';

  @override
  String get fieldServerUrlHint => 'https://company.odoo.com';

  @override
  String get fieldUsername => 'اسم المستخدم';

  @override
  String get fieldUsernameHint => 'you@company.com';

  @override
  String get filterCategory => 'الفئة';

  @override
  String get filterClearAll => 'مسح الكل';

  @override
  String get filterDepartment => 'القسم';

  @override
  String get filterIncludeRetired => 'تضمين المستبعدة';

  @override
  String get filterManufacturer => 'الشركة المصنّعة';

  @override
  String get filterOverdue => 'المتأخر فقط';

  @override
  String get filterStatus => 'الحالة';

  @override
  String get filterWarranty => 'الضمان';

  @override
  String get filtersLabel => 'الفلاتر';

  @override
  String filtersLabelActive(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'الفلاتر ($countString)';
  }

  @override
  String get filtersTitle => 'تصفية الأصول';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get handoverAddAssets => 'إضافة أصول';

  @override
  String handoverAddCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'إضافة $countString';
  }

  @override
  String get handoverBundleEmpty => 'لم تُضف أي أصول بعد.';

  @override
  String handoverBundleFull(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'أقصى عدد في التسليمة الواحدة $maxString';
  }

  @override
  String get handoverConfirm => 'تأكيد التسليم';

  @override
  String handoverDone(String employee) {
    return 'اتسلّم لـ $employee';
  }

  @override
  String get handoverNeedsAssets => 'ضيف أصل واحد على الأقل';

  @override
  String get handoverNeedsRecipient => 'اختر مَن المُستلِم';

  @override
  String get handoverNeedsSignature => 'لازم المُستلِم يوقّع';

  @override
  String get handoverNoAssignableAssets => 'لا توجد أصول متاحة للتسليم حاليًا.';

  @override
  String get handoverNotesHint => 'تجهيزات موظف جديد، بديل لابتوب عطلان…';

  @override
  String get handoverNothingRecorded => 'ما اتسجّلش حاجة';

  @override
  String get handoverNothingRecordedBody =>
      'لم يقبل أودو أي أصل من التسليمة، فلم تتغيّر عهدة أي أصل.';

  @override
  String handoverPartial(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'اتسجّل $doneString من $totalString';
  }

  @override
  String get handoverPickAssets => 'إضافة للتسليم';

  @override
  String get handoverPickAssetsBody => 'تظهر الأصول التي لا يحملها أحد فقط.';

  @override
  String get handoverProofSaved => 'التوقيع محفوظ على كل أصل في أودو.';

  @override
  String get handoverRecorded => 'اتسجّل';

  @override
  String get handoverRefused => 'أودو رفض دول';

  @override
  String handoverRemoveFromBundle(String asset) {
    return 'شيل $asset';
  }

  @override
  String get handoverRetryRefused => 'جرّب دول تاني';

  @override
  String get handoverSearchAssets => 'ابحث عن أصل';

  @override
  String get handoverSearchPeople => 'ابحث عن موظف';

  @override
  String get handoverSignHint => 'وقّع فوق';

  @override
  String get handoverSignatureIncomplete =>
      'اتسجّل، لكن التوقيع ما وصلش لكل الأصول.';

  @override
  String get handoverSignatureRequired => 'وقّع لتأكيد الاستلام';

  @override
  String get handoverStepBundle => 'ما سيتسلّمه';

  @override
  String get handoverStepDate => 'تاريخ التسليم';

  @override
  String get handoverStepNotes => 'ملاحظة';

  @override
  String get handoverStepRecipient => 'مَن المُستلِم';

  @override
  String get handoverStepSignature => 'توقيع المُستلِم';

  @override
  String get handoverSubtitle => 'عدة أصول، وتوقيع واحد';

  @override
  String get handoverTitle => 'تسليم';

  @override
  String get historyEmptyBody =>
      'التسليمات والاسترجاعات والصيانات هتظهر هنا أول ما تحصل.';

  @override
  String get historyEmptyTitle => 'مفيش حاجة اتسجلت لسه';

  @override
  String historyHolders(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString موظفًا',
      few: '$countString موظفين',
      two: 'موظفان',
      one: 'موظف واحد',
      zero: 'لا يوجد حاملون',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadOlder => 'عرض الأقدم';

  @override
  String get historyRegistered => 'تم التسجيل';

  @override
  String historySince(String date) {
    return 'في الخدمة منذ $date';
  }

  @override
  String get historyTitle => 'سجل الحركة';

  @override
  String get labelAll => 'الكل';

  @override
  String get labelAssetName => 'اسم الأصل';

  @override
  String get labelAssetTag => 'رمز الأصل';

  @override
  String get labelAssignedOn => 'تاريخ التسليم';

  @override
  String get labelCategory => 'الفئة';

  @override
  String get labelDueBack => 'موعد الإرجاع';

  @override
  String labelHeldDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString يومًا',
      few: '$daysString أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'أقل من يوم',
    );
    return '$_temp0';
  }

  @override
  String get labelManufacturer => 'الشركة المصنّعة';

  @override
  String get labelModel => 'الموديل';

  @override
  String get labelNone => 'لا يوجد';

  @override
  String get labelNotes => 'ملاحظات';

  @override
  String get labelOdooVersion => 'إصدار أودو';

  @override
  String get labelOptional => 'اختياري';

  @override
  String get labelPurchaseDate => 'تاريخ الشراء';

  @override
  String get labelPurchaseValue => 'قيمة الشراء';

  @override
  String get labelSerialNumber => 'الرقم التسلسلي';

  @override
  String get labelServer => 'الخادم';

  @override
  String labelSheetSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ملصقًا',
      few: '$countString ملصقات',
      two: 'ملصقان',
      one: 'ملصق واحد',
    );
    return '$_temp0';
  }

  @override
  String get labelSheetTitle => 'ملصقات الأصول';

  @override
  String get labelSignedInAs => 'المستخدم الحالي';

  @override
  String get labelUnassigned => 'غير مُسلَّم';

  @override
  String get labelUnknown => 'غير مسجّل';

  @override
  String get labelVendor => 'المورّد';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageSystem => 'النظام';

  @override
  String get launchNoMailApp => 'لا يوجد تطبيق بريد مُعَد على هذا الجهاز.';

  @override
  String get launchNoPhoneApp => 'هذا الجهاز لا يمكنه إجراء المكالمات.';

  @override
  String lifecycleAge(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'في الخدمة منذ $monthsString شهر',
      many: 'في الخدمة منذ $monthsString شهرًا',
      few: 'في الخدمة منذ $monthsString أشهر',
      two: 'في الخدمة منذ شهرين',
      one: 'في الخدمة منذ شهر',
      zero: 'في الخدمة منذ أقل من شهر',
    );
    return '$_temp0';
  }

  @override
  String get lifecycleAgeing => 'حان وقت الاستبدال';

  @override
  String get lifecycleCostPerYear => 'التكلفة لكل سنة حتى الآن';

  @override
  String get lifecycleOverdue => 'تجاوز عمره المتوقع';

  @override
  String lifecycleOverdueBy(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'تجاوز عمره المتوقع بـ $monthsString شهر',
      many: 'تجاوز عمره المتوقع بـ $monthsString شهرًا',
      few: 'تجاوز عمره المتوقع بـ $monthsString أشهر',
      two: 'تجاوز عمره المتوقع بشهرين',
      one: 'تجاوز عمره المتوقع بشهر',
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
      other: 'يتبقى $monthsString شهر من عمره المتوقع',
      many: 'يتبقى $monthsString شهرًا من عمره المتوقع',
      few: 'يتبقى $monthsString أشهر من عمره المتوقع',
      two: 'يتبقى شهران من عمره المتوقع',
      one: 'يتبقى شهر من عمره المتوقع',
    );
    return '$_temp0';
  }

  @override
  String get lifecycleReplaceLabel => 'استبدال';

  @override
  String get lifecycleTitle => 'عمر التشغيل';

  @override
  String get lifecycleUnknown => 'لا يوجد تاريخ شراء مسجّل';

  @override
  String get lifecycleUnknownHint =>
      'أضف تاريخ الشراء لتعرف كم بقي من عمر هذا الأصل وكم كلّف سنويًا.';

  @override
  String get loadingLabel => 'جارٍ التحميل…';

  @override
  String get lockBody =>
      'أي حد ماسك موبايل مفتوح يقدر يعيد توزيع أجهزة الشركة. افتح القفل عشان تكمل.';

  @override
  String get lockFailed => 'ماتفتحش. جرّب تاني.';

  @override
  String get lockReason => 'افتح سجل IT';

  @override
  String get lockSettingsSubtitle =>
      'اسأل عن بصمة الجهاز أو الوجه أو رمز المرور قبل ما سجل IT يفتح.';

  @override
  String get lockSettingsTitle => 'اطلب فتح القفل';

  @override
  String get lockTitle => 'سجل IT مقفول';

  @override
  String get lockUnavailable =>
      'الجهاز ده مفيهوش قفل شاشة، فمفيش حاجة نسأل عنها.';

  @override
  String get lockUnlock => 'افتح القفل';

  @override
  String get loginAclNotice =>
      'يعمل سِجل IT ضمن صلاحياتك في أودو. لن ترى أو تعدّل إلا ما يسمح به حسابك.';

  @override
  String get loginBackToServer => 'الرجوع إلى إعدادات الخادم';

  @override
  String get loginKeepSignedIn => 'أبقني مسجَّلًا';

  @override
  String get loginNeedApiKey => 'تحتاج مفتاح API؟';

  @override
  String get loginSubtitle => 'سجّل الدخول ببيانات أودو الخاصة بك.';

  @override
  String get loginWelcomeBack => 'أهلًا بعودتك';

  @override
  String maintenanceClosed(String date) {
    return 'أُغلق $date';
  }

  @override
  String get maintenanceDuration => 'المدة';

  @override
  String maintenanceHours(String hours) {
    return '$hours س';
  }

  @override
  String get maintenanceNewRequest => 'طلب جديد';

  @override
  String get maintenanceNextScheduled => 'الفحص الوقائي القادم';

  @override
  String get maintenanceOnlyOpen => 'المفتوحة فقط';

  @override
  String get maintenanceOverdue => 'متأخرة';

  @override
  String get maintenancePriorityHigh => 'عالية';

  @override
  String get maintenancePriorityLow => 'منخفضة';

  @override
  String get maintenancePriorityNormal => 'عادية';

  @override
  String get maintenancePriorityVeryLow => 'منخفضة جدًا';

  @override
  String maintenanceRequestCreated(String asset) {
    return 'تم فتح طلب صيانة لـ $asset';
  }

  @override
  String get maintenanceRequestHint => 'ما الذي يحتاج إصلاحًا؟';

  @override
  String get maintenanceRequestTitle => 'طلب صيانة';

  @override
  String get maintenanceRequestedOn => 'تاريخ الطلب';

  @override
  String get maintenanceScheduled => 'مجدول';

  @override
  String get maintenanceSearchHint => 'طلب أو أصل…';

  @override
  String get maintenanceStage => 'المرحلة';

  @override
  String get maintenanceTechnician => 'الفني';

  @override
  String get maintenanceTitle => 'الصيانة';

  @override
  String get maintenanceTypeCorrective => 'إصلاحية';

  @override
  String get maintenanceTypeField => 'النوع';

  @override
  String get maintenanceTypePreventive => 'وقائية';

  @override
  String get moreAuditSubtitle => 'اعرف الموجود فعلًا';

  @override
  String get moreHandoverSubtitle => 'سلّم عدة أصول لشخص واحد';

  @override
  String get moreMaintenanceSubtitle => 'الطلبات والسجل الخاص بأصولك';

  @override
  String get moreSettingsSubtitle => 'الاتصال والحساب والمظهر والذاكرة المؤقتة';

  @override
  String get moreTitle => 'المزيد';

  @override
  String get moreToolsLabel => 'الأدوات';

  @override
  String get navAssets => 'الأصول';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navEmployees => 'الموظفون';

  @override
  String get navMore => 'المزيد';

  @override
  String get navScan => 'مسح';

  @override
  String get operationCreate => 'إنشاء';

  @override
  String get operationDelete => 'حذف';

  @override
  String get operationRead => 'عرض';

  @override
  String get operationWrite => 'تعديل';

  @override
  String overdueCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString أصلًا متأخرًا',
      few: '$countString أصول متأخرة',
      two: 'أصلان متأخران',
      one: 'أصل واحد متأخر',
    );
    return '$_temp0';
  }

  @override
  String get overdueEmptyBody =>
      'كل أصل ليه تاريخ إرجاع لسه في وقته. حدّد تاريخ وإنت بتسلّم وهيتراقب هنا.';

  @override
  String get overdueEmptyTitle => 'مفيش حاجة متأخرة';

  @override
  String get overdueSubtitle => 'أصول فات موعد إرجاعها';

  @override
  String get overdueTitle => 'متأخر عن الإرجاع';

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

    return '$usedString من $maxString';
  }

  @override
  String get photosAdd => 'إضافة';

  @override
  String get photosAdded => 'تم حفظ الصورة';

  @override
  String get photosCamera => 'كاميرا';

  @override
  String get photosEmpty => 'مفيش صور لسه';

  @override
  String get photosEmptyHint =>
      'صوّر العطل قبل أن تبدأ، وصوّر الإصلاح عند الانتهاء.';

  @override
  String get photosGallery => 'المعرض';

  @override
  String photosPosition(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString من $totalString';
  }

  @override
  String get photosRemoveAction => 'شيل';

  @override
  String get photosRemoveBody => 'هتتمسح من أودو عند الجميع.';

  @override
  String get photosRemoveTitle => 'تشيل الصورة دي؟';

  @override
  String get photosRemoved => 'تم حذف الصورة';

  @override
  String get photosSavedToOdoo => 'محفوظة على أودو';

  @override
  String get photosTitle => 'الصور';

  @override
  String get qrHint => 'اطبع هذا وألصقه على الجهاز. لا يحمل سوى معرّف الأصل.';

  @override
  String get qrTitle => 'رمز QR للأصل';

  @override
  String get receiptAssets => 'الأصول';

  @override
  String get receiptDate => 'تاريخ التسليم';

  @override
  String get receiptNotes => 'ملاحظات';

  @override
  String get receiptRecipient => 'استلمها';

  @override
  String get receiptShare => 'مشاركة الإيصال';

  @override
  String get receiptSignature => 'التوقيع';

  @override
  String get receiptTitle => 'إيصال تسليم';

  @override
  String reminderMaintenanceDue(String request) {
    return '$request مجدولة اليوم.';
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
      other: '$request متأخرة $daysString يوم.',
      many: '$request متأخرة $daysString يومًا.',
      few: '$request متأخرة $daysString أيام.',
      two: '$request متأخرة يومين.',
      one: '$request متأخرة يومًا واحدًا.',
    );
    return '$_temp0';
  }

  @override
  String get reminderMaintenanceTitle => 'صيانة مستحقة';

  @override
  String reminderNotificationBody(String asset, int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بقي $daysString يوم',
      many: 'بقي $daysString يومًا',
      few: 'بقيت $daysString أيام',
      two: 'بقي يومان',
      one: 'بقي يوم واحد',
      zero: 'انتهى',
    );
    return '$asset — $_temp0';
  }

  @override
  String get reminderNotificationTitle => 'ضمان على وشك الانتهاء';

  @override
  String get remindersDenied =>
      'التنبيهات موقوفة لتطبيق سِجل IT في إعدادات جهازك.';

  @override
  String remindersLeadDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'قبل $daysString يوم',
      many: 'قبل $daysString يومًا',
      few: 'قبل $daysString أيام',
      two: 'قبل يومين',
      one: 'قبل يوم واحد',
      zero: 'بلا مهلة',
    );
    return '$_temp0';
  }

  @override
  String get remindersLeadLabel => 'نبّهني';

  @override
  String remindersScheduled(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString تنبيه مجدول',
      many: '$countString تنبيهًا مجدولًا',
      few: '$countString تنبيهات مجدولة',
      two: 'تنبيهان مجدولان',
      one: 'تنبيه واحد مجدول',
      zero: 'لا تنبيهات مجدولة',
    );
    return '$_temp0';
  }

  @override
  String get remindersSubtitle => 'نبّهني قبل انتهاء الضمان';

  @override
  String get remindersTitle => 'تنبيهات الضمان';

  @override
  String get returnCondition => 'الحالة عند الاسترجاع';

  @override
  String get returnConfirm => 'تأكيد الاسترجاع';

  @override
  String get returnDate => 'تاريخ الاسترجاع';

  @override
  String returnHeldFor(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بالعهدة $daysString يومًا',
      few: 'بالعهدة $daysString أيام',
      two: 'بالعهدة يومان',
      one: 'بالعهدة يوم واحد',
      zero: 'بالعهدة أقل من يوم',
    );
    return '$_temp0';
  }

  @override
  String get returnNotesHint => 'أي تلف أو ملحقات ناقصة…';

  @override
  String returnOutcome(String status) {
    return 'يعود إلى $status وتُسجَّل الملاحظة في أودو.';
  }

  @override
  String get returnPhotos => 'الصور';

  @override
  String returnSuccess(String asset) {
    return 'تم استرجاع $asset';
  }

  @override
  String get returnTitle => 'استرجاع أصل';

  @override
  String get scanAgain => 'مسح مرة أخرى';

  @override
  String get scanCameraErrorBody =>
      'قد يكون تطبيق آخر يستخدم الكاميرا، أو أن الجهاز لم يُتِح الوصول إليها.';

  @override
  String get scanCameraErrorFix =>
      'أغلق أي تطبيق آخر يستخدم الكاميرا ثم افتح هذه الشاشة من جديد، وإن لم يُحلّ الأمر فأعد تشغيل الجهاز.';

  @override
  String get scanCameraErrorTitle => 'تعذّر تشغيل الكاميرا';

  @override
  String get scanCreateAsset => 'إنشاء أصل';

  @override
  String get scanEnterCode => 'اكتب الكود';

  @override
  String get scanEnterCodeBody =>
      'للملصق اللي الكاميرا مش شايفاه — مخربش، أو في ضلمة، أو ورا مكتب.';

  @override
  String get scanEnterCodeHint => 'الرقم التسلسلي أو كود الأصل';

  @override
  String get scanEnterCodeTitle => 'اكتب كود الأصل';

  @override
  String get scanInstruction => 'وجّه الكاميرا نحو رمز الأصل';

  @override
  String get scanInstructionDetail =>
      'يعمل مع رموز QR وباركود الأجهزة والأرقام التسلسلية المطبوعة.';

  @override
  String scanMatched(String payload) {
    return 'تم التعرف على $payload';
  }

  @override
  String get scanModeBarcode => 'باركود';

  @override
  String get scanModeQr => 'رمز QR';

  @override
  String scanNoMatchBody(String code) {
    return 'لا يطابق $code أي سجل في أودو.';
  }

  @override
  String get scanNoMatchTitle => 'لا يوجد أصل بهذا الرمز';

  @override
  String get scanPermissionBody =>
      'يحتاج سِجل IT إلى الكاميرا لقراءة رموز الأصول.';

  @override
  String get scanPermissionFix =>
      'فعّل الوصول إلى الكاميرا لتطبيق سِجل IT من إعدادات جهازك.';

  @override
  String get scanPermissionTitle => 'الوصول إلى الكاميرا مغلق';

  @override
  String get scanTitle => 'مسح أصل';

  @override
  String get scanTorch => 'الفلاش';

  @override
  String get sectionActivity => 'السجل';

  @override
  String get sectionDeviceInformation => 'بيانات الجهاز';

  @override
  String get sectionMaintenance => 'الصيانة';

  @override
  String get sectionOwnership => 'العهدة';

  @override
  String get sectionPurchase => 'الشراء والمورّد';

  @override
  String get sectionWarranty => 'الضمان';

  @override
  String get selectionAll => 'تحديد كل المحمّل';

  @override
  String get selectionCancel => 'إنهاء التحديد';

  @override
  String selectionCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $countString',
      few: 'تم تحديد $countString',
      two: 'تم تحديد اثنين',
      one: 'تم تحديد واحد',
      zero: 'لم يتم تحديد شيء',
    );
    return '$_temp0';
  }

  @override
  String selectionLimitReached(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'تقدر تشتغل على $countString أصل في المرة.';
  }

  @override
  String get selectionNone => 'إلغاء التحديد';

  @override
  String get selectionStart => 'تحديد أصول';

  @override
  String sessionExpiresOn(String date) {
    return 'سيُسجَّل الخروج في $date ما لم يُفتح التطبيق.';
  }

  @override
  String get sessionExplain =>
      'تُحسب المدة من آخر مرة فتحت فيها التطبيق، فالاستخدام اليومي لا يُخرجك أبدًا. أما الجهاز الذي يُترك دون استخدام فيُسجَّل خروجه ويُحذف الاعتماد المحفوظ.';

  @override
  String sessionMaxAgeDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString يوم',
      many: '$daysString يومًا',
      few: '$daysString أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'بلا حد',
    );
    return '$_temp0';
  }

  @override
  String get sessionNeverExpiresNote =>
      'تسجيل الدخول المحفوظ لا تنتهي صلاحيته على هذا الجهاز.';

  @override
  String get sessionSubtitle =>
      'المدة التي يجوز فيها لهذا الجهاز إعادة استخدام تسجيل دخولك إلى أودو دون كتابته من جديد.';

  @override
  String get sessionTitle => 'تسجيل الدخول المحفوظ';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsCacheKeepStates => 'الاحتفاظ بحالات الأصول المحلية';

  @override
  String get settingsClearCache => 'مسح الذاكرة المؤقتة';

  @override
  String get settingsClearCacheBody =>
      'يحتفظ أودو بكل شيء. سيُحذف فقط النسخة دون اتصال على هذا الجهاز.';

  @override
  String get settingsClearCacheConfirm => 'مسح البيانات المخزنة؟';

  @override
  String get settingsClearCacheDone => 'تم مسح الذاكرة المؤقتة';

  @override
  String get settingsConnected => 'متصل';

  @override
  String get settingsConnection => 'الاتصال بأودو';

  @override
  String get settingsDetected => 'المُكتشَف في أودو لديك';

  @override
  String get settingsDiagnostics => 'التشخيص';

  @override
  String get settingsDiagnosticsDetail => 'سجل تقني، مع إخفاء بيانات الدخول';

  @override
  String get settingsDisconnected => 'غير متصل';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String settingsLastChecked(String time) {
    return 'آخر فحص $time';
  }

  @override
  String get settingsMetadataRefreshed => 'تم تحديث بيانات أودو الوصفية';

  @override
  String get settingsNeverChecked => 'لم يُفحص بعد';

  @override
  String get settingsRefreshMetadata => 'تحديث بيانات أودو الوصفية';

  @override
  String get settingsSignOut => 'تسجيل الخروج';

  @override
  String get settingsSignOutBody =>
      'ستُحذف بيانات دخولك المحفوظة من هذا الجهاز.';

  @override
  String get settingsSignOutConfirm => 'تسجيل الخروج من سِجل IT؟';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String settingsVersion(String version, String build) {
    return 'سِجل IT $version (إصدار $build)';
  }

  @override
  String get sortLabel => 'الترتيب';

  @override
  String get sortNameAsc => 'الاسم أ–ي';

  @override
  String get sortNameDesc => 'الاسم ي–أ';

  @override
  String get sortRecent => 'الأحدث تحديثًا';

  @override
  String get splashRestoring => 'جارٍ استعادة جلستك…';

  @override
  String get statusAssigned => 'مُسلَّم';

  @override
  String get statusAvailable => 'متاح';

  @override
  String get statusDamaged => 'تالف';

  @override
  String get statusKeptInLog => 'مسجَّل في السجل';

  @override
  String get statusLost => 'مفقود';

  @override
  String get statusMaintenance => 'صيانة';

  @override
  String get statusReserved => 'محجوز';

  @override
  String get statusRetired => 'خارج الخدمة';

  @override
  String syncAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString محاولة',
      many: '$countString محاولة',
      few: '$countString محاولات',
      two: 'محاولتان',
      one: 'محاولة واحدة',
      zero: 'بلا محاولات',
    );
    return '$_temp0';
  }

  @override
  String get syncBlocked => 'أودو رفض هذا التغيير، ولن تُعاد المحاولة.';

  @override
  String get syncDiscard => 'حذف قائمة الانتظار';

  @override
  String get syncDiscardBody =>
      'هذه التغييرات لم تصل إلى أودو مطلقًا، وحذفها لا يمكن التراجع عنه.';

  @override
  String get syncDiscardConfirm => 'حذف التغييرات المنتظرة؟';

  @override
  String get syncDiscardFailedAll => 'تجاهل الكل';

  @override
  String get syncDiscardFailedAllBody =>
      'ستُنسى هذه التغييرات. لم يستلمها أودو مطلقًا، فلا يمكن استرجاعها. ولن يُمَس ما زال في انتظار الإرسال.';

  @override
  String get syncDiscardFailedAllConfirm => 'تتجاهل كل ما تعذّر إرساله؟';

  @override
  String get syncDiscardOne => 'تجاهل';

  @override
  String syncDiscardOneBody(String subject) {
    return 'سيُنسى $subject. لم يستلمه أودو مطلقًا، فلا يمكن استرجاعه.';
  }

  @override
  String get syncDiscardOneConfirm => 'تتجاهل هذا التغيير؟';

  @override
  String syncFailedBanner(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر إرسال $countString تغيير — اضغط للمراجعة',
      many: 'تعذّر إرسال $countString تغييرًا — اضغط للمراجعة',
      few: 'تعذّر إرسال $countString تغييرات — اضغط للمراجعة',
      two: 'تعذّر إرسال تغييرين — اضغط للمراجعة',
      one: 'تعذّر إرسال تغيير واحد — اضغط للمراجعة',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedBody =>
      'رفضها أودو. ما زالت محفوظة هنا، فلم يضع شيء مما فعلته — لكنها لن تُرسل من تلقاء نفسها.';

  @override
  String syncFailedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر إرسال $countString تغيير',
      many: 'تعذّر إرسال $countString تغييرًا',
      few: 'تعذّر إرسال $countString تغييرات',
      two: 'تعذّر إرسال تغييرين',
      one: 'تعذّر إرسال تغيير واحد',
    );
    return '$_temp0';
  }

  @override
  String syncFailedReason(String reason) {
    return 'قال أودو: $reason';
  }

  @override
  String get syncFailedSection => 'تعذّر إرسالها';

  @override
  String get syncNow => 'أرسِل الآن';

  @override
  String get syncOfflineBanner => 'غير متصل';

  @override
  String syncPendingBanner(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString تغيير في انتظار الإرسال',
      many: '$countString تغييرًا في انتظار الإرسال',
      few: '$countString تغييرات في انتظار الإرسال',
      two: 'تغييران في انتظار الإرسال',
      one: 'تغيير واحد في انتظار الإرسال',
      zero: 'لا تغييرات في الانتظار',
    );
    return '$_temp0';
  }

  @override
  String get syncPendingChip => 'لم يُرسَل بعد';

  @override
  String get syncQueueEmptyBody =>
      'التغييرات التي تجريها بدون اتصال تنتظر هنا حتى يتوفر الاتصال.';

  @override
  String get syncQueueEmptyTitle => 'كل شيء وصل إلى أودو';

  @override
  String syncQueuedAssign(String employee) {
    return 'تسليم إلى $employee';
  }

  @override
  String get syncQueuedNotice =>
      'حُفظ على هذا الجهاز، وسيصل إلى أودو عند توفر الاتصال.';

  @override
  String get syncQueuedReturn => 'استرجاع';

  @override
  String syncQueuedStatus(String status) {
    return 'تعيين الحالة إلى $status';
  }

  @override
  String get syncRetryOne => 'إعادة المحاولة';

  @override
  String get syncSending => 'جارٍ الإرسال…';

  @override
  String syncSentCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُرسل $countString تغيير',
      many: 'أُرسل $countString تغييرًا',
      few: 'أُرسلت $countString تغييرات',
      two: 'أُرسل تغييران',
      one: 'أُرسل تغيير واحد',
      zero: 'لم يُرسَل شيء',
    );
    return '$_temp0';
  }

  @override
  String syncStaleBanner(String time) {
    return 'تُعرض النسخة المحفوظة من $time';
  }

  @override
  String get syncSubtitle => 'تغييرات في انتظار الاتصال';

  @override
  String get syncTitle => 'المزامنة';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'النظام';

  @override
  String timeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $countString يومًا',
      few: 'قبل $countString أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $countString ساعة',
      few: 'قبل $countString ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $countString دقيقة',
      few: 'قبل $countString دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'أمس';

  @override
  String get tooltipToggleLanguage => 'تغيير اللغة';

  @override
  String get tooltipToggleTheme => 'تغيير المظهر';

  @override
  String get validationEnterAssetName => 'أدخل اسمًا لهذا الأصل.';

  @override
  String get validationEnterCredential => 'أدخل كلمة المرور أو مفتاح API.';

  @override
  String get validationEnterDatabase => 'أدخل اسم قاعدة بيانات أودو.';

  @override
  String get validationEnterServerUrl => 'أدخل عنوان خادم أودو.';

  @override
  String get validationEnterUsername => 'أدخل اسم المستخدم في أودو.';

  @override
  String get validationHttpsRequired => 'يجب أن يبدأ عنوان الخادم بـ https://';

  @override
  String get validationInvalidUrl => 'هذا لا يبدو عنوان خادم صالحًا.';

  @override
  String get voiceHeardNothing =>
      'لم يُسمع شيء. أعد المحاولة من مسافة أقرب للهاتف.';

  @override
  String get voiceListening => 'يستمع…';

  @override
  String get voiceSearchStart => 'البحث بالصوت';

  @override
  String get voiceSearchStop => 'إيقاف الاستماع';

  @override
  String warrantyEnds(String date) {
    return 'ينتهي $date';
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
      other: 'انتهى منذ $daysString يومًا',
      few: 'انتهى منذ $daysString أيام',
      two: 'انتهى منذ يومين',
      one: 'انتهى منذ يوم واحد',
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
      other: 'ينتهي خلال $daysString يومًا',
      few: 'ينتهي خلال $daysString أيام',
      two: 'ينتهي خلال يومين',
      one: 'ينتهي خلال يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get warrantyFilterCritical => 'ينتهي خلال 30 يومًا';

  @override
  String get warrantyFilterExpired => 'منتهٍ';

  @override
  String get warrantyFilterSoon => 'ينتهي خلال 90 يومًا';

  @override
  String get warrantyFilterValid => 'ساري';

  @override
  String warrantyStarted(String date) {
    return 'بدأ $date';
  }

  @override
  String get warrantyUnknown => 'لا يوجد تاريخ ضمان';

  @override
  String get warrantyValid => 'الضمان ساري';
}
