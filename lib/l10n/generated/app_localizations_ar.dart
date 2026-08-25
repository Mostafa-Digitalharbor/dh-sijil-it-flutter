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
  String get actionSaveAndSignIn => 'حفظ وتسجيل الدخول';

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
  String get assignNotesHint => 'سُلِّم مع الشاحن وموزّع USB-C…';

  @override
  String get assignSearchHint => 'ابحث عن موظف…';

  @override
  String get assignStepDate => 'تاريخ التسليم';

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
  String get authModeApiKey => 'مفتاح API';

  @override
  String get authModePassword => 'كلمة المرور';

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
  String get dashboardRecentActivity => 'النشاط الأخير';

  @override
  String get dashboardTitle => 'الرئيسية';

  @override
  String get dashboardWarrantyDue => 'ضمان ينتهي خلال ٣٠ يومًا';

  @override
  String detectFoundCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'تم العثور على $countString قاعدة بيانات';
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
  String get diagnosticsEmpty => 'لم تُسجَّل أي مشاكل';

  @override
  String get diagnosticsEmptyBody =>
      'تظهر هنا التفاصيل التقنية عند حدوث أي إخفاق.';

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

    return '$countString عناصر';
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
  String get errorHowToFix => 'ما العمل';

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
  String get filterStatus => 'الحالة';

  @override
  String get filterWarranty => 'الضمان';

  @override
  String get filtersLabel => 'الفلاتر';

  @override
  String get filtersTitle => 'تصفية الأصول';

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
  String labelHeldDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    return '$daysString يومًا';
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
  String get loadingLabel => 'جارٍ التحميل…';

  @override
  String get loginAclNotice =>
      'يعمل سِجل IT ضمن صلاحياتك في أودو. لن ترى أو تعدّل إلا ما يسمح به حسابك.';

  @override
  String get loginDifferentServer => 'تريد الاتصال بخادم آخر؟';

  @override
  String get loginKeepSignedIn => 'أبقني مسجَّلًا';

  @override
  String get loginNeedApiKey => 'تحتاج مفتاح API؟';

  @override
  String get loginSubtitle => 'سجّل الدخول ببيانات أودو الخاصة بك.';

  @override
  String get loginSwitchServer => 'تغيير';

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
  String get moreMaintenanceSubtitle => 'الطلبات والسجل الخاص بأصولك';

  @override
  String get moreSettingsSubtitle => 'الاتصال والحساب والمظهر والذاكرة المؤقتة';

  @override
  String get moreTitle => 'المزيد';

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
  String get qrHint => 'اطبع هذا وألصقه على الجهاز. لا يحمل سوى معرّف الأصل.';

  @override
  String get qrTitle => 'رمز QR للأصل';

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

    return 'بالعهدة $daysString يومًا';
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
  String get scanCreateAsset => 'إنشاء أصل';

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
  String get statusLost => 'مفقود';

  @override
  String get statusMaintenance => 'صيانة';

  @override
  String get statusReserved => 'محجوز';

  @override
  String get statusRetired => 'خارج الخدمة';

  @override
  String get statusKeptInLog => 'مسجَّل في السجل';

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

    return 'قبل $countString يوم';
  }

  @override
  String timeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'قبل $countString ساعة';
  }

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'قبل $countString دقيقة';
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
  String warrantyEnds(String date) {
    return 'ينتهي $date';
  }

  @override
  String warrantyExpiredAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    return 'انتهى منذ $daysString يومًا';
  }

  @override
  String warrantyExpiresIn(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    return 'ينتهي خلال $daysString يومًا';
  }

  @override
  String get warrantyFilterCritical => 'ينتهي خلال ٣٠ يومًا';

  @override
  String get warrantyFilterExpired => 'منتهٍ';

  @override
  String get warrantyFilterSoon => 'ينتهي خلال ٩٠ يومًا';

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

  @override
  String get errorFileUnavailableTitle => 'تعذّر قراءة الصورة';

  @override
  String get errorFileUnavailableBody =>
      'الهاتف تخلّص من الملف قبل ما يخلص رفع. ده بيحصل غالبًا لما النظام يقفل تطبيق الكاميرا وهو شغّال في الخلفية.';

  @override
  String get errorFileUnavailableFix =>
      'صوّر الصورة تاني وفضل في التطبيق لحد ما الرفع يخلص.';

  @override
  String get photosTitle => 'الصور';

  @override
  String get photosAdd => 'إضافة';

  @override
  String get photosCamera => 'كاميرا';

  @override
  String get photosGallery => 'المعرض';

  @override
  String get photosSavedToOdoo => 'محفوظة على أودو';

  @override
  String get photosEmpty => 'مفيش صور لسه';

  @override
  String get photosEmptyHint => 'صوّر العطل قبل ما تبدأ، والإصلاح لما تخلص.';

  @override
  String get photosRemoveTitle => 'تشيل الصورة دي؟';

  @override
  String get photosRemoveBody => 'هتتمسح من أودو عند الجميع.';

  @override
  String get photosRemoveAction => 'شيل';

  @override
  String get photosRemoved => 'تم حذف الصورة';

  @override
  String get photosAdded => 'تم حفظ الصورة';

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
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String get dashboardTrendTitle => 'في الخدمة خلال ١٢ شهر';

  @override
  String get dashboardAssetsUnit => 'أصل';

  @override
  String get dashboardRareStatuses => 'محجوز · تالف · مفقود';

  @override
  String get historyTitle => 'سجل الحركة';

  @override
  String get historyEmptyTitle => 'مفيش حاجة اتسجلت لسه';

  @override
  String get historyEmptyBody =>
      'التسليمات والاسترجاعات والصيانات هتظهر هنا أول ما تحصل.';

  @override
  String get historyRegistered => 'تم التسجيل';

  @override
  String historySince(String date) {
    return 'في الخدمة منذ $date';
  }

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
  String get assetActionHistory => 'سجل الحركة';

  @override
  String get auditTitle => 'الجرد';

  @override
  String get auditStartTitle => 'بتجرد إيه؟';

  @override
  String get auditStartBody =>
      'الجرد المحدود بيخلص. جرد كل حاجة مرة واحدة محدش بيخلصه.';

  @override
  String get auditScopeAll => 'كل الأصول';

  @override
  String get auditScopeCategory => 'فئة واحدة';

  @override
  String get auditScopeDepartment => 'قسم واحد';

  @override
  String get auditPickCategory => 'اختر الفئة';

  @override
  String get auditPickDepartment => 'اختر القسم';

  @override
  String get auditBegin => 'ابدأ الجرد';

  @override
  String get auditCounting => 'جاري الجرد';

  @override
  String get auditFound => 'موجود';

  @override
  String get auditUnexpected => 'مش في النطاق';

  @override
  String get auditMissing => 'مش موجود';

  @override
  String get auditKeepScanning => 'كمّل مسح — مش محتاج توقف';

  @override
  String get auditJustScanned => 'آخر ما تم مسحه';

  @override
  String get auditWhereExpected => 'في مكانه المتوقع';

  @override
  String get auditOutOfScope => 'موجود هنا، ومسجّل في مكان تاني';

  @override
  String get auditUnknownCode => 'الكود ده مش تابع لأي أصل';

  @override
  String get auditFinish => 'إنهاء الجرد';

  @override
  String get auditResume => 'كمّل الجرد';

  @override
  String get auditReportTitle => 'انتهى الجرد';

  @override
  String get auditNothingMissing => 'كل الأصول في النطاق اتلقت.';

  @override
  String get auditSaveToOdoo => 'حفظ النتيجة في أودو';

  @override
  String get auditSaved => 'اتحفظت النتيجة في أودو';

  @override
  String get auditSavedNone => 'مفيش نتايج تتسجل.';

  @override
  String get auditDiscardTitle => 'تسيب الجرد؟';

  @override
  String get auditDiscardBody =>
      'اللي اتمسح لحد دلوقتي على الموبايل بس. لو خرجت هيضيع.';

  @override
  String get auditDiscardConfirm => 'اخرج';

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
  String get moreAuditSubtitle => 'اعرف الموجود فعلًا';

  @override
  String get moreToolsLabel => 'الأدوات';

  @override
  String get handoverTitle => 'تسليم';

  @override
  String get handoverSubtitle => 'أكتر من أصل، وتوقيع واحد';

  @override
  String get handoverConfirm => 'تأكيد التسليم';

  @override
  String get handoverStepRecipient => 'مَن المُستلِم';

  @override
  String get handoverStepBundle => 'اللي هيتسلّمه';

  @override
  String get handoverStepDate => 'تاريخ التسليم';

  @override
  String get handoverStepSignature => 'توقيع المُستلِم';

  @override
  String get handoverStepNotes => 'ملاحظة';

  @override
  String get handoverNotesHint => 'تجهيزات موظف جديد، بديل لابتوب عطلان…';

  @override
  String get handoverSearchPeople => 'ابحث عن موظف';

  @override
  String get handoverBundleEmpty => 'ما فيش حاجة مضافة لسّة.';

  @override
  String get handoverAddAssets => 'إضافة أصول';

  @override
  String handoverBundleFull(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'أقصى عدد في التسليمة الواحدة $maxString';
  }

  @override
  String handoverRemoveFromBundle(String asset) {
    return 'شيل $asset';
  }

  @override
  String get handoverSignHint => 'وقّع فوق';

  @override
  String get handoverSignatureRequired => 'وقّع لتأكيد الاستلام';

  @override
  String get handoverNeedsRecipient => 'اختر مَن المُستلِم';

  @override
  String get handoverNeedsAssets => 'ضيف أصل واحد على الأقل';

  @override
  String get handoverNeedsSignature => 'لازم المُستلِم يوقّع';

  @override
  String get handoverPickAssets => 'إضافة للتسليم';

  @override
  String get handoverPickAssetsBody => 'بتظهر الأصول اللي ما حدش ماسكها بس.';

  @override
  String get handoverSearchAssets => 'ابحث عن أصل';

  @override
  String handoverAddCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'إضافة $countString';
  }

  @override
  String get handoverNoAssignableAssets => 'ما فيش أصول متاحة للتسليم دلوقتي.';

  @override
  String handoverDone(String employee) {
    return 'اتسلّم لـ $employee';
  }

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
  String get handoverProofSaved => 'التوقيع محفوظ على كل أصل في أودو.';

  @override
  String get handoverSignatureIncomplete =>
      'اتسجّل، لكن التوقيع ما وصلش لكل الأصول.';

  @override
  String get handoverRecorded => 'اتسجّل';

  @override
  String get handoverRefused => 'أودو رفض دول';

  @override
  String get handoverRetryRefused => 'جرّب دول تاني';

  @override
  String get handoverNothingRecorded => 'ما اتسجّلش حاجة';

  @override
  String get handoverNothingRecordedBody =>
      'أودو ما قبلش أي حاجة من التسليمة، فما فيش أصل اتغيّر.';

  @override
  String get moreHandoverSubtitle => 'سلّم كذا أصل لشخص واحد';

  @override
  String get errorFieldUnavailableTitle => 'فيه حقل ناقص في أودو بتاعك';

  @override
  String get errorFieldUnavailableBody =>
      'الشاشة طلبت من أودو حقل مش موجود عندك. ما اتغيّرش أي حاجة.';

  @override
  String errorFieldUnavailableBodyDetailed(String field) {
    return 'الشاشة طلبت من أودو الحقل «$field»، ومش موجود عندك. ما اتغيّرش أي حاجة.';
  }

  @override
  String get errorFieldUnavailableFix =>
      'إعادة المحاولة مش هتفيد — لازم الحقل يكون موجود الأول. لو اتضاف دلوقتي، اطلع وادخل تاني؛ وإلا كلّم مسؤول أودو.';

  @override
  String get operationRead => 'عرض';

  @override
  String get operationCreate => 'إنشاء';

  @override
  String get operationWrite => 'تعديل';

  @override
  String get operationDelete => 'حذف';
}

/// The translations for Arabic, as used in Egypt (`ar_EG`).
class AppL10nArEg extends AppL10nAr {
  AppL10nArEg() : super('ar_EG');
}
