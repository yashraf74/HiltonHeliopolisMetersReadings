/// App languages. Arabic is right-to-left; English left-to-right.
enum AppLanguage {
  ar,
  en;

  static AppLanguage fromCode(String? code) => code == 'en' ? en : ar;
}

/// All user-facing copy, each string in Arabic and English side by side.
/// [language] is set by LanguageController, which rebuilds the app when it
/// changes. A plain class keeps every string in one place and readable
/// without ARB tooling.
class S {
  S._();

  static AppLanguage language = AppLanguage.ar;

  static bool get isEnglish => language == AppLanguage.en;

  /// Locale code for intl date formatting ('ar' / 'en').
  static String get localeCode => language.name;

  static String _t(String ar, String en) => isEnglish ? en : ar;

  static String get appName =>
      _t('عدادات هيلتون هليوبوليس', 'Hilton Heliopolis Meters');
  static String get appNameShort => _t('عدادات هيلتون', 'Hilton Meters');

  // Auth
  static String get login => _t('تسجيل الدخول', 'Sign in');
  static String get username => _t('اسم المستخدم', 'Username');
  static String get password => _t('كلمة المرور', 'Password');
  static String get loginButton => _t('دخول', 'Sign in');
  static String get logout => _t('تسجيل الخروج', 'Sign out');
  static String get loginRequired =>
      _t('أدخل اسم المستخدم وكلمة المرور', 'Enter your username and password');
  static String get loginFailed => _t(
    'اسم المستخدم أو كلمة المرور غير صحيحة',
    'Incorrect username or password',
  );
  static String get loginOffline => _t(
    'لا يوجد اتصال بالإنترنت. تسجيل الدخول يتطلب اتصالاً في المرة الأولى.',
    'No internet connection. The first sign-in needs a connection.',
  );
  static String get sessionExpired => _t(
    'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى',
    'Your session has expired. Please sign in again',
  );
  static String get serverError =>
      _t('حدث خطأ في الخادم، حاول مرة أخرى', 'Server error, please try again');
  static String get networkError =>
      _t('تعذر الاتصال بالخادم', 'Couldn\'t reach the server');

  // Roles
  static String get roleModerator => _t('مشرف', 'Moderator');
  static String get roleEngineer => _t('مهندس', 'Engineer');
  static String get roleTechnician => _t('فني', 'Technician');

  // Navigation
  static String get navNewReading => _t('تسجيل قراءة', 'New reading');
  static String get navMyReadings => _t('قراءاتي', 'My readings');
  static String get navMeters => _t('العدادات', 'Meters');
  static String get navReadings => _t('القراءات', 'Readings');
  static String get navDashboard => _t('لوحة التحكم', 'Dashboard');
  static String get comingSoon => _t('قريبًا', 'Coming soon');
  static String get dashboardComingSoon =>
      _t('لوحة التحكم قادمة قريبًا', 'The dashboard is coming soon');

  // Connectivity / sync
  static String get online => _t('متصل', 'Online');
  static String get offline => _t('غير متصل', 'Offline');
  static String get offlineBanner => _t(
    'أنت غير متصل بالإنترنت. سيتم حفظ القراءات على الجهاز ومزامنتها لاحقًا.',
    'You\'re offline. Readings are saved on this device and synced later.',
  );
  static String get syncPending => _t('بانتظار المزامنة', 'Waiting to sync');
  static String get syncSyncing => _t('جارٍ المزامنة', 'Syncing');
  static String get syncSynced => _t('تمت المزامنة', 'Synced');
  static String get syncFailed => _t('فشلت المزامنة', 'Sync failed');

  // Meter types
  static String get electricity => _t('كهرباء', 'Electricity');
  static String get water => _t('مياه', 'Water');
  static String get gas => _t('غاز', 'Gas');

