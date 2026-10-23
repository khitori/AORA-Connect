// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get language => 'Idioma';

  @override
  String get interfaceLanguage => 'Idioma de la interfaz';

  @override
  String get systemDefault => 'Idioma del sistema';

  @override
  String get languageSaveFailed => 'No se pudo guardar el idioma seleccionado.';

  @override
  String get settings => 'Ajustes';

  @override
  String get connection => 'Conexión';

  @override
  String get subscriptions => 'Suscripciones';

  @override
  String get routing => 'Enrutamiento';

  @override
  String get hideToTray => 'Minimizar al área de notificación';

  @override
  String get closeApp => 'Cerrar la aplicación';

  @override
  String get close => 'Cerrar';

  @override
  String get closeMenu => 'Cerrar el menú';

  @override
  String get openMenu => 'Abrir el menú';

  @override
  String get menu => 'Menú';

  @override
  String get connect => 'Conectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get connecting => 'Conectando…';

  @override
  String get stopping => 'Desconectando…';

  @override
  String get localProxy => 'Proxy local';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get saving => 'Guardando…';

  @override
  String get add => 'Añadir';

  @override
  String get edit => 'Editar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get validate => 'Validar';

  @override
  String get testConnection => 'Probar conexión';

  @override
  String get copyDiagnostics => 'Copiar diagnóstico';

  @override
  String get diagnosticsCopied => 'Diagnóstico copiado.';

  @override
  String get diagnosticsCopyFailed => 'No se pudo copiar el diagnóstico.';

  @override
  String get loadSubscriptionFirst =>
      'Primero añade una suscripción en la pestaña Suscripciones.';

  @override
  String serverRequiresCore(String p0) {
    return 'Este servidor requiere $p0. Selecciónalo en Ajustes.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'El servidor seleccionado requiere $p0.';
  }

  @override
  String get insecureProfile =>
      'Este perfil desactiva la verificación del certificado TLS.';

  @override
  String get addSubscription => 'Añadir suscripción';

  @override
  String get savedSubscriptions => 'Suscripciones guardadas';

  @override
  String get noSubscriptions =>
      'Aún no hay suscripciones. Añade un enlace arriba para empezar.';

  @override
  String get activeSubscriptionNodes => 'Servidores de la suscripción activa';

  @override
  String get chooseSubscription => 'Elegir suscripción';

  @override
  String get selectSubscription => 'Selecciona la suscripción que deseas usar';

  @override
  String get refreshSubscription => 'Actualizar la suscripción seleccionada';

  @override
  String get removeSubscription => 'Eliminar la suscripción seleccionada';

  @override
  String get subscriptionLink => 'Enlace de suscripción o servidor…';

  @override
  String get pasteClipboard => 'Pegar desde el portapapeles';

  @override
  String get copyLinkFirst =>
      'Primero copia un enlace de suscripción o servidor válido.';

  @override
  String get clipboardReadFailed => 'No se pudo leer el portapapeles.';

  @override
  String get website => 'Sitio web';

  @override
  String get support => 'Soporte';

  @override
  String get description => 'Descripción';

  @override
  String get lastUpdated => 'Última actualización';

  @override
  String get expires => 'Vencimiento';

  @override
  String get notUpdated => 'Sin actualizar';

  @override
  String get notProvided => 'No indicado';

  @override
  String get expired => 'Caducado';

  @override
  String openLink(String p0) {
    return 'Abrir $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return 'No se ha proporcionado el enlace de $p0';
  }

  @override
  String get openLinkFailed => 'No se pudo abrir el enlace.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'No se pudo abrir el enlace de $p0.';
  }

  @override
  String get disconnectSubscriptions =>
      'Desconéctate antes de modificar las suscripciones.';

  @override
  String get disconnectServers => 'Desconéctate antes de cambiar de servidor.';

  @override
  String get disconnectRefresh =>
      'Desconéctate antes de actualizar tu suscripción.';

  @override
  String get disconnectRouting =>
      'Desconéctate antes de editar las reglas de enrutamiento.';

  @override
  String get disconnectInstall =>
      'Desconéctate antes de instalar una actualización.';

  @override
  String get waitCurrentOperation =>
      'Espera a que termine la operación actual.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'Desconéctate antes de $p0.';
  }

  @override
  String get changingCore => 'cambiar de núcleo';

  @override
  String get changingMode => 'cambiar el modo de conexión';

  @override
  String get changingDns => 'cambiar el DNS';

  @override
  String get changingKillSwitch => 'modificar el bloqueo de emergencia';

  @override
  String get core => 'Núcleo';

  @override
  String get networkingCore => 'Núcleo de red';

  @override
  String get coreHelp =>
      'Elige el núcleo manualmente. Cada servidor muestra el núcleo que necesita en la pestaña Suscripciones.';

  @override
  String get connectionMode => 'Modo de conexión';

  @override
  String get connectionModeHelp =>
      'VPN (TUN) enruta el tráfico del sistema automáticamente. El proxy local requiere configurar el proxy en tus aplicaciones.';

  @override
  String get killSwitch => 'Bloqueo de emergencia';

  @override
  String get killSwitchHelp =>
      'Protege el DNS y el enrutamiento TUN mientras estás conectado. El acceso normal a Internet se restablece al desconectarte.';

  @override
  String get availableTun => 'Disponible en modo VPN (TUN).';

  @override
  String get quickSettings => 'Ajustes rápidos';

  @override
  String get quickSettingsSubtitle => 'Conectar desde el panel de Android';

  @override
  String get quickSettingsHelp =>
      'Usa el botón de AORA Connect para conectarte al servidor seleccionado o desconectarte. Mantenlo pulsado para abrir la aplicación.';

  @override
  String get addQuickSettings => 'Añadir a Ajustes rápidos';

  @override
  String get tileAdded => 'AORA Connect se ha añadido a Ajustes rápidos.';

  @override
  String get tileAlreadyAdded => 'AORA Connect ya está en Ajustes rápidos.';

  @override
  String get tileManual =>
      'Abre Ajustes rápidos, pulsa Editar y arrastra AORA Connect a tus botones.';

  @override
  String get tileDeclined => 'No se ha añadido el botón de ajustes rápidos.';

  @override
  String get tileFailed =>
      'No se pudo añadir el botón. Abre Ajustes rápidos y añade AORA Connect desde Editar.';

  @override
  String get dnsServer => 'Servidor DNS';

  @override
  String get dnsHelp =>
      'Proveedor DNS para VPN (TUN). El DNS del sistema no se configura en modo proxy local.';

  @override
  String get serverChecks => 'Pruebas de servidores';

  @override
  String get serverPingMethod => 'Método de prueba de servidores';

  @override
  String get serverChecksHelp =>
      'Se aplica a las pruebas de servidores de toda la aplicación. Las estadísticas usan ICMP. Las pruebas mediante proxy solicitan https://www.gstatic.com/generate_204 a través de cada servidor.';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get diagnosticsSubtitle =>
      'Validación, prueba de conexión y registros';

  @override
  String get coreLogs => 'Registros del núcleo';

  @override
  String get noLogs => 'Aún no hay registros.';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutClient => 'Un cliente VPN universal de código abierto.';

  @override
  String get license => 'Licencia: GNU GPL versión 3 o posterior.';

  @override
  String get coresLicense =>
      'Núcleos de red: sing-box y Xray. Sus binarios y licencias son independientes de los de la aplicación.';

  @override
  String get statistics => 'Estadísticas';

  @override
  String get off => 'Desactivado';

  @override
  String get pingMeasuring => 'Latencia del servidor · midiendo…';

  @override
  String get pingNoReply => 'Latencia del servidor · sin respuesta';

  @override
  String pingValue(String p0) {
    return 'Latencia del servidor · $p0';
  }

  @override
  String get connectStatistics =>
      'Conéctate para ver las estadísticas ICMP en directo';

  @override
  String target(String p0) {
    return 'Destino: $p0';
  }

  @override
  String get measuring => 'Midiendo…';

  @override
  String get noReply => 'Sin respuesta';

  @override
  String get waitingSamples => 'Esperando muestras';

  @override
  String replies(String p0, String p1) {
    return 'Respuestas: $p0/$p1';
  }

  @override
  String get pingHistory => 'Historial de latencia del servidor. ';

  @override
  String successfulChecks(String p0, String p1) {
    return 'Pruebas correctas: $p0 de $p1.';
  }

  @override
  String get pingHistoryHelp =>
      'Latencia medida cada segundo · últimas 30 muestras. Los huecos indican que no hubo respuesta.';

  @override
  String get connectCollectStatistics =>
      'Conéctate para recopilar muestras ICMP en directo.';

  @override
  String get statisticsOff => 'Las estadísticas están desactivadas.';

  @override
  String get lessOneMs => '<1 ms';

  @override
  String milliseconds(String p0) {
    return '$p0 ms';
  }

  @override
  String get notChecked => 'Sin probar';

  @override
  String get noCompletedCheck => 'Aún no se ha completado ninguna prueba';

  @override
  String lastCheck(String p0, String p1) {
    return 'Última prueba a las $p0:$p1';
  }

  @override
  String get checkServers => 'Probando servidores';

  @override
  String get cancelChecks => 'Cancelar pruebas de servidores';

  @override
  String serverCheck(String p0) {
    return 'Prueba de servidor mediante $p0';
  }

  @override
  String get applicationsAddresses => 'Aplicaciones y direcciones';

  @override
  String get routeListedItems =>
      'Enrutar las aplicaciones y direcciones de la lista';

  @override
  String get listedThroughTunnel =>
      'Los elementos de la lista pasan por el túnel. El resto usa tu conexión normal.';

  @override
  String get listedBypassTunnel =>
      'Los elementos de la lista usan tu conexión normal. El resto pasa por el túnel.';

  @override
  String get routingDisabled =>
      'Las reglas de enrutamiento están desactivadas. El tráfico usa el servidor VPN seleccionado.';

  @override
  String get useTunRouting =>
      'Usa el modo VPN (TUN) para enrutar el tráfico del sistema.';

  @override
  String get emptyThroughTunnel =>
      'Aún no hay elementos. Todo pasa por el túnel.';

  @override
  String get emptyBypassTunnel =>
      'Aún no hay elementos. Todo usa tu conexión normal.';

  @override
  String get addRule => 'Añadir regla';

  @override
  String get addRoutingRule => 'Añadir regla de enrutamiento';

  @override
  String get editRoutingRule => 'Editar regla de enrutamiento';

  @override
  String get editRule => 'Editar regla';

  @override
  String get deleteRule => 'Eliminar regla';

  @override
  String get moveUp => 'Mover hacia arriba';

  @override
  String get moveDown => 'Mover hacia abajo';

  @override
  String enableTarget(String p0) {
    return 'Activar $p0';
  }

  @override
  String get match => 'Coincidencia';

  @override
  String get value => 'Valor';

  @override
  String get chooseApplication => 'Elegir aplicación';

  @override
  String get installedApplications => 'Aplicaciones instaladas';

  @override
  String get runningApplications => 'Aplicaciones en ejecución';

  @override
  String get searchApplications => 'Buscar aplicaciones';

  @override
  String get noMatchingApplications => 'No hay aplicaciones que coincidan.';

  @override
  String get applicationsUnavailable =>
      'La lista de aplicaciones no está disponible.';

  @override
  String get runningSelectionDesktop =>
      'La selección de aplicaciones en ejecución está disponible en escritorio.';

  @override
  String get runningReadFailed =>
      'No se pudieron obtener las aplicaciones en ejecución.';

  @override
  String get installedLoadFailed =>
      'No se pudieron cargar las aplicaciones. Reintenta o introduce el nombre del paquete manualmente.';

  @override
  String get runningLoadFailed =>
      'No se pudieron cargar las aplicaciones en ejecución. Reintenta o introduce el nombre del proceso manualmente.';

  @override
  String get updates => 'Actualizaciones';

  @override
  String version(String p0) {
    return 'Versión $p0';
  }

  @override
  String get automaticUpdates => 'Comprobar al iniciar';

  @override
  String get automaticUpdatesSemantics =>
      'Buscar actualizaciones automáticamente';

  @override
  String get checkUpdates => 'Buscar actualizaciones';

  @override
  String get importUpdate => 'Actualizar desde archivo';

  @override
  String get downloadUpdate => 'Descargar actualización';

  @override
  String get installUpdate => 'Instalar actualización';

  @override
  String get install => 'Instalar';

  @override
  String installVersion(String p0) {
    return '¿Instalar $p0?';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect se cerrará y volverá a abrirse tras la instalación. Se conservarán tus ajustes y suscripciones.';

  @override
  String get androidInstallHelp =>
      'Android te pedirá que confirmes la instalación. Se conservarán tus ajustes, suscripciones y reglas de enrutamiento.';

  @override
  String get androidApk => 'APK de AORA para Android';

  @override
  String get windowsInstaller => 'Instalador de actualización de AORA';

  @override
  String get additionalSources => 'Fuentes adicionales (opcional)';

  @override
  String additionalSourcesCount(String p0) {
    return 'Fuentes adicionales: $p0';
  }

  @override
  String get updateSources => 'Fuentes de actualización';

  @override
  String get updateSourcesHelp =>
      'Servidores alternativos opcionales. Primero se consulta GitHub.';

  @override
  String get metadataUrlPerLine => 'Una URL HTTPS de metadatos por línea';

  @override
  String updateAvailableNotification(String p0) {
    return 'La actualización $p0 está disponible en Ajustes → Actualizaciones.';
  }

  @override
  String get notAvailable => 'No disponible';

  @override
  String get system => 'Sistema';

  @override
  String get idle => 'Inactivo';

  @override
  String get throughTunnel => 'A través del túnel';

  @override
  String get bypassingTunnel => 'Sin pasar por el túnel';

  @override
  String get application => 'Aplicación';

  @override
  String get domainSubdomains => 'Dominio y subdominios';

  @override
  String get exactDomain => 'Dominio exacto';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'Mediante proxy GET';

  @override
  String get proxyHead => 'Mediante proxy HEAD';

  @override
  String get stateStopped => 'desconectado';

  @override
  String get stateStarting => 'conectando';

  @override
  String get stateRunning => 'conectado';

  @override
  String get stateStopping => 'desconectando';

  @override
  String get timeout => 'Tiempo de espera agotado';

  @override
  String get failed => 'Error';

  @override
  String get unavailable => 'No disponible';

  @override
  String get checkingUpdates => 'Buscando actualizaciones…';

  @override
  String get upToDate => 'No se encontraron actualizaciones más recientes';

  @override
  String updateAvailable(String p0) {
    return 'Actualización $p0 disponible';
  }

  @override
  String get downloadingUpdate => 'Descargando actualización…';

  @override
  String get updateReady => 'Actualización verificada y lista para instalar';

  @override
  String get verifyingUpdate => 'Verificando archivo de actualización…';

  @override
  String updateVersionReady(String p0) {
    return 'Actualización $p0 verificada y lista para instalar';
  }

  @override
  String get updateFailed => 'No se pudo completar la actualización';

  @override
  String get installationCompleted => 'Instalación completada';

  @override
  String get trayShow => 'Abrir AORA Connect';

  @override
  String get trayExit => 'Salir';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count días',
      one: 'Queda $count día',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      one: '$count servidor',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'Sin cargar';

  @override
  String skippedServers(int count) {
    return 'Omitidos: $count';
  }

  @override
  String connectionVerified(String p0) {
    return 'Conexión verificada ($p0 ms).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'HTTPS mediante $p0 correcto ($p1 ms).';
  }

  @override
  String get routingValidationEmpty => 'Introduce un valor.';

  @override
  String get routingValidationControlCharacters =>
      'No se permiten caracteres de control.';

  @override
  String get routingValidationApplication =>
      'Introduce la ruta de un ejecutable o un nombre de proceso, sin comodines.';

  @override
  String get routingValidationDomain =>
      'Introduce un dominio sin protocolo, ruta ni comodines.';

  @override
  String get routingValidationIp =>
      'Introduce una dirección IP o un rango CIDR.';

  @override
  String get routingValidationPrefix => 'El prefijo CIDR no es válido.';

  @override
  String get httpsSourcesOnly =>
      'Las fuentes de actualización deben ser URL HTTPS sin credenciales.';

  @override
  String get checkAllServers => 'Probar todos los servidores';

  @override
  String get checkSelectedServer => 'Probar el servidor seleccionado';
}
