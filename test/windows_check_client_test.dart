// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/node_ping_controller.dart';
import 'package:aoravpn/core/connection_plan.dart';
import 'package:aoravpn/core/node_ping.dart';
import 'package:aoravpn/core/server_ping.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/windows_check_client.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';

class _Backend {
  final calls = <Map<String, Object?>>[];
  String phase = 'ready';
  bool malformed = false, unavailable = false;
  int port = 12345;
  Completer<void>? gate;
  List<Map<String, Object?>> nodes = [];
  Future<Map<String, dynamic>> request(Map<String, Object?> request) async {
    calls.add(request);
    if (unavailable) throw StateError('Unavailable');
    if (request['command'] == 'checks.open') {
      nodes = (request['nodes'] as List).cast<Map<String, Object?>>();
      await gate?.future;
    }
    if (request['command'] == 'checks.close') phase = 'closed';
    return {
      'protocol': 1,
      'ok': true,
      'id': request['id'],
      'phase': phase,
      'nodes': [
        for (final node in nodes)
          if (node['index'] == 69)
            {'index': 69, 'error': 'Core rejected this profile.'}
          else
            {'index': malformed ? 999 : node['index'], 'port': port},
      ],
    };
  }

  WindowsCheckClient client({
    Duration openTimeout = const Duration(seconds: 1),
    Duration heartbeat = const Duration(hours: 1),
  }) => WindowsCheckClient(
    request: request,
    pollInterval: const Duration(milliseconds: 2),
    heartbeatInterval: heartbeat,
    openTimeout: openTimeout,
    closeTimeout: const Duration(milliseconds: 50),
  );
}

Map<String, Object?> _node(int index) => {
  'index': index,
  'core': 'singBox',
  'outbound': {
    'type': 'hysteria2',
    'tag': 'proxy',
    'server': '127.0.0.1',
    'server_port': 443,
    'password': 'dummy',
    'tls': {'enabled': true, 'server_name': 'example.com', 'insecure': false},
  },
};

class _Engine implements PlannedTunnelEngine {
  @override
  TunnelState get state => TunnelState.stopped;
  @override
  Stream<TunnelState> get states => const Stream.empty();
  @override
  Stream<String> get logs => const Stream.empty();
  @override
  Future<void> validatePlan(ConnectionPlan plan) async {}
  @override
  Future<void> startPlan(ConnectionPlan plan) async {}
  @override
  Future<void> validate(String path) async =>
      throw StateError('No client files');
  @override
  Future<void> start(String path) async => throw StateError('No client files');
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Http extends HttpOverrides {}

void main() {
  test('Cancellation during open closes that exact session after the request completes', () async {
    final backend = _Backend()..gate = Completer<void>();
    final cancellation = PingCancellation();
    final opening = backend.client().open([_node(0)], cancellation);
    final expectation = expectLater(
      opening,
      throwsA(isA<ServerPingException>()),
    );
    while (backend.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    cancellation.cancel();
    backend.gate!.complete();
    await expectation;
    expect(backend.calls.map((r) => r['command']), [
      'checks.open',
      'checks.close',
    ]);
    expect(backend.calls.first['id'], backend.calls.last['id']);
    expect(backend.calls.first.keys.toSet(), {
      'protocol',
      'command',
      'id',
      'nodes',
    });
  });
  test(
    'Malformed replies and preparation timeouts release their session',
    () async {
      final malformed = _Backend()..malformed = true;
      await expectLater(
        malformed.client().open([_node(0)], PingCancellation()),
        throwsA(isA<ServerPingException>()),
      );
      expect(malformed.calls.last['command'], 'checks.close');
      final timeout = _Backend()..phase = 'preparing';
      await expectLater(
        timeout.client(openTimeout: const Duration(milliseconds: 15)).open([
          _node(0),
        ], PingCancellation()),
        throwsA(isA<ServerPingException>()),
      );
      expect(timeout.calls.last['command'], 'checks.close');
    },
  );
  test(
    'Heartbeat failure makes a session unavailable and disposal is idempotent',
    () async {
      final backend = _Backend();
      final session = await backend
          .client(heartbeat: const Duration(milliseconds: 10))
          .open([_node(0)], PingCancellation());
      expect(session.available, isTrue);
      expect(session.ports[0], backend.port);
      backend.unavailable = true;
      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (session.available && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(session.available, isFalse);
      await session.dispose();
      await session.dispose();
      expect(
        backend.calls.where((r) => r['command'] == 'checks.close'),
        hasLength(1),
      );
    },
  );
  test('Service batch preserves 32-request concurrency and per-node errors without client files', () async {
    final backend = _Backend();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    backend.port = server.port;
    final release = Completer<void>(), atLimit = Completer<void>();
    var received = 0;
    final requests = server.listen((request) async {
      received++;
      if (received == 32) atLimit.complete();
      await release.future;
      request.response.statusCode = 204;
      await request.response.close();
    });
    final connection = ConnectionController(
      engine: _Engine(),
      xrayEngine: _Engine(),
      sessionCreator: () async => throw StateError('No client runtime files'),
      subscriptionLoader: (_) async => SubscriptionLoadResult(
        profiles: [
          for (var i = 0; i < 70; i++)
            HysteriaProfile(
              name: 'Node $i',
              server: '127.0.0.1',
              port: 443,
              password: 'dummy',
              serverName: 'example.com',
            ),
        ],
      ),
    );
    final service = NodePingService(
      windowsChecks: backend.client(),
      targetUrl: Uri.parse('http://probe.invalid/check'),
      sessionCreator: () async => throw StateError('No client check files'),
      engineFactory: (_, _) => throw StateError('No client check cores'),
    );
    final pings = NodePingController(connection, service: service);
    try {
      await connection.addSubscription('https://fixture.invalid/sub');
      expect(connection.error, isNull);
      await HttpOverrides.runWithHttpOverrides(() async {
        final scan = pings.checkAll();
        await atLimit.future.timeout(const Duration(seconds: 3));
        expect(received, 32);
        release.complete();
        await scan;
      }, _Http());
      expect(received, 69);
      expect(pings.completed, 70);
      expect(pings.resultFor(connection.profiles.last)?.error, isNotNull);
      expect(
        connection.profiles
            .take(69)
            .every((p) => pings.resultFor(p)?.latency != null),
        isTrue,
      );
      expect(
        backend.calls.where((r) => r['command'] == 'checks.open'),
        hasLength(1),
      );
      final sent = backend.calls.first['nodes'] as List;
      expect(sent, hasLength(70));
      expect(sent.every((n) => !(n as Map).containsKey('config')), isTrue);
      expect(backend.calls.last['command'], 'checks.close');
    } finally {
      if (!release.isCompleted) release.complete();
      await pings.shutdown();
      pings.dispose();
      await connection.shutdown();
      connection.dispose();
      await requests.cancel();
      await server.close(force: true);
    }
  });
}