  // Meters
  static String get meterName => _t('اسم العداد', 'Meter name');
  static String get meterNameHint =>
      _t('مثال: عداد المطبخ الرئيسي', 'e.g. Main kitchen meter');
  static String get meterDuplicate => _t(
    'يوجد عداد بنفس الاسم والرقم والمنطقة',
    'A meter with the same name, number and area already exists',
  );
  static String get meterArea => _t('المنطقة', 'Area');
  static String get meterAreaHint =>
      _t('مثال: المبنى الرئيسي', 'e.g. Main building');
  static String get meterNumber => _t('رقم العداد', 'Meter number');
  static String get todoOrder => _t('ترتيب قائمة التسجيل', 'To-do list order');
  static String get todoOrderHint => _t(
    'رقم يحدد موضع العداد في قائمة التسجيل اليومية (الأصغر أولًا)',
    'Position in the daily reading list (lowest first)',
  );
  static String get exportOrder => _t('ترتيب التصدير', 'Export order');
  static String get exportOrderHint => _t(
    'الترتيب الافتراضي لقائمة القراءات والتصدير (الأصغر أولًا)',
    'Default order of the readings list and exports (lowest first)',
  );
  static String get orderInvalid =>
      _t('أدخل رقمًا صحيحًا موجبًا', 'Enter a whole number, 0 or more');
  static String get moderatorOnlyFields =>
      _t('إعدادات الترتيب (للمشرف)', 'Order settings (moderator)');
  static String get unitKwh => _t('كيلوواط·س', 'kWh');
  static String get unitCubicMeters => _t('م³', 'm³');
  static String get gainLabel =>
      _t('الزيادة عن القراءة السابقة', 'Increase since previous reading');
  static String get meterNumberHint =>
      _t('اختياري: الرقم التسلسلي', 'Optional: serial number');
  static String get colMeterArea => _t('المنطقة', 'Area');
  static String get colMeterNumber => _t('رقم العداد', 'Meter number');
  static String get colMeterName => _t('اسم العداد', 'Meter name');
  static String get noMeters => _t('لا توجد عدادات بعد', 'No meters yet');
  static String get noMetersHint => _t(
    'اضغط زر الإضافة لتسجيل أول عداد',
    'Tap the add button to create the first meter',
  );
  static String get noMetersHintTechnician =>
      _t('لم يضف المهندس أي عدادات بعد', 'No meters have been added yet');
  static String get addMeter => _t('إضافة عداد', 'Add meter');
  static String get editMeter => _t('تعديل العداد', 'Edit meter');
  static String get meterType => _t('نوع العداد', 'Meter type');
  static String get meterSaved => _t('تم حفظ العداد', 'Meter saved');
  static String get retireMeter => _t('حذف العداد', 'Delete meter');
  static String get retireMeterConfirm => _t(
    'سيتم حذف العداد ولن يظهر للفنيين ولن يمكن تسجيل قراءات جديدة عليه. القراءات السابقة المسجلة عليه ستبقى محفوظة. هل تريد المتابعة؟',
    'The meter will be deleted: technicians won\'t see it and no new readings can be logged on it. Its existing readings are kept. Continue?',
  );
  static String get meterRetired => _t('تم حذف العداد', 'Meter deleted');
  static String get fieldRequired =>
      _t('هذا الحقل مطلوب', 'This field is required');
  static String get onlineRequired => _t(
    'هذا الإجراء يتطلب اتصالاً بالإنترنت',
    'This needs an internet connection',
  );
  static String get refreshMeters => _t('تحديث العدادات', 'Refresh meters');
  static String get metersRefreshed =>
      _t('تم تحديث قائمة العدادات', 'Meter list updated');
  static String get metersRefreshFailed => _t(
    'تعذر تحديث العدادات، سيتم استخدام النسخة المحفوظة',
    'Couldn\'t update the meters; using the saved copy',
  );

  // Readings
  static String get noReadings => _t('لا توجد قراءات بعد', 'No readings yet');
  static String get readingValue => _t('قراءة العداد', 'Meter reading');
  static String get previousReading =>
      _t('القراءة السابقة', 'Previous reading');
  static String get noPreviousReading => _t(
    'لا توجد قراءة سابقة لهذا العداد',
    'No previous reading for this meter',
  );
  static String get loggedBy => _t('سجّلها', 'Logged by');
  static String get loggedAt => _t('التاريخ', 'Date');

  // New reading flow
  static String get todoTitle => _t('عدادات اليوم', 'Today\'s meters');
  static String get todoProgress => _t(
    'تم تسجيل {done} من {total} عدادًا اليوم',
    '{done} of {total} meters read today',
  );
  static String get doneToday => _t('تم اليوم', 'Done today');
  static String get notDoneToday => _t('لم يُسجَّل اليوم', 'Not read today');
  static String get allDoneToday =>
      _t('تم تسجيل كل العدادات اليوم', 'All meters read today');
  static String get stepType => _t('اختر نوع العداد', 'Choose the meter type');
  static String get stepMeter => _t('اختر العداد', 'Choose the meter');
  static String get stepDetails => _t('الصورة والقراءة', 'Photo and reading');
  static String get searchMeters => _t(
    'ابحث بالاسم أو المنطقة أو الرقم أو الموقع',
    'Search by name, area or number',
  );
  static String get noMetersOfType =>
      _t('لا توجد عدادات من هذا النوع', 'No meters of this type');
  static String get takePhoto => _t('التقاط صورة', 'Take photo');
  static String get pickFromGallery =>
      _t('اختيار من المعرض', 'Choose from gallery');
  static String get retakePhoto => _t('تغيير الصورة', 'Change photo');
  static String get photoRequired =>
      _t('صورة العداد مطلوبة', 'A photo of the meter is required');
  static String get valueRequired =>
      _t('أدخل قراءة العداد', 'Enter the meter reading');
  static String get valueInvalid =>
      _t('أدخل رقمًا صحيحًا', 'Enter a valid number');
  static String get valueHint => _t('مثال: 12345.6', 'e.g. 12345.6');
  static String get saveReading => _t('حفظ القراءة', 'Save reading');
  static String get readingSaved =>
      _t('تم حفظ القراءة على الجهاز', 'Reading saved on this device');
  static String get readingSavedOnline =>
      _t('تم حفظ القراءة وستتم مزامنتها الآن', 'Reading saved and syncing now');
  static String get newReadingAgain =>
      _t('تسجيل قراءة أخرى', 'Log another reading');
  static String get back => _t('رجوع', 'Back');
  static String get next => _t('التالي', 'Next');
  static String get loggedByYou => _t('أنت', 'You');
  static String get willBeLoggedAs =>
      _t('سيتم تسجيل القراءة باسم', 'Will be logged as');
  static String get photoUnavailable =>
      _t('تعذر فتح الكاميرا أو المعرض', 'Couldn\'t open the camera or gallery');

