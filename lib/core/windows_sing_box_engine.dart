// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tunnel_engine.dart';

class WindowsSingBoxEngine implements TunnelEngine {
  WindowsSingBoxEngine({required this.executablePath, this.hostPath});

  final String executablePath;
  final String? hostPath;
  bool _usingHost = false;
  final _logs = StreamController<String>.broadcast();
  final _states = StreamController<TunnelState>.broadcast();
  Process? _process;
  Future<void>? _operation;
  Future<void>? _disposal;
  bool _disposed = false;
  TunnelState _state = TunnelState.stopped;

  @override
  TunnelState get state => _state;
  @override
  Stream<TunnelState> get states => _states.stream;
  @override
  Stream<String> get logs => _logs.stream;

  void _setState(TunnelState value) {
    _state = value;
    _states.add(value);
  }

  Future<void> _exclusive(Future<void> Function() action) {
    if (_disposed) throw StateError('Engine has been disposed.');
    if (_operation != null) {
      throw StateError('An operation is already running.');
    }
    final operation = action();
    _operation = operation;
    return operation.whenComplete(() => _operation = null);
  }

  Future<void> _validate(String configPath) async {
    if (!Platform.isWindows) throw UnsupportedError('Windows core required.');
    if (!await File(executablePath).exists()) {
      throw StateError('Core not found: $executablePath');
    }
    final result = await Process.run(executablePath, [
      'check',
      '-c',
      File(configPath).absolute.path,
      '--disable-color',
    ], workingDirectory: File(executablePath).absolute.parent.path);
    final output = '${result.stdout}${result.stderr}'.trim();
    if (output.isNotEmpty) _logs.add(output);
    if (result.exitCode != 0) {
      throw StateError('Configuration rejected (exit ${result.exitCode}).');
    }
    _logs.add('Configuration is valid.');
  }

  @override
  Future<void> validate(String configPath) =>
      _exclusive(() => _validate(configPath));

  @override
  Future<void> start(String configPath) => _exclusive(() async {
    if (_state != TunnelState.stopped) {
      throw StateError('Core is already active.');
    }
    _setState(TunnelState.starting);
    try {
      await _validate(configPath);
      final host =
          hostPath ??
          '${File(Platform.resolvedExecutable).parent.path}/aoravpn_core_host.exe';
      _usingHost = await File(host).exists();
      final config = jsonDecode(await File(configPath).readAsString()) as Map;
      final isTun = (config['inbounds'] as List? ?? []).any(
        (entry) => entry['type'] == 'tun',
      );
      if (isTun && !_usingHost) {
        throw StateError(
          'TUN requires aoravpn_core_host.exe beside the app. Rebuild the Windows application.',
        );
      }
      final process = await Process.start(
        _usingHost ? host : executablePath,
        _usingHost
            ? [
                File(executablePath).absolute.path,
                File(configPath).absolute.path,
              ]
            : ['run', '-c', File(configPath).absolute.path, '--disable-color'],
        workingDirectory: File(executablePath).absolute.parent.path,
      );
      _process = process;
      final ready = Completer<void>();
      final subscriptions = <StreamSubscription<String>>[];
      void read(String line) {
        _logs.add(line);
        if (line.contains('sing-box started') && !ready.isCompleted) {
          ready.complete();
        }
      }

      for (final stream in [process.stdout, process.stderr]) {
        subscriptions.add(
          stream
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())
              .listen(read),
        );
      }
      unawaited(
        process.exitCode.then((code) async {
          if (!ready.isCompleted) {
            ready.completeError(
              StateError('Core exited during startup (exit $code).'),
            );
          }
          // Drain the pipes before disposing their listeners.
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
          if (identical(_process, process)) {
            _process = null;
            _setState(TunnelState.stopped);
            _logs.add('Core exited (exit $code).');
          }
        }),
      );
      await ready.future.timeout(const Duration(seconds: 20));
      if (!identical(_process, process)) throw StateError('Core has exited.');
      _setState(TunnelState.running);
    } catch (_) {
      await _stop();
      rethrow;
    }
  });

  Future<void> _stop() async {
    final process = _process;
    if (process == null) {
      _setState(TunnelState.stopped);
      return;
    }
    _setState(TunnelState.stopping);
    if (_usingHost) {
      process.stdin.writeln('stop');
      await process.stdin.flush();
      final code = await process.exitCode.timeout(const Duration(seconds: 12));
      _logs.add('Core stopped (exit $code).');
      if (code != 0) _logs.add('Core shutdown returned exit $code.');
    } else {
      // Used only for local proxy tests without the native host.
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
    _process = null;
    _setState(TunnelState.stopped);
  }

  @override
  Future<void> stop() => _exclusive(_stop);

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    if (_operation != null) {
      try {
        await _operation;
      } catch (_) {
        /* Startup may have failed. */
      }
    }
    await _stop();
    await _logs.close();
    await _states.close();
  }
}
