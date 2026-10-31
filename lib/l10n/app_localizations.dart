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

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
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

  /// No description provided for @startup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get startup;

  /// No description provided for @manualStart.
  ///
  /// In en, this message translates to:
  /// **'Start manually'**
  String get manualStart;

  /// No description provided for @startWithWindows.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get startWithWindows;

  /// No description provided for @startWithWindowsHelp.
  ///
  /// In en, this message translates to:
  /// **'Open the installed app when you sign in to Windows.'**
  String get startWithWindowsHelp;

  /// No description provided for @startMinimized.
  ///
  /// In en, this message translates to:
  /// **'Start minimized'**
  String get startMinimized;

  /// No description provided for @startMinimizedHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep the app in the system tray when it starts.'**
  String get startMinimizedHelp;

  /// No description provided for @startupConnectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Opening the app does not connect the VPN automatically.'**
  String get startupConnectionHelp;

  /// No description provided for @startupLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load startup settings. Try again.'**
  String get startupLoadFailed;

  /// No description provided for @startupSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save startup settings. Refresh and try again.'**
  String get startupSaveFailed;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get interfaceLanguage;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the language preference.'**
  String get languageSaveFailed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @routing.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get routing;

  /// No description provided for @hideToTray.
  ///
  /// In en, this message translates to:
  /// **'Hide to tray'**
  String get hideToTray;

  /// No description provided for @closeApp.
  ///
  /// In en, this message translates to:
  /// **'Close app'**
  String get closeApp;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeMenu.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get closeMenu;

  /// No description provided for @openMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get openMenu;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @stopping.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get stopping;

  /// No description provided for @localProxy.
  ///
  /// In en, this message translates to:
  /// **'Local proxy'**
  String get localProxy;

  /// No description provided for @vpnTun.
  ///
  /// In en, this message translates to:
  /// **'VPN (TUN)'**
  String get vpnTun;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @validate.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get validate;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testConnection;

  /// No description provided for @copyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get copyDiagnostics;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied.'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy diagnostics.'**
  String get diagnosticsCopyFailed;

  /// No description provided for @loadSubscriptionFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a subscription in the Subscriptions tab first.'**
  String get loadSubscriptionFirst;

  /// No description provided for @serverRequiresCore.
  ///
  /// In en, this message translates to:
  /// **'This server requires {p0}. Select it in Settings.'**
  String serverRequiresCore(String p0);

  /// No description provided for @selectedRequiresCore.
  ///
  /// In en, this message translates to:
  /// **'Selected server requires {p0}.'**
  String selectedRequiresCore(String p0);

  /// No description provided for @insecureProfile.
  ///
  /// In en, this message translates to:
  /// **'This profile disables TLS certificate verification.'**
  String get insecureProfile;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// No description provided for @savedSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Saved subscriptions'**
  String get savedSubscriptions;

  /// No description provided for @noSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet. Add a link above.'**
  String get noSubscriptions;

  /// No description provided for @activeSubscriptionNodes.
  ///
  /// In en, this message translates to:
  /// **'Servers in active subscription'**
  String get activeSubscriptionNodes;

  /// No description provided for @chooseSubscription.
  ///
  /// In en, this message translates to:
  /// **'Choose a subscription'**
  String get chooseSubscription;

  /// No description provided for @selectSubscription.
  ///
  /// In en, this message translates to:
  /// **'Choose an active subscription'**
  String get selectSubscription;

  /// No description provided for @refreshSubscription.
  ///
  /// In en, this message translates to:
  /// **'Refresh selected subscription'**
  String get refreshSubscription;

  /// No description provided for @removeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Remove selected subscription'**
  String get removeSubscription;

  /// No description provided for @subscriptionLink.
  ///
  /// In en, this message translates to:
  /// **'Subscription or server link…'**
  String get subscriptionLink;

  /// No description provided for @pasteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteClipboard;

  /// No description provided for @copyLinkFirst.
  ///
  /// In en, this message translates to:
  /// **'Copy a valid subscription or server link first.'**
  String get copyLinkFirst;

  /// No description provided for @clipboardReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the clipboard.'**
  String get clipboardReadFailed;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @notUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not updated'**
  String get notUpdated;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open {p0}'**
  String openLink(String p0);

  /// No description provided for @linkNotProvided.
  ///
  /// In en, this message translates to:
  /// **'{p0} link not provided'**
  String linkNotProvided(String p0);

  /// No description provided for @openLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open link.'**
  String get openLinkFailed;

  /// No description provided for @openNamedLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {p0} link.'**
  String openNamedLinkFailed(String p0);

  /// No description provided for @disconnectSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before changing subscriptions.'**
  String get disconnectSubscriptions;

  /// No description provided for @disconnectServers.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before changing servers.'**
  String get disconnectServers;

  /// No description provided for @disconnectRefresh.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before refreshing your subscription.'**
  String get disconnectRefresh;

  /// No description provided for @disconnectRouting.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before editing routing rules.'**
  String get disconnectRouting;

  /// No description provided for @disconnectInstall.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before installing an update.'**
  String get disconnectInstall;

  /// No description provided for @waitCurrentOperation.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current operation to finish.'**
  String get waitCurrentOperation;

  /// No description provided for @disconnectBeforeAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before {p0}.'**
  String disconnectBeforeAction(String p0);

  /// No description provided for @changingCore.
  ///
  /// In en, this message translates to:
  /// **'changing the core'**
  String get changingCore;

  /// No description provided for @changingMode.
  ///
  /// In en, this message translates to:
  /// **'changing connection mode'**
  String get changingMode;

  /// No description provided for @changingDns.
  ///
  /// In en, this message translates to:
  /// **'changing DNS'**
  String get changingDns;

  /// No description provided for @changingKillSwitch.
  ///
  /// In en, this message translates to:
  /// **'changing Kill Switch'**
  String get changingKillSwitch;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @networkingCore.
  ///
  /// In en, this message translates to:
  /// **'Networking core'**
  String get networkingCore;

  /// No description provided for @coreHelp.
  ///
  /// In en, this message translates to:
  /// **'Select the core required by your server.'**
  String get coreHelp;

  /// No description provided for @connectionMode.
  ///
  /// In en, this message translates to:
  /// **'Connection mode'**
  String get connectionMode;

  /// No description provided for @connectionModeHelp.
  ///
  /// In en, this message translates to:
  /// **'VPN (TUN) routes system traffic automatically. Local proxy requires proxy configuration in your applications.'**
  String get connectionModeHelp;

  /// No description provided for @killSwitch.
  ///
  /// In en, this message translates to:
  /// **'Kill Switch'**
  String get killSwitch;

  /// No description provided for @killSwitchHelp.
  ///
  /// In en, this message translates to:
  /// **'Protects against DNS and traffic leaks while connected.'**
  String get killSwitchHelp;

  /// No description provided for @availableTun.
  ///
  /// In en, this message translates to:
  /// **'Available in VPN (TUN) mode.'**
  String get availableTun;

  /// No description provided for @quickSettings.
  ///
  /// In en, this message translates to:
  /// **'Quick Settings'**
  String get quickSettings;

  /// No description provided for @quickSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect from the panel'**
  String get quickSettingsSubtitle;

  /// No description provided for @quickSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap the system tile to connect to the selected server or disconnect. Hold it to open the app.'**
  String get quickSettingsHelp;

  /// No description provided for @addQuickSettings.
  ///
  /// In en, this message translates to:
  /// **'Add tile'**
  String get addQuickSettings;

  /// No description provided for @tileAdded.
  ///
  /// In en, this message translates to:
  /// **'AORA Connect tile added.'**
  String get tileAdded;

  /// No description provided for @tileAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'AORA Connect tile already added.'**
  String get tileAlreadyAdded;

  /// No description provided for @tileManual.
  ///
  /// In en, this message translates to:
  /// **'Open Quick Settings, tap Edit, then drag AORA Connect into your tiles.'**
  String get tileManual;

  /// No description provided for @tileDeclined.
  ///
  /// In en, this message translates to:
  /// **'Tile not added.'**
  String get tileDeclined;

  /// No description provided for @tileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the tile. Open Quick Settings and add AORA Connect using Edit.'**
  String get tileFailed;

  /// No description provided for @dnsServer.
  ///
  /// In en, this message translates to:
  /// **'DNS server'**
  String get dnsServer;

  /// No description provided for @dnsHelp.
  ///
  /// In en, this message translates to:
  /// **'DNS provider for VPN (TUN). System-wide DNS is not configured in local proxy mode.'**
  String get dnsHelp;

  /// No description provided for @serverChecks.
  ///
  /// In en, this message translates to:
  /// **'Server checks'**
  String get serverChecks;

  /// No description provided for @serverPingMethod.
  ///
  /// In en, this message translates to:
  /// **'Server ping method'**
  String get serverPingMethod;

  /// No description provided for @serverChecksHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies to server checks throughout the app. Statistics uses live ICMP. Proxy checks request https://www.gstatic.com/generate_204 through each node.'**
  String get serverChecksHelp;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration and connection'**
  String get diagnosticsSubtitle;

  /// No description provided for @coreLogs.
  ///
  /// In en, this message translates to:
  /// **'Core logs'**
  String get coreLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs yet.'**
  String get noLogs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutClient.
  ///
  /// In en, this message translates to:
  /// **'An open-source, universal VPN client.'**
  String get aboutClient;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License: GNU GPL version 3 or later.'**
  String get license;

  /// No description provided for @coresLicense.
  ///
  /// In en, this message translates to:
  /// **'Networking cores: sing-box and Xray. Their binaries and licenses are separate from the app.'**
  String get coresLicense;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @pingMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Latency · measuring…'**
  String get pingMeasuring;

  /// No description provided for @pingNoReply.
  ///
  /// In en, this message translates to:
  /// **'Latency · no reply'**
  String get pingNoReply;

  /// No description provided for @pingValue.
  ///
  /// In en, this message translates to:
  /// **'Latency · {p0}'**
  String pingValue(String p0);

  /// No description provided for @connectStatistics.
  ///
  /// In en, this message translates to:
  /// **'Connect to any server.'**
  String get connectStatistics;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Address: {p0}'**
  String target(String p0);

  /// No description provided for @measuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get measuring;

  /// No description provided for @noReply.
  ///
  /// In en, this message translates to:
  /// **'No reply'**
  String get noReply;

  /// No description provided for @waitingSamples.
  ///
  /// In en, this message translates to:
  /// **'Waiting for samples'**
  String get waitingSamples;

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'{p0}/{p1} replies'**
  String replies(String p0, String p1);

  /// No description provided for @pingHistory.
  ///
  /// In en, this message translates to:
  /// **'Latency history. '**
  String get pingHistory;

  /// No description provided for @successfulChecks.
  ///
  /// In en, this message translates to:
  /// **'{p0} of {p1} completed checks succeeded.'**
  String successfulChecks(String p0, String p1);

  /// No description provided for @pingHistoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Server ping every second · last 30 samples. Gaps mean no reply.'**
  String get pingHistoryHelp;

  /// No description provided for @connectCollectStatistics.
  ///
  /// In en, this message translates to:
  /// **'Connect to collect live ICMP samples.'**
  String get connectCollectStatistics;

  /// No description provided for @statisticsOff.
  ///
  /// In en, this message translates to:
  /// **'Statistics is off.'**
  String get statisticsOff;

  /// No description provided for @lessOneMs.
  ///
  /// In en, this message translates to:
  /// **'<1 ms'**
  String get lessOneMs;

  /// No description provided for @milliseconds.
  ///
  /// In en, this message translates to:
  /// **'{p0} ms'**
  String milliseconds(String p0);

  /// No description provided for @notChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get notChecked;

  /// No description provided for @noCompletedCheck.
  ///
  /// In en, this message translates to:
  /// **'No completed server check yet'**
  String get noCompletedCheck;

  /// No description provided for @lastCheck.
  ///
  /// In en, this message translates to:
  /// **'Last check {p0}:{p1}'**
  String lastCheck(String p0, String p1);

  /// No description provided for @checkServers.
  ///
  /// In en, this message translates to:
  /// **'Checking servers'**
  String get checkServers;

  /// No description provided for @cancelChecks.
  ///
  /// In en, this message translates to:
  /// **'Cancel server checks'**
  String get cancelChecks;

  /// No description provided for @serverCheck.
  ///
  /// In en, this message translates to:
  /// **'{p0} server check'**
  String serverCheck(String p0);

  /// No description provided for @applicationsAddresses.
  ///
  /// In en, this message translates to:
  /// **'Applications and addresses'**
  String get applicationsAddresses;

  /// No description provided for @routeListedItems.
  ///
  /// In en, this message translates to:
  /// **'Route listed applications and addresses'**
  String get routeListedItems;

  /// No description provided for @listedThroughTunnel.
  ///
  /// In en, this message translates to:
  /// **'Listed items go through the tunnel. Everything else uses your normal connection.'**
  String get listedThroughTunnel;

  /// No description provided for @listedBypassTunnel.
  ///
  /// In en, this message translates to:
  /// **'Listed items use your normal connection. Everything else goes through the tunnel.'**
  String get listedBypassTunnel;

  /// No description provided for @routingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Routing rules are off. Traffic uses the selected VPN server.'**
  String get routingDisabled;

  /// No description provided for @useTunRouting.
  ///
  /// In en, this message translates to:
  /// **'Use VPN (TUN) mode to route system traffic.'**
  String get useTunRouting;

  /// No description provided for @emptyThroughTunnel.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Everything goes through the tunnel.'**
  String get emptyThroughTunnel;

  /// No description provided for @emptyBypassTunnel.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Everything uses your normal connection.'**
  String get emptyBypassTunnel;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addRule;

  /// No description provided for @addRoutingRule.
  ///
  /// In en, this message translates to:
  /// **'Add routing rule'**
  String get addRoutingRule;

  /// No description provided for @editRoutingRule.
  ///
  /// In en, this message translates to:
  /// **'Edit routing rule'**
  String get editRoutingRule;

  /// No description provided for @editRule.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get editRule;

  /// No description provided for @deleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get deleteRule;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @enableTarget.
  ///
  /// In en, this message translates to:
  /// **'Enable {p0}'**
  String enableTarget(String p0);

  /// No description provided for @match.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get match;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @chooseApplication.
  ///
  /// In en, this message translates to:
  /// **'Choose application'**
  String get chooseApplication;

  /// No description provided for @installedApplications.
  ///
  /// In en, this message translates to:
  /// **'Installed applications'**
  String get installedApplications;

  /// No description provided for @runningApplications.
  ///
  /// In en, this message translates to:
  /// **'Running applications'**
  String get runningApplications;

  /// No description provided for @searchApplications.
  ///
  /// In en, this message translates to:
  /// **'Search applications'**
  String get searchApplications;

  /// No description provided for @noMatchingApplications.
  ///
  /// In en, this message translates to:
  /// **'No matching applications.'**
  String get noMatchingApplications;

  /// No description provided for @applicationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Application list unavailable.'**
  String get applicationsUnavailable;

  /// No description provided for @runningSelectionDesktop.
  ///
  /// In en, this message translates to:
  /// **'Running application selection is available on desktop.'**
  String get runningSelectionDesktop;

  /// No description provided for @runningReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read running applications.'**
  String get runningReadFailed;

  /// No description provided for @installedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load applications. Retry or enter a package name manually.'**
  String get installedLoadFailed;

  /// No description provided for @runningLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load running applications. Retry or enter a process name manually.'**
  String get runningLoadFailed;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {p0}'**
  String version(String p0);

  /// No description provided for @automaticUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check at startup'**
  String get automaticUpdates;

  /// No description provided for @automaticUpdatesSemantics.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get automaticUpdatesSemantics;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get checkUpdates;

  /// No description provided for @importUpdate.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get importUpdate;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @installUpdate.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get installUpdate;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @installVersion.
  ///
  /// In en, this message translates to:
  /// **'Install {p0}?'**
  String installVersion(String p0);

  /// No description provided for @windowsInstallHelp.
  ///
  /// In en, this message translates to:
  /// **'AORA Connect will close and reopen after installation. Your settings and subscriptions will be kept.'**
  String get windowsInstallHelp;

  /// No description provided for @androidInstallHelp.
  ///
  /// In en, this message translates to:
  /// **'Android will ask you to confirm installation. Your settings, subscriptions and routing rules will be kept.'**
  String get androidInstallHelp;

  /// No description provided for @androidApk.
  ///
  /// In en, this message translates to:
  /// **'AORA Android APK'**
  String get androidApk;

  /// No description provided for @windowsInstaller.
  ///
  /// In en, this message translates to:
  /// **'AORA update installer'**
  String get windowsInstaller;

  /// No description provided for @additionalSources.
  ///
  /// In en, this message translates to:
  /// **'Additional sources'**
  String get additionalSources;

  /// No description provided for @additionalSourcesCount.
  ///
  /// In en, this message translates to:
  /// **'{p0} additional sources'**
  String additionalSourcesCount(String p0);

  /// No description provided for @updateSources.
  ///
  /// In en, this message translates to:
  /// **'Update sources'**
  String get updateSources;

  /// No description provided for @updateSourcesHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional mirrors. GitHub is tried first.'**
  String get updateSourcesHelp;

  /// No description provided for @metadataUrlPerLine.
  ///
  /// In en, this message translates to:
  /// **'One HTTPS metadata URL per line'**
  String get metadataUrlPerLine;

  /// No description provided for @updateAvailableNotification.
  ///
  /// In en, this message translates to:
  /// **'Update {p0} is available in Settings → Updates.'**
  String updateAvailableNotification(String p0);

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @throughTunnel.
  ///
  /// In en, this message translates to:
  /// **'Through tunnel'**
  String get throughTunnel;

  /// No description provided for @bypassingTunnel.
  ///
  /// In en, this message translates to:
  /// **'Bypassing tunnel'**
  String get bypassingTunnel;

  /// No description provided for @application.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get application;

  /// No description provided for @domainSubdomains.
  ///
  /// In en, this message translates to:
  /// **'Domain + subdomains'**
  String get domainSubdomains;

  /// No description provided for @exactDomain.
  ///
  /// In en, this message translates to:
  /// **'Exact domain'**
  String get exactDomain;

  /// No description provided for @ipCidr.
  ///
  /// In en, this message translates to:
  /// **'IP / CIDR'**
  String get ipCidr;

  /// No description provided for @proxyGet.
  ///
  /// In en, this message translates to:
  /// **'Via Proxy GET'**
  String get proxyGet;

  /// No description provided for @proxyHead.
  ///
  /// In en, this message translates to:
  /// **'Via Proxy HEAD'**
  String get proxyHead;

  /// No description provided for @stateStopped.
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get stateStopped;

  /// No description provided for @stateStarting.
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get stateStarting;

  /// No description provided for @stateRunning.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get stateRunning;

  /// No description provided for @stateStopping.
  ///
  /// In en, this message translates to:
  /// **'disconnecting'**
  String get stateStopping;

  /// No description provided for @timeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get timeout;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get unavailable;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get checkingUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'No newer update found'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update {p0} available'**
  String updateAvailable(String p0);

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get downloadingUpdate;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Update verified and ready to install'**
  String get updateReady;

  /// No description provided for @verifyingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Verifying update file…'**
  String get verifyingUpdate;

  /// No description provided for @updateVersionReady.
  ///
  /// In en, this message translates to:
  /// **'Update {p0} verified and ready to install'**
  String updateVersionReady(String p0);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update could not be completed'**
  String get updateFailed;

  /// No description provided for @installationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Installation completed'**
  String get installationCompleted;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Open AORA Connect'**
  String get trayShow;

  /// No description provided for @trayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get trayExit;

  /// Whole days until a subscription expires.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day left} other{{count} days left}}'**
  String daysLeft(int count);

  /// No description provided for @serverCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} server} other{{count} servers}}'**
  String serverCount(int count);

  /// No description provided for @notLoaded.
  ///
  /// In en, this message translates to:
  /// **'Not loaded'**
  String get notLoaded;

  /// No description provided for @skippedServers.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String skippedServers(int count);

  /// No description provided for @connectionVerified.
  ///
  /// In en, this message translates to:
  /// **'Connection verified ({p0} ms).'**
  String connectionVerified(String p0);

  /// No description provided for @httpsSucceeded.
  ///
  /// In en, this message translates to:
  /// **'HTTPS through {p0} succeeded ({p1} ms).'**
  String httpsSucceeded(String p0, String p1);

  /// No description provided for @routingValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a value.'**
  String get routingValidationEmpty;

  /// No description provided for @routingValidationControlCharacters.
  ///
  /// In en, this message translates to:
  /// **'Control characters are not allowed.'**
  String get routingValidationControlCharacters;

  /// No description provided for @routingValidationApplication.
  ///
  /// In en, this message translates to:
  /// **'Enter an executable path or process name, without wildcards.'**
  String get routingValidationApplication;

  /// No description provided for @routingValidationDomain.
  ///
  /// In en, this message translates to:
  /// **'Enter a domain without a URL scheme, path, or wildcard.'**
  String get routingValidationDomain;

  /// No description provided for @routingValidationIp.
  ///
  /// In en, this message translates to:
  /// **'Enter an IP address or CIDR range.'**
  String get routingValidationIp;

  /// No description provided for @routingValidationPrefix.
  ///
  /// In en, this message translates to:
  /// **'The CIDR prefix is invalid.'**
  String get routingValidationPrefix;

  /// No description provided for @httpsSourcesOnly.
  ///
  /// In en, this message translates to:
  /// **'Update sources must be HTTPS URLs without credentials.'**
  String get httpsSourcesOnly;

  /// No description provided for @checkAllServers.
  ///
  /// In en, this message translates to:
  /// **'Check all servers'**
  String get checkAllServers;

  /// No description provided for @checkSelectedServer.
  ///
  /// In en, this message translates to:
  /// **'Check selected server'**
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
  // Lookup logic when only language code is specified.
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