  // Sync
  static String get syncNow => _t('مزامنة الآن', 'Sync now');
  static String get syncAllDone =>
      _t('كل القراءات متزامنة', 'All readings are synced');
  static String get syncStarted => _t('بدأت المزامنة', 'Sync started');
  static String get syncNeedsInternet => _t(
    'المزامنة تحتاج اتصالاً بالإنترنت',
    'Syncing needs an internet connection',
  );
  static String get retrySync => _t('إعادة المزامنة', 'Retry sync');
  static String get photoMissingOnDevice =>
      _t('الصورة غير موجودة على الجهاز', 'The photo is missing on this device');
  static String get lastErrorLabel => _t('سبب الفشل', 'Reason');

  // Engineer readings list
  static String get pendingSection =>
      _t('بانتظار المزامنة على هذا الجهاز', 'Waiting to sync on this device');
  static String get sort => _t('ترتيب', 'Sort');
  static String get sortBy => _t('ترتيب حسب', 'Sort by');
  static String get sortDate => _t('التاريخ', 'Date');
  static String get sortValue => _t('القراءة', 'Reading');
  static String get sortMeterName => _t('اسم العداد', 'Meter name');
  static String get sortUser => _t('اسم المستخدم', 'User');
  static String get sortDefault => _t('الافتراضي', 'Default');
  static String get sortType => _t('نوع العداد', 'Meter type');
  static String get sortAsc => _t('تصاعدي', 'Ascending');
  static String get sortDesc => _t('تنازلي', 'Descending');
  static String get editReading => _t('تعديل القراءة', 'Edit reading');
  static String get editReadingHint =>
      _t('أدخل القيمة الجديدة', 'Enter the new value');
  static String get readingUpdated => _t('تم تعديل القراءة', 'Reading updated');
  static String get editNeedsInternet => _t(
    'التعديل يتطلب اتصالاً بالإنترنت',
    'Editing needs an internet connection',
  );
  static String get photoExpired => _t(
    'انتهت مدة الاحتفاظ بالصورة (90 يومًا)',
    'Photo expired after the retention period (90 days)',
  );
  static String get openPhoto =>
      _t('عرض الصورة بالحجم الكامل', 'View full-size photo');
  static String get deleteLocalReading =>
      _t('حذف القراءة من الجهاز', 'Delete reading from this device');
  static String get deleteLocalReadingConfirm => _t(
    'هذه القراءة لم تُرفع بعد. سيتم حذفها نهائيًا من الجهاز. هل تريد المتابعة؟',
    'This reading hasn\'t been uploaded yet. It will be permanently deleted from this device. Continue?',
  );
  static String get filters => _t('تصفية', 'Filter');
  static String get clearFilters => _t('مسح التصفية', 'Clear filters');
  static String get applyFilters => _t('تطبيق', 'Apply');
  static String get searchReadings => _t(
    'ابحث باسم العداد أو المنطقة أو الرقم أو اسم المستخدم',
    'Search by meter name, area, number or user',
  );
  static String get filterType => _t('نوع العداد', 'Meter type');
  static String get filterAllTypes => _t('كل الأنواع', 'All types');
  static String get filterUser => _t('اسم المستخدم', 'User');
  static String get filterAllUsers => _t('كل المستخدمين', 'All users');
  static String get filterNumber => _t('رقم العداد', 'Meter number');
  static String get filterDateRange => _t('الفترة الزمنية', 'Date range');
  static String get filterDateFrom => _t('من', 'From');
  static String get filterDateTo => _t('إلى', 'To');
  static String get pickDates => _t('اختيار الفترة', 'Pick dates');
  static String get readingsCount => _t('عدد القراءات', 'Readings');
  static String get noReadingsMatch =>
      _t('لا توجد قراءات مطابقة', 'No matching readings');
  static String get readingsNeedInternet => _t(
    'عرض القراءات يتطلب اتصالاً بالإنترنت',
    'Viewing readings needs an internet connection',
  );
  static String get loadFailed =>
      _t('تعذر تحميل القراءات', 'Couldn\'t load the readings');
  static String get readingId => _t('معرف القراءة', 'Reading ID');
  static String get syncedAtLabel => _t('وقت المزامنة', 'Synced at');
  static String get photo => _t('الصورة', 'Photo');
  static String get photoLoadFailed =>
      _t('تعذر تحميل الصورة', 'Couldn\'t load the photo');

