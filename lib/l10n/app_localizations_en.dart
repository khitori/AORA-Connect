// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get startup => 'Startup';

  @override
  String get manualStart => 'Start manually';

  @override
  String get startWithWindows => 'Start with Windows';

  @override
  String get startWithWindowsHelp =>
      'Open the installed app when you sign in to Windows.';

  @override
  String get startMinimized => 'Start minimized';

  @override
  String get startMinimizedHelp =>
      'Keep the app in the system tray when it starts.';

  @override
  String get startupConnectionHelp =>
      'Opening the app does not connect the VPN automatically.';

  @override
  String get startupLoadFailed => 'Could not load startup settings. Try again.';

  @override
  String get startupSaveFailed =>
      'Could not save startup settings. Refresh and try again.';

  @override
  String get language => 'Language';

  @override
  String get interfaceLanguage => 'Interface language';

  @override
  String get systemDefault => 'System default';

  @override
  String get languageSaveFailed => 'Could not save the language preference.';

  @override
  String get settings => 'Settings';

  @override
  String get connection => 'Connection';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get routing => 'Routing';

  @override
  String get hideToTray => 'Hide to tray';

  @override
  String get closeApp => 'Close app';

  @override
  String get close => 'Close';

  @override
  String get closeMenu => 'Close menu';

  @override
  String get openMenu => 'Open menu';

  @override
  String get menu => 'Menu';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connecting => 'Connecting…';

  @override
  String get stopping => 'Disconnecting…';

  @override
  String get localProxy => 'Local proxy';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get refresh => 'Refresh';

  @override
  String get validate => 'Check';

  @override
  String get testConnection => 'Test';

  @override
  String get copyDiagnostics => 'Copy diagnostics';

  @override
  String get diagnosticsCopied => 'Diagnostics copied.';

  @override
  String get diagnosticsCopyFailed => 'Could not copy diagnostics.';

  @override
  String get loadSubscriptionFirst =>
      'Add a subscription in the Subscriptions tab first.';

  @override
  String serverRequiresCore(String p0) {
    return 'This server requires $p0. Select it in Settings.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'Selected server requires $p0.';
  }

  @override
  String get insecureProfile =>
      'This profile disables TLS certificate verification.';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get savedSubscriptions => 'Saved subscriptions';

  @override
  String get noSubscriptions => 'No subscriptions yet. Add a link above.';

  @override
  String get activeSubscriptionNodes => 'Servers in active subscription';

  @override
  String get chooseSubscription => 'Choose a subscription';

  @override
  String get selectSubscription => 'Choose an active subscription';

  @override
  String get refreshSubscription => 'Refresh selected subscription';

  @override
  String get removeSubscription => 'Remove selected subscription';

  @override
  String get subscriptionLink => 'Subscription or server link…';

  @override
  String get pasteClipboard => 'Paste from clipboard';

  @override
  String get copyLinkFirst => 'Copy a valid subscription or server link first.';

  @override
  String get clipboardReadFailed => 'Could not read the clipboard.';

  @override
  String get website => 'Website';

  @override
  String get support => 'Support';

  @override
  String get description => 'Description';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get expires => 'Expires';

  @override
  String get notUpdated => 'Not updated';

  @override
  String get notProvided => 'Not provided';

  @override
  String get expired => 'Expired';

  @override
  String openLink(String p0) {
    return 'Open $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return '$p0 link not provided';
  }

  @override
  String get openLinkFailed => 'Could not open link.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'Could not open $p0 link.';
  }

  @override
  String get disconnectSubscriptions =>
      'Disconnect before changing subscriptions.';

  @override
  String get disconnectServers => 'Disconnect before changing servers.';

  @override
  String get disconnectRefresh =>
      'Disconnect before refreshing your subscription.';

  @override
  String get disconnectRouting => 'Disconnect before editing routing rules.';

  @override
  String get disconnectInstall => 'Disconnect before installing an update.';

  @override
  String get waitCurrentOperation =>
      'Wait for the current operation to finish.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'Disconnect before $p0.';
  }

  @override
  String get changingCore => 'changing the core';

  @override
  String get changingMode => 'changing connection mode';

  @override
  String get changingDns => 'changing DNS';

  @override
  String get changingKillSwitch => 'changing Kill Switch';

  @override
  String get core => 'Core';

  @override
  String get networkingCore => 'Networking core';

  @override
  String get coreHelp => 'Select the core required by your server.';

  @override
  String get connectionMode => 'Connection mode';

  @override
  String get connectionModeHelp =>
      'VPN (TUN) routes system traffic automatically. Local proxy requires proxy configuration in your applications.';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchHelp =>
      'Protects against DNS and traffic leaks while connected.';

  @override
  String get availableTun => 'Available in VPN (TUN) mode.';

  @override
  String get quickSettings => 'Quick Settings';

  @override
  String get quickSettingsSubtitle => 'Connect from the panel';

  @override
  String get quickSettingsHelp =>
      'Tap the system tile to connect to the selected server or disconnect. Hold it to open the app.';

  @override
  String get addQuickSettings => 'Add tile';

  @override
  String get tileAdded => 'AORA Connect tile added.';

  @override
  String get tileAlreadyAdded => 'AORA Connect tile already added.';

  @override
  String get tileManual =>
      'Open Quick Settings, tap Edit, then drag AORA Connect into your tiles.';

  @override
  String get tileDeclined => 'Tile not added.';

  @override
  String get tileFailed =>
      'Could not add the tile. Open Quick Settings and add AORA Connect using Edit.';

  @override
  String get dnsServer => 'DNS server';

  @override
  String get dnsHelp =>
      'DNS provider for VPN (TUN). System-wide DNS is not configured in local proxy mode.';

  @override
  String get serverChecks => 'Server checks';

  @override
  String get serverPingMethod => 'Server ping method';

  @override
  String get serverChecksHelp =>
      'Applies to server checks throughout the app. Statistics uses live ICMP. Proxy checks request https://www.gstatic.com/generate_204 through each node.';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsSubtitle => 'Configuration and connection';

  @override
  String get coreLogs => 'Core logs';

  @override
  String get noLogs => 'No logs yet.';

  @override
  String get about => 'About';

  @override
  String get aboutClient => 'An open-source, universal VPN client.';

  @override
  String get license => 'License: GNU GPL version 3 or later.';

  @override
  String get coresLicense =>
      'Networking cores: sing-box and Xray. Their binaries and licenses are separate from the app.';

  @override
  String get statistics => 'Statistics';

  @override
  String get off => 'Off';

  @override
  String get pingMeasuring => 'Latency · measuring…';

  @override
  String get pingNoReply => 'Latency · no reply';

  @override
  String pingValue(String p0) {
    return 'Latency · $p0';
  }

  @override
  String get connectStatistics => 'Connect to any server.';

  @override
  String target(String p0) {
    return 'Address: $p0';
  }

  @override
  String get measuring => 'Measuring…';

  @override
  String get noReply => 'No reply';

  @override
  String get waitingSamples => 'Waiting for samples';

  @override
  String replies(String p0, String p1) {
    return '$p0/$p1 replies';
  }

  @override
  String get pingHistory => 'Latency history. ';

  @override
  String successfulChecks(String p0, String p1) {
    return '$p0 of $p1 completed checks succeeded.';
  }

  @override
  String get pingHistoryHelp =>
      'Server ping every second · last 30 samples. Gaps mean no reply.';

  @override
  String get connectCollectStatistics =>
      'Connect to collect live ICMP samples.';

  @override
  String get statisticsOff => 'Statistics is off.';

  @override
  String get lessOneMs => '<1 ms';

  @override
  String milliseconds(String p0) {
    return '$p0 ms';
  }

  @override
  String get notChecked => 'Not checked';

  @override
  String get noCompletedCheck => 'No completed server check yet';

  @override
  String lastCheck(String p0, String p1) {
    return 'Last check $p0:$p1';
  }

  @override
  String get checkServers => 'Checking servers';

  @override
  String get cancelChecks => 'Cancel server checks';

  @override
  String serverCheck(String p0) {
    return '$p0 server check';
  }

  @override
  String get applicationsAddresses => 'Applications and addresses';

  @override
  String get routeListedItems => 'Route listed applications and addresses';

  @override
  String get listedThroughTunnel =>
      'Listed items go through the tunnel. Everything else uses your normal connection.';

  @override
  String get listedBypassTunnel =>
      'Listed items use your normal connection. Everything else goes through the tunnel.';

  @override
  String get routingDisabled =>
      'Routing rules are off. Traffic uses the selected VPN server.';

  @override
  String get useTunRouting => 'Use VPN (TUN) mode to route system traffic.';

  @override
  String get emptyThroughTunnel =>
      'No items yet. Everything goes through the tunnel.';

  @override
  String get emptyBypassTunnel =>
      'No items yet. Everything uses your normal connection.';

  @override
  String get addRule => 'Add rule';

  @override
  String get addRoutingRule => 'Add routing rule';

  @override
  String get editRoutingRule => 'Edit routing rule';

  @override
  String get editRule => 'Edit rule';

  @override
  String get deleteRule => 'Delete rule';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String enableTarget(String p0) {
    return 'Enable $p0';
  }

  @override
  String get match => 'Match';

  @override
  String get value => 'Value';

  @override
  String get chooseApplication => 'Choose application';

  @override
  String get installedApplications => 'Installed applications';

  @override
  String get runningApplications => 'Running applications';

  @override
  String get searchApplications => 'Search applications';

  @override
  String get noMatchingApplications => 'No matching applications.';

  @override
  String get applicationsUnavailable => 'Application list unavailable.';

  @override
  String get runningSelectionDesktop =>
      'Running application selection is available on desktop.';

  @override
  String get runningReadFailed => 'Unable to read running applications.';

  @override
  String get installedLoadFailed =>
      'Could not load applications. Retry or enter a package name manually.';

  @override
  String get runningLoadFailed =>
      'Could not load running applications. Retry or enter a process name manually.';

  @override
  String get updates => 'Updates';

  @override
  String version(String p0) {
    return 'Version $p0';
  }

  @override
  String get automaticUpdates => 'Check at startup';

  @override
  String get automaticUpdatesSemantics => 'Check for updates automatically';

  @override
  String get checkUpdates => 'Check';

  @override
  String get importUpdate => 'From file';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get installUpdate => 'Install update';

  @override
  String get install => 'Install';

  @override
  String installVersion(String p0) {
    return 'Install $p0?';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect will close and reopen after installation. Your settings and subscriptions will be kept.';

  @override
  String get androidInstallHelp =>
      'Android will ask you to confirm installation. Your settings, subscriptions and routing rules will be kept.';

  @override
  String get androidApk => 'AORA Android APK';

  @override
  String get windowsInstaller => 'AORA update installer';

  @override
  String get additionalSources => 'Additional sources';

  @override
  String additionalSourcesCount(String p0) {
    return '$p0 additional sources';
  }

  @override
  String get updateSources => 'Update sources';

  @override
  String get updateSourcesHelp => 'Optional mirrors. GitHub is tried first.';

  @override
  String get metadataUrlPerLine => 'One HTTPS metadata URL per line';

  @override
  String updateAvailableNotification(String p0) {
    return 'Update $p0 is available in Settings → Updates.';
  }

  @override
  String get notAvailable => 'Not available';

  @override
  String get system => 'System';

  @override
  String get idle => 'Idle';

  @override
  String get throughTunnel => 'Through tunnel';

  @override
  String get bypassingTunnel => 'Bypassing tunnel';

  @override
  String get application => 'Application';

  @override
  String get domainSubdomains => 'Domain + subdomains';

  @override
  String get exactDomain => 'Exact domain';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'Via Proxy GET';

  @override
  String get proxyHead => 'Via Proxy HEAD';

  @override
  String get stateStopped => 'disconnected';

  @override
  String get stateStarting => 'connecting';

  @override
  String get stateRunning => 'connected';

  @override
  String get stateStopping => 'disconnecting';

  @override
  String get timeout => 'Timeout';

  @override
  String get failed => 'Failed';

  @override
  String get unavailable => 'N/A';

  @override
  String get checkingUpdates => 'Checking for updates…';

  @override
  String get upToDate => 'No newer update found';

  @override
  String updateAvailable(String p0) {
    return 'Update $p0 available';
  }

  @override
  String get downloadingUpdate => 'Downloading update…';

  @override
  String get updateReady => 'Update verified and ready to install';

  @override
  String get verifyingUpdate => 'Verifying update file…';

  @override
  String updateVersionReady(String p0) {
    return 'Update $p0 verified and ready to install';
  }

  @override
  String get updateFailed => 'Update could not be completed';

  @override
  String get installationCompleted => 'Installation completed';

  @override
  String get trayShow => 'Open AORA Connect';

  @override
  String get trayExit => 'Exit';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '$count day left',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '$count server',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'Not loaded';

  @override
  String skippedServers(int count) {
    return '$count skipped';
  }

  @override
  String connectionVerified(String p0) {
    return 'Connection verified ($p0 ms).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'HTTPS through $p0 succeeded ($p1 ms).';
  }

  @override
  String get routingValidationEmpty => 'Enter a value.';

  @override
  String get routingValidationControlCharacters =>
      'Control characters are not allowed.';

  @override
  String get routingValidationApplication =>
      'Enter an executable path or process name, without wildcards.';

  @override
  String get routingValidationDomain =>
      'Enter a domain without a URL scheme, path, or wildcard.';

  @override
  String get routingValidationIp => 'Enter an IP address or CIDR range.';

  @override
  String get routingValidationPrefix => 'The CIDR prefix is invalid.';

  @override
  String get httpsSourcesOnly =>
      'Update sources must be HTTPS URLs without credentials.';

  @override
  String get checkAllServers => 'Check all servers';

  @override
  String get checkSelectedServer => 'Check selected server';
}
