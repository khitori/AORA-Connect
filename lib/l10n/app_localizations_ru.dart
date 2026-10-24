// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get language => 'Язык';

  @override
  String get interfaceLanguage => 'Язык интерфейса';

  @override
  String get systemDefault => 'Как в системе';

  @override
  String get languageSaveFailed => 'Не удалось сохранить выбранный язык.';

  @override
  String get settings => 'Настройки';

  @override
  String get connection => 'Подключение';

  @override
  String get subscriptions => 'Подписки';

  @override
  String get routing => 'Роутинг';

  @override
  String get hideToTray => 'Свернуть в трей';

  @override
  String get closeApp => 'Закрыть приложение';

  @override
  String get close => 'Закрыть';

  @override
  String get closeMenu => 'Закрыть меню';

  @override
  String get openMenu => 'Открыть меню';

  @override
  String get menu => 'Меню';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get connecting => 'Подключение…';

  @override
  String get stopping => 'Отключение…';

  @override
  String get localProxy => 'Локальный прокси';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get saving => 'Сохранение…';

  @override
  String get add => 'Добавить';

  @override
  String get edit => 'Изменить';

  @override
  String get refresh => 'Обновить';

  @override
  String get validate => 'Проверить';

  @override
  String get testConnection => 'Соединение';

  @override
  String get copyDiagnostics => 'Скопировать диагностику';

  @override
  String get diagnosticsCopied => 'Диагностика скопирована.';

  @override
  String get diagnosticsCopyFailed => 'Не удалось скопировать диагностику.';

  @override
  String get loadSubscriptionFirst =>
      'Сначала добавьте подписку на вкладке «Подписки».';

  @override
  String serverRequiresCore(String p0) {
    return 'Для этого сервера требуется $p0. Выберите ядро в настройках.';
  }

  @override
  String selectedRequiresCore(String p0) {
    return 'Для выбранного сервера требуется $p0.';
  }

  @override
  String get insecureProfile =>
      'В этом профиле отключена проверка сертификата TLS.';

  @override
  String get addSubscription => 'Добавить подписку';

  @override
  String get savedSubscriptions => 'Сохранённые подписки';

  @override
  String get noSubscriptions => 'Подписок пока нет. Добавьте ссылку выше.';

  @override
  String get activeSubscriptionNodes => 'Серверы активной подписки';

  @override
  String get chooseSubscription => 'Выберите подписку';

  @override
  String get selectSubscription => 'Выберите активную подписку';

  @override
  String get refreshSubscription => 'Обновить выбранную подписку';

  @override
  String get removeSubscription => 'Удалить выбранную подписку';

  @override
  String get subscriptionLink => 'Ссылка на подписку или сервер…';

  @override
  String get pasteClipboard => 'Вставить из буфера';

  @override
  String get copyLinkFirst =>
      'Сначала скопируйте ссылку на подписку или сервер.';

  @override
  String get clipboardReadFailed => 'Не удалось прочитать буфер обмена.';

  @override
  String get website => 'Сайт';

  @override
  String get support => 'Поддержка';

  @override
  String get description => 'Описание';

  @override
  String get lastUpdated => 'Обновлено';

  @override
  String get expires => 'Срок действия';

  @override
  String get notUpdated => 'Не обновлялась';

  @override
  String get notProvided => 'Не указан';

  @override
  String get expired => 'Истёк';

  @override
  String openLink(String p0) {
    return 'Открыть: $p0';
  }

  @override
  String linkNotProvided(String p0) {
    return 'Ссылка «$p0» не указана';
  }

  @override
  String get openLinkFailed => 'Не удалось открыть ссылку.';

  @override
  String openNamedLinkFailed(String p0) {
    return 'Не удалось открыть ссылку «$p0».';
  }

  @override
  String get disconnectSubscriptions =>
      'Отключитесь перед изменением подписок.';

  @override
  String get disconnectServers => 'Отключитесь перед сменой сервера.';

  @override
  String get disconnectRefresh => 'Отключитесь перед обновлением подписки.';

  @override
  String get disconnectRouting =>
      'Отключитесь перед изменением правил маршрутизации.';

  @override
  String get disconnectInstall => 'Отключитесь перед установкой обновления.';

  @override
  String get waitCurrentOperation => 'Дождитесь завершения текущей операции.';

  @override
  String disconnectBeforeAction(String p0) {
    return 'Отключитесь перед $p0.';
  }

  @override
  String get changingCore => 'сменой ядра';

  @override
  String get changingMode => 'сменой режима подключения';

  @override
  String get changingDns => 'изменением DNS';

  @override
  String get changingKillSwitch => 'изменением аварийной блокировки';

  @override
  String get core => 'Ядро';

  @override
  String get networkingCore => 'Сетевое ядро';

  @override
  String get coreHelp =>
      'Выбор ядра. Необходимо если сервер требует поддержки конкретного.';

  @override
  String get connectionMode => 'Режим подключения';

  @override
  String get connectionModeHelp =>
      'VPN (TUN) автоматически направляет системный трафик через туннель. Для локального прокси настройте прокси в приложениях.';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchHelp => 'Защищает DNS и трафик от утечек.';

  @override
  String get availableTun => 'Доступно в режиме VPN (TUN).';

  @override
  String get quickSettings => 'Быстрые настройки';

  @override
  String get quickSettingsSubtitle => 'Подключение панели';

  @override
  String get quickSettingsHelp =>
      'Системная плитка подключает к выбранному серверу или отключает VPN. Удерживание на плитке открывает само приложение.';

  @override
  String get addQuickSettings => 'Добавить плитку';

  @override
  String get tileAdded => 'Плитка AORA Connect добавлена.';

  @override
  String get tileAlreadyAdded => 'Плитка AORA Connect уже добавлена.';

  @override
  String get tileManual =>
      'Откройте быстрые настройки, нажмите «Изменить» и добавьте плитку AORA Connect.';

  @override
  String get tileDeclined => 'Плитка не добавлена.';

  @override
  String get tileFailed =>
      'Не удалось добавить плитку. Добавьте AORA Connect через «Изменить» в быстрых настройках.';

  @override
  String get dnsServer => 'DNS-сервер';

  @override
  String get dnsHelp =>
      'DNS-провайдер для VPN (TUN). В режиме локального прокси системный DNS не меняется.';

  @override
  String get serverChecks => 'Проверки серверов';

  @override
  String get serverPingMethod => 'Способ проверки серверов';

  @override
  String get serverChecksHelp =>
      'Применяется ко всем проверкам серверов. Статистика использует ICMP. Проверки через прокси запрашивают https://www.gstatic.com/generate_204 через каждый сервер.';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get diagnosticsSubtitle => 'Конфигурация и соединение';

  @override
  String get coreLogs => 'Журнал ядра';

  @override
  String get noLogs => 'Журнал пока пуст.';

  @override
  String get about => 'О приложении';

  @override
  String get aboutClient =>
      'Универсальный VPN-клиент с открытым исходным кодом.';

  @override
  String get license => 'Лицензия: GNU GPL версии 3 или новее.';

  @override
  String get coresLicense =>
      'Сетевые ядра: sing-box и Xray. Их бинарные файлы и лицензии поставляются отдельно от приложения.';

  @override
  String get statistics => 'Статистика';

  @override
  String get off => 'Выключено';

  @override
  String get pingMeasuring => 'Задержка · измерение…';

  @override
  String get pingNoReply => 'Задержка · нет ответа';

  @override
  String pingValue(String p0) {
    return 'Задержка · $p0';
  }

  @override
  String get connectStatistics => 'Подключитесь к любому серверу.';

  @override
  String target(String p0) {
    return 'Адрес: $p0';
  }

  @override
  String get measuring => 'Измерение…';

  @override
  String get noReply => 'Нет ответа';

  @override
  String get waitingSamples => 'Ожидание измерений';

  @override
  String replies(String p0, String p1) {
    return 'Ответы: $p0/$p1';
  }

  @override
  String get pingHistory => 'История задержки. ';

  @override
  String successfulChecks(String p0, String p1) {
    return 'Успешных проверок: $p0 из $p1.';
  }

  @override
  String get pingHistoryHelp =>
      'Измерение каждую секунду · последние 30 измерений. Пропуски означают отсутствие ответа.';

  @override
  String get connectCollectStatistics =>
      'Подключитесь для сбора статистики ICMP.';

  @override
  String get statisticsOff => 'Статистика выключена.';

  @override
  String get lessOneMs => '<1 мс';

  @override
  String milliseconds(String p0) {
    return '$p0 мс';
  }

  @override
  String get notChecked => 'Не проверен';

  @override
  String get noCompletedCheck => 'Проверки ещё не завершены';

  @override
  String lastCheck(String p0, String p1) {
    return 'Последняя проверка: $p0:$p1';
  }

  @override
  String get checkServers => 'Проверка серверов';

  @override
  String get cancelChecks => 'Отменить проверки';

  @override
  String serverCheck(String p0) {
    return 'Проверка сервера: $p0';
  }

  @override
  String get applicationsAddresses => 'Приложения и адреса';

  @override
  String get routeListedItems => 'Маршрутизация указанных приложений и адресов';

  @override
  String get listedThroughTunnel =>
      'Указанные приложения и адреса используют туннель. Остальной трафик идёт напрямую.';

  @override
  String get listedBypassTunnel =>
      'Указанные приложения и адреса работают напрямую. Остальной трафик идёт через туннель.';

  @override
  String get routingDisabled =>
      'Правила маршрутизации выключены. Трафик идёт через выбранный VPN-сервер.';

  @override
  String get useTunRouting =>
      'Для маршрутизации системного трафика включите VPN (TUN).';

  @override
  String get emptyThroughTunnel =>
      'Список пуст. Весь трафик идёт через туннель.';

  @override
  String get emptyBypassTunnel => 'Список пуст. Весь трафик идёт напрямую.';

  @override
  String get addRule => 'Добавить правило';

  @override
  String get addRoutingRule => 'Добавить правило маршрутизации';

  @override
  String get editRoutingRule => 'Изменить правило маршрутизации';

  @override
  String get editRule => 'Изменить правило';

  @override
  String get deleteRule => 'Удалить правило';

  @override
  String get moveUp => 'Переместить вверх';

  @override
  String get moveDown => 'Переместить вниз';

  @override
  String enableTarget(String p0) {
    return 'Включить: $p0';
  }

  @override
  String get match => 'Условие';

  @override
  String get value => 'Значение';

  @override
  String get chooseApplication => 'Выбрать приложение';

  @override
  String get installedApplications => 'Установленные приложения';

  @override
  String get runningApplications => 'Запущенные приложения';

  @override
  String get searchApplications => 'Поиск приложений';

  @override
  String get noMatchingApplications => 'Приложения не найдены.';

  @override
  String get applicationsUnavailable => 'Список приложений недоступен.';

  @override
  String get runningSelectionDesktop =>
      'Выбор запущенного приложения доступен на компьютере.';

  @override
  String get runningReadFailed =>
      'Не удалось получить список запущенных приложений.';

  @override
  String get installedLoadFailed =>
      'Не удалось загрузить приложения. Повторите попытку или введите имя пакета вручную.';

  @override
  String get runningLoadFailed =>
      'Не удалось загрузить приложения. Повторите попытку или введите имя процесса вручную.';

  @override
  String get updates => 'Обновления';

  @override
  String version(String p0) {
    return 'Версия $p0';
  }

  @override
  String get automaticUpdates => 'Проверять при запуске';

  @override
  String get automaticUpdatesSemantics => 'Проверять обновления автоматически';

  @override
  String get checkUpdates => 'Проверить';

  @override
  String get importUpdate => 'Через файл';

  @override
  String get downloadUpdate => 'Скачать обновление';

  @override
  String get installUpdate => 'Установить обновление';

  @override
  String get install => 'Установить';

  @override
  String installVersion(String p0) {
    return 'Установить $p0?';
  }

  @override
  String get windowsInstallHelp =>
      'AORA Connect закроется и откроется после установки. Настройки и подписки сохранятся.';

  @override
  String get androidInstallHelp =>
      'Android запросит подтверждение установки. Настройки, подписки и правила маршрутизации сохранятся.';

  @override
  String get androidApk => 'APK AORA для Android';

  @override
  String get windowsInstaller => 'Установщик обновления AORA';

  @override
  String get additionalSources => 'Дополнительные источники';

  @override
  String additionalSourcesCount(String p0) {
    return 'Дополнительные источники: $p0';
  }

  @override
  String get updateSources => 'Источники обновлений';

  @override
  String get updateSourcesHelp =>
      'Необязательные зеркала. Сначала проверяется GitHub.';

  @override
  String get metadataUrlPerLine =>
      'По одной HTTPS-ссылке на метаданные в строке';

  @override
  String updateAvailableNotification(String p0) {
    return 'Обновление $p0 доступно в разделе «Настройки → Обновления».';
  }

  @override
  String get notAvailable => 'Недоступно';

  @override
  String get system => 'Система';

  @override
  String get idle => 'Ожидание';

  @override
  String get throughTunnel => 'Через туннель';

  @override
  String get bypassingTunnel => 'В обход туннеля';

  @override
  String get application => 'Приложение';

  @override
  String get domainSubdomains => 'Домен и поддомены';

  @override
  String get exactDomain => 'Точный домен';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => 'Через прокси GET';

  @override
  String get proxyHead => 'Через прокси HEAD';

  @override
  String get stateStopped => 'отключено';

  @override
  String get stateStarting => 'подключение';

  @override
  String get stateRunning => 'подключено';

  @override
  String get stateStopping => 'отключение';

  @override
  String get timeout => 'Время ожидания истекло';

  @override
  String get failed => 'Ошибка';

  @override
  String get unavailable => 'Недоступно';

  @override
  String get checkingUpdates => 'Проверка обновлений…';

  @override
  String get upToDate => 'Установлена последняя версия';

  @override
  String updateAvailable(String p0) {
    return 'Доступно обновление $p0';
  }

  @override
  String get downloadingUpdate => 'Загрузка обновления…';

  @override
  String get updateReady => 'Обновление проверено и готово к установке';

  @override
  String get verifyingUpdate => 'Проверка файла обновления…';

  @override
  String updateVersionReady(String p0) {
    return 'Обновление $p0 проверено и готово к установке';
  }

  @override
  String get updateFailed => 'Не удалось завершить обновление';

  @override
  String get installationCompleted => 'Установка завершена';

  @override
  String get trayShow => 'Открыть AORA Connect';

  @override
  String get trayExit => 'Выход';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count дня',
      many: 'Осталось $count дней',
      few: 'Осталось $count дня',
      one: 'Остался $count день',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сервера',
      many: '$count серверов',
      few: '$count сервера',
      one: '$count сервер',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => 'Не загружена';

  @override
  String skippedServers(int count) {
    return 'Пропущено: $count';
  }

  @override
  String connectionVerified(String p0) {
    return 'Соединение проверено ($p0 мс).';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return 'HTTPS через $p0: успешно ($p1 мс).';
  }

  @override
  String get routingValidationEmpty => 'Введите значение.';

  @override
  String get routingValidationControlCharacters =>
      'Управляющие символы недопустимы.';

  @override
  String get routingValidationApplication =>
      'Введите путь к программе или имя процесса без подстановочных знаков.';

  @override
  String get routingValidationDomain =>
      'Введите домен без протокола, пути и подстановочных знаков.';

  @override
  String get routingValidationIp => 'Введите IP-адрес или диапазон CIDR.';

  @override
  String get routingValidationPrefix => 'Некорректный префикс CIDR.';

  @override
  String get httpsSourcesOnly =>
      'Источники обновлений должны быть HTTPS-ссылками без учётных данных.';

  @override
  String get checkAllServers => 'Проверить все серверы';

  @override
  String get checkSelectedServer => 'Проверить выбранный сервер';
}