  // Export
  static String get exportExcel => _t('تصدير إلى Excel', 'Export to Excel');
  static String get exporting => _t('جارٍ التصدير…', 'Exporting…');
  static String get exportDone => _t('تم حفظ الملف', 'File saved');
  static String get exportCancelled =>
      _t('تم إلغاء التصدير', 'Export cancelled');
  static String get exportFailed =>
      _t('تعذر تصدير الملف', 'Couldn\'t export the file');
  static String get exportNothing =>
      _t('لا توجد قراءات لتصديرها', 'No readings to export');
  static String get exportHow =>
      _t('كيف تريد استلام الملف؟', 'How do you want the file?');
  static String get exportToDevice =>
      _t('حفظ على الجهاز', 'Save on this device');
  static String get exportToEmail =>
      _t('إرسال إلى بريدي الإلكتروني', 'Send to my email');
  static String get exportToBoth => _t('الاثنان معًا', 'Both');
  static String get exportDeviceHint => _t(
    'يُحفظ ملف Excel على هذا الجهاز',
    'Saves the Excel file on this device',
  );

  /// [email] is the account's address, or null when unknown.
  static String exportEmailHint(String? email) => _t(
    'يُرسل الملف إلى بريدك الإلكتروني${email == null ? ' المسجل في حسابك' : ': \u2066$email\u2069'}',
    'Sends the file to your email${email == null ? ' on your account' : ': $email'}',
  );
  static String exportBothHint(String? email) => _t(
    'يُحفظ الملف على هذا الجهاز ويُرسل إلى بريدك الإلكتروني${email == null ? ' المسجل في حسابك' : ': \u2066$email\u2069'}',
    'Saves the file on this device and sends it to your email${email == null ? ' on your account' : ': $email'}',
  );
  static String get exportEmailed => _t('تم إرسال الملف إلى', 'File sent to');
  static String get exportNoEmail => _t(
    'لا يوجد بريد إلكتروني مسجل لحسابك، اطلب من المشرف إضافته',
    'Your account has no email address. Ask a moderator to add one',
  );
  static String get exportEmailNotConfigured => _t(
    'إرسال البريد غير مفعّل على الخادم بعد',
    'Email sending isn\'t set up on the server yet',
  );
  static String get exportEmailFailed =>
      _t('تعذر إرسال البريد الإلكتروني', 'Couldn\'t send the email');
  static String get colDateTime => _t('التاريخ والوقت', 'Date and time');
  static String get colType => _t('نوع العداد', 'Meter type');
  static String get colValue => _t('القراءة', 'Reading');
  static String get colLoggedBy => _t('سجّلها', 'Logged by');
  static String get colSyncedAt => _t('وقت المزامنة', 'Synced at');
  static String get colReadingId => _t('معرف القراءة', 'Reading ID');
  static String get colUnit => _t('الوحدة', 'Unit');
  static String get sheetName => _t('القراءات', 'Readings');

  // Users (engineer)
  static String get navUsers => _t('المستخدمون', 'Users');
  static String get addUser => _t('إضافة مستخدم', 'Add user');
  static String get editUser => _t('تعديل المستخدم', 'Edit user');
  static String get usernameRules => _t(
    'اسم المستخدم: 3 إلى 32 حرفًا، أحرف إنجليزية صغيرة وأرقام و _ و . فقط',
    'Username: 3–32 characters, lowercase English letters, digits, _ and . only',
  );
  static String get passwordRules =>
      _t('كلمة المرور: 6 أحرف على الأقل', 'Password: at least 6 characters');
  static String get usernameTaken =>
      _t('اسم المستخدم مستخدم بالفعل', 'That username is already taken');
  static String get userSaved => _t('تم حفظ المستخدم', 'User saved');
  static String get role => _t('الدور', 'Role');
  static String get fullName => _t('الاسم الكامل', 'Full name');
  static String get email => _t('البريد الإلكتروني', 'Email');
  static String get emailInvalid => _t(
    'أدخل بريدًا إلكترونيًا صحيحًا مثل name@example.com',
    'Enter a valid email like name@example.com',
  );
  static String get emailMissing => _t('لا يوجد بريد إلكتروني', 'No email');
  static String get activeUsers => _t('الحسابات النشطة', 'Active accounts');
  static String get inactiveUsers =>
      _t('الحسابات الموقوفة', 'Suspended accounts');
  static String get active => _t('نشط', 'Active');
  static String get inactive => _t('موقوف', 'Suspended');
  static String get deleteUser => _t('حذف المستخدم', 'Delete user');
  static String get deleteUserConfirm => _t(
    'سيتم حذف الحساب ولن يتمكن من تسجيل الدخول. القراءات المسجلة باسمه ستبقى محفوظة. هل تريد المتابعة؟',
    'The account will be deleted and can\'t sign in. Readings logged under it are kept. Continue?',
  );
  static String get userDeleted => _t('تم حذف المستخدم', 'User deleted');
  static String get cannotDeleteSelf => _t(
    'لا يمكنك حذف حسابك أو تغيير دورك',
    'You can\'t delete your own account or change your role',
  );
  static String get accountActive => _t('الحساب نشط', 'Account active');
  static String get accountActiveHint => _t(
    'الحساب الموقوف لا يستطيع تسجيل الدخول',
    'A suspended account can\'t sign in',
  );
  static String get newPassword => _t('كلمة مرور جديدة', 'New password');
  static String get resetPasswordHint => _t(
    'اتركه فارغًا للإبقاء على كلمة المرور الحالية',
    'Leave empty to keep the current password',
  );
  static String get usersNeedInternet => _t(
    'إدارة المستخدمين تتطلب اتصالاً بالإنترنت',
    'Managing users needs an internet connection',
  );
  static String get noUsers => _t('لا يوجد مستخدمون', 'No users');
  static String get you => _t('أنت', 'you');
  static String get cannotEditSelf => _t(
    'لا يمكنك إيقاف حسابك أو تغيير دورك',
    'You can\'t suspend your own account or change your role',
  );

