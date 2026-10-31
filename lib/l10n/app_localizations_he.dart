// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get startup => 'הפעלה';

  @override
  String get manualStart => 'הפעלה ידנית';

  @override
  String get startWithWindows => 'הפעלה עם Windows';

  @override
  String get startWithWindowsHelp =>
      'פתיחת היישום המותקן בעת הכניסה ל־Windows.';

  @override
  String get startMinimized => 'הפעלה ממוזערת';

  @override
  String get startMinimizedHelp => 'השארת היישום במגש המערכת בעת ההפעלה.';

  @override
  String get startupConnectionHelp =>
      'פתיחת היישום אינה מחברת את ה־VPN אוטומטית.';

  @override
  String get startupLoadFailed =>
      'לא ניתן לטעון את הגדרות ההפעלה. יש לנסות שוב.';

  @override
  String get startupSaveFailed =>
      'לא ניתן לשמור את הגדרות ההפעלה. יש לרענן ולנסות שוב.';

  @override
  String get language => 'שפה';

  @override
  String get interfaceLanguage => 'שפת הממשק';

  @override
  String get systemDefault => 'ברירת המחדל של המערכת';

  @override
  String get languageSaveFailed => 'לא ניתן לשמור את העדפת השפה.';

  @override
  String get settings => 'הגדרות';

  @override
  String get connection => 'חיבור';

  @override
  String get subscriptions => 'מינויים';

  @override
  String get routing => 'ניתוב';

  @override
  String get hideToTray => 'הסתרה במגש המערכת';

  @override
  String get closeApp => 'סגירת היישום';

  @override
  String get close => 'סגירה';

  @override
  String get closeMenu => 'סגירת התפריט';

  @override
  String get openMenu => 'פתיחת התפריט';

  @override
  String get menu => 'תפריט';

  @override
  String get connect => 'התחברות';

  @override
  String get disconnect => 'ניתוק';

  @override
  String get connecting => 'מתחבר…';

  @override
  String get stopping => 'מתנתק…';

  @override
  String get localProxy => 'פרוקסי מקומי';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמירה';

  @override
  String get saving => 'שומר…';

  @override
  String get add => 'הוספה';

  @override
  String get edit => 'עריכה';

  @override
  String get refresh => 'רענון';

  @override
  String get validate => 'בדיקה';

  @override
  String get testConnection => 'חיבור';

  @override
  String get copyDiagnostics => 'העתקת נתוני אבחון';

  @override
  String get diagnosticsCopied => 'נתוני האבחון הועתקו.';

  @override
  String get diagnosticsCopyFailed => 'לא ניתן להעתיק את נתוני האבחון.';

  @override
  String get loadSubscriptionFirst => 'יש להוסיף תחילה מינוי בלשונית המינויים.';

  @override
  String serverRequiresCore(String p0) {
    return 'שרת זה דורש $p0. יש לבחור בליבה זו בהגדרות.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'השרת שנבחר דורש $p0.';
  }

  @override
  String get insecureProfile => 'בפרופיל זה אימות תעודת TLS מושבת.';

  @override
  String get addSubscription => 'הוספת מינוי';

  @override
  String get savedSubscriptions => 'מינויים שמורים';

  @override
  String get noSubscriptions => 'אין עדיין מינויים. יש להוסיף קישור למעלה.';

  @override
  String get activeSubscriptionNodes => 'שרתים במינוי הפעיל';

  @override
  String get chooseSubscription => 'בחירת מינוי';

  @override
  String get selectSubscription => 'בחירת מינוי פעיל';

  @override
  String get refreshSubscription => 'רענון המינוי שנבחר';

  @override
  String get removeSubscription => 'הסרת המינוי שנבחר';

  @override
  String get subscriptionLink => 'קישור למינוי או לשרת…';

  @override
  String get pasteClipboard => 'הדבקה מהלוח';

  @override
  String get copyLinkFirst => 'יש להעתיק תחילה קישור תקין למינוי או לשרת.';

  @override
  String get clipboardReadFailed => 'לא ניתן לקרוא את הלוח.';

  @override
  String get website => 'אתר';

  @override
  String get support => 'תמיכה';

  @override
  String get description => 'תיאור';

  @override
  String get lastUpdated => 'עדכון אחרון';

  @override
  String get expires => 'תוקף';

  @override
  String get notUpdated => 'לא עודכן';

  @override
  String get notProvided => 'לא צוין';

  @override
  String get expired => 'פג התוקף';

  @override
  String openLink(String p0) {
    return 'פתיחת $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return 'לא צוין קישור עבור $p0';
  }

  @override
  String get openLinkFailed => 'לא ניתן לפתוח את הקישור.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'לא ניתן לפתוח את הקישור עבור $p0.';
  }

  @override
  String get disconnectSubscriptions => 'יש להתנתק לפני שינוי מינויים.';

  @override
  String get disconnectServers => 'יש להתנתק לפני החלפת שרתים.';

  @override
  String get disconnectRefresh => 'יש להתנתק לפני רענון המינוי.';

  @override
  String get disconnectRouting => 'יש להתנתק לפני עריכת כללי ניתוב.';

  @override
  String get disconnectInstall => 'יש להתנתק לפני התקנת עדכון.';

  @override
  String get waitCurrentOperation => 'יש להמתין לסיום הפעולה הנוכחית.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'יש להתנתק לפני $p0.';
  }

  @override
  String get changingCore => 'החלפת הליבה';

  @override
  String get changingMode => 'שינוי מצב החיבור';

  @override
  String get changingDns => 'שינוי DNS';

  @override
  String get changingKillSwitch => 'שינוי Kill Switch';

  @override
  String get core => 'ליבה';

  @override
  String get networkingCore => 'ליבת רשת';

  @override
  String get coreHelp => 'יש לבחור את הליבה הנדרשת לשרת.';

  @override
  String get connectionMode => 'מצב חיבור';

  @override
  String get connectionModeHelp =>
      'מצב VPN (TUN) מנתב את תעבורת המערכת אוטומטית. בפרוקסי מקומי יש להגדיר פרוקסי ביישומים.';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchHelp => 'מגן מפני דליפות DNS ותעבורה בזמן החיבור.';

  @override
  String get availableTun => 'זמין במצב VPN (TUN).';

  @override
  String get quickSettings => 'הגדרות מהירות';

  @override
  String get quickSettingsSubtitle => 'חיבור מהחלונית';

  @override
  String get quickSettingsHelp =>
      'האריח מתחבר לשרת שנבחר או מנתק את ה־VPN. לחיצה ממושכת פותחת את היישום.';

  @override
  String get addQuickSettings => 'הוספת אריח';

  @override
  String get tileAdded => 'האריח של AORA Connect נוסף.';

  @override
  String get tileAlreadyAdded => 'האריח של AORA Connect כבר נוסף.';

  @override
  String get tileManual =>
      'יש לפתוח את ההגדרות המהירות, להקיש על עריכה ולגרור את AORA Connect אל האריחים.';

  @override
  String get tileDeclined => 'האריח לא נוסף.';

  @override
  String get tileFailed =>
      'לא ניתן להוסיף את האריח. יש לפתוח את ההגדרות המהירות ולהוסיף את AORA Connect באמצעות עריכה.';

  @override
  String get dnsServer => 'שרת DNS';

  @override
  String get dnsHelp =>
      'ספק DNS עבור VPN (TUN). מצב פרוקסי מקומי אינו משנה את DNS המערכת.';

  @override
  String get serverChecks => 'בדיקות שרתים';

  @override
  String get serverPingMethod => 'שיטת בדיקת השהיה';

  @override
  String get serverChecksHelp =>
      'חל על כל בדיקות השרתים. הסטטיסטיקה משתמשת ב־ICMP. בדיקות פרוקסי פונות אל https://www.gstatic.com/generate_204 דרך כל שרת.';

  @override
  String get diagnostics => 'אבחון';

  @override
  String get diagnosticsSubtitle => 'תצורה וחיבור';

  @override
  String get coreLogs => 'יומני הליבה';

  @override
  String get noLogs => 'אין עדיין יומנים.';

  @override
  String get about => 'אודות';

  @override
  String get aboutClient => 'לקוח VPN אוניברסלי בקוד פתוח.';

  @override
  String get license => 'רישיון: GNU GPL גרסה 3 ואילך.';

  @override
  String get coresLicense =>
      'ליבות רשת: sing-box ו־Xray. קובצי ההפעלה והרישיונות שלהן נפרדים מהיישום.';

  @override
  String get statistics => 'נתונים סטטיסטיים';

  @override
  String get off => 'כבוי';

  @override
  String get pingMeasuring => 'השהיה · מודד…';

  @override
  String get pingNoReply => 'השהיה · אין תגובה';

  @override
  String pingValue(String p0) {
    return 'השהיה · $p0';
  }

  @override
  String get connectStatistics => 'יש להתחבר לשרת כלשהו.';

  @override
  String target(String p0) {
    return 'כתובת: $p0';
  }

  @override
  String get measuring => 'מודד…';

  @override
  String get noReply => 'אין תגובה';

  @override
  String get waitingSamples => 'ממתין לדגימות';

  @override
  String replies(String p0, String p1) {
    return '$p0/$p1 תגובות';
  }

  @override
  String get pingHistory => 'היסטוריית השהיה. ';

  @override
  String successfulChecks(String p0, String p1) {
    return '$p0 מתוך $p1 בדיקות שהושלמו הצליחו.';
  }

  @override
  String get pingHistoryHelp =>
      'בדיקת השהיה מדי שנייה · 30 הדגימות האחרונות. פערים מציינים שלא התקבלה תגובה.';

  @override
  String get connectCollectStatistics =>
      'יש להתחבר כדי לאסוף דגימות ICMP בזמן אמת.';

  @override
  String get statisticsOff => 'הנתונים הסטטיסטיים כבויים.';

  @override
  String get lessOneMs => 'פחות מ־1 אלפית שנייה';

  @override
  String milliseconds(String p0) {
    return '$p0 אלפיות שנייה';
  }

  @override
  String get notChecked => 'לא נבדק';

  @override
  String get noCompletedCheck => 'עדיין לא הושלמה בדיקת שרת';

  @override
  String lastCheck(String p0, String p1) {
    return 'בדיקה אחרונה $p0:$p1';
  }

  @override
  String get checkServers => 'בודק שרתים';

  @override
  String get cancelChecks => 'ביטול בדיקות שרתים';

  @override
  String serverCheck(String p0) {
    return 'בדיקת שרת $p0';
  }

  @override
  String get applicationsAddresses => 'יישומים וכתובות';

  @override
  String get routeListedItems => 'ניתוב היישומים והכתובות שברשימה';

  @override
  String get listedThroughTunnel =>
      'הפריטים שברשימה עוברים דרך המנהרה. כל השאר משתמשים בחיבור הרגיל.';

  @override
  String get listedBypassTunnel =>
      'הפריטים שברשימה משתמשים בחיבור הרגיל. כל השאר עוברים דרך המנהרה.';

  @override
  String get routingDisabled =>
      'כללי הניתוב כבויים. התעבורה משתמשת בשרת ה־VPN שנבחר.';

  @override
  String get useTunRouting =>
      'יש להשתמש במצב VPN (TUN) כדי לנתב את תעבורת המערכת.';

  @override
  String get emptyThroughTunnel => 'אין עדיין פריטים. הכול עובר דרך המנהרה.';

  @override
  String get emptyBypassTunnel => 'אין עדיין פריטים. הכול משתמש בחיבור הרגיל.';

  @override
  String get addRule => 'הוספת כלל';

  @override
  String get addRoutingRule => 'הוספת כלל ניתוב';

  @override
  String get editRoutingRule => 'עריכת כלל ניתוב';

  @override
  String get editRule => 'עריכת כלל';

  @override
  String get deleteRule => 'מחיקת כלל';

  @override
  String get moveUp => 'העברה למעלה';

  @override
  String get moveDown => 'העברה למטה';

  @override
  String enableTarget(String p0) {
    return 'הפעלת $p0';
  }

  @override
  String get match => 'סוג כלל';

  @override
  String get value => 'ערך';

  @override
  String get chooseApplication => 'בחירת יישום';

  @override
  String get installedApplications => 'יישומים מותקנים';

  @override
  String get runningApplications => 'יישומים פועלים';

  @override
  String get searchApplications => 'חיפוש יישומים';

  @override
  String get noMatchingApplications => 'לא נמצאו יישומים תואמים.';

  @override
  String get applicationsUnavailable => 'רשימת היישומים אינה זמינה.';

  @override
  String get runningSelectionDesktop =>
      'בחירת יישומים פועלים זמינה במחשב בלבד.';

  @override
  String get runningReadFailed => 'לא ניתן לקרוא את רשימת היישומים הפועלים.';

  @override
  String get installedLoadFailed =>
      'לא ניתן לטעון יישומים. יש לנסות שוב או להזין שם חבילה ידנית.';

  @override
  String get runningLoadFailed =>
      'לא ניתן לטעון יישומים פועלים. יש לנסות שוב או להזין שם תהליך ידנית.';

  @override
  String get updates => 'עדכונים';

  @override
  String version(String p0) {
    return 'גרסה $p0';
  }

  @override
  String get automaticUpdates => 'בדיקה בעת ההפעלה';

  @override
  String get automaticUpdatesSemantics => 'בדיקת עדכונים אוטומטית';

  @override
  String get checkUpdates => 'בדיקה';

  @override
  String get importUpdate => 'מקובץ';

  @override
  String get downloadUpdate => 'הורדת עדכון';

  @override
  String get installUpdate => 'התקנת עדכון';

  @override
  String get install => 'התקנה';

  @override
  String installVersion(String p0) {
    return 'להתקין את $p0?';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect ייסגר וייפתח מחדש לאחר ההתקנה. ההגדרות והמינויים יישמרו.';

  @override
  String get androidInstallHelp =>
      'Android יבקש לאשר את ההתקנה. ההגדרות, המינויים וכללי הניתוב יישמרו.';

  @override
  String get androidApk => 'קובץ APK של AORA ל־Android';

  @override
  String get windowsInstaller => 'תוכנית התקנת עדכון של AORA';

  @override
  String get additionalSources => 'מקורות נוספים';

  @override
  String additionalSourcesCount(String p0) {
    return '$p0 מקורות נוספים';
  }

  @override
  String get updateSources => 'מקורות עדכון';

  @override
  String get updateSourcesHelp =>
      'שרתי מראה לבחירה. תחילה מתבצע ניסיון דרך GitHub.';

  @override
  String get metadataUrlPerLine => 'כתובת HTTPS אחת למטא־נתונים בכל שורה';

  @override
  String updateAvailableNotification(String p0) {
    return 'עדכון $p0 זמין בהגדרות ← עדכונים.';
  }

  @override
  String get notAvailable => 'לא זמין';

  @override
  String get system => 'מערכת';

  @override
  String get idle => 'לא פעיל';

  @override
  String get throughTunnel => 'דרך המנהרה';

  @override
  String get bypassingTunnel => 'עקיפת המנהרה';

  @override
  String get application => 'יישום';

  @override
  String get domainSubdomains => 'שם מתחם ותתי־מתחמים';

  @override
  String get exactDomain => 'שם מתחם מדויק';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'דרך פרוקסי GET';

  @override
  String get proxyHead => 'דרך פרוקסי HEAD';

  @override
  String get stateStopped => 'מנותק';

  @override
  String get stateStarting => 'מתחבר';

  @override
  String get stateRunning => 'מחובר';

  @override
  String get stateStopping => 'מתנתק';

  @override
  String get timeout => 'תם הזמן הקצוב';

  @override
  String get failed => 'נכשל';

  @override
  String get unavailable => 'לא זמין';

  @override
  String get checkingUpdates => 'בודק עדכונים…';

  @override
  String get upToDate => 'לא נמצא עדכון חדש יותר';

  @override
  String updateAvailable(String p0) {
    return 'עדכון $p0 זמין';
  }

  @override
  String get downloadingUpdate => 'מוריד עדכון…';

  @override
  String get updateReady => 'העדכון אומת ומוכן להתקנה';

  @override
  String get verifyingUpdate => 'מאמת את קובץ העדכון…';

  @override
  String updateVersionReady(String p0) {
    return 'עדכון $p0 אומת ומוכן להתקנה';
  }

  @override
  String get updateFailed => 'לא ניתן להשלים את העדכון';

  @override
  String get installationCompleted => 'ההתקנה הושלמה';

  @override
  String get trayShow => 'פתיחת AORA Connect';

  @override
  String get trayExit => 'יציאה';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נותרו $count ימים',
      two: 'נותרו יומיים',
      one: 'נותר יום אחד',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שרתים',
      two: 'שני שרתים',
      one: 'שרת אחד',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'לא נטען';

  @override
  String skippedServers(int count) {
    return '$count דולגו';
  }

  @override
  String connectionVerified(String p0) {
    return 'החיבור אומת ($p0 אלפיות שנייה).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'HTTPS דרך $p0 הצליח ($p1 אלפיות שנייה).';
  }

  @override
  String get routingValidationEmpty => 'יש להזין ערך.';

  @override
  String get routingValidationControlCharacters => 'אין להשתמש בתווי בקרה.';

  @override
  String get routingValidationApplication =>
      'יש להזין נתיב לקובץ הפעלה או שם תהליך, ללא תווים כלליים.';

  @override
  String get routingValidationDomain =>
      'יש להזין שם מתחם ללא סכמת כתובת, נתיב או תו כללי.';

  @override
  String get routingValidationIp => 'יש להזין כתובת IP או טווח CIDR.';

  @override
  String get routingValidationPrefix => 'קידומת CIDR אינה תקינה.';

  @override
  String get httpsSourcesOnly =>
      'מקורות עדכון חייבים להיות כתובות HTTPS ללא פרטי הזדהות.';

  @override
  String get checkAllServers => 'בדיקת כל השרתים';

  @override
  String get checkSelectedServer => 'בדיקת השרת שנבחר';
}
