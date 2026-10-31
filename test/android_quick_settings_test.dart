// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'support/runtime_session.dart';

import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/core/android_quick_settings.dart';
import 'package:aoravpn/core/android_tunnel_engine.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late ConnectionController connection;
  final calls = <MethodCall>[];
  var racedWithTile = false;
  final first = HysteriaProfile(
    name: 'First',
    server: '127.0.0.1',
    port: 443,
    password: 'private-test',
    serverName: 'test.invalid',
  );
  final second = HysteriaProfile(
    name: 'Second',
    server: '127.0.0.1',
    port: 8443,
    password: 'private-test',
    serverName: 'test.invalid',
  );

  setUp(() async {
    calls.clear();
    racedWithTile = false;
    messenger.setMockMethodCallHandler(
      const MethodChannel('aora/vpn/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      AndroidTunnelEngine.channel,
      (call) async => call.method == 'status' ? 'stopped' : null,
    );
    messenger.setMockMethodCallHandler(AndroidQuickSettings.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'busy' &&
          (call.arguments as Map)['busy'] == true &&
          racedWithTile) {
        throw PlatformException(code: 'BUSY', message: 'VPN state changed');
      }
      return null;
    });
    final engine = AndroidTunnelEngine();
    final xray = AndroidTunnelEngine(core: CoreKind.xray);
    await Future.wait([engine.ready, xray.ready]);
    connection = ConnectionController(
      sessionCreator: createTestRuntimeSession,
      engine: engine,
      xrayEngine: xray,
      subscriptionLoader: (_) async =>
          SubscriptionLoadResult(profiles: [first, second]),
    );
  });
  tearDown(() async {
    await connection.shutdown();
    connection.dispose();
    messenger.setMockMethodCallHandler(AndroidTunnelEngine.channel, null);
    messenger.setMockMethodCallHandler(AndroidQuickSettings.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('aora/vpn/events'),
      null,
    );
  });

  Map getSaved() =>
      calls.lastWhere((call) => call.method == 'save').arguments as Map;

  test(
    'tile snapshot follows selection and DNS, not a disposable file path',
    () async {
      await connection.addSubscription('https://test.invalid/sub');
      expect(connection.error, isNull);
      expect(calls.first.method, 'busy');
      expect((calls.first.arguments as Map)['busy'], true);
      expect((calls.last.arguments as Map)['busy'], false);
      expect(getSaved()['name'], 'First');
      expect(getSaved()['host'], '127.0.0.1');
      expect(jsonDecode(getSaved()['config'] as String), isA<Map>());
      await connection.selectProfile(second);
      expect(getSaved()['name'], 'Second');
      var config = jsonDecode(getSaved()['config'] as String) as Map;
      expect((config['outbounds'] as List).first['server_port'], 8443);
      await connection.setDnsProvider(DnsProvider.quad9);
      config = jsonDecode(getSaved()['config'] as String) as Map;
      final servers = (config['dns'] as Map)['servers'] as List;
      expect(
        servers.where((server) => server['tag'] == 'vpn-dns').single['server'],
        '9.9.9.9',
      );
    },
  );

  test(
    'removing selection or choosing incompatible core clears tile snapshot',
    () async {
      await connection.addSubscription('https://test.invalid/sub');
      await connection.setCore(CoreKind.xray);
      expect(getSaved()['config'], isNull);
      await connection.setCore(CoreKind.singBox);
      expect(getSaved()['config'], isNotNull);
      await connection.removeSubscription('https://test.invalid/sub');
      expect(getSaved()['config'], isNull);
    },
  );

  test('tile race prevents UI mutations and does not overwrite the active snapshot', () async {
    await connection.addSubscription('https://test.invalid/sub');
    final saves = calls.where((call) => call.method == 'save').length;
    racedWithTile = true;
    await connection.selectProfile(second);
    expect(connection.selected, same(first));
    expect(connection.error, contains('VPN state changed'));
    expect(calls.where((call) => call.method == 'save').length, saves);
    expect(connection.busy, isFalse);
  });
}