  // Misc additions
  static String get photoTooLarge => _t(
    'حجم الصورة يتجاوز الحد الأقصى (3 ميجابايت)',
    'The photo is larger than the 3 MB limit',
  );
  static String get syncFailedCheckConnection => _t(
    'تعذرت المزامنة، تحقق من الاتصال بالإنترنت',
    'Sync failed; check the internet connection',
  );
  static String get loadingMore => _t('جارٍ تحميل المزيد…', 'Loading more…');
  static String get exportingPages =>
      _t('جارٍ تجميع كل القراءات…', 'Collecting all readings…');

  // Polish round
  static String get deleteReading => _t('حذف القراءة', 'Delete reading');
  static String get deleteReadingConfirm => _t(
    'سيتم حذف القراءة وصورتها نهائيًا من الخادم. هل تريد المتابعة؟',
    'The reading and its photo will be permanently deleted from the server. Continue?',
  );
  static String get readingDeleted => _t('تم حذف القراءة', 'Reading deleted');
  static String get deleteNeedsInternet => _t(
    'الحذف يتطلب اتصالاً بالإنترنت',
    'Deleting needs an internet connection',
  );
  static String get meterPhoto =>
      _t('صورة العداد (للمرجع)', 'Meter photo (reference)');
  static String get meterPhotoHint => _t(
    'تظهر في قوائم العدادات وليست إلزامية',
    'Shown in meter lists; optional',
  );
  static String get addMeterPhoto => _t('إضافة صورة', 'Add photo');
  static String get changePhoto => _t('تغيير الصورة', 'Change photo');
  static String get removePhoto => _t('إزالة الصورة', 'Remove photo');
  static String get filterAll => _t('الكل', 'All');
  static String get noMetersForFilter =>
      _t('لا توجد عدادات من هذا النوع', 'No meters of this type');

  // Settings (moderator)
  static String get appSettings => _t('إعدادات التطبيق', 'App settings');
  static String get manageUsers => _t('إدارة المستخدمين', 'Manage users');
  static String get settingMinVersion =>
      _t('الحد الأدنى لإصدار التطبيق', 'Minimum app version');
  static String get settingMinVersionHint => _t(
    'الإصدارات الأقدم لا تستطيع تسجيل الدخول',
    'Older versions can\'t sign in',
  );
  static String get settingMaintenance => _t('وضع الصيانة', 'Maintenance mode');
  static String get settingMaintenanceHint => _t(
    'يمنع الجميع عدا المشرفين من استخدام التطبيق',
    'Blocks everyone except moderators from using the app',
  );
  static String get settingDeleteEnabled =>
      _t('السماح بحذف القراءات', 'Allow deleting readings');
  static String get settingExportEnabled =>
      _t('السماح بالتصدير إلى Excel', 'Allow exporting to Excel');
  static String get settingRetention =>
      _t('مدة الاحتفاظ بالصور (أيام)', 'Photo retention (days)');
  static String get settingRetentionHint => _t(
    'تُحذف صور القراءات الأقدم من هذه المدة أسبوعيًا',
    'Reading photos older than this are deleted weekly',
  );
  static String get settingsSaved => _t('تم حفظ الإعدادات', 'Settings saved');
  static String get settingsNeedInternet => _t(
    'الإعدادات تتطلب اتصالاً بالإنترنت',
    'Settings need an internet connection',
  );
  static String get versionInvalid =>
      _t('أدخل إصدارًا بالشكل 2.0.0', 'Enter a version like 2.0.0');
  static String get retentionInvalid =>
      _t('أدخل عددًا بين 7 و3650', 'Enter a number from 7 to 3650');
  static String get settingTokenLifetime =>
      _t('مدة صلاحية تسجيل الدخول (أيام)', 'Sign-in validity (days)');
  static String get settingTokenLifetimeHint => _t(
    'بعدها يُطلب تسجيل الدخول مرة أخرى. تنطبق على عمليات الدخول الجديدة.',
    'After this, users must sign in again. Applies to new sign-ins.',
  );
  static String get tokenLifetimeInvalid =>
      _t('أدخل عددًا بين 1 و365', 'Enter a number from 1 to 365');
  static String get settingPrices =>
      _t('أسعار الاستهلاك', 'Consumption prices');
  static String get settingPricesHint => _t(
    'بالجنيه لكل وحدة، تُستخدم لحساب التكلفة في لوحة التحكم. اتركها 0 لإخفاء التكلفة.',
    'In EGP per unit, used for the cost chart on the dashboard. Leave 0 to hide the cost.',
  );
  static String get priceInvalid =>
      _t('أدخل رقمًا موجبًا', 'Enter a positive number');
  static String get currentVersion =>
      _t('إصدار التطبيق الحالي', 'Current app version');
  static String get latestVersion => _t('أحدث إصدار', 'Latest version');
  static String get thisDeviceVersion => _t('هذا الجهاز', 'This device');
  static String get updateRequiredTitle =>
      _t('يلزم تحديث التطبيق', 'Update required');
  static String get updateRequiredBody => _t(
    'هذا الإصدار لم يعد مدعومًا. يرجى تنزيل أحدث إصدار ثم تسجيل الدخول مرة أخرى.',
    'This version is no longer supported. Please install the latest version and sign in again.',
  );
  static String get maintenanceTitle =>
      _t('التطبيق قيد الصيانة', 'Under maintenance');
  static String get maintenanceBody => _t(
    'يقوم المشرف بأعمال صيانة حاليًا. يرجى المحاولة لاحقًا.',
    'A moderator is doing maintenance right now. Please try again later.',
  );
  static String get checkAgain => _t('إعادة المحاولة', 'Try again');
  static String get deleteDisabledByAdmin => _t(
    'حذف القراءات معطّل من قبل المشرف',
    'Deleting readings is turned off by a moderator',
  );
  static String get exportDisabledByAdmin => _t(
    'التصدير معطّل من قبل المشرف',
    'Exporting is turned off by a moderator',
  );

