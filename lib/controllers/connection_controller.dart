// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import '../core/connection_probe.dart';
import '../core/development_paths.dart';
import '../core/kill_switch.dart';
import '../core/ping_type.dart';
import '../core/tunnel_engine.dart';
import '../core/windows_core_engine.dart';
import '../profiles/server_profile.dart';
import '../profiles/hysteria_profile.dart';
import '../profiles/subscription_loader.dart';
import '../storage/app_settings_store.dart';
import '../storage/app_paths.dart';
import '../routing/routing_policy.dart';

typedef SubscriptionLoader = Future<SubscriptionLoadResult> Function(
  String url,
);

enum ConnectionErrorScope { connection, subscriptions, settings, routing }

/// Owns the core session and its state; pages only display it and invoke actions.
class ConnectionController extends ChangeNotifier {
  ConnectionController({
    TunnelEngine? engine,
    TunnelEngine? xrayEngine,
    String? configPath,
    this.settingsStore,
    SubscriptionLoader? subscriptionLoader,
    KillSwitch? killSwitch,
  }) : supported = engine != null || Platform.isWindows,
       _hasTestConfig = configPath != null,
       _subscriptionLoader = subscriptionLoader ?? loadSubscriptionDetailed {
    final root = findCoreRoot();
    _engine =
        engine ??
        WindowsSingBoxEngine(
          executablePath:
              '${root.path}/cores/sing-box-${CoreKind.singBox.configuredVersion}-windows-amd64/sing-box.exe',
        );
    _xrayEngine =
        xrayEngine ??
        WindowsXrayEngine(
          executablePath:
              '${root.path}/cores/xray-v${CoreKind.xray.configuredVersion}-windows-64/xray.exe',
        );
    _configPath = configPath ?? '${root.path}/configs/local-test.json';
    _killSwitch =
        killSwitch ??
        (engine == null && Platform.isWindows
            ? const WindowsKillSwitch()
            : null);
    _state = _engine.state;
    _logs = [
      _listenLogs(_engine, CoreKind.singBox),
      _listenLogs(_xrayEngine, CoreKind.xray),
    ];
    _states = [
      _listenStates(_engine, CoreKind.singBox),
      _listenStates(_xrayEngine, CoreKind.xray),
    ];
  }

  final bool supported;
  final AppSettingsStore? settingsStore;
  final SubscriptionLoader _subscriptionLoader;
  final bool _hasTestConfig;
  late final KillSwitch? _killSwitch;
  late final TunnelEngine _engine;
  late final TunnelEngine _xrayEngine;
  late final String _configPath;
  late final List<StreamSubscription<String>> _logs;
  late final List<StreamSubscription<TunnelState>> _states;
  final _lines = <String>[];
  List<ServerProfile> _profiles = [];
  List<SavedSubscription> _subscriptions = [];
  final Map<String, SubscriptionLoadResult> _profileCache = {};
  String? _activeSubscriptionUrl;
  ServerProfile? _selected;
  TunnelState _state = TunnelState.stopped;
  ConnectionMode _mode = ConnectionMode.tun;
  CoreKind _core = CoreKind.singBox;
  PingType _pingType = PingType.proxyGet;
  bool _killSwitchEnabled = true;
  bool _statisticsEnabled = false;
  RoutingPolicy _routingPolicy = const RoutingPolicy();
  String? _selectedServerAddress;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  ConnectionErrorScope? _errorScope;
  String? _probeResult;
  String? _importedConfigPath;
  Directory? _runtimeDirectory;
  Future<void>? _pending;
  Future<void>? _cleanup;

  TunnelState get state => _state;
  ConnectionMode get mode => _mode;
  CoreKind get core => _core;
  PingType get pingType => _pingType;
  bool get killSwitchEnabled => _killSwitchEnabled;
  bool get statisticsEnabled => _statisticsEnabled;
  RoutingPolicy get routingPolicy => _routingPolicy;
  bool get killSwitchAvailable => supported && _mode == ConnectionMode.tun;
  String? get selectedServerAddress => _selectedServerAddress;
  bool get busy => _busy;
  String? get error => _error;
  String? errorFor(ConnectionErrorScope scope) =>
      _errorScope == scope ? _error : null;
  String? get probeResult => _probeResult;
  ServerProfile? get selected => _selected;
  List<ServerProfile> get profiles => List.unmodifiable(_profiles);
  List<SavedSubscription> get subscriptions =>
      List.unmodifiable(_subscriptions);
  String? get activeSubscriptionUrl => _activeSubscriptionUrl;
  String get activeProviderName {
    final title = _profileCache[_activeSubscriptionUrl]?.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final uri = Uri.tryParse(_activeSubscriptionUrl ?? '');
    return uri?.scheme == 'https' && uri!.host.isNotEmpty
        ? uri.host
        : 'Direct link';
  }

