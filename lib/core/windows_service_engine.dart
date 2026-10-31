// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'windows_service_transport.dart';

import 'dart:io';

import '../storage/app_paths.dart';
import 'core_kind.dart';
import 'connection_plan.dart';
import 'tunnel_engine.dart';

typedef ServiceRequest = Future<Map<String, dynamic>> Function(
  Map<String, Object?> request,
);

class WindowsServiceUnavailable implements Exception {
  WindowsServiceUnavailable(this.cause);
  final Object cause;
  @override
  String toString() =>
      'Windows service connection state is unconfirmed: $cause';
}

class WindowsServiceStopped implements Exception {
  @override
  String toString() =>
      'Windows service has stopped. Connect again to restart it.';
}

class WindowsServiceSnapshot {
  WindowsServiceSnapshot(Map<String, dynamic> value)
    : state = TunnelState.values.byName(value['state'] as String),
      core = value['core'] == null
          ? null
          : CoreKind.values.byName(value['core'] as String),
      mode = value['mode'] as String?,
      session = value['session'] as String?,
      ready = value['ready'] as bool,
      issued = value['issued'] as int,
      completed = value['completed'] as int,
      error = value['error'] as String?,
      instance = value['instance'] as String,
      revision = value['revision'] as int;
  final TunnelState state;
  final CoreKind? core;
  final String? mode;
  final String? session;
  final bool ready;
  final int issued;
  final int completed;
  final String? error;
  final String instance;
  final int revision;

  WindowsServiceSnapshot stopped() => WindowsServiceSnapshot({
    'state': 'stopped',
    'core': core?.name,
    'mode': mode,
    'session': null,
    'ready': false,
    'issued': issued,
    'completed': completed,
    'error': null,
    'instance': instance,
    'revision': revision + 1,
  });
}

class WindowsServiceClient {
  WindowsServiceClient({
    ServiceRequest? request,
    Future<void> Function()? ensureStarted,
    this.pollInterval = const Duration(seconds: 1),
  }) : _request = request ?? _nativeRequest,
       _ensureStarted =
           ensureStarted ?? (request == null ? _nativeStart : () async {});
  final ServiceRequest _request;
  final Future<void> Function() _ensureStarted;
  final Duration pollInterval;
  final _snapshots = StreamController<WindowsServiceSnapshot>.broadcast();
  final _logs = StreamController<String>.broadcast();
  Stream<WindowsServiceSnapshot> get snapshots => _snapshots.stream;
  Stream<String> get logs => _logs.stream;
  WindowsServiceSnapshot? current;
  Timer? _timer;
  Future<WindowsServiceSnapshot>? _refresh;
  int _cursor = 0;
  bool _disposed = false;
  Future<void> _requestTail = Future.value();

  static Future<void> _nativeStart() => WindowsServiceTransport.start();