  // Dashboard
  static String get dashboardTitle => _t('لوحة التحكم', 'Dashboard');
  static String get rangeLastWeek => _t('آخر 7 أيام', 'Last 7 days');
  static String get rangeCustom => _t('اختيار الفترة', 'Pick range');
  static String get statReadings => _t('قراءات مسجلة', 'Readings logged');
  static String get statMetersRead => _t('عدادات تمت قراءتها', 'Meters read');
  static String get mostReadMeter => _t('الأكثر قراءةً', 'Most read');
  static String get leastReadMeter => _t('الأقل قراءةً', 'Least read');

  /// "reading(s)" after a count, with Arabic dual and plural forms.
  static String readingsUnit(int n) => _t(
    n == 2 ? 'قراءتان' : (n >= 3 && n <= 10 ? 'قراءات' : 'قراءة'),
    n == 1 ? 'reading' : 'readings',
  );

  /// "day(s)" after a count, with Arabic dual and plural forms.
  static String daysUnit(int n) => _t(
    n == 2 ? 'يومان' : (n >= 3 && n <= 10 ? 'أيام' : 'يوم'),
    n == 1 ? 'day' : 'days',
  );
  static String get consumption => _t('الاستهلاك', 'Consumption');
  static String get perDay => _t('يوميًا', 'Daily');
  static String get perWeek => _t('أسبوعيًا', 'Weekly');
  static String get perMonth => _t('شهريًا', 'Monthly');
  static String get completion =>
      _t('نسبة إنجاز القراءات', 'Reading completion');
  static String get completionHint => _t(
    'العدادات التي قُرئت من إجمالي العدادات',
    'Meters read out of all meters',
  );
  static String get changeVsAverage =>
      _t('مقارنة بمتوسط الفترة', 'Change vs. period average');
  static String get changeVsAverageHint => _t(
    'كل نوع مقارنةً بمتوسطه، فتظهر الأنواع الثلاثة على مقياس واحد',
    'Each type compared with its own average, so all three share one scale',
  );
  static String get cost => _t('التكلفة', 'Cost');
  static String get currency => _t('ج.م', 'EGP');
  static String get costNoPrices => _t(
    'حدد أسعار الوحدات من الإعدادات لعرض التكلفة',
    'Set unit prices in Settings to see the cost',
  );
  static String get costNoPricesEngineer => _t(
    'لم يحدد المشرف أسعار الوحدات بعد',
    'A moderator hasn\'t set unit prices yet',
  );
  static String get topConsumers => _t('الأعلى استهلاكًا', 'Top consumers');
  static String get byMeter => _t('العدادات', 'Meters');
  static String get byArea => _t('المناطق', 'Areas');
  static String get unusualReadings =>
      _t('قراءات غير معتادة', 'Unusual readings');
  static String get unusualNegative =>
      _t('أقل من القراءة السابقة', 'Lower than previous');
  static String get unusualHigh => _t('أعلى من المعتاد', 'Higher than usual');
  static String get timesUsual => _t('ضعف المعتاد', '× usual');
  static String get noUnusual =>
      _t('لا توجد قراءات غير معتادة', 'No unusual readings');
  static String get overdueMeters => _t('عدادات متأخرة', 'Overdue meters');
  static String get overdueHint =>
      _t('لم تُقرأ أمس ولا اليوم', 'Not read yesterday or today');
  static String get neverRead => _t('لم يُقرأ أبدًا', 'Never read');
  static String get lastReadDaysAgo =>
      _t('آخر قراءة منذ', 'since last reading');
  static String get noOverdue =>
      _t('كل العدادات مقروءة', 'All meters have been read');
  static String get showAll => _t('عرض الكل', 'Show all');
  static String get showLess => _t('عرض أقل', 'Show less');
  static String get noDataInRange =>
      _t('لا توجد بيانات في هذه الفترة', 'No data in this period');
  static String get dashboardNeedInternet => _t(
    'لوحة التحكم تتطلب اتصالاً بالإنترنت',
    'The dashboard needs an internet connection',
  );

