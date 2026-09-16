/// All user-facing copy. The app is Arabic-only, so a plain constants class is
/// simpler than ARB localization and keeps every string in one place.
class S {
  S._();

  static const appName = 'عدادات هيلتون هليوبوليس';
  static const appNameShort = 'عدادات هيلتون';

  // Auth
  static const login = 'تسجيل الدخول';
  static const username = 'اسم المستخدم';
  static const password = 'كلمة المرور';
  static const loginButton = 'دخول';
  static const logout = 'تسجيل الخروج';
  static const loginRequired = 'أدخل اسم المستخدم وكلمة المرور';
  static const loginFailed = 'اسم المستخدم أو كلمة المرور غير صحيحة';
  static const loginOffline =
      'لا يوجد اتصال بالإنترنت. تسجيل الدخول يتطلب اتصالاً في المرة الأولى.';
  static const sessionExpired =
      'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى';
  static const serverError = 'حدث خطأ في الخادم، حاول مرة أخرى';
  static const networkError = 'تعذر الاتصال بالخادم';

  // Roles
  static const roleModerator = 'مشرف';
  static const roleEngineer = 'مهندس';
  static const roleTechnician = 'فني';

  // Navigation
  static const navNewReading = 'تسجيل قراءة';
  static const navMyReadings = 'قراءاتي';
  static const navMeters = 'العدادات';
  static const navReadings = 'القراءات';
  static const navDashboard = 'لوحة التحكم';
  static const comingSoon = 'قريبًا';
  static const dashboardComingSoon = 'لوحة التحكم قادمة قريبًا';

  // Connectivity / sync
  static const online = 'متصل';
  static const offline = 'غير متصل';
  static const offlineBanner =
      'أنت غير متصل بالإنترنت. سيتم حفظ القراءات على الجهاز ومزامنتها لاحقًا.';
  static const syncPending = 'بانتظار المزامنة';
  static const syncSyncing = 'جارٍ المزامنة';
  static const syncSynced = 'تمت المزامنة';
  static const syncFailed = 'فشلت المزامنة';

  // Meter types
  static const electricity = 'كهرباء';
  static const water = 'مياه';
  static const gas = 'غاز';

  // Meters
  static const meterName = 'اسم العداد';
  static const meterNameHint = 'مثال: عداد المطبخ الرئيسي';
  static const meterDuplicate = 'يوجد عداد بنفس الاسم والرقم والمنطقة';
  static const meterArea = 'المنطقة';
  static const meterAreaHint = 'مثال: المبنى الرئيسي';
  static const meterNumber = 'رقم العداد';
  static const todoOrder = 'ترتيب قائمة التسجيل';
  static const todoOrderHint =
      'رقم يحدد موضع العداد في قائمة التسجيل اليومية (الأصغر أولًا)';
  static const exportOrder = 'ترتيب التصدير';
  static const exportOrderHint =
      'الترتيب الافتراضي لقائمة القراءات والتصدير (الأصغر أولًا)';
  static const orderInvalid = 'أدخل رقمًا صحيحًا موجبًا';
  static const moderatorOnlyFields = 'إعدادات الترتيب (للمشرف)';
  static const unitKwh = 'كيلوواط·س';
  static const unitCubicMeters = 'م³';
  static const gainLabel = 'الزيادة عن القراءة السابقة';
  static const meterNumberHint = 'اختياري: الرقم التسلسلي';
  static const colMeterArea = 'المنطقة';
  static const colMeterNumber = 'رقم العداد';
  static const colMeterName = 'اسم العداد';
  static const meterLocation = 'الموقع';
  static const meterDescription = 'الوصف';
  static const noMeters = 'لا توجد عدادات بعد';
  static const noMetersHint = 'اضغط زر الإضافة لتسجيل أول عداد';
  static const noMetersHintTechnician = 'لم يضف المهندس أي عدادات بعد';
  static const addMeter = 'إضافة عداد';
  static const editMeter = 'تعديل العداد';
  static const meterType = 'نوع العداد';
  static const meterLocationHint = 'مثال: المطبخ الرئيسي';
  static const meterDescriptionHint =
      'اختياري: الرقم التسلسلي، الموديل، ملاحظات';
  static const meterSaved = 'تم حفظ العداد';
  static const retireMeter = 'حذف العداد';
  static const retireMeterConfirm =
      'سيتم حذف العداد ولن يظهر للفنيين ولن يمكن تسجيل قراءات جديدة عليه. القراءات السابقة المسجلة عليه ستبقى محفوظة. هل تريد المتابعة؟';
  static const meterRetired = 'تم حذف العداد';
  static const fieldRequired = 'هذا الحقل مطلوب';
  static const onlineRequired = 'هذا الإجراء يتطلب اتصالاً بالإنترنت';
  static const refreshMeters = 'تحديث العدادات';
  static const metersRefreshed = 'تم تحديث قائمة العدادات';
  static const metersRefreshFailed =
      'تعذر تحديث العدادات، سيتم استخدام النسخة المحفوظة';