  static Future<Map<String, dynamic>> _nativeRequest(
    Map<String, Object?> request,
  ) => WindowsServiceTransport.request({
    ...request,
    'command': switch (request['command']) {
      'status' => 'connection.status',
      'recover' => 'connection.recover',
      'confirm' => 'connection.confirm',
      'stop' => 'connection.stop',
      final command => command,
    },
  });
  Future<WindowsServiceSnapshot> send(
    String command, [
    Map<String, Object?> fields = const {},
  ]) {
    final operation = _requestTail.then((_) => _send(command, fields));
    _requestTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<WindowsServiceSnapshot> _send(
    String command, [
    Map<String, Object?> fields = const {},
  ]) async {
    if (_disposed) throw StateError('Service client has been disposed.');
    final reply = await _request({
      'protocol': 1,
      'command': command,
      ...fields,
    });
    if (reply['protocol'] == 1 && reply['service_stopped'] == true) {
      final stopped = current?.stopped();
      if (!_disposed && stopped != null) {
        current = stopped;
        _snapshots.add(stopped);
      }
      throw WindowsServiceStopped();
    }
    if (reply['protocol'] != 1 || reply['ok'] != true) {
      throw StateError(
        reply['error'] as String? ?? 'Incompatible Windows service.',
      );
    }
    final snapshot = WindowsServiceSnapshot(
      reply['snapshot'] as Map<String, dynamic>,
    );
    if (_disposed) return snapshot;
    if (current?.instance == snapshot.instance &&
        snapshot.revision < current!.revision) {
      return snapshot;
    }
    final instanceChanged = current?.instance != snapshot.instance;
    if (instanceChanged) _cursor = 0;
    current = snapshot;
    for (final entry in reply['logs'] as List? ?? const []) {
      final line = entry as List;
      if ((line[0] as int) > _cursor) _logs.add(line[1] as String);
    }
    if (command == 'status' && (!instanceChanged || fields['cursor'] == 0)) {
      _cursor = reply['cursor'] as int;
    }
    if (!_disposed) _snapshots.add(snapshot);
    return snapshot;
  }

  Future<WindowsServiceSnapshot> refresh() => _refresh ??= send('status', {
    'cursor': _cursor,
  }).whenComplete(() => _refresh = null);

  Future<WindowsServiceSnapshot> initialize() async {
    await _ensureStarted();
    var snapshot = await refresh();
    if (snapshot.state == TunnelState.starting && snapshot.session != null) {
      final cancelled = await send('stop', {'session': snapshot.session});
      snapshot = await waitFor(cancelled.issued);
    } else if (snapshot.state == TunnelState.stopping) {
      snapshot = await waitFor(snapshot.issued);
    }
    if (snapshot.state == TunnelState.stopped) {
      final recovery = await send('recover');
      snapshot = await waitFor(recovery.issued);
    }
    _timer ??= Timer.periodic(pollInterval, (_) {
      unawaited(
        refresh().catchError((Object error) {
          if (!_disposed) {
            _snapshots.addError(
              error is WindowsServiceStopped
                  ? error
                  : WindowsServiceUnavailable(error),
            );
          }
          return current!;
        }),
      );
    });
    return snapshot;
  }

  Future<WindowsServiceSnapshot> waitFor(
    int ticket, {
    Duration timeout = const Duration(seconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final instance = current?.instance;
    while (true) {
      final snapshot = await refresh();
      if (instance != null && snapshot.instance != instance) {
        throw StateError(
          'Windows service restarted before the operation finished. Please retry.',
        );
      }
      if (snapshot.completed >= ticket) {
        if (snapshot.error != null) throw StateError(snapshot.error!);
        return snapshot;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Windows service operation timed out.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _refresh?.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    await _requestTail;
    await _snapshots.close();
    await _logs.close();
  }
}

class WindowsServiceEngine implements PlannedTunnelEngine {
  WindowsServiceEngine(this.client, this.core, {this.runtimeDirectory}) {
    _subscription = client.snapshots.listen(
      _receive,
      onError: (Object error) => _states.addError(error),
    );
  }
  final WindowsServiceClient client;
  final CoreKind core;
  final Directory? runtimeDirectory;
  late final StreamSubscription<WindowsServiceSnapshot> _subscription;
  final _states = StreamController<TunnelState>.broadcast();
  TunnelState _state = TunnelState.stopped;
  String? _session;
  String? _pendingSession;
  String? _lastError;
  @override
  TunnelState get state => _state;
  @override
  Stream<TunnelState> get states => _states.stream;
  @override
  Stream<String> get logs => client.logs;
  void _receive(WindowsServiceSnapshot snapshot) {
    _session = snapshot.core == core ? snapshot.session : null;
    final next = snapshot.core == core ? snapshot.state : TunnelState.stopped;
    _state = next;
    _states.add(next);
    if (snapshot.core == core &&
        snapshot.error != null &&
        snapshot.error != _lastError &&
        snapshot.state == TunnelState.stopped) {
      _states.addError(StateError(snapshot.error!));
    }
    _lastError = snapshot.error;
  }

  String _reference(String configPath) {
    final runtime =
        (runtimeDirectory ?? Directory('${AppPaths.windowsRoot.path}/runtime'))
            .absolute
            .uri;
    final config = File(configPath).absolute.uri;
    if (!config.path.startsWith(runtime.path)) {
      throw StateError(
        'Configuration must be inside application runtime storage.',
      );
    }
    return Uri.decodeComponent(config.path.substring(runtime.path.length));
  }

  @override
  Future<void> validate(String configPath) async {
    final reference = _reference(configPath);
    await client._ensureStarted();
    final request = await client.send('validate', {
      'core': core.name,
      'config': reference,
    });
    await client.waitFor(request.issued);
  }

  @override
  Future<void> start(String configPath) async {
    final reference = _reference(configPath);
    await client._ensureStarted();
    final request = await client.send('start', {
      'core': core.name,
      'config': reference,
    });
    await _waitForStart(request);
  }

  @override
  Future<void> validatePlan(ConnectionPlan plan) async {
    if (plan.core != core) {
      throw StateError('Connection plan uses another core.');
    }
    await client._ensureStarted();
    final request = await client.send('connection.validate', {
      'plan': plan.toJson(),
    });
    await client.waitFor(request.issued);
  }

  @override
  Future<void> startPlan(ConnectionPlan plan) async {
    if (plan.core != core) {
      throw StateError('Connection plan uses another core.');
    }
    await client._ensureStarted();
    final request = await client.send('connection.start', {
      'plan': plan.toJson(),
    });
    await _waitForStart(request);
  }

  Future<void> _waitForStart(WindowsServiceSnapshot request) async {
    _session = request.session;
    _pendingSession = request.session;
    try {
      final result = await client.waitFor(request.issued);
      if (!result.ready || result.session != request.session) {
        throw StateError('Core did not become ready.');
      }
    } catch (_) {
      try {
        await _stopSession(request.session);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> confirm() async {
    if (_pendingSession == null) {
      throw StateError('No service connection session.');
    }
    await client.send('confirm', {'session': _pendingSession});
    _pendingSession = null;
  }

  @override
  Future<void> stop() async {
    await _stopSession(_pendingSession ?? _session);
    _pendingSession = null;
  }

  Future<void> _stopSession(String? session) async {
    if (session == null) return;
    final request = await client.send('stop', {'session': session});
    await client.waitFor(request.issued);
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _states.close();
  }
}
