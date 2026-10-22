// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/server_selector.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/node_ping_controller.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/core/node_ping.dart';
import 'package:aoravpn/core/ping_type.dart';
import 'package:aoravpn/core/server_ping.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/windows_core_engine.dart';
import 'package:aoravpn/profiles/server_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/theme/app_theme.dart';

class _Engine implements TunnelEngine {
  final _states = StreamController<TunnelState>.broadcast();
  final _logs = StreamController<String>.broadcast();
  @override
  TunnelState get state => TunnelState.stopped;
  @override
  Stream<TunnelState> get states => _states.stream;
  @override
  Stream<String> get logs => _logs.stream;
  @override
  Future<void> validate(String path) async {}
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await _states.close();
    await _logs.close();
  }
}

class _LocalProfile extends ServerProfile {
  const _LocalProfile(
    this.kind,
    int number, {
    super.port = 443,
    this.unreachable = false,
    this.invalid = false,
  }) : super(name: 'Server $number', server: '127.0.0.1');
  final CoreKind kind;
  final bool unreachable;
  final bool invalid;
  @override
  CoreKind get coreKind => kind;
  @override
  String get protocol => 'direct';
  @override
  Map<String, Object?> outbound({String? serverAddress}) => invalid
      ? kind == CoreKind.xray
            ? {'protocol': 'invalid'}
            : {'type': 'invalid'}
      : unreachable
      ? kind == CoreKind.xray
            ? {
                'protocol': 'http',
                'settings': {
                  'servers': [
                    {'address': '127.0.0.1', 'port': 1},
                  ],
                },
              }
            : {'type': 'http', 'server': '127.0.0.1', 'server_port': 1}
      : kind == CoreKind.xray
      ? {'protocol': 'freedom'}
      : {'type': 'direct'};
  @override
  Map<String, Object?> config({
    int listenPort = 17890,
    ConnectionMode mode = ConnectionMode.tun,
    String? serverAddress,
    bool leakProtection = true,
    DnsProvider dnsProvider = DnsProvider.cloudflare,
  }) => {
    'log': kind == CoreKind.xray ? {'loglevel': 'warning'} : {'level': 'info'},
    'inbounds': [
      kind == CoreKind.xray
          ? {'listen': '127.0.0.1', 'port': listenPort, 'protocol': 'http'}
          : {'listen': '127.0.0.1', 'listen_port': listenPort, 'type': 'mixed'},
    ],
    'outbounds': [outbound()],
  };
}