  // Readings
  static const noReadings = 'لا توجد قراءات بعد';
  static const readingValue = 'قراءة العداد';
  static const loggedBy = 'سجّلها';
  static const loggedAt = 'التاريخ';

  // New reading flow
  static const todoTitle = 'عدادات اليوم';
  static const todoProgress = 'تم تسجيل {done} من {total} عدادًا اليوم';
  static const doneToday = 'تم اليوم';
  static const notDoneToday = 'لم يُسجَّل اليوم';
  static const allDoneToday = 'تم تسجيل كل العدادات اليوم';
  static const stepType = 'اختر نوع العداد';
  static const stepMeter = 'اختر العداد';
  static const stepDetails = 'الصورة والقراءة';
  static const searchMeters = 'ابحث بالاسم أو المنطقة أو الرقم أو الموقع';
  static const noMetersOfType = 'لا توجد عدادات من هذا النوع';
  static const takePhoto = 'التقاط صورة';
  static const pickFromGallery = 'اختيار من المعرض';
  static const retakePhoto = 'تغيير الصورة';
  static const photoRequired = 'صورة العداد مطلوبة';
  static const valueRequired = 'أدخل قراءة العداد';
  static const valueInvalid = 'أدخل رقمًا صحيحًا';
  static const valueHint = 'مثال: 12345.6';
  static const saveReading = 'حفظ القراءة';
  static const readingSaved = 'تم حفظ القراءة على الجهاز';
  static const readingSavedOnline = 'تم حفظ القراءة وستتم مزامنتها الآن';
  static const newReadingAgain = 'تسجيل قراءة أخرى';
  static const back = 'رجوع';
  static const next = 'التالي';
  static const loggedByYou = 'أنت';
  static const willBeLoggedAs = 'سيتم تسجيل القراءة باسم';
  static const photoUnavailable = 'تعذر فتح الكاميرا أو المعرض';

  // Sync
  static const syncNow = 'مزامنة الآن';
  static const syncAllDone = 'كل القراءات متزامنة';
  static const syncStarted = 'بدأت المزامنة';
  static const syncNeedsInternet = 'المزامنة تحتاج اتصالاً بالإنترنت';
  static const retrySync = 'إعادة المزامنة';
  static const lastErrorLabel = 'سبب الفشل';

