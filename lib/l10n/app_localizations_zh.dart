// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get language => '语言';

  @override
  String get interfaceLanguage => '界面语言';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get languageSaveFailed => '无法保存语言设置。';

  @override
  String get settings => '设置';

  @override
  String get connection => '连接';

  @override
  String get subscriptions => '订阅';

  @override
  String get routing => '路由';

  @override
  String get hideToTray => '最小化到系统托盘';

  @override
  String get closeApp => '关闭应用';

  @override
  String get close => '关闭';

  @override
  String get closeMenu => '关闭菜单';

  @override
  String get openMenu => '打开菜单';

  @override
  String get menu => '菜单';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get connecting => '正在连接…';

  @override
  String get stopping => '正在断开连接…';

  @override
  String get localProxy => '本地代理';

  @override
  String get vpnTun => 'VPN (TUN)';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get saving => '正在保存…';

  @override
  String get add => '添加';

  @override
  String get edit => '编辑';

  @override
  String get refresh => '刷新';

  @override
  String get validate => '检查';

  @override
  String get testConnection => '连接';

  @override
  String get copyDiagnostics => '复制诊断信息';

  @override
  String get diagnosticsCopied => '诊断信息已复制。';

  @override
  String get diagnosticsCopyFailed => '无法复制诊断信息。';

  @override
  String get loadSubscriptionFirst => '请先在“订阅”选项卡中添加订阅。';

  @override
  String serverRequiresCore(String p0) {
    return '此服务器需要 $p0。请在设置中选择该核心。';
  }

  @override
  String selectedRequiresCore(String p0) {
    return '所选服务器需要 $p0。';
  }

  @override
  String get insecureProfile => '此配置已禁用 TLS 证书验证。';

  @override
  String get addSubscription => '添加订阅';

  @override
  String get savedSubscriptions => '已保存的订阅';

  @override
  String get noSubscriptions => '暂无订阅。请在上方添加链接。';

  @override
  String get activeSubscriptionNodes => '当前订阅中的服务器';

  @override
  String get chooseSubscription => '选择订阅';

  @override
  String get selectSubscription => '选择当前订阅';

  @override
  String get refreshSubscription => '刷新所选订阅';

  @override
  String get removeSubscription => '删除所选订阅';

  @override
  String get subscriptionLink => '订阅或服务器链接…';

  @override
  String get pasteClipboard => '从剪贴板粘贴';

  @override
  String get copyLinkFirst => '请先复制有效的订阅或服务器链接。';

  @override
  String get clipboardReadFailed => '无法读取剪贴板。';

  @override
  String get website => '网站';

  @override
  String get support => '支持';

  @override
  String get description => '描述';

  @override
  String get lastUpdated => '上次更新';

  @override
  String get expires => '到期时间';

  @override
  String get notUpdated => '尚未更新';

  @override
  String get notProvided => '未提供';

  @override
  String get expired => '已过期';

  @override
  String openLink(String p0) {
    return '打开$p0';
  }

  @override
  String linkNotProvided(String p0) {
    return '未提供$p0链接';
  }

  @override
  String get openLinkFailed => '无法打开链接。';

  @override
  String openNamedLinkFailed(String p0) {
    return '无法打开$p0链接。';
  }

  @override
  String get disconnectSubscriptions => '请先断开连接，再修改订阅。';

  @override
  String get disconnectServers => '请先断开连接，再切换服务器。';

  @override
  String get disconnectRefresh => '请先断开连接，再刷新订阅。';

  @override
  String get disconnectRouting => '请先断开连接，再编辑路由规则。';

  @override
  String get disconnectInstall => '请先断开连接，再安装更新。';

  @override
  String get waitCurrentOperation => '请等待当前操作完成。';

  @override
  String disconnectBeforeAction(String p0) {
    return '请先断开连接，再$p0。';
  }

  @override
  String get changingCore => '切换核心';

  @override
  String get changingMode => '切换连接模式';

  @override
  String get changingDns => '修改 DNS';

  @override
  String get changingKillSwitch => '修改 Kill Switch';

  @override
  String get core => '核心';

  @override
  String get networkingCore => '网络核心';

  @override
  String get coreHelp => '选择服务器所需的核心。';

  @override
  String get connectionMode => '连接模式';

  @override
  String get connectionModeHelp => 'VPN (TUN) 会自动接管系统流量。本地代理模式需要在各应用中配置代理。';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchHelp => '连接期间防止 DNS 和流量泄漏。';

  @override
  String get availableTun => '仅在 VPN (TUN) 模式下可用。';

  @override
  String get quickSettings => '快捷设置';

  @override
  String get quickSettingsSubtitle => '从快捷设置连接';

  @override
  String get quickSettingsHelp => '点按快捷设置中的图块可连接所选服务器或断开 VPN。长按可打开应用。';

  @override
  String get addQuickSettings => '添加图块';

  @override
  String get tileAdded => '已添加 AORA Connect 图块。';

  @override
  String get tileAlreadyAdded => '已添加过 AORA Connect 图块。';

  @override
  String get tileManual => '打开快捷设置，点击“编辑”，然后添加 AORA Connect 图块。';

  @override
  String get tileDeclined => '未添加图块。';

  @override
  String get tileFailed => '无法添加图块。请在快捷设置中点击“编辑”，手动添加 AORA Connect。';

  @override
  String get dnsServer => 'DNS 服务器';

  @override
  String get dnsHelp => 'VPN (TUN) 使用的 DNS 服务商。本地代理模式不会修改系统 DNS。';

  @override
  String get serverChecks => '服务器检查';

  @override
  String get serverPingMethod => '服务器检查方式';

  @override
  String get serverChecksHelp =>
      '适用于应用中的所有服务器检查。统计使用实时 ICMP。代理检查会通过每个节点访问 https://www.gstatic.com/generate_204。';

  @override
  String get diagnostics => '诊断';

  @override
  String get diagnosticsSubtitle => '配置与连接';

  @override
  String get coreLogs => '核心日志';

  @override
  String get noLogs => '暂无日志。';

  @override
  String get about => '关于';

  @override
  String get aboutClient => '开源的通用 VPN 客户端。';

  @override
  String get license => '许可证：GNU GPL 第 3 版或更新版本。';

  @override
  String get coresLicense => '网络核心：sing-box 和 Xray。其二进制文件和许可证与本应用独立。';

  @override
  String get statistics => '统计';

  @override
  String get off => '已关闭';

  @override
  String get pingMeasuring => '延迟 · 正在测量…';

  @override
  String get pingNoReply => '延迟 · 无响应';

  @override
  String pingValue(String p0) {
    return '延迟 · $p0';
  }

  @override
  String get connectStatistics => '请连接任意服务器。';

  @override
  String target(String p0) {
    return '地址：$p0';
  }

  @override
  String get measuring => '正在测量…';

  @override
  String get noReply => '无响应';

  @override
  String get waitingSamples => '正在等待采样';

  @override
  String replies(String p0, String p1) {
    return '响应：$p0/$p1';
  }

  @override
  String get pingHistory => '延迟历史。';

  @override
  String successfulChecks(String p0, String p1) {
    return '已完成的 $p1 次检查中有 $p0 次成功。';
  }

  @override
  String get pingHistoryHelp => '每秒检查一次服务器延迟 · 显示最近 30 次采样。空缺表示无响应。';

  @override
  String get connectCollectStatistics => '连接后可收集实时 ICMP 采样。';

  @override
  String get statisticsOff => '统计已关闭。';

  @override
  String get lessOneMs => '<1 毫秒';

  @override
  String milliseconds(String p0) {
    return '$p0 毫秒';
  }

  @override
  String get notChecked => '尚未检查';

  @override
  String get noCompletedCheck => '尚未完成服务器检查';

  @override
  String lastCheck(String p0, String p1) {
    return '上次检查：$p0:$p1';
  }

  @override
  String get checkServers => '正在检查服务器';

  @override
  String get cancelChecks => '取消服务器检查';

  @override
  String serverCheck(String p0) {
    return '通过 $p0 检查服务器';
  }

  @override
  String get applicationsAddresses => '应用和地址';

  @override
  String get routeListedItems => '对列表中的应用和地址进行路由';

  @override
  String get listedThroughTunnel => '列表中的项目通过隧道，其余流量使用正常连接。';

  @override
  String get listedBypassTunnel => '列表中的项目使用正常连接，其余流量通过隧道。';

  @override
  String get routingDisabled => '路由规则已关闭。流量将使用所选 VPN 服务器。';

  @override
  String get useTunRouting => '请使用 VPN (TUN) 模式路由系统流量。';

  @override
  String get emptyThroughTunnel => '列表为空。所有流量均通过隧道。';

  @override
  String get emptyBypassTunnel => '列表为空。所有流量均使用正常连接。';

  @override
  String get addRule => '添加规则';

  @override
  String get addRoutingRule => '添加路由规则';

  @override
  String get editRoutingRule => '编辑路由规则';

  @override
  String get editRule => '编辑规则';

  @override
  String get deleteRule => '删除规则';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String enableTarget(String p0) {
    return '启用 $p0';
  }

  @override
  String get match => '匹配类型';

  @override
  String get value => '值';

  @override
  String get chooseApplication => '选择应用';

  @override
  String get installedApplications => '已安装的应用';

  @override
  String get runningApplications => '正在运行的应用';

  @override
  String get searchApplications => '搜索应用';

  @override
  String get noMatchingApplications => '未找到匹配的应用。';

  @override
  String get applicationsUnavailable => '应用列表不可用。';

  @override
  String get runningSelectionDesktop => '仅桌面端支持选择正在运行的应用。';

  @override
  String get runningReadFailed => '无法获取正在运行的应用。';

  @override
  String get installedLoadFailed => '无法加载应用。请重试，或手动输入应用包名。';

  @override
  String get runningLoadFailed => '无法加载正在运行的应用。请重试，或手动输入进程名。';

  @override
  String get updates => '更新';

  @override
  String version(String p0) {
    return '版本 $p0';
  }

  @override
  String get automaticUpdates => '启动时自动检查';

  @override
  String get automaticUpdatesSemantics => '自动检查更新';

  @override
  String get checkUpdates => '检查';

  @override
  String get importUpdate => '从文件导入';

  @override
  String get downloadUpdate => '下载更新';

  @override
  String get installUpdate => '安装更新';

  @override
  String get install => '安装';

  @override
  String installVersion(String p0) {
    return '是否安装 $p0？';
  }

  @override
  String get windowsInstallHelp => 'AORA Connect 将关闭，并在安装后重新打开。你的设置和订阅将会保留。';

  @override
  String get androidInstallHelp => 'Android 将要求你确认安装。你的设置、订阅和路由规则将会保留。';

  @override
  String get androidApk => 'AORA Android APK';

  @override
  String get windowsInstaller => 'AORA 更新安装程序';

  @override
  String get additionalSources => '其他来源';

  @override
  String additionalSourcesCount(String p0) {
    return '其他来源：$p0';
  }

  @override
  String get updateSources => '更新来源';

  @override
  String get updateSourcesHelp => '可选的镜像来源。优先尝试 GitHub。';

  @override
  String get metadataUrlPerLine => '每行填写一个 HTTPS 元数据链接';

  @override
  String updateAvailableNotification(String p0) {
    return '更新 $p0 已可用，请前往“设置 → 更新”。';
  }

  @override
  String get notAvailable => '不可用';

  @override
  String get system => '系统';

  @override
  String get idle => '空闲';

  @override
  String get throughTunnel => '通过隧道';

  @override
  String get bypassingTunnel => '绕过隧道';

  @override
  String get application => '应用';

  @override
  String get domainSubdomains => '域名及子域名';

  @override
  String get exactDomain => '精确域名';

  @override
  String get ipCidr => 'IP / CIDR';

  @override
  String get proxyGet => '通过代理 GET';

  @override
  String get proxyHead => '通过代理 HEAD';

  @override
  String get stateStopped => '已断开';

  @override
  String get stateStarting => '正在连接';

  @override
  String get stateRunning => '已连接';

  @override
  String get stateStopping => '正在断开';

  @override
  String get timeout => '超时';

  @override
  String get failed => '失败';

  @override
  String get unavailable => '不可用';

  @override
  String get checkingUpdates => '正在检查更新…';

  @override
  String get upToDate => '未发现更新版本';

  @override
  String updateAvailable(String p0) {
    return '更新 $p0 已可用';
  }

  @override
  String get downloadingUpdate => '正在下载更新…';

  @override
  String get updateReady => '更新已验证，可以安装';

  @override
  String get verifyingUpdate => '正在验证更新文件…';

  @override
  String updateVersionReady(String p0) {
    return '更新 $p0 已验证，可以安装';
  }

  @override
  String get updateFailed => '无法完成更新';

  @override
  String get installationCompleted => '安装完成';

  @override
  String get trayShow => '打开 AORA Connect';

  @override
  String get trayExit => '退出';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 天',
    );
    return '$_temp0';
  }

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台服务器',
    );
    return '$_temp0';
  }

  @override
  String get notLoaded => '尚未加载';

  @override
  String skippedServers(int count) {
    return '已跳过 $count 个';
  }

  @override
  String connectionVerified(String p0) {
    return '连接已验证（$p0 毫秒）。';
  }

  @override
  String httpsSucceeded(String p0, String p1) {
    return '通过 $p0 的 HTTPS 请求成功（$p1 毫秒）。';
  }

  @override
  String get routingValidationEmpty => '请输入一个值。';

  @override
  String get routingValidationControlCharacters => '不允许使用控制字符。';

  @override
  String get routingValidationApplication => '请输入可执行文件路径或进程名，不要使用通配符。';

  @override
  String get routingValidationDomain => '请输入域名，不要包含协议、路径或通配符。';

  @override
  String get routingValidationIp => '请输入 IP 地址或 CIDR 网段。';

  @override
  String get routingValidationPrefix => 'CIDR 前缀无效。';

  @override
  String get httpsSourcesOnly => '更新来源必须是 HTTPS 链接，且不能包含用户名或密码。';

  @override
  String get checkAllServers => '检查所有服务器';

  @override
  String get checkSelectedServer => '检查所选服务器';
}