Future<ConnectionController> _connection(int count) async {
  final connection = ConnectionController(
    engine: _Engine(),
    xrayEngine: _Engine(),
    subscriptionLoader: (_) async => SubscriptionLoadResult(
      profiles: [
        for (var i = 0; i < count; i++)
          _LocalProfile(i.isEven ? CoreKind.singBox : CoreKind.xray, i),
      ],
    ),
  );
  await connection.addSubscription('https://example.com/sub');
  return connection;
}

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  test(
    'Batch concurrency is bounded; cancellation stops queued nodes',
    () async {
      final connection = await _connection(50);
      final pending = <Completer<Duration>>[];
      final pings = NodePingController(
        connection,
        probe: (profile, type, token) {
          expect(type, PingType.proxyGet);
          final future = Completer<Duration>();
          pending.add(future);
          return future.future;
        },
      );
      try {
        final operation = pings.checkAll();
        await Future<void>.delayed(Duration.zero);
        expect(pending, hasLength(NodePingController.maxConcurrentChecks));
        pings.cancel();
        for (final future in pending) {
          future.complete(const Duration(milliseconds: 42));
        }
        await operation;
        expect(pending, hasLength(NodePingController.maxConcurrentChecks));
        expect(pings.busy, isFalse);
        expect(pings.completed, 0);
        expect(pings.resultFor(connection.profiles.last)?.error, 'Cancelled');
      } finally {
        pings.dispose();
        await connection.shutdown();
        connection.dispose();
      }
    },
  );

  test(
    'Changing method discards in-flight results and checks use new method',
    () async {
      final connection = await _connection(2);
      final gate = Completer<Duration>();
      final pings = NodePingController(
        connection,
        probe: (_, type, token) => type == PingType.proxyGet
            ? gate.future
            : Future.value(const Duration(milliseconds: 17)),
      );
      try {
        final old = pings.checkAll();
        await Future<void>.delayed(Duration.zero);
        await connection.setPingType(PingType.icmp);
        gate.complete(const Duration(milliseconds: 42));
        await old;
        expect(pings.resultFor(connection.profiles.first), isNull);
        await pings.checkAll();
        expect(pings.completed, 2);
        for (final profile in connection.profiles) {
          expect(
            pings.resultFor(profile)?.latency,
            const Duration(milliseconds: 17),
          );
        }
      } finally {
        pings.dispose();
        await connection.shutdown();
        connection.dispose();
      }
    },
  );

  testWidgets('Connected selector opens read-only and displays core and ping', (
    tester,
  ) async {
    final connection = await tester.runAsync(() => _connection(2));
    final checked = <ServerProfile>[];
    final pings = NodePingController(
      connection!,
      probe: (profile, type, token) async {
        checked.add(profile);
        return const Duration(milliseconds: 123);
      },
    );
    await tester.runAsync(pings.checkAll);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ServerSelector(
              profiles: connection.profiles,
              selected: connection.selected,
              onChanged: null,
              pings: pings,
            ),
          ),
        ),
      ),
    );
    expect(find.text('example.com'), findsOneWidget);
    expect(pings.lastCheckedAt, isNotNull);
    checked.clear();
    await tester.tap(find.byIcon(Icons.network_check_rounded));
    await tester.pumpAndSettle();
    expect(checked, [connection.selected]);
    expect(pings.checkingCount, 1);
    expect(
      pings.resultFor(connection.profiles.last)?.latency,
      const Duration(milliseconds: 123),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.network_check_rounded)).dy,
      lessThan(tester.getCenter(find.byType(AppSelect<ServerProfile>)).dy),
    );
    await tester.tap(find.text('Server 0'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sing-box', findRichText: true), findsWidgets);
    expect(find.textContaining('Xray', findRichText: true), findsWidgets);
    checked.clear();
    await tester.tap(find.byIcon(Icons.network_check_rounded));
    await tester.pumpAndSettle();
    expect(checked, unorderedEquals(connection.profiles));
    expect(pings.checkingCount, 2);
    expect(find.byKey(const ValueKey('app-select-menu')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('app-select-menu'))).width,
      tester.getSize(find.byType(AppSelect<ServerProfile>)).width,
    );
    expect(find.text('123 ms'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    pings.dispose();
    await tester.runAsync(connection.shutdown);
    connection.dispose();
  });

  final helper = File('build/windows/x64/runner/Debug/aoravpn_server_ping.exe');
  final nativeAvailable = Platform.isWindows && helper.existsSync();
  test('Native TCP accepts open port and rejects closed port', () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = listener.listen((socket) => socket.destroy());
    final port = listener.port;
    final service = NodePingService(helperPath: helper.absolute.path);
    try {
      final result = await service.check(
        _LocalProfile(CoreKind.singBox, 0, port: port),
        PingType.tcp,
        PingCancellation(),
      );
      expect(result.inMilliseconds, greaterThanOrEqualTo(0));
      await sockets.cancel();
      await listener.close();
      await expectLater(
        service.check(
          _LocalProfile(CoreKind.singBox, 0, port: port),
          PingType.tcp,
          PingCancellation(),
        ),
        throwsA(isA<ServerPingException>()),
      );
    } finally {
      await sockets.cancel();
      await listener.close();
    }
  }, skip: !nativeAvailable);

  test(
    'Mixed 70-node scan has 32 requests in flight and only two core sessions',
    () async {
      final connection = await _connection(70);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final atLimit = Completer<void>();
      final release = Completer<void>();
      var received = 0;
      final requests = server.listen((request) async {
        received++;
        if (received == NodePingController.maxConcurrentChecks) {
          atLimit.complete();
        }
        await release.future;
        request.response.statusCode = 204;
        try {
          await request.response.close();
        } on IOException {
        }
      });
      final engines = <WindowsCoreEngine>[];
      final service = NodePingService(
        helperPath: helper.absolute.path,
        targetUrl: Uri.parse('http://127.0.0.1:${server.port}/check'),
        engineFactory: (executable, kind) {
          final engine = WindowsCoreEngine(
            executablePath: executable,
            coreKind: kind,
          );
          engines.add(engine);
          return engine;
        },
      );
      final pings = NodePingController(connection, service: service);
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final scan = pings.checkAll();
          await atLimit.future.timeout(const Duration(seconds: 10));
          expect(received, NodePingController.maxConcurrentChecks);
          expect(
            engines.map((engine) => engine.coreKind).toSet(),
            CoreKind.values.toSet(),
          );
          expect(engines, hasLength(2));
          release.complete();
          await scan;
        }, _RealHttpOverrides());
        expect(pings.completed, 70);
        expect(received, 70);
        expect(
          connection.profiles.every(
            (profile) => pings.resultFor(profile)?.latency != null,
          ),
          isTrue,
        );
        expect(
          engines.every((engine) => engine.state == TunnelState.stopped),
          isTrue,
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await pings.shutdown();
        pings.dispose();
        await connection.shutdown();
        connection.dispose();
        await requests.cancel();
        await server.close(force: true);
      }
    },
    skip:
        !nativeAvailable ||
        !File(
          'cores/windows/sing-box-${CoreKind.singBox.configuredVersion}-windows-amd64/sing-box.exe',
        ).existsSync() ||
        !File(
          'cores/windows/xray-v${CoreKind.xray.configuredVersion}-windows-64/xray.exe',
        ).existsSync(),
  );

  for (final kind in CoreKind.values) {
    final binary = kind == CoreKind.xray
        ? 'cores/windows/xray-v${kind.configuredVersion}-windows-64/xray.exe'
        : 'cores/windows/sing-box-${kind.configuredVersion}-windows-amd64/sing-box.exe';
    test(
      'Shared ${kind.label} core routes multiple nodes and isolates failed requests',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final methods = <String>[];
        var starts = 0;
        final requests = server.listen((request) async {
          methods.add(request.method);
          request.response.statusCode = 204;
          await request.response.close();
        });
        final service = NodePingService(
          helperPath: helper.absolute.path,
          targetUrl: Uri.parse('http://127.0.0.1:${server.port}/check'),
          engineFactory: (executable, kind) {
            starts++;
            return WindowsCoreEngine(
              executablePath: executable,
              coreKind: kind,
            );
          },
        );
        final profiles = [
          _LocalProfile(kind, 0),
          _LocalProfile(kind, 1),
          _LocalProfile(kind, 2, unreachable: true),
          _LocalProfile(kind, 3, invalid: true),
        ];
        final batch = await service.openBatch(profiles, PingCancellation());
        try {
          for (final type in [PingType.proxyGet, PingType.proxyHead]) {
            final results = await HttpOverrides.runWithHttpOverrides(
              () => Future.wait(
                profiles
                    .take(2)
                    .map(
                      (profile) =>
                          batch.check(profile, type, PingCancellation()),
                    ),
              ),
              _RealHttpOverrides(),
            );
            expect(
              results.every((result) => result.inMicroseconds > 0),
              isTrue,
            );
          }
          await HttpOverrides.runWithHttpOverrides(() async {
            await expectLater(
              batch.check(profiles[2], PingType.proxyGet, PingCancellation()),
              throwsA(isA<ServerPingException>()),
            );
          }, _RealHttpOverrides());
          await expectLater(
            batch.check(profiles.last, PingType.proxyGet, PingCancellation()),
            throwsA(isA<ServerPingException>()),
          );
          expect(methods, ['GET', 'GET', 'HEAD', 'HEAD']);
          expect(starts, 1);
        } finally {
          await batch.dispose();
          await requests.cancel();
          await server.close(force: true);
        }
      },
      skip: !nativeAvailable || !File(binary).existsSync(),
    );
  }
}