  // Engineer readings list
  static const pendingSection = 'بانتظار المزامنة على هذا الجهاز';
  static const sort = 'ترتيب';
  static const sortBy = 'ترتيب حسب';
  static const sortDate = 'التاريخ';
  static const sortValue = 'القراءة';
  static const sortMeterName = 'اسم العداد';
  static const sortUser = 'اسم المستخدم';
  static const sortDefault = 'الافتراضي';
  static const sortType = 'نوع العداد';
  static const sortAsc = 'تصاعدي';
  static const sortDesc = 'تنازلي';
  static const editReading = 'تعديل القراءة';
  static const editReadingHint = 'أدخل القيمة الجديدة';
  static const readingUpdated = 'تم تعديل القراءة';
  static const editNeedsInternet = 'التعديل يتطلب اتصالاً بالإنترنت';
  static const photoExpired = 'انتهت مدة الاحتفاظ بالصورة (90 يومًا)';
  static const openPhoto = 'عرض الصورة بالحجم الكامل';
  static const deleteLocalReading = 'حذف القراءة من الجهاز';
  static const deleteLocalReadingConfirm =
      'هذه القراءة لم تُرفع بعد. سيتم حذفها نهائيًا من الجهاز. هل تريد المتابعة؟';
  static const filters = 'تصفية';
  static const clearFilters = 'مسح التصفية';
  static const applyFilters = 'تطبيق';
  static const searchReadings =
      'ابحث باسم العداد أو المنطقة أو الرقم أو اسم المستخدم';
  static const filterType = 'نوع العداد';
  static const filterAllTypes = 'كل الأنواع';
  static const filterUser = 'اسم المستخدم';
  static const filterAllUsers = 'كل المستخدمين';
  static const filterNumber = 'رقم العداد';
  static const filterDateRange = 'الفترة الزمنية';
  static const filterDateFrom = 'من';
  static const filterDateTo = 'إلى';
  static const pickDates = 'اختيار الفترة';
  static const readingsCount = 'عدد القراءات';
  static const noReadingsMatch = 'لا توجد قراءات مطابقة';
  static const readingsNeedInternet = 'عرض القراءات يتطلب اتصالاً بالإنترنت';
  static const loadFailed = 'تعذر تحميل القراءات';
  static const readingId = 'معرف القراءة';
  static const syncedAtLabel = 'وقت المزامنة';
  static const photo = 'الصورة';
  static const photoLoadFailed = 'تعذر تحميل الصورة';

  // Export
  static const exportExcel = 'تصدير إلى Excel';
  static const exporting = 'جارٍ التصدير…';
  static const exportDone = 'تم حفظ الملف';
  static const exportCancelled = 'تم إلغاء التصدير';
  static const exportFailed = 'تعذر تصدير الملف';
  static const exportNothing = 'لا توجد قراءات لتصديرها';
  static const colDateTime = 'التاريخ والوقت';
  static const colType = 'نوع العداد';
  static const colLocation = 'الموقع';
  static const colDescription = 'الوصف';
  static const colValue = 'القراءة';
  static const colLoggedBy = 'سجّلها';
  static const colSyncedAt = 'وقت المزامنة';
  static const colReadingId = 'معرف القراءة';
  static const colUnit = 'الوحدة';
  static const sheetName = 'القراءات';

  // Users (engineer)
  static const navUsers = 'المستخدمون';
  static const addUser = 'إضافة مستخدم';
  static const editUser = 'تعديل المستخدم';
  static const usernameRules =
      'اسم المستخدم: 3 إلى 32 حرفًا، أحرف إنجليزية صغيرة وأرقام و _ و . فقط';
  static const passwordRules = 'كلمة المرور: 6 أحرف على الأقل';
  static const usernameTaken = 'اسم المستخدم مستخدم بالفعل';
  static const userSaved = 'تم حفظ المستخدم';
  static const role = 'الدور';
  static const fullName = 'الاسم الكامل';
  static const activeUsers = 'الحسابات النشطة';
  static const inactiveUsers = 'الحسابات الموقوفة';
  static const active = 'نشط';
  static const inactive = 'موقوف';
  static const deleteUser = 'حذف المستخدم';
  static const deleteUserConfirm =
      'سيتم حذف الحساب ولن يتمكن من تسجيل الدخول. القراءات المسجلة باسمه ستبقى محفوظة. هل تريد المتابعة؟';
  static const userDeleted = 'تم حذف المستخدم';
  static const cannotDeleteSelf = 'لا يمكنك حذف حسابك أو تغيير دورك';
  static const accountActive = 'الحساب نشط';
  static const accountActiveHint = 'الحساب الموقوف لا يستطيع تسجيل الدخول';
  static const newPassword = 'كلمة مرور جديدة';
  static const resetPasswordHint =
      'اتركه فارغًا للإبقاء على كلمة المرور الحالية';
  static const usersNeedInternet = 'إدارة المستخدمين تتطلب اتصالاً بالإنترنت';
  static const noUsers = 'لا يوجد مستخدمون';
  static const you = 'أنت';
  static const cannotEditSelf = 'لا يمكنك إيقاف حسابك أو تغيير دورك';