  int? profileCountFor(String url) => _profileCache[url]?.profiles.length;
  int? skippedCountFor(String url) => _profileCache[url]?.skippedCount;
  SubscriptionLoadResult? subscriptionDetailsFor(String url) =>
      _profileCache[url];
  List<String> get logs => List.unmodifiable(_lines);
  bool get canEdit => !_busy && _state == TunnelState.stopped;
  bool get canConnect =>
      supported &&
      canEdit &&
      (_selected != null
          ? _selected!.coreKind == _core
          : _hasTestConfig && _core == CoreKind.singBox);
  bool get canStop => !_busy && _state == TunnelState.running;
  bool get canTest => canStop && _selected != null;
  String get _activeConfig => _importedConfigPath ?? _configPath;
  CoreKind get activeCore => _core;
  bool get selectedRequiresDifferentCore =>
      _selected != null && _selected!.coreKind != _core;
  TunnelEngine get _activeEngine => _engineFor(activeCore);
  TunnelEngine _engineFor(CoreKind kind) =>
      kind == CoreKind.xray ? _xrayEngine : _engine;

  StreamSubscription<String> _listenLogs(TunnelEngine engine, CoreKind kind) =>
      engine.logs.listen((line) {
        if (kind != activeCore) return;
        _lines.add(line);
        if (_lines.length > 500) _lines.removeAt(0);
        _changed();
      });

