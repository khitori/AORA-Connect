// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/connection_plan.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/routing/routing_policy.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/windows_service_engine.dart';

class ServiceFixture {
  final commands = <Map<String, Object?>>[];
  final state = <String, dynamic>{
    'state': 'stopped',
    'core': null,
    'mode': 'proxy',
    'session': null,
    'ready': false,
    'issued': 0,
    'completed': 0,
    'error': null,
    'instance': 'test-service',
    'revision': 0,
  };
  Future<Map<String, dynamic>> request(Map<String, Object?> request) async {
    commands.add(request);
    switch (request['command']) {
      case 'start':
      case 'connection.start':
        state.addAll({
          'state': 'starting',
          'core': request['core'] ?? (request['plan'] as Map)['core'],
          'session': 'original-session',
          'ready': true,
          'issued': 1,
          'completed': 1,
        });
      case 'confirm':
        if (request['session'] != state['session']) {
          return {'protocol': 1, 'ok': false, 'error': 'stale session'};
        }
        state['state'] = 'running';
      case 'stop':
        if (request['session'] != state['session']) {
          return {'protocol': 1, 'ok': false, 'error': 'stale session'};
        }
        state['state'] = 'stopped';
    }
    state['revision'] = (state['revision'] as int) + 1;
    return {
      'protocol': 1,
      'ok': true,
      'snapshot': Map<String, dynamic>.of(state),
      'logs': <Object>[],
      'cursor': 0,
    };
  }
}

