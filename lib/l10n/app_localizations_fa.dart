// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get language => 'زبان';

  @override
  String get interfaceLanguage => 'زبان رابط کاربری';

  @override
  String get systemDefault => 'زبان سیستم';

  @override
  String get languageSaveFailed => 'ذخیرهٔ زبان انتخاب‌شده ممکن نشد.';

  @override
  String get settings => 'تنظیمات';

  @override
  String get connection => 'اتصال';

  @override
  String get subscriptions => 'اشتراک‌ها';

  @override
  String get routing => 'مسیریابی';

  @override
  String get hideToTray => 'کوچک‌کردن در سینی سیستم';

  @override
  String get closeApp => 'بستن برنامه';

  @override
  String get close => 'بستن';

  @override
  String get closeMenu => 'بستن منو';

  @override
  String get openMenu => 'بازکردن منو';

  @override
  String get menu => 'منو';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get connecting => 'در حال اتصال…';

  @override
  String get stopping => 'در حال قطع اتصال…';

  @override
  String get localProxy => 'پروکسی محلی';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'لغو';

  @override
  String get save => 'ذخیره';

  @override
  String get saving => 'در حال ذخیره…';

  @override
  String get add => 'افزودن';

  @override
  String get edit => 'ویرایش';

  @override
  String get refresh => 'تازه‌سازی';

  @override
  String get validate => 'اعتبارسنجی';

  @override
  String get testConnection => 'آزمایش اتصال';

  @override
  String get copyDiagnostics => 'کپی اطلاعات عیب‌یابی';

  @override
  String get diagnosticsCopied => 'اطلاعات عیب‌یابی کپی شد.';

  @override
  String get diagnosticsCopyFailed => 'کپی اطلاعات عیب‌یابی ممکن نشد.';

  @override
  String get loadSubscriptionFirst =>
      'ابتدا در زبانهٔ اشتراک‌ها یک اشتراک اضافه کنید.';

  @override
  String serverRequiresCore(String p0) {
    return 'این سرور به $p0 نیاز دارد. آن را در تنظیمات انتخاب کنید.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'سرور انتخاب‌شده به $p0 نیاز دارد.';
  }

  @override
  String get insecureProfile =>
      'این پیکربندی تأیید گواهی TLS را غیرفعال می‌کند.';

  @override
  String get addSubscription => 'افزودن اشتراک';

  @override
  String get savedSubscriptions => 'اشتراک‌های ذخیره‌شده';

  @override
  String get noSubscriptions =>
      'هنوز اشتراکی وجود ندارد. برای شروع یک پیوند در بالا اضافه کنید.';

  @override
  String get activeSubscriptionNodes => 'سرورهای اشتراک فعال';

  @override
  String get chooseSubscription => 'انتخاب اشتراک';

  @override
  String get selectSubscription => 'اشتراک مورد استفاده را انتخاب کنید';

  @override
  String get refreshSubscription => 'تازه‌سازی اشتراک انتخاب‌شده';

  @override
  String get removeSubscription => 'حذف اشتراک انتخاب‌شده';

  @override
  String get subscriptionLink => 'پیوند اشتراک یا سرور…';

  @override
  String get pasteClipboard => 'چسباندن از کلیپ‌بورد';

  @override
  String get copyLinkFirst =>
      'ابتدا یک پیوند معتبر اشتراک یا سرور را کپی کنید.';

  @override
  String get clipboardReadFailed => 'خواندن کلیپ‌بورد ممکن نشد.';

  @override
  String get website => 'وب‌سایت';

  @override
  String get support => 'پشتیبانی';

  @override
  String get description => 'توضیحات';

  @override
  String get lastUpdated => 'آخرین به‌روزرسانی';

  @override
  String get expires => 'تاریخ انقضا';

  @override
  String get notUpdated => 'هنوز به‌روز نشده';

  @override
  String get notProvided => 'ارائه نشده';

  @override
  String get expired => 'منقضی شده';

  @override
  String openLink(String p0) {
    return 'بازکردن $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return 'پیوند $p0 ارائه نشده است';
  }

  @override
  String get openLinkFailed => 'بازکردن پیوند ممکن نشد.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'بازکردن پیوند $p0 ممکن نشد.';
  }

  @override
  String get disconnectSubscriptions =>
      'پیش از تغییر اشتراک‌ها، اتصال را قطع کنید.';

  @override
  String get disconnectServers => 'پیش از تغییر سرور، اتصال را قطع کنید.';

  @override
  String get disconnectRefresh => 'پیش از تازه‌سازی اشتراک، اتصال را قطع کنید.';

  @override
  String get disconnectRouting =>
      'پیش از ویرایش قوانین مسیریابی، اتصال را قطع کنید.';

  @override
  String get disconnectInstall => 'پیش از نصب به‌روزرسانی، اتصال را قطع کنید.';

  @override
  String get waitCurrentOperation => 'منتظر بمانید تا عملیات جاری تمام شود.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'پیش از $p0، اتصال را قطع کنید.';
  }

  @override
  String get changingCore => 'تغییر هسته';

  @override
  String get changingMode => 'تغییر حالت اتصال';

  @override
  String get changingDns => 'تغییر DNS';

  @override
  String get changingKillSwitch => 'تغییر قطع‌کن اضطراری';

  @override
  String get core => 'هسته';

  @override
  String get networkingCore => 'هستهٔ شبکه';

  @override
  String get coreHelp =>
      'هسته را به‌صورت دستی انتخاب کنید. هستهٔ مورد نیاز هر سرور در صفحهٔ اشتراک‌ها نمایش داده می‌شود.';

  @override
  String get connectionMode => 'حالت اتصال';

  @override
  String get connectionModeHelp =>
      'حالت VPN (TUN) ترافیک سیستم را خودکار مسیریابی می‌کند. در حالت پروکسی محلی باید پروکسی را در برنامه‌هایتان تنظیم کنید.';

  @override
  String get killSwitch => 'قطع‌کن اضطراری';

  @override
  String get killSwitchHelp =>
      'هنگام اتصال از DNS و مسیریابی TUN محافظت می‌کند. پس از قطع اتصال، دسترسی عادی به اینترنت برقرار می‌شود.';

  @override
  String get availableTun => 'در حالت VPN (TUN) در دسترس است.';

  @override
  String get quickSettings => 'تنظیمات سریع';

  @override
  String get quickSettingsSubtitle => 'اتصال از پنل اندروید';

  @override
  String get quickSettingsHelp =>
      'از کاشی AORA Connect برای اتصال به سرور انتخاب‌شده یا قطع اتصال استفاده کنید. برای بازکردن برنامه، کاشی را نگه دارید.';

  @override
  String get addQuickSettings => 'افزودن به تنظیمات سریع';

  @override
  String get tileAdded => 'کاشی AORA Connect به تنظیمات سریع اضافه شد.';

  @override
  String get tileAlreadyAdded =>
      'کاشی AORA Connect از قبل در تنظیمات سریع وجود دارد.';

  @override
  String get tileManual =>
      'تنظیمات سریع را باز کنید، روی ویرایش بزنید و کاشی AORA Connect را اضافه کنید.';

  @override
  String get tileDeclined => 'کاشی تنظیمات سریع اضافه نشد.';

  @override
  String get tileFailed =>
      'افزودن کاشی ممکن نشد. تنظیمات سریع را باز کنید و از بخش ویرایش، AORA Connect را اضافه کنید.';

  @override
  String get dnsServer => 'سرور DNS';

  @override
  String get dnsHelp =>
      'ارائه‌دهندهٔ DNS برای VPN (TUN). در حالت پروکسی محلی، DNS سیستم تغییر نمی‌کند.';

  @override
  String get serverChecks => 'آزمایش سرورها';

  @override
  String get serverPingMethod => 'روش آزمایش سرورها';

  @override
  String get serverChecksHelp =>
      'در آزمایش سرورها در سراسر برنامه اعمال می‌شود. آمار از ICMP زنده استفاده می‌کند. آزمایش‌های پروکسی، https://www.gstatic.com/generate_204 را از طریق هر سرور درخواست می‌کنند.';

  @override
  String get diagnostics => 'عیب‌یابی';

  @override
  String get diagnosticsSubtitle => 'اعتبارسنجی، آزمایش اتصال و گزارش‌ها';

  @override
  String get coreLogs => 'گزارش‌های هسته';

  @override
  String get noLogs => 'هنوز گزارشی وجود ندارد.';

  @override
  String get about => 'دربارهٔ برنامه';

  @override
  String get aboutClient => 'یک کلاینت VPN همه‌کاره و متن‌باز.';

  @override
  String get license => 'مجوز: GNU GPL نسخهٔ ۳ یا جدیدتر.';

  @override
  String get coresLicense =>
      'هسته‌های شبکه: sing-box و Xray. فایل‌های اجرایی و مجوزهای آن‌ها از برنامه مستقل هستند.';

  @override
  String get statistics => 'آمار';

  @override
  String get off => 'خاموش';

  @override
  String get pingMeasuring => 'تأخیر سرور · در حال اندازه‌گیری…';

  @override
  String get pingNoReply => 'تأخیر سرور · بدون پاسخ';

  @override
  String pingValue(String p0) {
    return 'تأخیر سرور · $p0';
  }

  @override
  String get connectStatistics => 'برای مشاهدهٔ آمار زندهٔ ICMP متصل شوید';

  @override
  String target(String p0) {
    return 'مقصد: $p0';
  }

  @override
  String get measuring => 'در حال اندازه‌گیری…';

  @override
  String get noReply => 'بدون پاسخ';

  @override
  String get waitingSamples => 'در انتظار نمونه‌ها';

  @override
  String replies(String p0, String p1) {
    return 'پاسخ‌ها: $p0/$p1';
  }

  @override
  String get pingHistory => 'تاریخچهٔ تأخیر سرور. ';

  @override
  String successfulChecks(String p0, String p1) {
    return 'از $p1 آزمایش انجام‌شده، $p0 مورد موفق بوده است.';
  }

  @override
  String get pingHistoryHelp =>
      'آزمایش تأخیر هر ثانیه · ۳۰ نمونهٔ اخیر. فاصله‌های خالی نشان‌دهندهٔ نبود پاسخ هستند.';

  @override
  String get connectCollectStatistics =>
      'برای جمع‌آوری نمونه‌های زندهٔ ICMP متصل شوید.';

  @override
  String get statisticsOff => 'آمار خاموش است.';

  @override
  String get lessOneMs => 'کمتر از ۱ میلی‌ثانیه';

  @override
  String milliseconds(String p0) {
    return '$p0 میلی‌ثانیه';
  }

  @override
  String get notChecked => 'آزمایش نشده';

  @override
  String get noCompletedCheck => 'هنوز آزمایش سروری انجام نشده است';

  @override
  String lastCheck(String p0, String p1) {
    return 'آخرین آزمایش در $p0:$p1';
  }

  @override
  String get checkServers => 'در حال آزمایش سرورها';

  @override
  String get cancelChecks => 'لغو آزمایش سرورها';

  @override
  String serverCheck(String p0) {
    return 'آزمایش سرور با $p0';
  }

  @override
  String get applicationsAddresses => 'برنامه‌ها و نشانی‌ها';

  @override
  String get routeListedItems => 'مسیریابی برنامه‌ها و نشانی‌های فهرست‌شده';

  @override
  String get listedThroughTunnel =>
      'موارد فهرست‌شده از تونل عبور می‌کنند. بقیهٔ ترافیک از اتصال عادی شما استفاده می‌کند.';

  @override
  String get listedBypassTunnel =>
      'موارد فهرست‌شده از اتصال عادی شما استفاده می‌کنند. بقیهٔ ترافیک از تونل عبور می‌کند.';

  @override
  String get routingDisabled =>
      'قوانین مسیریابی خاموش هستند. ترافیک از سرور VPN انتخاب‌شده عبور می‌کند.';

  @override
  String get useTunRouting =>
      'برای مسیریابی ترافیک سیستم از حالت VPN (TUN) استفاده کنید.';

  @override
  String get emptyThroughTunnel =>
      'هنوز موردی وجود ندارد. همهٔ ترافیک از تونل عبور می‌کند.';

  @override
  String get emptyBypassTunnel =>
      'هنوز موردی وجود ندارد. همهٔ ترافیک از اتصال عادی شما استفاده می‌کند.';

  @override
  String get addRule => 'افزودن قانون';

  @override
  String get addRoutingRule => 'افزودن قانون مسیریابی';

  @override
  String get editRoutingRule => 'ویرایش قانون مسیریابی';

  @override
  String get editRule => 'ویرایش قانون';

  @override
  String get deleteRule => 'حذف قانون';

  @override
  String get moveUp => 'انتقال به بالا';

  @override
  String get moveDown => 'انتقال به پایین';

  @override
  String enableTarget(String p0) {
    return 'فعال‌کردن $p0';
  }

  @override
  String get match => 'شرط تطبیق';

  @override
  String get value => 'مقدار';

  @override
  String get chooseApplication => 'انتخاب برنامه';

  @override
  String get installedApplications => 'برنامه‌های نصب‌شده';

  @override
  String get runningApplications => 'برنامه‌های در حال اجرا';

  @override
  String get searchApplications => 'جست‌وجوی برنامه‌ها';

  @override
  String get noMatchingApplications => 'برنامه‌ای پیدا نشد.';

  @override
  String get applicationsUnavailable => 'فهرست برنامه‌ها در دسترس نیست.';

  @override
  String get runningSelectionDesktop =>
      'انتخاب برنامه‌های در حال اجرا در نسخهٔ دسکتاپ در دسترس است.';

  @override
  String get runningReadFailed =>
      'خواندن فهرست برنامه‌های در حال اجرا ممکن نشد.';

  @override
  String get installedLoadFailed =>
      'بارگذاری برنامه‌ها ممکن نشد. دوباره تلاش کنید یا نام بسته را دستی وارد کنید.';

  @override
  String get runningLoadFailed =>
      'بارگذاری برنامه‌های در حال اجرا ممکن نشد. دوباره تلاش کنید یا نام فرایند را دستی وارد کنید.';

  @override
  String get updates => 'به‌روزرسانی‌ها';

  @override
  String version(String p0) {
    return 'نسخهٔ $p0';
  }

  @override
  String get automaticUpdates => 'بررسی خودکار هنگام اجرا';

  @override
  String get automaticUpdatesSemantics => 'بررسی خودکار به‌روزرسانی‌ها';

  @override
  String get checkUpdates => 'بررسی به‌روزرسانی';

  @override
  String get importUpdate => 'به‌روزرسانی از فایل';

  @override
  String get downloadUpdate => 'دانلود به‌روزرسانی';

  @override
  String get installUpdate => 'نصب به‌روزرسانی';

  @override
  String get install => 'نصب';

  @override
  String installVersion(String p0) {
    return 'نسخهٔ $p0 نصب شود؟';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect بسته می‌شود و پس از نصب دوباره باز خواهد شد. تنظیمات و اشتراک‌های شما حفظ می‌شوند.';

  @override
  String get androidInstallHelp =>
      'اندروید از شما تأیید نصب می‌خواهد. تنظیمات، اشتراک‌ها و قوانین مسیریابی شما حفظ می‌شوند.';

  @override
  String get androidApk => 'فایل APK برنامهٔ AORA برای اندروید';

  @override
  String get windowsInstaller => 'نصب‌کنندهٔ به‌روزرسانی AORA';

  @override
  String get additionalSources => 'منابع اضافی (اختیاری)';

  @override
  String additionalSourcesCount(String p0) {
    return 'منابع اضافی: $p0';
  }

  @override
  String get updateSources => 'منابع به‌روزرسانی';

  @override
  String get updateSourcesHelp =>
      'منابع جایگزین اختیاری. ابتدا GitHub بررسی می‌شود.';

  @override
  String get metadataUrlPerLine =>
      'در هر خط یک پیوند HTTPS برای فراداده وارد کنید';

  @override
  String updateAvailableNotification(String p0) {
    return 'به‌روزرسانی $p0 در تنظیمات ← به‌روزرسانی‌ها در دسترس است.';
  }

  @override
  String get notAvailable => 'در دسترس نیست';

  @override
  String get system => 'سیستم';

  @override
  String get idle => 'بی‌کار';

  @override
  String get throughTunnel => 'از طریق تونل';

  @override
  String get bypassingTunnel => 'خارج از تونل';

  @override
  String get application => 'برنامه';

  @override
  String get domainSubdomains => 'دامنه و زیردامنه‌ها';

  @override
  String get exactDomain => 'دامنهٔ دقیق';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'از طریق پروکسی GET';

  @override
  String get proxyHead => 'از طریق پروکسی HEAD';

  @override
  String get stateStopped => 'قطع شده';

  @override
  String get stateStarting => 'در حال اتصال';

  @override
  String get stateRunning => 'متصل';

  @override
  String get stateStopping => 'در حال قطع اتصال';

  @override
  String get timeout => 'پایان مهلت انتظار';

  @override
  String get failed => 'ناموفق';

  @override
  String get unavailable => 'در دسترس نیست';

  @override
  String get checkingUpdates => 'در حال بررسی به‌روزرسانی‌ها…';

  @override
  String get upToDate => 'به‌روزرسانی جدیدتری پیدا نشد';

  @override
  String updateAvailable(String p0) {
    return 'به‌روزرسانی $p0 در دسترس است';
  }

  @override
  String get downloadingUpdate => 'در حال دانلود به‌روزرسانی…';

  @override
  String get updateReady => 'به‌روزرسانی تأیید شده و آمادهٔ نصب است';

  @override
  String get verifyingUpdate => 'در حال بررسی فایل به‌روزرسانی…';

  @override
  String updateVersionReady(String p0) {
    return 'به‌روزرسانی $p0 تأیید شده و آمادهٔ نصب است';
  }

  @override
  String get updateFailed => 'تکمیل به‌روزرسانی ممکن نشد';

  @override
  String get installationCompleted => 'نصب کامل شد';

  @override
  String get trayShow => 'نمایش AORA Connect';

  @override
  String get trayExit => 'خروج';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روز باقی مانده',
      one: '$count روز باقی مانده',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سرور',
      one: '$count سرور',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'بارگذاری نشده';

  @override
  String skippedServers(int count) {
    return 'ردشده: $count';
  }

  @override
  String connectionVerified(String p0) {
    return 'اتصال تأیید شد ($p0 میلی‌ثانیه).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'اتصال HTTPS از طریق $p0 موفق بود ($p1 میلی‌ثانیه).';
  }

  @override
  String get routingValidationEmpty => 'یک مقدار وارد کنید.';

  @override
  String get routingValidationControlCharacters =>
      'نویسه‌های کنترلی مجاز نیستند.';

  @override
  String get routingValidationApplication =>
      'مسیر فایل اجرایی یا نام فرایند را بدون نویسه‌های جایگزین وارد کنید.';

  @override
  String get routingValidationDomain =>
      'دامنه را بدون پروتکل، مسیر یا نویسه‌های جایگزین وارد کنید.';

  @override
  String get routingValidationIp => 'یک نشانی IP یا محدودهٔ CIDR وارد کنید.';

  @override
  String get routingValidationPrefix => 'پیشوند CIDR نامعتبر است.';

  @override
  String get httpsSourcesOnly =>
      'منابع به‌روزرسانی باید پیوندهای HTTPS بدون نام کاربری یا گذرواژه باشند.';

  @override
  String get checkAllServers => 'آزمایش همهٔ سرورها';

  @override
  String get checkSelectedServer => 'آزمایش سرور انتخاب‌شده';
}
