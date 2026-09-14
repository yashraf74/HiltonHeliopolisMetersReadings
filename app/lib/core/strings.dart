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
  static const roleEngineer = 'مهندس';
  static const roleTechnician = 'فني';

  // Navigation
  static const navNewReading = 'تسجيل قراءة';
  static const navMyReadings = 'قراءاتي';
  static const navMeters = 'العدادات';
  static const navReadings = 'القراءات';
  static const navDashboard = 'لوحة التحكم';
  static const comingSoon = 'قريبًا';
  static const dashboardComingSoon = 'لوحة التحكم قادمة في المرحلة الثانية';

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
  static const meterNameTaken = 'يوجد عداد بهذا الاسم في نفس الطابق';
  static const colMeterName = 'اسم العداد';
  static const meterLocation = 'الموقع';
  static const meterFloor = 'الطابق';
  static const meterDescription = 'الوصف';
  static const floorLabel = 'الطابق';
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
  static const floorInvalid = 'أدخل رقم طابق صحيح';
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
  static const stepType = 'اختر نوع العداد';
  static const stepMeter = 'اختر العداد';
  static const stepDetails = 'الصورة والقراءة';
  static const searchMeters = 'ابحث بالاسم أو الموقع أو الطابق';
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
  static const filters = 'تصفية';
  static const clearFilters = 'مسح التصفية';
  static const applyFilters = 'تطبيق';
  static const searchReadings = 'ابحث باسم العداد أو الموقع أو اسم الفني';
  static const filterType = 'نوع العداد';
  static const filterAllTypes = 'كل الأنواع';
  static const filterFloor = 'رقم الطابق';
  static const filterTechnician = 'اسم الفني';
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
  static const colFloor = 'الطابق';
  static const colDescription = 'الوصف';
  static const colValue = 'القراءة';
  static const colLoggedBy = 'سجّلها';
  static const colSyncedAt = 'وقت المزامنة';
  static const colReadingId = 'معرف القراءة';
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
  static const notes = 'ملاحظات';
  static const notesOptionalHint = 'اختياري: أي ملاحظة عن العداد أو القراءة';
  static const deleteReading = 'حذف القراءة';
  static const deleteReadingConfirm =
      'سيتم حذف القراءة وصورتها نهائيًا من الخادم. هل تريد المتابعة؟';
  static const readingDeleted = 'تم حذف القراءة';
  static const deleteNeedsInternet = 'الحذف يتطلب اتصالاً بالإنترنت';
  static const meterPhoto = 'صورة العداد (مرجع للمهندس فقط)';
  static const meterPhotoHint =
      'تظهر في قائمة العدادات فقط ولا تُستخدم في القراءات';
  static const addMeterPhoto = 'إضافة صورة';
  static const changePhoto = 'تغيير الصورة';
  static const removePhoto = 'إزالة الصورة';
  static const filterAll = 'الكل';
  static const noMetersForFilter = 'لا توجد عدادات من هذا النوع';

  // Generic
  static const retry = 'إعادة المحاولة';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const placeholderTitle = 'قيد التنفيذ';
  static const placeholderBody =
      'هذه الشاشة ستكون جاهزة في المرحلة القادمة من التطوير.';
}