void main() {
  test(
    'Typed connection plans start and validate without configuration paths',
    () async {
      final fixture = ServiceFixture();
      final client = WindowsServiceClient(request: fixture.request);
      final engine = WindowsServiceEngine(client, CoreKind.singBox);
      final plan = ConnectionPlan(
        profile: parseSubscription('hy2://dummy@127.0.0.1:443?sni=example.com')
            .single,
        serverAddress: '127.0.0.1',
        mode: ConnectionMode.proxy,
        dnsProvider: DnsProvider.cloudflare,
        leakProtection: true,
        routing: const RoutingPolicy(),
      );
      try {
        await engine.validatePlan(plan);
        await engine.startPlan(plan);
        await engine.confirm();
        expect(fixture.state['state'], 'running');
        final calls = fixture.commands.where((c) => c['plan'] != null).toList();
        expect(calls.map((c) => c['command']), [
          'connection.validate',
          'connection.start',
        ]);
        expect(
          calls.every(
            (c) => !c.containsKey('config') && !c.containsKey('core'),
          ),
          isTrue,
        );
        final other = WindowsServiceEngine(client, CoreKind.xray);
        try {
          await expectLater(other.validatePlan(plan), throwsStateError);
        } finally {
          await other.dispose();
        }
        await engine.stop();
        expect(fixture.state['state'], 'stopped');
      } finally {
        await engine.dispose();
        await client.dispose();
      }
    },
  );
  test('A service restart cannot satisfy a pending operation from the old instance', () async {
    final fixture = ServiceFixture();
    final client = WindowsServiceClient(request: fixture.request);
    try {
      await client.refresh();
      fixture.state['instance'] = 'restarted-service';
      fixture.state['completed'] = 100;
      await expectLater(client.waitFor(1), throwsStateError);
    } finally {
      await client.dispose();
    }
  });
  test('An abandoned unverified session is stopped rather than acknowledged on restore', () async {
    final fixture = ServiceFixture()
      ..state.addAll({
        'state': 'starting',
        'core': 'singBox',
        'session': 'abandoned',
        'ready': true,
      });
    final client = WindowsServiceClient(
      request: fixture.request,
      pollInterval: const Duration(hours: 1),
    );
    try {
      expect((await client.initialize()).state, TunnelState.stopped);
      expect(fixture.commands.where((r) => r['command'] == 'confirm'), isEmpty);
      expect(
        fixture.commands.firstWhere((r) => r['command'] == 'stop')['session'],
        'abandoned',
      );
    } finally {
      await client.dispose();
    }
  });

  test(
    'An authoritative stopped-service response clears the last connected state',
    () async {
      final fixture = ServiceFixture()
        ..state.addAll({
          'state': 'running',
          'core': 'xray',
          'session': 'active',
          'ready': true,
        });
      var stopped = false;
      final client = WindowsServiceClient(
        request: (request) async => stopped
            ? {'protocol': 1, 'ok': false, 'service_stopped': true}
            : await fixture.request(request),
      );
      final engine = WindowsServiceEngine(client, CoreKind.xray);
      try {
        await client.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(engine.state, TunnelState.running);
        stopped = true;
        await expectLater(
          client.refresh(),
          throwsA(isA<WindowsServiceStopped>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(engine.state, TunnelState.stopped);
        expect(client.current!.session, isNull);
      } finally {
        await engine.dispose();
        await client.dispose();
      }
    },
  );

  test('Starting waits for an explicit verification acknowledgement', () async {
    final fixture = ServiceFixture();
    final client = WindowsServiceClient(request: fixture.request);
    final runtime = Directory.systemTemp.absolute;
    final engine = WindowsServiceEngine(
      client,
      CoreKind.singBox,
      runtimeDirectory: runtime,
    );
    try {
      await engine.start('${runtime.path}/profile-test/config.json');
      await Future<void>.delayed(Duration.zero);
      expect(engine.state, TunnelState.starting);
      expect(fixture.commands.where((r) => r['command'] == 'confirm'), isEmpty);
      await engine.confirm();
      await Future<void>.delayed(Duration.zero);
      expect(engine.state, TunnelState.running);
      await engine.stop();
      await Future<void>.delayed(Duration.zero);
      expect(engine.state, TunnelState.stopped);
    } finally {
      await engine.dispose();
      await client.dispose();
    }
  });

  test(
    'A delayed confirmation cannot acknowledge a different session',
    () async {
      final fixture = ServiceFixture();
      final client = WindowsServiceClient(request: fixture.request);
      final runtime = Directory.systemTemp.absolute;
      final engine = WindowsServiceEngine(
        client,
        CoreKind.singBox,
        runtimeDirectory: runtime,
      );
      try {
        await engine.start('${runtime.path}/profile-test/config.json');
        fixture.state['session'] = 'replacement-session';
        await client.refresh();
        await Future<void>.delayed(Duration.zero);
        await expectLater(engine.confirm(), throwsStateError);
        expect(fixture.commands.last['session'], 'original-session');
        expect(fixture.state['state'], 'starting');
      } finally {
        await engine.dispose();
        await client.dispose();
      }
    },
  );

  test(
    'Restoring and disposing a UI adapter never restarts or stops the core',
    () async {
      final fixture = ServiceFixture()
        ..state.addAll({
          'state': 'running',
          'core': 'xray',
          'session': 'existing',
          'ready': true,
        });
      final client = WindowsServiceClient(
        request: fixture.request,
        pollInterval: const Duration(hours: 1),
      );
      final engine = WindowsServiceEngine(client, CoreKind.xray);
      await client.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(engine.state, TunnelState.running);
      await engine.dispose();
      await client.dispose();
      expect(fixture.commands.every((r) => r['command'] == 'status'), isTrue);
      expect(fixture.state['state'], 'running');
    },
  );

  test(
    'Requests are serialized and an RPC failure does not break the queue',
    () async {
      final fixture = ServiceFixture();
      var active = 0;
      var maximum = 0;
      var calls = 0;
      final client = WindowsServiceClient(
        request: (request) async {
          active++;
          if (active > maximum) {
            maximum = active;
          }
          try {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            if (calls++ == 0) {
              throw StateError('Service unavailable');
            }
            return await fixture.request(request);
          } finally {
            active--;
          }
        },
      );
      try {
        final failed = client.send('status');
        final recovered = client.send('status');
        await expectLater(failed, throwsStateError);
        expect((await recovered).state, TunnelState.stopped);
        expect(maximum, 1);
      } finally {
        await client.dispose();
      }
    },
  );

  test(
    'An outside configuration is rejected before any service command',
    () async {
      final fixture = ServiceFixture();
      final client = WindowsServiceClient(request: fixture.request);
      final runtime = Directory('${Directory.systemTemp.path}/service-runtime');
      final engine = WindowsServiceEngine(
        client,
        CoreKind.singBox,
        runtimeDirectory: runtime,
      );
      try {
        await expectLater(
          engine.start('${Directory.systemTemp.path}/outside/config.json'),
          throwsStateError,
        );
        expect(fixture.commands, isEmpty);
      } finally {
        await engine.dispose();
        await client.dispose();
      }
    },
  );
}
