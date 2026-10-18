// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/android_tunnel_engine.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/core_kind.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late File config;
  final calls = <String>[];
  var initialState = 'stopped';
  var denyPermission = false;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aora-android-engine-');
    config = await File('${directory.path}/config.json').writeAsString('{}');
    calls.clear();
    initialState = 'stopped';
    denyPermission = false;
    messenger.setMockMethodCallHandler(
      const MethodChannel('aora/vpn/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(AndroidTunnelEngine.channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'status') return initialState;
      if (call.method == 'start' && denyPermission) {
        throw PlatformException(
          code: 'PERMISSION',
          message: 'VPN permission was not granted.',
        );
      }
      if (call.method == 'start' || call.method == 'validate') {
        expect((call.arguments as Map)['config'], '{}');
      }
      return null;
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(AndroidTunnelEngine.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('aora/vpn/events'),
      null,
    );
    await directory.delete(recursive: true);
  });

  test(
    'Reopening Flutter restores the service; disposal never disconnects it',
    () async {
      initialState = 'running';
      final engine = AndroidTunnelEngine();
      await engine.ready;
      expect(engine.state, TunnelState.running);
      await engine.dispose();
      expect(calls, ['status']);
    },
  );

  test(
    'Both Android cores share events without stealing or mixing state',
    () async {
      final singBox = AndroidTunnelEngine();
      final xray = AndroidTunnelEngine(core: CoreKind.xray);
      await Future.wait([singBox.ready, xray.ready]);
      final running = xray.states.firstWhere(
        (value) => value == TunnelState.running,
      );
      final response = Completer<void>();
      // ignore: deprecated_member_use
      messenger.handlePlatformMessage(
        'aora/vpn/events',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'core': 'xray',
          'state': 'running',
        }),
        (_) => response.complete(),
      );
      await response.future;
      await running;
      expect(singBox.state, TunnelState.stopped);
      expect(xray.state, TunnelState.running);
      await singBox.dispose();
      final stopped = xray.states.firstWhere(
        (value) => value == TunnelState.stopped,
      );
      final next = Completer<void>();
      // ignore: deprecated_member_use
      messenger.handlePlatformMessage(
        'aora/vpn/events',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'core': 'xray',
          'state': 'stopped',
        }),
        (_) => next.complete(),
      );
      await next.future;
      await stopped;
      await xray.dispose();
      expect(calls.where((call) => call == 'stop'), isEmpty);
    },
  );

  test('Permission denial performs cleanup and cannot leave a false connected state', () async {
    denyPermission = true;
    final engine = AndroidTunnelEngine();
    await engine.ready;
    await expectLater(
      engine.start(config.path),
      throwsA(isA<PlatformException>()),
    );
    expect(engine.state, TunnelState.stopped);
    expect(calls, ['status', 'start', 'stop']);
    await engine.dispose();
  });

  test(
    'A duplicate start rejection never disconnects the existing VPN',
    () async {
      messenger.setMockMethodCallHandler(AndroidTunnelEngine.channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'status') return 'running';
        if (call.method == 'start') throw PlatformException(code: 'BUSY');
        return null;
      });
      final engine = AndroidTunnelEngine();
      await engine.ready;
      await expectLater(
        engine.start(config.path),
        throwsA(isA<PlatformException>()),
      );
      expect(engine.state, TunnelState.running);
      expect(calls, ['status', 'start']);
      await engine.dispose();
    },
  );

  test('Start/stop waits for native results and notification disconnect updates state', () async {
    final engine = AndroidTunnelEngine();
    await engine.ready;
    await engine.validate(config.path);
    await engine.start(config.path);
    expect(engine.state, TunnelState.running);
    final stopped = engine.states.firstWhere(
      (value) => value == TunnelState.stopped,
    );
    final response = Completer<void>();
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      'aora/vpn/events',
      const StandardMethodCodec().encodeSuccessEnvelope({'state': 'stopped'}),
      (_) => response.complete(),
    );
    await response.future;
    await stopped;
    expect(calls.where((value) => value == 'stop'), isEmpty);
    await engine.start(config.path);
    await engine.stop();
    expect(engine.state, TunnelState.stopped);
    await engine.dispose();
    expect(calls.where((value) => value == 'stop'), hasLength(1));
  });
}