  // Profiles, popups and links (v2.4.0)
  static String get phone => _t('رقم الموبايل', 'Mobile number');
  static String get phoneOptional => _t('اختياري', 'Optional');

  /// Shown inside the (left-to-right) phone field.
  static const phoneFormats = '01xxxxxxxxx / +20xxxxxxxxxx';

  // \u2066…\u2069 keep the Latin formats in one piece inside Arabic text.
  static String get phoneInvalid => _t(
    'أدخل رقمًا بالشكل \u206601xxxxxxxxx\u2069 أو \u2066+20xxxxxxxxxx\u2069',
    'Enter a number like 01xxxxxxxxx or +20xxxxxxxxxx',
  );
  static String get userPhoto =>
      _t('صورة المستخدم (اختيارية)', 'User photo (optional)');
  static String get meterDetails => _t('بيانات العداد', 'Meter details');
  static String get readingDetails => _t('تفاصيل القراءة', 'Reading details');
  static String get userDetails => _t('بيانات المستخدم', 'User details');
  static String get lastReading => _t('آخر قراءة', 'Last reading');
  static String get edit => _t('تعديل', 'Edit');
  static String get close => _t('إغلاق', 'Close');
  static String get userLoadFailed =>
      _t('تعذر تحميل بيانات المستخدم', "Couldn't load this user");
  static String get meterNotFound =>
      _t('هذا العداد لم يعد موجودًا', 'This meter no longer exists');

  // Language
  /// Menu item that switches to the *other* language, named in that language.
  static String get switchLanguage => _t('English', 'العربية');

  // About (moderators)
  static String get aboutApp => _t('عن التطبيق', 'About the app');
  static String get aboutTagline => _t(
    'نظام رقمي لتسجيل ومتابعة قراءات عدادات الكهرباء والمياه والغاز',
    'A digital system for logging and tracking electricity, water and gas meter readings',
  );
  static String get developedBy =>
      _t('تصميم وتطوير', 'Designed and developed by');
  static String get developerName =>
      _t('م. خالد عبد الفتاح', 'Eng. Khalid Abdelfattah');
  static String get hotelName =>
      _t('فندق هيلتون القاهرة هليوبوليس', 'Hilton Cairo Heliopolis Hotel');
  static String get experience => _t('الخبرة', 'Experience');
  static String get education => _t('التعليم', 'Education');
  static String get certifications => _t('الشهادات', 'Certifications');
  static String get expHilton => _t(
    'مهندس وردية · هيلتون القاهرة هليوبوليس',
    'Shift Engineer · Hilton Cairo Heliopolis',
  );
  static String get expHiltonDates =>
      _t('يوليو 2022 – الآن', 'Jul 2022 – Present');
  static String get expPyramisa => _t(
    'مهندس وردية · فنادق ومنتجعات بيراميزا',
    'Shift Engineer · Pyramisa Hotels & Resorts',
  );
  static String get expPyramisaDates =>
      _t('نوفمبر 2021 – يوليو 2022', 'Nov 2021 – Jul 2022');
  static String get eduDegree => _t(
    'بكالوريوس هندسة القوى والآلات الكهربية',
    'B.Sc. Electrical Power and Machines Engineering',
  );
  static String get eduSchool =>
      _t('جامعة عين شمس · 2016 – 2021', 'Ain Shams University · 2016 – 2021');
  static String get certHarvard => _t(
    'Hilton Lead 1.1 – سلسلة هارفارد الافتراضية لتطوير القيادة',
    'Hilton Lead 1.1 – Harvard Virtual Leadership Development Series',
  );
  static String get certHarvardIssued =>
      _t('هيلتون · صدرت سبتمبر 2024', 'Hilton · Issued Sep 2024');
  static String get licenseTitle =>
      _t('الترخيص والاستخدام', 'License and usage');
  static String get licenseBody => _t(
    'هذا التطبيق برنامج خاص طُوّر لإدارة الهندسة في فندق هيلتون القاهرة هليوبوليس، وهو مخصص للاستخدام الداخلي فقط. لا يجوز نسخه أو توزيعه أو تعديله أو استخدامه خارج الفندق دون إذن كتابي من المطوّر.',
    'This app is proprietary software developed for the Engineering Department of Hilton Cairo Heliopolis Hotel, for internal use only. It may not be copied, distributed, modified or used outside the hotel without the developer\'s written permission.',
  );
  static String get usageTitle => _t('سياسة الاستخدام', 'Acceptable use');
  static String get usageBody => _t(
    'الحسابات شخصية ولا يجوز مشاركتها. تُسجَّل كل قراءة باسم من أدخلها مع صورة العداد ووقت التسجيل، وتُستخدم البيانات لأغراض التشغيل ومتابعة الاستهلاك في الفندق فقط.',
    'Accounts are personal and must not be shared. Every reading is recorded under the name of the person who logged it, with a photo of the meter and the time. Data is used only for the hotel\'s operations and consumption tracking.',
  );
  static String get copyright => _t(
    '© 2026 خالد عبد الفتاح. جميع الحقوق محفوظة.',
    '© 2026 Khalid Abdelfattah. All rights reserved.',
  );
  static String get trademarkNote => _t(
    'هيلتون وHilton علامات تجارية مملوكة لأصحابها.',
    'Hilton is a trademark of its respective owner.',
  );
  static String get openSourceLicenses =>
      _t('تراخيص البرمجيات مفتوحة المصدر', 'Open-source licenses');
  static String get version => _t('الإصدار', 'Version');

