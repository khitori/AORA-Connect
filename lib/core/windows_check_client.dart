// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math';

import 'ping_cancellation.dart';
import 'server_ping.dart';
import 'windows_service_transport.dart';

typedef CheckRequest = Future<Map<String, dynamic>> Function(
  Map<String, Object?> request,
);

class WindowsCheckClient {
  WindowsCheckClient({
    CheckRequest? request,
    Future<void> Function()? ensureStarted,
    this.pollInterval = const Duration(milliseconds: 100),
    this.heartbeatInterval = const Duration(seconds: 5),
    this.openTimeout = const Duration(seconds: 140),
    this.closeTimeout = const Duration(seconds: 12),
  }) : request = request ?? WindowsServiceTransport.request,
       ensureStarted =
           ensureStarted ??
           (request == null ? WindowsServiceTransport.start : () async {});
  final CheckRequest request;
  final Future<void> Function() ensureStarted;
  final Duration pollInterval, heartbeatInterval, openTimeout, closeTimeout;
  Future<WindowsCheckSession> open(
    List<Map<String, Object?>> nodes,
    PingCancellation cancellation,
  ) async {
    if (nodes.isEmpty || nodes.length > 1024) {
      throw const ServerPingException(
        'A server-check batch must contain 1–1024 nodes.',
      );
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final session = WindowsCheckSession._(this, id, cancellation);
    try {
      cancellation.check();
      await ensureStarted();
      cancellation.check();
      session._sent = true;
      final opening = session._send('checks.open', {'nodes': nodes});
      cancellation.add(session._abort);
      var reply = await opening;
      final deadline = DateTime.now().add(openTimeout);
      while (reply['phase'] == 'preparing') {
        cancellation.check();
        if (DateTime.now().isAfter(deadline)) {
          throw const ServerPingException(
            'Server-check preparation timed out.',
          );
        }
        await Future<void>.delayed(pollInterval);
        cancellation.check();
        reply = await session._send('checks.status');
      }
      cancellation.check();
      if (reply['phase'] != 'ready') {
        throw const ServerPingException('Could not prepare server checks.');
      }
      final expected = {for (final node in nodes) node['index'] as int};
      final results = reply['nodes'];
      if (results is! List || results.length != expected.length) {
        throw const ServerPingException('Invalid server-check response.');
      }
      for (final item in results) {
        if (item is! Map || !expected.remove(item['index'])) {
          throw const ServerPingException('Invalid server-check response.');
        }
        final index = item['index'] as int, port = item['port'];
        final error = item['error'];
        if (port is int && port > 0 && port <= 65535 && error == null) {
          session.ports[index] = port;
        } else if (error is String &&
            error.isNotEmpty &&
            error.length <= 256 &&
            port == null) {
          session.errors[index] = error;
        } else {
          throw const ServerPingException('Invalid server-check response.');
        }
      }
      session._available = true;
      session._timer = Timer.periodic(
        heartbeatInterval,
        (_) => session._heartbeat(),
      );
      return session;
    } catch (_) {
      await session.dispose();
      rethrow;
    }
  }
}

class WindowsCheckSession {
  WindowsCheckSession._(this.client, this.id, this.cancellation);
  final WindowsCheckClient client;
  final String id;
  final PingCancellation cancellation;
  final ports = <int, int>{};
  final errors = <int, String>{};
  bool _sent = false, _available = false;
  bool get available => _available && _disposal == null;
  Timer? _timer;
  Future<void>? _tail, _heartbeatOperation, _disposal;
  Future<Map<String, dynamic>> _send(
    String command, [
    Map<String, Object?> fields = const {},
  ]) {
    Future<Map<String, dynamic>> action() async {
      final reply = await client.request({
        'protocol': 1,
        'command': command,
        'id': id,
        ...fields,
      });
      if (reply['protocol'] != 1 ||
          reply['ok'] != true ||
          reply['id'] != id ||
          !const {
            'preparing',
            'ready',
            'closing',
            'closed',
          }.contains(reply['phase'])) {
        throw const ServerPingException(
          'Windows server-check session is unavailable.',
        );
      }
      return reply;
    }

    final operation = _tail?.then((_) => action()) ?? action();
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return operation;
  }

  void _abort() => unawaited(dispose());
  void _heartbeat() {
    if (!available || _heartbeatOperation != null) return;
    _heartbeatOperation = (() async {
      try {
        final reply = await _send('checks.status');
        if (reply['phase'] != 'ready') {
          throw const ServerPingException('Server checks stopped.');
        }
      } catch (_) {
        _available = false;
        unawaited(dispose());
      }
    })().whenComplete(() => _heartbeatOperation = null);
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _available = false;
    _timer?.cancel();
    cancellation.remove(_abort);
    if (!_sent) return;
    try {
      var reply = await _send('checks.close');
      final deadline = DateTime.now().add(client.closeTimeout);
      while (reply['phase'] != 'closed' && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(client.pollInterval);
        reply = await _send('checks.status');
      }
    } catch (_) {}
  }
}
