import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_he.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('de'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('he'),
    Locale('ru'),
    Locale('zh'),
  ];

  String get language;

  String get interfaceLanguage;

  String get systemDefault;

  String get languageSaveFailed;

  String get settings;

  String get connection;

  String get subscriptions;

  String get routing;

  String get hideToTray;

  String get closeApp;

  String get close;

  String get closeMenu;

  String get openMenu;

  String get menu;

  String get connect;

  String get disconnect;

  String get connecting;

  String get stopping;

  String get localProxy;

  String get vpnTun;

  String get cancel;

  String get save;

  String get saving;

  String get add;

  String get edit;

  String get refresh;

  String get validate;

  String get testConnection;

  String get copyDiagnostics;

  String get diagnosticsCopied;

  String get diagnosticsCopyFailed;

  String get loadSubscriptionFirst;

  String serverRequiresCore(String p0);

  String selectedRequiresCore(String p0);

  String get insecureProfile;

  String get addSubscription;

  String get savedSubscriptions;

  String get noSubscriptions;

  String get activeSubscriptionNodes;

  String get chooseSubscription;

  String get selectSubscription;

  String get refreshSubscription;

  String get removeSubscription;

  String get subscriptionLink;

  String get pasteClipboard;

  String get copyLinkFirst;

  String get clipboardReadFailed;

  String get website;

  String get support;

  String get description;

  String get lastUpdated;

  String get expires;

  String get notUpdated;

  String get notProvided;

  String get expired;

  String openLink(String p0);

  String linkNotProvided(String p0);

  String get openLinkFailed;

  String openNamedLinkFailed(String p0);

  String get disconnectSubscriptions;

  String get disconnectServers;

  String get disconnectRefresh;

  String get disconnectRouting;

  String get disconnectInstall;

  String get waitCurrentOperation;

  String disconnectBeforeAction(String p0);

  String get changingCore;

  String get changingMode;

  String get changingDns;

  String get changingKillSwitch;

  String get core;

  String get networkingCore;

  String get coreHelp;

  String get connectionMode;

  String get connectionModeHelp;

  String get killSwitch;

  String get killSwitchHelp;

  String get availableTun;

  String get quickSettings;

  String get quickSettingsSubtitle;

  String get quickSettingsHelp;

  String get addQuickSettings;

  String get tileAdded;

  String get tileAlreadyAdded;

  String get tileManual;

  String get tileDeclined;

  String get tileFailed;

  String get dnsServer;

  String get dnsHelp;

  String get serverChecks;

  String get serverPingMethod;

  String get serverChecksHelp;

  String get diagnostics;

  String get diagnosticsSubtitle;

  String get coreLogs;

  String get noLogs;

  String get about;

  String get aboutClient;

  String get license;

  String get coresLicense;

  String get statistics;

  String get off;

  String get pingMeasuring;

  String get pingNoReply;

  String pingValue(String p0);

  String get connectStatistics;

  String target(String p0);

  String get measuring;

  String get noReply;

  String get waitingSamples;

  String replies(String p0, String p1);

  String get pingHistory;

  String successfulChecks(String p0, String p1);

  String get pingHistoryHelp;

  String get connectCollectStatistics;

  String get statisticsOff;

  String get lessOneMs;

  String milliseconds(String p0);

  String get notChecked;

  String get noCompletedCheck;

  String lastCheck(String p0, String p1);

  String get checkServers;

  String get cancelChecks;

  String serverCheck(String p0);

  String get applicationsAddresses;

  String get routeListedItems;

  String get listedThroughTunnel;

  String get listedBypassTunnel;

  String get routingDisabled;

  String get useTunRouting;

  String get emptyThroughTunnel;

  String get emptyBypassTunnel;

  String get addRule;

  String get addRoutingRule;

  String get editRoutingRule;

  String get editRule;

  String get deleteRule;

  String get moveUp;

  String get moveDown;

  String enableTarget(String p0);

  String get match;

  String get value;

  String get chooseApplication;

  String get installedApplications;

  String get runningApplications;

  String get searchApplications;

  String get noMatchingApplications;

  String get applicationsUnavailable;

  String get runningSelectionDesktop;

  String get runningReadFailed;

  String get installedLoadFailed;

  String get runningLoadFailed;

  String get updates;

  String version(String p0);

  String get automaticUpdates;

  String get automaticUpdatesSemantics;

  String get checkUpdates;

  String get importUpdate;

  String get downloadUpdate;

  String get installUpdate;

  String get install;

  String installVersion(String p0);

  String get windowsInstallHelp;

  String get androidInstallHelp;

  String get androidApk;

  String get windowsInstaller;

  String get additionalSources;

  String additionalSourcesCount(String p0);

  String get updateSources;

  String get updateSourcesHelp;

  String get metadataUrlPerLine;

  String updateAvailableNotification(String p0);

  String get notAvailable;

  String get system;

  String get idle;

  String get throughTunnel;

  String get bypassingTunnel;

  String get application;

  String get domainSubdomains;

  String get exactDomain;

  String get ipCidr;

  String get proxyGet;

  String get proxyHead;

  String get stateStopped;

  String get stateStarting;

  String get stateRunning;

  String get stateStopping;

  String get timeout;

  String get failed;

  String get unavailable;

  String get checkingUpdates;

  String get upToDate;

  String updateAvailable(String p0);

  String get downloadingUpdate;

  String get updateReady;

  String get verifyingUpdate;

  String updateVersionReady(String p0);

  String get updateFailed;

  String get installationCompleted;

  String get trayShow;

  String get trayExit;

  String daysLeft(int count);

  String serverCount(int count);

  String get notLoaded;

  String skippedServers(int count);

  String connectionVerified(String p0);

  String httpsSucceeded(String p0, String p1);

  String get routingValidationEmpty;

  String get routingValidationControlCharacters;

  String get routingValidationApplication;

  String get routingValidationDomain;

  String get routingValidationIp;

  String get routingValidationPrefix;

  String get httpsSourcesOnly;

  String get checkAllServers;

  String get checkSelectedServer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fa',
    'fr',
    'he',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'he':
      return AppLocalizationsHe();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