  // Export settings (moderator) and profiles
  static String get settingExport => _t('إعدادات ملف Excel', 'Excel export');
  static String get settingExportHint => _t(
    'تُطبَّق على كل من يصدّر القراءات',
    'Applies to everyone who exports readings',
  );
  static String get exportColumns =>
      _t('الأعمدة وترتيبها', 'Columns and order');
  static String get exportColumnsHint => _t(
    'اسحب لإعادة الترتيب، وألغِ التحديد لإخفاء العمود',
    'Drag to reorder; untick to leave a column out',
  );
  static String get exportAtLeastOneColumn =>
      _t('اختر عمودًا واحدًا على الأقل', 'Choose at least one column');
  static String get exportDirection => _t('اتجاه الورقة', 'Sheet direction');
  static String get exportDirectionAuto => _t('حسب اللغة', 'Follow language');
  static String get exportDirectionRtl =>
      _t('من اليمين لليسار', 'Right to left');
  static String get exportDirectionLtr =>
      _t('من اليسار لليمين', 'Left to right');
  static String get exportDateFormat => _t('تنسيق التاريخ', 'Date format');
  static String get exportDecimals => _t('الأرقام العشرية', 'Decimal places');
  static String get exportThousands =>
      _t('فاصل الآلاف (1,234.5)', 'Thousands separator (1,234.5)');
  static String get exportSheetPerType =>
      _t('ورقة لكل نوع عداد', 'A sheet per meter type');
  static String get exportSheetPerTypeHint => _t(
    'كهرباء ومياه وغاز في أوراق منفصلة داخل نفس الملف',
    'Electricity, water and gas on separate tabs of the same file',
  );
  static String get settingProfileEditing =>
      _t('السماح بتعديل الملف الشخصي', 'Allow editing own profile');
  static String get settingProfileEditingHint => _t(
    'يمكن لكل مستخدم تغيير صورته وبريده ورقم موبايله',
    'Each user can change their photo, email and mobile number',
  );
  static String get myProfile => _t('ملفي الشخصي', 'My profile');
  static String get profileSaved => _t('تم حفظ الملف الشخصي', 'Profile saved');
  static String get profileEditingDisabled => _t(
    'تعديل الملف الشخصي معطّل من قبل المشرف',
    'Editing your profile is turned off by a moderator',
  );
  static String get changingLanguage =>
      _t('جارٍ تغيير اللغة…', 'Changing language…');

  static String get hiddenFromFilter =>
      _t('إخفاء من فلتر القراءات', 'Hide from the readings filter');
  static String get hiddenFromFilterHint => _t(
    'لن يظهر هذا الحساب في قائمة "اسم المستخدم" عند تصفية القراءات. قراءاته تبقى ظاهرة كالمعتاد.',
    "This account won't appear in the readings 'by user' filter. Its readings still show as usual.",
  );

  // Leaving a form with edits
  static String get unsavedChanges =>
      _t('تغييرات غير محفوظة', 'Unsaved changes');
  static String get unsavedChangesBody => _t(
    'هل تريد حفظ التغييرات قبل الخروج؟',
    'Do you want to save your changes before leaving?',
  );
  static String get discardChanges => _t('تجاهل', 'Discard');

  // Generic
  static String get retry => _t('إعادة المحاولة', 'Retry');
  static String get cancel => _t('إلغاء', 'Cancel');
  static String get save => _t('حفظ', 'Save');
  static String get placeholderTitle => _t('قيد التنفيذ', 'In progress');
  static String get placeholderBody => _t(
    'هذه الشاشة ستكون جاهزة في المرحلة القادمة من التطوير.',
    'This screen is coming in the next development stage.',
  );
}
