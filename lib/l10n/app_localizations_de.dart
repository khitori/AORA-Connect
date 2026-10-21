// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get language => 'Sprache';

  @override
  String get interfaceLanguage => 'Sprache der Benutzeroberfläche';

  @override
  String get systemDefault => 'Systemsprache';

  @override
  String get languageSaveFailed =>
      'Die Spracheinstellung konnte nicht gespeichert werden.';

  @override
  String get settings => 'Einstellungen';

  @override
  String get connection => 'Verbindung';

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get routing => 'Routing';

  @override
  String get hideToTray => 'In den Infobereich minimieren';

  @override
  String get closeApp => 'Anwendung schließen';

  @override
  String get close => 'Schließen';

  @override
  String get closeMenu => 'Menü schließen';

  @override
  String get openMenu => 'Menü öffnen';

  @override
  String get menu => 'Menü';

  @override
  String get connect => 'Verbinden';

  @override
  String get disconnect => 'Trennen';

  @override
  String get connecting => 'Verbindung wird hergestellt…';

  @override
  String get stopping => 'Verbindung wird getrennt…';

  @override
  String get localProxy => 'Lokaler Proxy';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get saving => 'Wird gespeichert…';

  @override
  String get add => 'Hinzufügen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get validate => 'Validieren';

  @override
  String get testConnection => 'Verbindung testen';

  @override
  String get copyDiagnostics => 'Diagnose kopieren';

  @override
  String get diagnosticsCopied => 'Diagnose kopiert.';

  @override
  String get diagnosticsCopyFailed =>
      'Die Diagnose konnte nicht kopiert werden.';

  @override
  String get loadSubscriptionFirst =>
      'Fügen Sie zuerst im Tab „Abonnements“ ein Abonnement hinzu.';

  @override
  String serverRequiresCore(String p0) {
    return 'Dieser Server benötigt $p0. Wählen Sie diesen Kern in den Einstellungen aus.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'Der ausgewählte Server benötigt $p0.';
  }

  @override
  String get insecureProfile =>
      'Dieses Profil deaktiviert die Prüfung des TLS-Zertifikats.';

  @override
  String get addSubscription => 'Abonnement hinzufügen';

  @override
  String get savedSubscriptions => 'Gespeicherte Abonnements';

  @override
  String get noSubscriptions =>
      'Noch keine Abonnements. Fügen Sie oben einen Link hinzu.';

  @override
  String get activeSubscriptionNodes => 'Server im aktiven Abonnement';

  @override
  String get chooseSubscription => 'Abonnement auswählen';

  @override
  String get selectSubscription => 'Zu verwendendes Abonnement auswählen';

  @override
  String get refreshSubscription => 'Ausgewähltes Abonnement aktualisieren';

  @override
  String get removeSubscription => 'Ausgewähltes Abonnement entfernen';

  @override
  String get subscriptionLink => 'Abonnement- oder Serverlink…';

  @override
  String get pasteClipboard => 'Aus der Zwischenablage einfügen';

  @override
  String get copyLinkFirst =>
      'Kopieren Sie zuerst einen gültigen Abonnement- oder Serverlink.';

  @override
  String get clipboardReadFailed =>
      'Die Zwischenablage konnte nicht gelesen werden.';

  @override
  String get website => 'Webseite';

  @override
  String get support => 'Support';

  @override
  String get description => 'Beschreibung';

  @override
  String get lastUpdated => 'Zuletzt aktualisiert';

  @override
  String get expires => 'Gültig bis';

  @override
  String get notUpdated => 'Nicht aktualisiert';

  @override
  String get notProvided => 'Nicht angegeben';

  @override
  String get expired => 'Abgelaufen';

  @override
  String openLink(String p0) {
    return '$p0 öffnen';
  }

  @override
  String linkNotProvided(String p0) {
    return 'Kein Link für $p0 angegeben';
  }

  @override
  String get openLinkFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'Der Link für $p0 konnte nicht geöffnet werden.';
  }

  @override
  String get disconnectSubscriptions =>
      'Trennen Sie die Verbindung, bevor Sie Abonnements ändern.';

  @override
  String get disconnectServers =>
      'Trennen Sie die Verbindung, bevor Sie den Server wechseln.';

  @override
  String get disconnectRefresh =>
      'Trennen Sie die Verbindung, bevor Sie Ihr Abonnement aktualisieren.';

  @override
  String get disconnectRouting =>
      'Trennen Sie die Verbindung, bevor Sie Routing-Regeln bearbeiten.';

  @override
  String get disconnectInstall =>
      'Trennen Sie die Verbindung, bevor Sie ein Update installieren.';

  @override
  String get waitCurrentOperation =>
      'Warten Sie, bis der aktuelle Vorgang abgeschlossen ist.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'Trennen Sie die Verbindung vor $p0.';
  }

  @override
  String get changingCore => 'dem Wechsel des Kerns';

  @override
  String get changingMode => 'dem Wechsel des Verbindungsmodus';

  @override
  String get changingDns => 'der Änderung des DNS';

  @override
  String get changingKillSwitch => 'der Änderung des Kill Switch';

  @override
  String get core => 'Kern';

  @override
  String get networkingCore => 'Netzwerkkern';

  @override
  String get coreHelp =>
      'Wählen Sie den Kern manuell aus. Der benötigte Kern wird für jeden Server im Tab „Abonnements“ angezeigt.';

  @override
  String get connectionMode => 'Verbindungsmodus';

  @override
  String get connectionModeHelp =>
      'VPN (TUN) leitet den Systemverkehr automatisch weiter. Beim lokalen Proxy müssen Sie den Proxy in Ihren Anwendungen konfigurieren.';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchHelp =>
      'Schützt DNS und TUN-Routing während der Verbindung. Nach dem Trennen ist der normale Internetzugang wieder verfügbar.';

  @override
  String get availableTun => 'Im Modus VPN (TUN) verfügbar.';

  @override
  String get quickSettings => 'Schnelleinstellungen';

  @override
  String get quickSettingsSubtitle => 'Über das Android-Panel verbinden';

  @override
  String get quickSettingsHelp =>
      'Über die Kachel „AORA Connect“ können Sie sich mit dem ausgewählten Server verbinden oder die Verbindung trennen. Halten Sie die Kachel gedrückt, um die App zu öffnen.';

  @override
  String get addQuickSettings => 'Zu Schnelleinstellungen hinzufügen';

  @override
  String get tileAdded =>
      'AORA Connect wurde zu den Schnelleinstellungen hinzugefügt.';

  @override
  String get tileAlreadyAdded =>
      'AORA Connect ist bereits in den Schnelleinstellungen vorhanden.';

  @override
  String get tileManual =>
      'Öffnen Sie die Schnelleinstellungen, tippen Sie auf „Bearbeiten“ und ziehen Sie AORA Connect zu Ihren Kacheln.';

  @override
  String get tileDeclined => 'Die Kachel wurde nicht hinzugefügt.';

  @override
  String get tileFailed =>
      'Die Kachel konnte nicht hinzugefügt werden. Öffnen Sie die Schnelleinstellungen und fügen Sie AORA Connect über „Bearbeiten“ hinzu.';

  @override
  String get dnsServer => 'DNS-Server';

  @override
  String get dnsHelp =>
      'DNS-Anbieter für VPN (TUN). Im lokalen Proxy-Modus wird das systemweite DNS nicht konfiguriert.';

  @override
  String get serverChecks => 'Serverprüfungen';

  @override
  String get serverPingMethod => 'Methode der Serverprüfung';

  @override
  String get serverChecksHelp =>
      'Gilt für Serverprüfungen in der gesamten App. Die Statistik verwendet ICMP. Proxy-Prüfungen rufen https://www.gstatic.com/generate_204 über jeden Server ab.';

  @override
  String get diagnostics => 'Diagnose';

  @override
  String get diagnosticsSubtitle =>
      'Validierung, Verbindungstest und Protokolle';

  @override
  String get coreLogs => 'Kernprotokolle';

  @override
  String get noLogs => 'Noch keine Protokolle.';

  @override
  String get about => 'Über die App';

  @override
  String get aboutClient => 'Ein universeller Open-Source-VPN-Client.';

  @override
  String get license => 'Lizenz: GNU GPL Version 3 oder neuer.';

  @override
  String get coresLicense =>
      'Netzwerkkerne: sing-box und Xray. Ihre Binärdateien und Lizenzen sind von der App getrennt.';

  @override
  String get statistics => 'Statistik';

  @override
  String get off => 'Aus';

  @override
  String get pingMeasuring => 'Server-Ping · Messung…';

  @override
  String get pingNoReply => 'Server-Ping · keine Antwort';

  @override
  String pingValue(String p0) {
    return 'Server-Ping · $p0';
  }

  @override
  String get connectStatistics =>
      'Verbinden Sie sich, um die ICMP-Livestatistik anzuzeigen';

  @override
  String target(String p0) {
    return 'Ziel: $p0';
  }

  @override
  String get measuring => 'Messung…';

  @override
  String get noReply => 'Keine Antwort';

  @override
  String get waitingSamples => 'Warten auf Messwerte';

  @override
  String replies(String p0, String p1) {
    return 'Antworten: $p0/$p1';
  }

  @override
  String get pingHistory => 'Server-Ping-Verlauf. ';

  @override
  String successfulChecks(String p0, String p1) {
    return 'Erfolgreiche Prüfungen: $p0 von $p1.';
  }

  @override
  String get pingHistoryHelp =>
      'Server-Ping jede Sekunde · die letzten 30 Messwerte. Lücken bedeuten keine Antwort.';

  @override
  String get connectCollectStatistics =>
      'Verbinden Sie sich, um ICMP-Livemesswerte zu erfassen.';

  @override
  String get statisticsOff => 'Die Statistik ist deaktiviert.';

  @override
  String get lessOneMs => '<1 ms';

  @override
  String milliseconds(String p0) {
    return '$p0 ms';
  }

  @override
  String get notChecked => 'Nicht geprüft';

  @override
  String get noCompletedCheck => 'Noch keine Serverprüfung abgeschlossen';

  @override
  String lastCheck(String p0, String p1) {
    return 'Letzte Prüfung $p0:$p1';
  }

  @override
  String get checkServers => 'Server werden geprüft';

  @override
  String get cancelChecks => 'Serverprüfungen abbrechen';

  @override
  String serverCheck(String p0) {
    return 'Serverprüfung über $p0';
  }

  @override
  String get applicationsAddresses => 'Anwendungen und Adressen';

  @override
  String get routeListedItems =>
      'Aufgeführte Anwendungen und Adressen weiterleiten';

  @override
  String get listedThroughTunnel =>
      'Aufgeführte Einträge verwenden den Tunnel. Alles andere nutzt Ihre normale Verbindung.';

  @override
  String get listedBypassTunnel =>
      'Aufgeführte Einträge nutzen Ihre normale Verbindung. Alles andere wird durch den Tunnel geleitet.';

  @override
  String get routingDisabled =>
      'Routing-Regeln sind deaktiviert. Der Datenverkehr nutzt den ausgewählten VPN-Server.';

  @override
  String get useTunRouting =>
      'Verwenden Sie VPN (TUN), um den Systemverkehr weiterzuleiten.';

  @override
  String get emptyThroughTunnel =>
      'Noch keine Einträge. Alles wird durch den Tunnel geleitet.';

  @override
  String get emptyBypassTunnel =>
      'Noch keine Einträge. Alles nutzt Ihre normale Verbindung.';

  @override
  String get addRule => 'Regel hinzufügen';

  @override
  String get addRoutingRule => 'Routing-Regel hinzufügen';

  @override
  String get editRoutingRule => 'Routing-Regel bearbeiten';

  @override
  String get editRule => 'Regel bearbeiten';

  @override
  String get deleteRule => 'Regel löschen';

  @override
  String get moveUp => 'Nach oben verschieben';

  @override
  String get moveDown => 'Nach unten verschieben';

  @override
  String enableTarget(String p0) {
    return '$p0 aktivieren';
  }

  @override
  String get match => 'Abgleich';

  @override
  String get value => 'Wert';

  @override
  String get chooseApplication => 'Anwendung auswählen';

  @override
  String get installedApplications => 'Installierte Anwendungen';

  @override
  String get runningApplications => 'Laufende Anwendungen';

  @override
  String get searchApplications => 'Anwendungen suchen';

  @override
  String get noMatchingApplications => 'Keine passenden Anwendungen.';

  @override
  String get applicationsUnavailable => 'Anwendungsliste nicht verfügbar.';

  @override
  String get runningSelectionDesktop =>
      'Laufende Anwendungen können auf dem Desktop ausgewählt werden.';

  @override
  String get runningReadFailed =>
      'Laufende Anwendungen konnten nicht ermittelt werden.';

  @override
  String get installedLoadFailed =>
      'Anwendungen konnten nicht geladen werden. Versuchen Sie es erneut oder geben Sie den Paketnamen manuell ein.';

  @override
  String get runningLoadFailed =>
      'Laufende Anwendungen konnten nicht geladen werden. Versuchen Sie es erneut oder geben Sie den Prozessnamen manuell ein.';

  @override
  String get updates => 'Updates';

  @override
  String version(String p0) {
    return 'Version $p0';
  }

  @override
  String get automaticUpdates => 'Beim Start automatisch prüfen';

  @override
  String get automaticUpdatesSemantics => 'Automatisch nach Updates suchen';

  @override
  String get checkUpdates => 'Nach Updates suchen';

  @override
  String get importUpdate => 'Update aus Datei';

  @override
  String get downloadUpdate => 'Update herunterladen';

  @override
  String get installUpdate => 'Update installieren';

  @override
  String get install => 'Installieren';

  @override
  String installVersion(String p0) {
    return '$p0 installieren?';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect wird geschlossen und nach der Installation neu geöffnet. Ihre Einstellungen und Abonnements bleiben erhalten.';

  @override
  String get androidInstallHelp =>
      'Android fordert Sie auf, die Installation zu bestätigen. Ihre Einstellungen, Abonnements und Routing-Regeln bleiben erhalten.';

  @override
  String get androidApk => 'AORA-APK für Android';

  @override
  String get windowsInstaller => 'AORA-Update-Installer';

  @override
  String get additionalSources => 'Zusätzliche Quellen (optional)';

  @override
  String additionalSourcesCount(String p0) {
    return 'Zusätzliche Quellen: $p0';
  }

  @override
  String get updateSources => 'Update-Quellen';

  @override
  String get updateSourcesHelp =>
      'Optionale Spiegelserver. GitHub wird zuerst geprüft.';

  @override
  String get metadataUrlPerLine => 'Eine HTTPS-Metadaten-URL pro Zeile';

  @override
  String updateAvailableNotification(String p0) {
    return 'Update $p0 ist unter Einstellungen → Updates verfügbar.';
  }

  @override
  String get notAvailable => 'Nicht verfügbar';

  @override
  String get system => 'System';

  @override
  String get idle => 'Leerlauf';

  @override
  String get throughTunnel => 'Durch den Tunnel';

  @override
  String get bypassingTunnel => 'Am Tunnel vorbei';

  @override
  String get application => 'Anwendung';

  @override
  String get domainSubdomains => 'Domain und Subdomains';

  @override
  String get exactDomain => 'Exakte Domain';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'Über Proxy GET';

  @override
  String get proxyHead => 'Über Proxy HEAD';

  @override
  String get stateStopped => 'getrennt';

  @override
  String get stateStarting => 'Verbindungsaufbau';

  @override
  String get stateRunning => 'verbunden';

  @override
  String get stateStopping => 'Verbindung wird getrennt';

  @override
  String get timeout => 'Zeitüberschreitung';

  @override
  String get failed => 'Fehlgeschlagen';

  @override
  String get unavailable => 'Nicht verfügbar';

  @override
  String get checkingUpdates => 'Updates werden gesucht…';

  @override
  String get upToDate => 'Kein neueres Update gefunden';

  @override
  String updateAvailable(String p0) {
    return 'Update $p0 verfügbar';
  }

  @override
  String get downloadingUpdate => 'Update wird heruntergeladen…';

  @override
  String get updateReady => 'Update geprüft und bereit zur Installation';

  @override
  String get verifyingUpdate => 'Update-Datei wird geprüft…';

  @override
  String updateVersionReady(String p0) {
    return 'Update $p0 geprüft und bereit zur Installation';
  }

  @override
  String get updateFailed => 'Das Update konnte nicht abgeschlossen werden';

  @override
  String get installationCompleted => 'Installation abgeschlossen';

  @override
  String get trayShow => 'AORA Connect öffnen';

  @override
  String get trayExit => 'Beenden';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Tage',
      one: 'Noch $count Tag',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Server',
      one: '$count Server',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'Nicht geladen';

  @override
  String skippedServers(int count) {
    return '$count übersprungen';
  }

  @override
  String connectionVerified(String p0) {
    return 'Verbindung geprüft ($p0 ms).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'HTTPS über $p0 erfolgreich ($p1 ms).';
  }

  @override
  String get routingValidationEmpty => 'Geben Sie einen Wert ein.';

  @override
  String get routingValidationControlCharacters =>
      'Steuerzeichen sind nicht erlaubt.';

  @override
  String get routingValidationApplication =>
      'Geben Sie einen Programmpfad oder Prozessnamen ohne Platzhalter ein.';

  @override
  String get routingValidationDomain =>
      'Geben Sie eine Domain ohne Protokoll, Pfad oder Platzhalter ein.';

  @override
  String get routingValidationIp =>
      'Geben Sie eine IP-Adresse oder einen CIDR-Bereich ein.';

  @override
  String get routingValidationPrefix => 'Das CIDR-Präfix ist ungültig.';

  @override
  String get httpsSourcesOnly =>
      'Update-Quellen müssen HTTPS-URLs ohne Zugangsdaten sein.';

  @override
  String get checkAllServers => 'Alle Server prüfen';

  @override
  String get checkSelectedServer => 'Ausgewählten Server prüfen';
}
