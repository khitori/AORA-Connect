// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get language => 'اللغة';

  @override
  String get interfaceLanguage => 'لغة الواجهة';

  @override
  String get systemDefault => 'لغة النظام';

  @override
  String get languageSaveFailed => 'تعذّر حفظ اللغة المختارة.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get connection => 'الاتصال';

  @override
  String get subscriptions => 'الاشتراكات';

  @override
  String get routing => 'التوجيه';

  @override
  String get hideToTray => 'تصغير إلى منطقة الإشعارات';

  @override
  String get closeApp => 'إغلاق التطبيق';

  @override
  String get close => 'إغلاق';

  @override
  String get closeMenu => 'إغلاق القائمة';

  @override
  String get openMenu => 'فتح القائمة';

  @override
  String get menu => 'القائمة';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get connecting => 'جارٍ الاتصال…';

  @override
  String get stopping => 'جارٍ قطع الاتصال…';

  @override
  String get localProxy => 'وكيل محلي';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get saving => 'جارٍ الحفظ…';

  @override
  String get add => 'إضافة';

  @override
  String get edit => 'تعديل';

  @override
  String get refresh => 'تحديث';

  @override
  String get validate => 'التحقق من الإعدادات';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get copyDiagnostics => 'نسخ معلومات التشخيص';

  @override
  String get diagnosticsCopied => 'نُسخت معلومات التشخيص.';

  @override
  String get diagnosticsCopyFailed => 'تعذّر نسخ معلومات التشخيص.';

  @override
  String get loadSubscriptionFirst => 'أضف اشتراكًا أولًا من تبويب الاشتراكات.';

  @override
  String serverRequiresCore(String p0) {
    return 'يتطلب هذا الخادم $p0. اختره من الإعدادات.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'يتطلب الخادم المحدد $p0.';
  }

  @override
  String get insecureProfile => 'يُعطّل هذا الملف التحقق من شهادة TLS.';

  @override
  String get addSubscription => 'إضافة اشتراك';

  @override
  String get savedSubscriptions => 'الاشتراكات المحفوظة';

  @override
  String get noSubscriptions => 'لا توجد اشتراكات بعد. أضف رابطًا أعلاه للبدء.';

  @override
  String get activeSubscriptionNodes => 'خوادم الاشتراك النشط';

  @override
  String get chooseSubscription => 'اختيار اشتراك';

  @override
  String get selectSubscription => 'اختر الاشتراك الذي تريد استخدامه';

  @override
  String get refreshSubscription => 'تحديث الاشتراك المحدد';

  @override
  String get removeSubscription => 'إزالة الاشتراك المحدد';

  @override
  String get subscriptionLink => 'رابط الاشتراك أو الخادم…';

  @override
  String get pasteClipboard => 'لصق من الحافظة';

  @override
  String get copyLinkFirst => 'انسخ أولًا رابط اشتراك أو خادم صالحًا.';

  @override
  String get clipboardReadFailed => 'تعذّرت قراءة الحافظة.';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get support => 'الدعم';

  @override
  String get description => 'الوصف';

  @override
  String get lastUpdated => 'آخر تحديث';

  @override
  String get expires => 'تاريخ الانتهاء';

  @override
  String get notUpdated => 'لم يُحدّث بعد';

  @override
  String get notProvided => 'غير محدد';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String openLink(String p0) {
    return 'فتح $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return 'لم يُوفَّر رابط $p0';
  }

  @override
  String get openLinkFailed => 'تعذّر فتح الرابط.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'تعذّر فتح رابط $p0.';
  }

  @override
  String get disconnectSubscriptions => 'اقطع الاتصال قبل تغيير الاشتراكات.';

  @override
  String get disconnectServers => 'اقطع الاتصال قبل تغيير الخادم.';

  @override
  String get disconnectRefresh => 'اقطع الاتصال قبل تحديث اشتراكك.';

  @override
  String get disconnectRouting => 'اقطع الاتصال قبل تعديل قواعد التوجيه.';

  @override
  String get disconnectInstall => 'اقطع الاتصال قبل تثبيت أي تحديث.';

  @override
  String get waitCurrentOperation => 'انتظر حتى تنتهي العملية الحالية.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'اقطع الاتصال قبل $p0.';
  }

  @override
  String get changingCore => 'تغيير المحرّك';

  @override
  String get changingMode => 'تغيير وضع الاتصال';

  @override
  String get changingDns => 'تغيير DNS';

  @override
  String get changingKillSwitch => 'تغيير قاطع الاتصال';

  @override
  String get core => 'المحرّك';

  @override
  String get networkingCore => 'محرّك الشبكة';

  @override
  String get coreHelp =>
      'اختر المحرّك يدويًا. يُعرض المحرّك المطلوب لكل خادم في صفحة الاشتراكات.';

  @override
  String get connectionMode => 'وضع الاتصال';

  @override
  String get connectionModeHelp =>
      'يوجّه وضع VPN (TUN) حركة مرور النظام تلقائيًا. ويتطلب الوكيل المحلي إعداد الوكيل داخل تطبيقاتك.';

  @override
  String get killSwitch => 'قاطع الاتصال';

  @override
  String get killSwitchHelp =>
      'يحمي DNS وتوجيه TUN أثناء الاتصال. ويعود الوصول العادي إلى الإنترنت بعد قطع الاتصال.';

  @override
  String get availableTun => 'متاح في وضع VPN (TUN).';

  @override
  String get quickSettings => 'الإعدادات السريعة';

  @override
  String get quickSettingsSubtitle => 'الاتصال من لوحة Android';

  @override
  String get quickSettingsHelp =>
      'استخدم مربع AORA Connect للاتصال بالخادم المحدد أو قطع الاتصال. اضغط عليه مطولًا لفتح التطبيق.';

  @override
  String get addQuickSettings => 'إضافة إلى الإعدادات السريعة';

  @override
  String get tileAdded => 'أُضيف AORA Connect إلى الإعدادات السريعة.';

  @override
  String get tileAlreadyAdded =>
      'AORA Connect موجود بالفعل في الإعدادات السريعة.';

  @override
  String get tileManual =>
      'افتح الإعدادات السريعة، واضغط على تعديل، ثم أضف مربع AORA Connect.';

  @override
  String get tileDeclined => 'لم يُضف مربع الإعدادات السريعة.';

  @override
  String get tileFailed =>
      'تعذّرت إضافة المربع. افتح الإعدادات السريعة وأضف AORA Connect من خيار تعديل.';

  @override
  String get dnsServer => 'خادم DNS';

  @override
  String get dnsHelp =>
      'مزوّد DNS لوضع VPN (TUN). لا تُغيَّر إعدادات DNS على مستوى النظام في وضع الوكيل المحلي.';

  @override
  String get serverChecks => 'فحص الخوادم';

  @override
  String get serverPingMethod => 'طريقة فحص الخوادم';

  @override
  String get serverChecksHelp =>
      'يُطبّق على فحوص الخوادم في التطبيق كله. تستخدم الإحصاءات ICMP المباشر. تطلب فحوص الوكيل https://www.gstatic.com/generate_204 عبر كل خادم.';

  @override
  String get diagnostics => 'التشخيص';

  @override
  String get diagnosticsSubtitle => 'التحقق واختبار الاتصال والسجلات';

  @override
  String get coreLogs => 'سجلات المحرّك';

  @override
  String get noLogs => 'لا توجد سجلات بعد.';

  @override
  String get about => 'حول التطبيق';

  @override
  String get aboutClient => 'عميل VPN عام ومفتوح المصدر.';

  @override
  String get license => 'الترخيص: GNU GPL، الإصدار 3 أو أحدث.';

  @override
  String get coresLicense =>
      'محرّكا الشبكة: sing-box وXray. ملفاتهما التنفيذية وتراخيصهما مستقلة عن التطبيق.';

  @override
  String get statistics => 'الإحصاءات';

  @override
  String get off => 'معطّل';

  @override
  String get pingMeasuring => 'زمن استجابة الخادم · جارٍ القياس…';

  @override
  String get pingNoReply => 'زمن استجابة الخادم · لا توجد استجابة';

  @override
  String pingValue(String p0) {
    return 'زمن استجابة الخادم · $p0';
  }

  @override
  String get connectStatistics => 'اتصل لعرض إحصاءات ICMP المباشرة';

  @override
  String target(String p0) {
    return 'الهدف: $p0';
  }

  @override
  String get measuring => 'جارٍ القياس…';

  @override
  String get noReply => 'لا توجد استجابة';

  @override
  String get waitingSamples => 'في انتظار القياسات';

  @override
  String replies(String p0, String p1) {
    return 'الاستجابات: $p0/$p1';
  }

  @override
  String get pingHistory => 'سجل زمن استجابة الخادم. ';

  @override
  String successfulChecks(String p0, String p1) {
    return 'نجح $p0 من أصل $p1 من الفحوص المكتملة.';
  }

  @override
  String get pingHistoryHelp =>
      'قياس كل ثانية · آخر 30 قياسًا. تشير الفراغات إلى عدم وجود استجابة.';

  @override
  String get connectCollectStatistics => 'اتصل لجمع قياسات ICMP المباشرة.';

  @override
  String get statisticsOff => 'الإحصاءات معطّلة.';

  @override
  String get lessOneMs => 'أقل من 1 مللي ثانية';

  @override
  String milliseconds(String p0) {
    return '$p0 مللي ثانية';
  }

  @override
  String get notChecked => 'لم يُفحص';

  @override
  String get noCompletedCheck => 'لم يكتمل أي فحص للخوادم بعد';

  @override
  String lastCheck(String p0, String p1) {
    return 'آخر فحص في $p0:$p1';
  }

  @override
  String get checkServers => 'جارٍ فحص الخوادم';

  @override
  String get cancelChecks => 'إلغاء فحص الخوادم';

  @override
  String serverCheck(String p0) {
    return 'فحص الخادم عبر $p0';
  }

  @override
  String get applicationsAddresses => 'التطبيقات والعناوين';

  @override
  String get routeListedItems => 'توجيه التطبيقات والعناوين المدرجة';

  @override
  String get listedThroughTunnel =>
      'تمر العناصر المدرجة عبر النفق. ويستخدم كل ما عداها اتصالك العادي.';

  @override
  String get listedBypassTunnel =>
      'تستخدم العناصر المدرجة اتصالك العادي. ويمر كل ما عداها عبر النفق.';

  @override
  String get routingDisabled =>
      'قواعد التوجيه معطّلة. تمر حركة المرور عبر خادم VPN المحدد.';

  @override
  String get useTunRouting => 'استخدم وضع VPN (TUN) لتوجيه حركة مرور النظام.';

  @override
  String get emptyThroughTunnel =>
      'لا توجد عناصر بعد. تمر حركة المرور كلها عبر النفق.';

  @override
  String get emptyBypassTunnel =>
      'لا توجد عناصر بعد. تستخدم حركة المرور كلها اتصالك العادي.';

  @override
  String get addRule => 'إضافة قاعدة';

  @override
  String get addRoutingRule => 'إضافة قاعدة توجيه';

  @override
  String get editRoutingRule => 'تعديل قاعدة التوجيه';

  @override
  String get editRule => 'تعديل القاعدة';

  @override
  String get deleteRule => 'حذف القاعدة';

  @override
  String get moveUp => 'نقل إلى الأعلى';

  @override
  String get moveDown => 'نقل إلى الأسفل';

  @override
  String enableTarget(String p0) {
    return 'تفعيل $p0';
  }

  @override
  String get match => 'شرط المطابقة';

  @override
  String get value => 'القيمة';

  @override
  String get chooseApplication => 'اختيار تطبيق';

  @override
  String get installedApplications => 'التطبيقات المثبتة';

  @override
  String get runningApplications => 'التطبيقات قيد التشغيل';

  @override
  String get searchApplications => 'البحث عن التطبيقات';

  @override
  String get noMatchingApplications => 'لا توجد تطبيقات مطابقة.';

  @override
  String get applicationsUnavailable => 'قائمة التطبيقات غير متاحة.';

  @override
  String get runningSelectionDesktop =>
      'اختيار التطبيقات قيد التشغيل متاح على الحاسوب.';

  @override
  String get runningReadFailed => 'تعذّرت قراءة قائمة التطبيقات قيد التشغيل.';

  @override
  String get installedLoadFailed =>
      'تعذّر تحميل التطبيقات. أعد المحاولة أو أدخل اسم الحزمة يدويًا.';

  @override
  String get runningLoadFailed =>
      'تعذّر تحميل التطبيقات قيد التشغيل. أعد المحاولة أو أدخل اسم العملية يدويًا.';

  @override
  String get updates => 'التحديثات';

  @override
  String version(String p0) {
    return 'الإصدار $p0';
  }

  @override
  String get automaticUpdates => 'الفحص تلقائيًا عند التشغيل';

  @override
  String get automaticUpdatesSemantics => 'البحث عن التحديثات تلقائيًا';

  @override
  String get checkUpdates => 'البحث عن تحديثات';

  @override
  String get importUpdate => 'التحديث من ملف';

  @override
  String get downloadUpdate => 'تنزيل التحديث';

  @override
  String get installUpdate => 'تثبيت التحديث';

  @override
  String get install => 'تثبيت';

  @override
  String installVersion(String p0) {
    return 'هل تريد تثبيت $p0؟';
  }

  @override
  String get windowsInstallHelp =>
      'سيُغلق AORA Connect ثم يُفتح مجددًا بعد التثبيت. ستُحفظ إعداداتك واشتراكاتك.';

  @override
  String get androidInstallHelp =>
      'سيطلب Android تأكيد التثبيت. ستُحفظ إعداداتك واشتراكاتك وقواعد التوجيه.';

  @override
  String get androidApk => 'ملف APK لتطبيق AORA على Android';

  @override
  String get windowsInstaller => 'مثبّت تحديث AORA';

  @override
  String get additionalSources => 'مصادر إضافية (اختياري)';

  @override
  String additionalSourcesCount(String p0) {
    return 'المصادر الإضافية: $p0';
  }

  @override
  String get updateSources => 'مصادر التحديث';

  @override
  String get updateSourcesHelp => 'مرايا اختيارية. يُجرَّب GitHub أولًا.';

  @override
  String get metadataUrlPerLine => 'رابط HTTPS واحد للبيانات الوصفية في كل سطر';

  @override
  String updateAvailableNotification(String p0) {
    return 'التحديث $p0 متاح في الإعدادات ← التحديثات.';
  }

  @override
  String get notAvailable => 'غير متاح';

  @override
  String get system => 'النظام';

  @override
  String get idle => 'خامل';

  @override
  String get throughTunnel => 'عبر النفق';

  @override
  String get bypassingTunnel => 'خارج النفق';

  @override
  String get application => 'تطبيق';

  @override
  String get domainSubdomains => 'النطاق ونطاقاته الفرعية';

  @override
  String get exactDomain => 'النطاق المحدد فقط';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'عبر الوكيل GET';

  @override
  String get proxyHead => 'عبر الوكيل HEAD';

  @override
  String get stateStopped => 'غير متصل';

  @override
  String get stateStarting => 'جارٍ الاتصال';

  @override
  String get stateRunning => 'متصل';

  @override
  String get stateStopping => 'جارٍ قطع الاتصال';

  @override
  String get timeout => 'انتهت مهلة الانتظار';

  @override
  String get failed => 'فشل';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get checkingUpdates => 'جارٍ البحث عن تحديثات…';

  @override
  String get upToDate => 'لم يُعثر على تحديث أحدث';

  @override
  String updateAvailable(String p0) {
    return 'التحديث $p0 متاح';
  }

  @override
  String get downloadingUpdate => 'جارٍ تنزيل التحديث…';

  @override
  String get updateReady => 'تم التحقق من التحديث وهو جاهز للتثبيت';

  @override
  String get verifyingUpdate => 'جارٍ التحقق من ملف التحديث…';

  @override
  String updateVersionReady(String p0) {
    return 'تم التحقق من التحديث $p0 وهو جاهز للتثبيت';
  }

  @override
  String get updateFailed => 'تعذّر إكمال التحديث';

  @override
  String get installationCompleted => 'اكتمل التثبيت';

  @override
  String get trayShow => 'إظهار AORA Connect';

  @override
  String get trayExit => 'خروج';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم متبقٍ',
      many: '$count يومًا متبقيًا',
      few: '$count أيام متبقية',
      two: 'يومان متبقيان',
      one: 'يوم واحد متبقٍ',
      zero: 'لم يتبقَّ أي يوم',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خادم',
      many: '$count خادمًا',
      few: '$count خوادم',
      two: 'خادمان',
      one: 'خادم واحد',
      zero: 'لا توجد خوادم',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'غير محمّل';

  @override
  String skippedServers(int count) {
    return 'تم تخطي $count';
  }

  @override
  String connectionVerified(String p0) {
    return 'تم التحقق من الاتصال ($p0 مللي ثانية).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'نجح اتصال HTTPS عبر $p0 ($p1 مللي ثانية).';
  }

  @override
  String get routingValidationEmpty => 'أدخل قيمة.';

  @override
  String get routingValidationControlCharacters =>
      'محارف التحكم غير مسموح بها.';

  @override
  String get routingValidationApplication =>
      'أدخل مسار ملف تنفيذي أو اسم عملية دون أحرف بدل.';

  @override
  String get routingValidationDomain =>
      'أدخل نطاقًا دون بروتوكول أو مسار أو أحرف بدل.';

  @override
  String get routingValidationIp => 'أدخل عنوان IP أو نطاق CIDR.';

  @override
  String get routingValidationPrefix => 'بادئة CIDR غير صالحة.';

  @override
  String get httpsSourcesOnly =>
      'يجب أن تكون مصادر التحديث روابط HTTPS دون بيانات اعتماد.';

  @override
  String get checkAllServers => 'فحص كل الخوادم';

  @override
  String get checkSelectedServer => 'فحص الخادم المحدد';
}