  StreamSubscription<TunnelState> _listenStates(
    TunnelEngine engine,
    CoreKind kind,
  ) => engine.states.listen((state) {
    if (kind != activeCore) return;
    _state = state;
    if (state != TunnelState.running) _probeResult = null;
    _changed();
  });

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _perform(
    Future<void> Function() action, {
    required ConnectionErrorScope errorScope,
  }) {
    if (_disposed || _cleanup != null || _busy) return Future.value();
    _busy = true;
    _error = null;
    _errorScope = errorScope;
    _probeResult = null;
    _changed();
    final operation = _run(action);
    _pending = operation;
    return operation;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      _pending = null;
      _changed();
    }
  }

  static String _serverKey(ServerProfile profile) => jsonEncode([
    profile.protocol,
    profile.server,
    profile.port,
    profile.name,
  ]);

  static bool _matchesSavedKey(ServerProfile profile, String? key) {
    if (key == _serverKey(profile)) return true;
    return profile is HysteriaProfile &&
        key ==
            jsonEncode([
              profile.server,
              profile.port,
              profile.serverName,
              profile.name,
            ]);
  }

  ServerProfile _preferredProfile(
    SavedSubscription subscription,
    List<ServerProfile> profiles,
  ) => profiles.firstWhere(
    (profile) => _matchesSavedKey(profile, subscription.selectedServerKey),
    orElse: () => profiles.first,
  );

  Future<void> _persist() async {
    final store = settingsStore;
    if (store == null) return;
    await store.write(
      AppSettingsData(
        subscriptions: _subscriptions,
        activeSubscriptionUrl: _activeSubscriptionUrl,
        mode: _mode,
        core: _core,
        killSwitchEnabled: _killSwitchEnabled,
        statisticsEnabled: _statisticsEnabled,
        routingPolicy: _routingPolicy,
        pingType: _pingType,
      ),
    );
  }

  Future<void> restore() {
    if (settingsStore == null && _killSwitch == null) return Future.value();
    return _perform(() async {
      // Recovery for the previous persistent firewall implementation. Perform
      // this before any network requests, even if saved preferences are invalid.
      await _killSwitch?.disarm();
      final saved = await settingsStore?.read() ?? const AppSettingsData();
      _subscriptions = saved.subscriptions;
      _activeSubscriptionUrl = saved.activeSubscriptionUrl;
      _mode = saved.mode;
      _core = saved.core;
      _pingType = saved.pingType;
      _killSwitchEnabled = saved.killSwitchEnabled;
      _statisticsEnabled = saved.statisticsEnabled;
      _routingPolicy = saved.routingPolicy;
      _changed();
      if (_activeSubscriptionUrl != null) {
        await _activate(_activeSubscriptionUrl!, refresh: true);
      }
    }, errorScope: ConnectionErrorScope.subscriptions);
  }

  Future<void> load(String url) => addSubscription(url);

  Future<void> addSubscription(String url) => _perform(() async {
    final normalized = url.trim();
    final result = await _subscriptionLoader(normalized);
    final profiles = result.profiles;
    final existing = _subscriptions.where((entry) => entry.url == normalized);
    final entry = existing.isEmpty
        ? SavedSubscription(normalized)
        : existing.first;
    final chosen = _preferredProfile(entry, profiles);
    await _selectProfile(chosen);
    if (existing.isEmpty) _subscriptions = [..._subscriptions, entry];
    _subscriptions = [
      for (final current in _subscriptions)
        if (current.url == normalized)
          current.withSelectedServer(_serverKey(chosen))
        else
          current,
    ];
    _profileCache[normalized] = result;
    _activeSubscriptionUrl = normalized;
    _profiles = profiles;
    await _persist();
  }, errorScope: ConnectionErrorScope.subscriptions);

  Future<void> _activate(String url, {bool refresh = false}) async {
    final entry = _subscriptions.firstWhere((value) => value.url == url);
    final result = refresh || !_profileCache.containsKey(url)
        ? await _subscriptionLoader(url)
        : _profileCache[url]!;
    final profiles = result.profiles;
    final chosen = _preferredProfile(entry, profiles);
    await _selectProfile(chosen);
    _profileCache[url] = result;
    _activeSubscriptionUrl = url;
    _profiles = profiles;
    _subscriptions = [
      for (final current in _subscriptions)
        if (current.url == url)
          current.withSelectedServer(_serverKey(chosen))
        else
          current,
    ];
  }

  Future<void> activateSubscription(String url) => _perform(() async {
    await _activate(url);
    await _persist();
  }, errorScope: ConnectionErrorScope.subscriptions);

  Future<void> refreshSubscription(
    String url, {
    ConnectionErrorScope errorScope = ConnectionErrorScope.subscriptions,
  }) => _perform(() async {
    if (url == _activeSubscriptionUrl) {
      await _activate(url, refresh: true);
      await _persist();
    } else {
      if (!_subscriptions.any((entry) => entry.url == url)) return;
      _profileCache[url] = await _subscriptionLoader(url);
    }
  }, errorScope: errorScope);

  Future<void> removeSubscription(String url) => _perform(() async {
    _subscriptions = _subscriptions.where((entry) => entry.url != url).toList();
    _profileCache.remove(url);
    if (_activeSubscriptionUrl == url) {
      _activeSubscriptionUrl = null;
      _profiles = [];
      _selected = null;
      _selectedServerAddress = null;
      _state = _engine.state;
      _importedConfigPath = null;
      final previous = _runtimeDirectory;
      _runtimeDirectory = null;
      if (previous != null && await previous.exists()) {
        await previous.delete(recursive: true);
      }
    }
    await _persist();
  }, errorScope: ConnectionErrorScope.subscriptions);

  Future<void> selectProfile(ServerProfile profile) => _perform(() async {
    if (!_profiles.contains(profile)) return;
    await _selectProfile(profile);
    _subscriptions = [
      for (final entry in _subscriptions)
        if (entry.url == _activeSubscriptionUrl)
          entry.withSelectedServer(_serverKey(profile))
        else
          entry,
    ];
    await _persist();
  }, errorScope: ConnectionErrorScope.connection);

  Future<void> setMode(ConnectionMode mode) => _perform(() async {
    if (_selected == null) {
      _mode = mode;
    } else {
      await _selectProfile(_selected!, mode: mode);
    }
    await _persist();
  }, errorScope: ConnectionErrorScope.settings);

  Future<void> setCore(CoreKind core) {
    if (!canEdit) return Future.value();
    return _perform(() async {
      if (_selected != null && _selected!.coreKind == core) {
        await _engineFor(core).validate(_activeConfig);
      }
      _core = core;
      _state = _activeEngine.state;
      _lines.clear();
      await _persist();
    }, errorScope: ConnectionErrorScope.settings);
  }

  Future<void> setPingType(PingType type) => _perform(() async {
    _pingType = type;
    await _persist();
  }, errorScope: ConnectionErrorScope.settings);

  Future<void> setStatisticsEnabled(bool enabled) => _perform(() async {
    _statisticsEnabled = enabled;
    await _persist();
  }, errorScope: ConnectionErrorScope.settings);

  Future<void> setRoutingPolicy(RoutingPolicy policy) {
    if (!canEdit) return Future.value();
    return _perform(() async {
      for (final rule in policy.rules) {
        final error = rule.validationError;
        if (error != null) {
          throw FormatException(error);
        }
      }
      final previous = _routingPolicy;
      _routingPolicy = policy;
      try {
        if (_selected != null) await _selectProfile(_selected!);
      } catch (_) {
        _routingPolicy = previous;
        rethrow;
      }
      await _persist();
    }, errorScope: ConnectionErrorScope.routing);
  }

  Future<void> setKillSwitchEnabled(bool enabled) => _perform(() async {
    if (_state != TunnelState.stopped) {
      throw StateError('Disconnect before changing leak protection.');
    }
    final previous = _killSwitchEnabled;
    _killSwitchEnabled = enabled;
    try {
      if (_selected != null) await _selectProfile(_selected!);
    } catch (_) {
      _killSwitchEnabled = previous;
      rethrow;
    }
    await _persist();
  }, errorScope: ConnectionErrorScope.settings);

  Future<void> _selectProfile(
    ServerProfile profile, {
    ConnectionMode? mode,
  }) async {
    final nextMode = mode ?? _mode;
    final directory = await AppPaths.createSession('profile-');
    try {
      final addresses = await InternetAddress.lookup(profile.server)
          .timeout(const Duration(seconds: 10));
      if (addresses.isEmpty) {
        throw StateError('Could not resolve the selected server.');
      }
      final address = addresses.firstWhere(
        (value) => value.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
      final config = File('${directory.path}/config.json');
      await config.writeAsString(
        jsonEncode(
          applyRouting(
            profile.config(
              mode: nextMode,
              serverAddress: address.address,
              leakProtection: _killSwitchEnabled,
            ),
            profile.coreKind,
            _routingPolicy,
          ),
        ),
      );
      if (profile.coreKind == _core) {
        await _activeEngine.validate(config.path);
      }
      final previous = _runtimeDirectory;
      if (previous != null) await previous.delete(recursive: true);
      _runtimeDirectory = directory;
      _importedConfigPath = config.path;
      _selected = profile;
      _selectedServerAddress = address.address;
      _mode = nextMode;
      _state = _activeEngine.state;
      _lines.clear();
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> validate() => _perform(() async {
    if (selectedRequiresDifferentCore) {
      throw StateError('Select ${_selected!.coreKind.label} in Settings.');
    }
    await _activeEngine.validate(_activeConfig);
  }, errorScope: ConnectionErrorScope.connection);
  Future<void> connect() => _perform(() async {
    if (selectedRequiresDifferentCore) {
      throw StateError('Select ${_selected!.coreKind.label} in Settings.');
    }
    await _killSwitch?.disarm();
    await _activeEngine.start(_activeConfig);
    if (_selected == null) return;
    try {
      final elapsed = await probeConnection(
        port: _mode == ConnectionMode.tun ? null : 17890,
      );
      _probeResult = 'Connection verified (${elapsed.inMilliseconds} ms).';
    } catch (_) {
      await _activeEngine.stop();
      rethrow;
    }
  }, errorScope: ConnectionErrorScope.connection);
  Future<void> stop() => _perform(() async {
    await _activeEngine.stop();
  }, errorScope: ConnectionErrorScope.connection);
  Future<void> testConnection() => _perform(() async {
    final elapsed = await probeConnection(
      port: _mode == ConnectionMode.tun ? null : 17890,
    );
    _probeResult =
        'HTTPS through ${_selected?.protocol ?? 'proxy'} succeeded (${elapsed.inMilliseconds} ms).';
  }, errorScope: ConnectionErrorScope.connection);

  /// Await this before accepting an application exit request.
  Future<void> shutdown() => _cleanup ??= _shutdown();
  Future<void> _shutdown() async {
    await _pending;
    await _engine.dispose();
    await _xrayEngine.dispose();
    for (final subscription in _logs) {
      await subscription.cancel();
    }
    for (final subscription in _states) {
      await subscription.cancel();
    }
    final directory = _runtimeDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}