  // Misc additions
  static const photoTooLarge = 'حجم الصورة يتجاوز الحد الأقصى (3 ميجابايت)';
  static const syncFailedCheckConnection =
      'تعذرت المزامنة، تحقق من الاتصال بالإنترنت';
  static const loadingMore = 'جارٍ تحميل المزيد…';
  static const exportingPages = 'جارٍ تجميع كل القراءات…';

  // Polish round
  static const deleteReading = 'حذف القراءة';
  static const deleteReadingConfirm =
      'سيتم حذف القراءة وصورتها نهائيًا من الخادم. هل تريد المتابعة؟';
  static const readingDeleted = 'تم حذف القراءة';
  static const deleteNeedsInternet = 'الحذف يتطلب اتصالاً بالإنترنت';
  static const meterPhoto = 'صورة العداد (للمرجع)';
  static const meterPhotoHint = 'تظهر في قوائم العدادات وليست إلزامية';
  static const addMeterPhoto = 'إضافة صورة';
  static const changePhoto = 'تغيير الصورة';
  static const removePhoto = 'إزالة الصورة';
  static const filterAll = 'الكل';
  static const noMetersForFilter = 'لا توجد عدادات من هذا النوع';

  // Settings (moderator)
  static const appSettings = 'إعدادات التطبيق';
  static const manageUsers = 'إدارة المستخدمين';
  static const settingMinVersion = 'الحد الأدنى لإصدار التطبيق';
  static const settingMinVersionHint =
      'الإصدارات الأقدم لا تستطيع تسجيل الدخول';
  static const settingMaintenance = 'وضع الصيانة';
  static const settingMaintenanceHint =
      'يمنع الجميع عدا المشرفين من استخدام التطبيق';
  static const settingDeleteEnabled = 'السماح بحذف القراءات';
  static const settingExportEnabled = 'السماح بالتصدير إلى Excel';
  static const settingRetention = 'مدة الاحتفاظ بالصور (أيام)';
  static const settingRetentionHint =
      'تُحذف صور القراءات الأقدم من هذه المدة أسبوعيًا';
  static const settingsSaved = 'تم حفظ الإعدادات';
  static const settingsNeedInternet = 'الإعدادات تتطلب اتصالاً بالإنترنت';
  static const versionInvalid = 'أدخل إصدارًا بالشكل 2.0.0';
  static const retentionInvalid = 'أدخل عددًا بين 7 و3650';
  static const currentVersion = 'إصدار التطبيق الحالي';
  static const updateRequiredTitle = 'يلزم تحديث التطبيق';
  static const updateRequiredBody =
      'هذا الإصدار لم يعد مدعومًا. يرجى تنزيل أحدث إصدار ثم تسجيل الدخول مرة أخرى.';
  static const maintenanceTitle = 'التطبيق قيد الصيانة';
  static const maintenanceBody =
      'يقوم المشرف بأعمال صيانة حاليًا. يرجى المحاولة لاحقًا.';
  static const checkAgain = 'إعادة المحاولة';
  static const deleteDisabledByAdmin = 'حذف القراءات معطّل من قبل المشرف';
  static const exportDisabledByAdmin = 'التصدير معطّل من قبل المشرف';

  // Dashboard
  static const dashboardTitle = 'لوحة التحكم';
  static const rangeLastWeek = 'آخر 7 أيام';
  static const rangeCustom = 'اختيار الفترة';
  static const statReadings = 'قراءات مسجلة';
  static const statMetersRead = 'عدادات تمت قراءتها';
  static const mostReadMeter = 'الأكثر قراءةً';
  static const leastReadMeter = 'الأقل قراءةً';
  static const readingsSuffix = 'قراءة';
  static const gainTrend = 'الاستهلاك اليومي حسب النوع';
  static const gainTrendWeekly = 'الاستهلاك الأسبوعي حسب النوع';
  static const totalConsumption = 'إجمالي الاستهلاك في الفترة';
  static const noDataInRange = 'لا توجد بيانات في هذه الفترة';
  static const dashboardNeedInternet = 'لوحة التحكم تتطلب اتصالاً بالإنترنت';

  // Generic
  static const retry = 'إعادة المحاولة';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const placeholderTitle = 'قيد التنفيذ';
  static const placeholderBody =
      'هذه الشاشة ستكون جاهزة في المرحلة القادمة من التطوير.';
}
