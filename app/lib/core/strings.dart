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
  static const loginOffline = 'لا يوجد اتصال بالإنترنت. تسجيل الدخول يتطلب اتصالاً في المرة الأولى.';
  static const sessionExpired = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى';
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
  static const offlineBanner = 'أنت غير متصل بالإنترنت. سيتم حفظ القراءات على الجهاز ومزامنتها لاحقًا.';
  static const syncPending = 'بانتظار المزامنة';
  static const syncSyncing = 'جارٍ المزامنة';
  static const syncSynced = 'تمت المزامنة';
  static const syncFailed = 'فشلت المزامنة';

  // Meter types
  static const electricity = 'كهرباء';
  static const water = 'مياه';
  static const gas = 'غاز';

  // Meters
  static const meterLocation = 'الموقع';
  static const meterFloor = 'الطابق';
  static const meterDescription = 'الوصف';
  static const floorLabel = 'الطابق';
  static const noMeters = 'لا توجد عدادات بعد';
  static const noMetersHint = 'يقوم المهندس بإضافة العدادات من شاشة العدادات';
  static const refreshMeters = 'تحديث العدادات';
  static const metersRefreshed = 'تم تحديث قائمة العدادات';
  static const metersRefreshFailed = 'تعذر تحديث العدادات، سيتم استخدام النسخة المحفوظة';

  // Readings
  static const noReadings = 'لا توجد قراءات بعد';
  static const readingValue = 'قراءة العداد';
  static const loggedBy = 'سجّلها';
  static const loggedAt = 'التاريخ';

  // Generic
  static const retry = 'إعادة المحاولة';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const placeholderTitle = 'قيد التنفيذ';
  static const placeholderBody = 'هذه الشاشة ستكون جاهزة في المرحلة القادمة من التطوير.';
}
