// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get language => 'Langue';

  @override
  String get interfaceLanguage => 'Langue de l’interface';

  @override
  String get systemDefault => 'Langue du système';

  @override
  String get languageSaveFailed =>
      'Impossible d’enregistrer la langue choisie.';

  @override
  String get settings => 'Paramètres';

  @override
  String get connection => 'Connexion';

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get routing => 'Routage';

  @override
  String get hideToTray => 'Réduire dans la zone de notification';

  @override
  String get closeApp => 'Fermer l’application';

  @override
  String get close => 'Fermer';

  @override
  String get closeMenu => 'Fermer le menu';

  @override
  String get openMenu => 'Ouvrir le menu';

  @override
  String get menu => 'Menu';

  @override
  String get connect => 'Connecter';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get connecting => 'Connexion…';

  @override
  String get stopping => 'Déconnexion…';

  @override
  String get localProxy => 'Proxy local';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get add => 'Ajouter';

  @override
  String get edit => 'Modifier';

  @override
  String get refresh => 'Actualiser';

  @override
  String get validate => 'Valider';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get copyDiagnostics => 'Copier le diagnostic';

  @override
  String get diagnosticsCopied => 'Diagnostic copié.';

  @override
  String get diagnosticsCopyFailed => 'Impossible de copier le diagnostic.';

  @override
  String get loadSubscriptionFirst =>
      'Ajoutez d’abord un abonnement dans l’onglet « Abonnements ».';

  @override
  String serverRequiresCore(String p0) {
    return 'Ce serveur nécessite $p0. Sélectionnez ce moteur dans les paramètres.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'Le serveur sélectionné nécessite $p0.';
  }

  @override
  String get insecureProfile =>
      'Ce profil désactive la vérification du certificat TLS.';

  @override
  String get addSubscription => 'Ajouter un abonnement';

  @override
  String get savedSubscriptions => 'Abonnements enregistrés';

  @override
  String get noSubscriptions =>
      'Aucun abonnement pour le moment. Ajoutez un lien ci-dessus pour commencer.';

  @override
  String get activeSubscriptionNodes => 'Serveurs de l’abonnement actif';

  @override
  String get chooseSubscription => 'Choisir un abonnement';

  @override
  String get selectSubscription => 'Sélectionnez un abonnement à utiliser';

  @override
  String get refreshSubscription => 'Actualiser l’abonnement sélectionné';

  @override
  String get removeSubscription => 'Supprimer l’abonnement sélectionné';

  @override
  String get subscriptionLink => 'Lien d’abonnement ou de serveur…';

  @override
  String get pasteClipboard => 'Coller depuis le presse-papiers';

  @override
  String get copyLinkFirst =>
      'Copiez d’abord un lien d’abonnement ou de serveur valide.';

  @override
  String get clipboardReadFailed => 'Impossible de lire le presse-papiers.';

  @override
  String get website => 'Site web';

  @override
  String get support => 'Assistance';

  @override
  String get description => 'Description';

  @override
  String get lastUpdated => 'Dernière mise à jour';

  @override
  String get expires => 'Expiration';

  @override
  String get notUpdated => 'Non actualisé';

  @override
  String get notProvided => 'Non indiqué';

  @override
  String get expired => 'Expiré';

  @override
  String openLink(String p0) {
    return 'Ouvrir $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return 'Lien $p0 non fourni';
  }

  @override
  String get openLinkFailed => 'Impossible d’ouvrir le lien.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'Impossible d’ouvrir le lien $p0.';
  }

  @override
  String get disconnectSubscriptions =>
      'Déconnectez-vous avant de modifier les abonnements.';

  @override
  String get disconnectServers =>
      'Déconnectez-vous avant de changer de serveur.';

  @override
  String get disconnectRefresh =>
      'Déconnectez-vous avant d’actualiser votre abonnement.';

  @override
  String get disconnectRouting =>
      'Déconnectez-vous avant de modifier les règles de routage.';

  @override
  String get disconnectInstall =>
      'Déconnectez-vous avant d’installer une mise à jour.';

  @override
  String get waitCurrentOperation => 'Attendez la fin de l’opération en cours.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'Déconnectez-vous avant $p0.';
  }

  @override
  String get changingCore => 'de changer de moteur';

  @override
  String get changingMode => 'de changer de mode de connexion';

  @override
  String get changingDns => 'de modifier le DNS';

  @override
  String get changingKillSwitch => 'de modifier le coupe-circuit';

  @override
  String get core => 'Moteur';

  @override
  String get networkingCore => 'Moteur réseau';

  @override
  String get coreHelp =>
      'Choisissez le moteur manuellement. Le moteur requis est indiqué pour chaque serveur dans l’onglet « Abonnements ».';

  @override
  String get connectionMode => 'Mode de connexion';

  @override
  String get connectionModeHelp =>
      'Le mode VPN (TUN) achemine automatiquement le trafic système. Le proxy local nécessite de configurer le proxy dans vos applications.';

  @override
  String get killSwitch => 'Coupe-circuit';

  @override
  String get killSwitchHelp =>
      'Protège le DNS et le routage TUN pendant la connexion. L’accès normal à Internet reprend après la déconnexion.';

  @override
  String get availableTun => 'Disponible en mode VPN (TUN).';

  @override
  String get quickSettings => 'Paramètres rapides';

  @override
  String get quickSettingsSubtitle => 'Se connecter depuis le panneau Android';

  @override
  String get quickSettingsHelp =>
      'Utilisez la tuile AORA Connect pour vous connecter au serveur sélectionné ou vous déconnecter. Maintenez-la appuyée pour ouvrir l’application.';

  @override
  String get addQuickSettings => 'Ajouter aux paramètres rapides';

  @override
  String get tileAdded => 'AORA Connect a été ajouté aux paramètres rapides.';

  @override
  String get tileAlreadyAdded =>
      'AORA Connect est déjà dans les paramètres rapides.';

  @override
  String get tileManual =>
      'Ouvrez les paramètres rapides, appuyez sur « Modifier », puis ajoutez la tuile AORA Connect.';

  @override
  String get tileDeclined => 'La tuile n’a pas été ajoutée.';

  @override
  String get tileFailed =>
      'Impossible d’ajouter la tuile. Ouvrez les paramètres rapides et ajoutez AORA Connect via « Modifier ».';

  @override
  String get dnsServer => 'Serveur DNS';

  @override
  String get dnsHelp =>
      'Fournisseur DNS pour VPN (TUN). Le DNS du système n’est pas modifié en mode proxy local.';

  @override
  String get serverChecks => 'Tests des serveurs';

  @override
  String get serverPingMethod => 'Méthode de test des serveurs';

  @override
  String get serverChecksHelp =>
      'S’applique aux tests des serveurs dans toute l’application. Les statistiques utilisent ICMP. Les tests par proxy accèdent à https://www.gstatic.com/generate_204 via chaque serveur.';

  @override
  String get diagnostics => 'Diagnostic';

  @override
  String get diagnosticsSubtitle => 'Validation, test de connexion et journaux';

  @override
  String get coreLogs => 'Journaux du moteur';

  @override
  String get noLogs => 'Aucun journal pour le moment.';

  @override
  String get about => 'À propos';

  @override
  String get aboutClient => 'Un client VPN universel et open source.';

  @override
  String get license => 'Licence : GNU GPL version 3 ou ultérieure.';

  @override
  String get coresLicense =>
      'Moteurs réseau : sing-box et Xray. Leurs binaires et licences sont distincts de ceux de l’application.';

  @override
  String get statistics => 'Statistiques';

  @override
  String get off => 'Désactivé';

  @override
  String get pingMeasuring => 'Latence serveur · mesure…';

  @override
  String get pingNoReply => 'Latence serveur · aucune réponse';

  @override
  String pingValue(String p0) {
    return 'Latence serveur · $p0';
  }

  @override
  String get connectStatistics =>
      'Connectez-vous pour voir les statistiques ICMP en direct';

  @override
  String target(String p0) {
    return 'Cible : $p0';
  }

  @override
  String get measuring => 'Mesure…';

  @override
  String get noReply => 'Aucune réponse';

  @override
  String get waitingSamples => 'En attente de mesures';

  @override
  String replies(String p0, String p1) {
    return 'Réponses : $p0/$p1';
  }

  @override
  String get pingHistory => 'Historique de latence du serveur. ';

  @override
  String successfulChecks(String p0, String p1) {
    return 'Tests réussis : $p0 sur $p1.';
  }

  @override
  String get pingHistoryHelp =>
      'Latence mesurée chaque seconde · 30 dernières mesures. Les interruptions indiquent une absence de réponse.';

  @override
  String get connectCollectStatistics =>
      'Connectez-vous pour recueillir des mesures ICMP en direct.';

  @override
  String get statisticsOff => 'Les statistiques sont désactivées.';

  @override
  String get lessOneMs => '<1 ms';

  @override
  String milliseconds(String p0) {
    return '$p0 ms';
  }

  @override
  String get notChecked => 'Non testé';

  @override
  String get noCompletedCheck => 'Aucun test de serveur terminé';

  @override
  String lastCheck(String p0, String p1) {
    return 'Dernier test à $p0:$p1';
  }

  @override
  String get checkServers => 'Test des serveurs';

  @override
  String get cancelChecks => 'Annuler les tests des serveurs';

  @override
  String serverCheck(String p0) {
    return 'Test de serveur via $p0';
  }

  @override
  String get applicationsAddresses => 'Applications et adresses';

  @override
  String get routeListedItems =>
      'Acheminer les applications et adresses de la liste';

  @override
  String get listedThroughTunnel =>
      'Les éléments de la liste passent par le tunnel. Le reste utilise votre connexion habituelle.';

  @override
  String get listedBypassTunnel =>
      'Les éléments de la liste utilisent votre connexion habituelle. Le reste passe par le tunnel.';

  @override
  String get routingDisabled =>
      'Les règles de routage sont désactivées. Le trafic utilise le serveur VPN sélectionné.';

  @override
  String get useTunRouting =>
      'Utilisez le mode VPN (TUN) pour acheminer le trafic système.';

  @override
  String get emptyThroughTunnel =>
      'Aucun élément. Tout le trafic passe par le tunnel.';

  @override
  String get emptyBypassTunnel =>
      'Aucun élément. Tout le trafic utilise votre connexion habituelle.';

  @override
  String get addRule => 'Ajouter une règle';

  @override
  String get addRoutingRule => 'Ajouter une règle de routage';

  @override
  String get editRoutingRule => 'Modifier la règle de routage';

  @override
  String get editRule => 'Modifier la règle';

  @override
  String get deleteRule => 'Supprimer la règle';

  @override
  String get moveUp => 'Déplacer vers le haut';

  @override
  String get moveDown => 'Déplacer vers le bas';

  @override
  String enableTarget(String p0) {
    return 'Activer $p0';
  }

  @override
  String get match => 'Critère';

  @override
  String get value => 'Valeur';

  @override
  String get chooseApplication => 'Choisir une application';

  @override
  String get installedApplications => 'Applications installées';

  @override
  String get runningApplications => 'Applications en cours';

  @override
  String get searchApplications => 'Rechercher des applications';

  @override
  String get noMatchingApplications => 'Aucune application correspondante.';

  @override
  String get applicationsUnavailable => 'Liste des applications indisponible.';

  @override
  String get runningSelectionDesktop =>
      'La sélection des applications en cours est disponible sur ordinateur.';

  @override
  String get runningReadFailed =>
      'Impossible de lire la liste des applications en cours.';

  @override
  String get installedLoadFailed =>
      'Impossible de charger les applications. Réessayez ou saisissez le nom du paquet manuellement.';

  @override
  String get runningLoadFailed =>
      'Impossible de charger les applications en cours. Réessayez ou saisissez le nom du processus manuellement.';

  @override
  String get updates => 'Mises à jour';

  @override
  String version(String p0) {
    return 'Version $p0';
  }

  @override
  String get automaticUpdates => 'Vérifier au démarrage';

  @override
  String get automaticUpdatesSemantics =>
      'Rechercher automatiquement les mises à jour';

  @override
  String get checkUpdates => 'Rechercher des mises à jour';

  @override
  String get importUpdate => 'Mettre à jour depuis un fichier';

  @override
  String get downloadUpdate => 'Télécharger la mise à jour';

  @override
  String get installUpdate => 'Installer la mise à jour';

  @override
  String get install => 'Installer';

  @override
  String installVersion(String p0) {
    return 'Installer $p0 ?';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect se fermera puis se rouvrira après l’installation. Vos paramètres et abonnements seront conservés.';

  @override
  String get androidInstallHelp =>
      'Android vous demandera de confirmer l’installation. Vos paramètres, abonnements et règles de routage seront conservés.';

  @override
  String get androidApk => 'APK AORA pour Android';

  @override
  String get windowsInstaller => 'Programme de mise à jour AORA';

  @override
  String get additionalSources => 'Sources supplémentaires (facultatif)';

  @override
  String additionalSourcesCount(String p0) {
    return 'Sources supplémentaires : $p0';
  }

  @override
  String get updateSources => 'Sources des mises à jour';

  @override
  String get updateSourcesHelp =>
      'Miroirs facultatifs. GitHub est consulté en premier.';

  @override
  String get metadataUrlPerLine => 'Une URL HTTPS de métadonnées par ligne';

  @override
  String updateAvailableNotification(String p0) {
    return 'La mise à jour $p0 est disponible dans Paramètres → Mises à jour.';
  }

  @override
  String get notAvailable => 'Indisponible';

  @override
  String get system => 'Système';

  @override
  String get idle => 'Inactif';

  @override
  String get throughTunnel => 'Via le tunnel';

  @override
  String get bypassingTunnel => 'Hors du tunnel';

  @override
  String get application => 'Application';

  @override
  String get domainSubdomains => 'Domaine et sous-domaines';

  @override
  String get exactDomain => 'Domaine exact';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'Via proxy GET';

  @override
  String get proxyHead => 'Via proxy HEAD';

  @override
  String get stateStopped => 'déconnecté';

  @override
  String get stateStarting => 'connexion';

  @override
  String get stateRunning => 'connecté';

  @override
  String get stateStopping => 'déconnexion';

  @override
  String get timeout => 'Délai dépassé';

  @override
  String get failed => 'Échec';

  @override
  String get unavailable => 'Indisponible';

  @override
  String get checkingUpdates => 'Recherche de mises à jour…';

  @override
  String get upToDate => 'Aucune mise à jour plus récente';

  @override
  String updateAvailable(String p0) {
    return 'Mise à jour $p0 disponible';
  }

  @override
  String get downloadingUpdate => 'Téléchargement de la mise à jour…';

  @override
  String get updateReady => 'Mise à jour vérifiée et prête à être installée';

  @override
  String get verifyingUpdate => 'Vérification du fichier de mise à jour…';

  @override
  String updateVersionReady(String p0) {
    return 'Mise à jour $p0 vérifiée et prête à être installée';
  }

  @override
  String get updateFailed => 'La mise à jour n’a pas pu être effectuée';

  @override
  String get installationCompleted => 'Installation terminée';

  @override
  String get trayShow => 'Afficher AORA Connect';

  @override
  String get trayExit => 'Quitter';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count jours',
      one: 'Encore $count jour',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '$count serveur',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'Non chargé';

  @override
  String skippedServers(int count) {
    return '$count ignorés';
  }

  @override
  String connectionVerified(String p0) {
    return 'Connexion vérifiée ($p0 ms).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'Connexion HTTPS via $p0 réussie ($p1 ms).';
  }

  @override
  String get routingValidationEmpty => 'Saisissez une valeur.';

  @override
  String get routingValidationControlCharacters =>
      'Les caractères de contrôle ne sont pas autorisés.';

  @override
  String get routingValidationApplication =>
      'Saisissez un chemin d’exécutable ou un nom de processus, sans caractère générique.';

  @override
  String get routingValidationDomain =>
      'Saisissez un domaine sans protocole, chemin ni caractère générique.';

  @override
  String get routingValidationIp =>
      'Saisissez une adresse IP ou une plage CIDR.';

  @override
  String get routingValidationPrefix => 'Le préfixe CIDR est invalide.';

  @override
  String get httpsSourcesOnly =>
      'Les sources de mise à jour doivent être des URL HTTPS sans identifiants.';

  @override
  String get checkAllServers => 'Tester tous les serveurs';

  @override
  String get checkSelectedServer => 'Tester le serveur sélectionné';
}
