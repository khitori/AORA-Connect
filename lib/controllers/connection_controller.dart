// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/connection_mode.dart';
import '../core/connection_probe.dart';
import '../core/development_paths.dart';
import '../core/tunnel_engine.dart';
import '../core/windows_sing_box_engine.dart';
import '../profiles/hysteria_profile.dart';

/// Owns the core session and its state; pages only display it and invoke actions.
class ConnectionController extends ChangeNotifier {
  ConnectionController({TunnelEngine? engine, String? configPath})
    : supported = engine != null || Platform.isWindows,
      _hasTestConfig = configPath != null {
    final root = findProjectDirectory();
    _engine =
        engine ??
        WindowsSingBoxEngine(
          executablePath:
              '${root.path}/cores/sing-box-1.14.2-windows-amd64/sing-box.exe',
        );
    _configPath = configPath ?? '${root.path}/configs/local-test.json';
    _state = _engine.state;
    _logs = _engine.logs.listen((line) {
      _lines.add(line);
      if (_lines.length > 500) _lines.removeAt(0);
      _changed();
    });
    _states = _engine.states.listen((state) {
      _state = state;
      if (state != TunnelState.running) _probeResult = null;
      _changed();
    });
  }

  final bool supported;
  final bool _hasTestConfig;
  late final TunnelEngine _engine;
  late final String _configPath;
  late final StreamSubscription<String> _logs;
  late final StreamSubscription<TunnelState> _states;
  final _lines = <String>[];
  List<HysteriaProfile> _profiles = [];
  HysteriaProfile? _selected;
  TunnelState _state = TunnelState.stopped;
  ConnectionMode _mode = ConnectionMode.tun;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  String? _probeResult;
  String? _importedConfigPath;
  Directory? _runtimeDirectory;
  Future<void>? _pending;
  Future<void>? _cleanup;

  TunnelState get state => _state;
  ConnectionMode get mode => _mode;
  bool get busy => _busy;
  String? get error => _error;
  String? get probeResult => _probeResult;
  HysteriaProfile? get selected => _selected;
  List<HysteriaProfile> get profiles => List.unmodifiable(_profiles);
  List<String> get logs => List.unmodifiable(_lines);
  bool get canEdit => !_busy && _state == TunnelState.stopped;
  bool get canConnect =>
      supported && canEdit && (_selected != null || _hasTestConfig);
  bool get canStop => !_busy && _state == TunnelState.running;
  bool get canTest => canStop && _selected != null;
  String get _activeConfig => _importedConfigPath ?? _configPath;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _perform(Future<void> Function() action) {
    if (_disposed || _cleanup != null || _busy) return Future.value();
    _busy = true;
    _error = null;
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

  Future<void> load(String url) => _perform(() async {
    final profiles = await loadSubscription(url);
    await _selectProfile(profiles.first);
    _profiles = profiles;
  });

  Future<void> selectProfile(HysteriaProfile profile) =>
      _perform(() => _selectProfile(profile));

  Future<void> setMode(ConnectionMode mode) => _perform(() async {
    if (_selected == null) {
      _mode = mode;
    } else {
      await _selectProfile(_selected!, mode: mode);
    }
  });

  Future<void> _selectProfile(
    HysteriaProfile profile, {
    ConnectionMode? mode,
  }) async {
    final nextMode = mode ?? _mode;
    final directory = await Directory.systemTemp.createTemp('aoravpn-profile-');
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
          profile.config(mode: nextMode, serverAddress: address.address),
        ),
      );
      await _engine.validate(config.path);
      final previous = _runtimeDirectory;
      if (previous != null) await previous.delete(recursive: true);
      _runtimeDirectory = directory;
      _importedConfigPath = config.path;
      _selected = profile;
      _mode = nextMode;
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> validate() => _perform(() => _engine.validate(_activeConfig));
  Future<void> connect() => _perform(() async {
    await _engine.start(_activeConfig);
    if (_selected == null) return;
    try {
      final elapsed = await probeConnection(
        port: _mode == ConnectionMode.tun ? null : 17890,
      );
      _probeResult = 'Connection verified (${elapsed.inMilliseconds} ms).';
    } catch (_) {
      await _engine.stop();
      rethrow;
    }
  });
  Future<void> stop() => _perform(_engine.stop);
  Future<void> testConnection() => _perform(() async {
    final elapsed = await probeConnection(
      port: _mode == ConnectionMode.tun ? null : 17890,
    );
    _probeResult =
        'HTTPS through Hysteria2 succeeded (${elapsed.inMilliseconds} ms).';
  });

  /// Await this before accepting an application exit request.
  Future<void> shutdown() => _cleanup ??= _shutdown();
  Future<void> _shutdown() async {
    await _pending;
    await _engine.dispose();
    await _logs.cancel();
    await _states.cancel();
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
