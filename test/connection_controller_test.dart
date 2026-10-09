// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/profiles/xray_vless_profile.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/kill_switch.dart';
import 'package:aoravpn/storage/app_settings_store.dart';
import 'package:aoravpn/routing/routing_policy.dart';

class MemorySettingsStore implements AppSettingsStore {
  AppSettingsData data = const AppSettingsData();

  @override
  Future<AppSettingsData> read() async => data;

  @override
  Future<void> write(AppSettingsData value) async => data = value;
}

class ControlledEngine implements TunnelEngine {
  final messages = StreamController<String>.broadcast();
  final changes = StreamController<TunnelState>.broadcast();
  Completer<void>? validationGate;
  bool rejectValidation = false;
  int disposalCalls = 0;
  int validationCalls = 0;
  String? lastValidatedPath;
  @override
  TunnelState get state => TunnelState.stopped;
  @override
  Stream<String> get logs => messages.stream;
  @override
  Stream<TunnelState> get states => changes.stream;
  @override
  Future<void> validate(String path) async {
    validationCalls++;
    lastValidatedPath = path;
    await validationGate?.future;
    if (rejectValidation) throw StateError('Invalid configuration');
  }

  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposalCalls++;
    await messages.close();
    await changes.close();
  }
}

class MemoryKillSwitch implements KillSwitch {
  bool armed = false;
  int disarmCalls = 0;
  int armCalls = 0;

  @override
  Future<bool> isArmed() async => armed;

  @override
  Future<void> arm({
    required String corePath,
    required String serverAddress,
    required int serverPort,
  }) async {
    armCalls++;
    armed = true;
  }

  @override
  Future<void> allowTun() async {}

  @override
  Future<void> revokeTun() async {}

  @override
  Future<void> disarm() async {
    disarmCalls++;
    armed = false;
  }
}

void main() {
  test(
    'Routing edits update the selected config and rejected edits roll back',
    () async {
      final engine = ControlledEngine();
      final store = MemorySettingsStore();
      final controller = ConnectionController(
        engine: engine,
        settingsStore: store,
        subscriptionLoader: (_) async => SubscriptionLoadResult(
          profiles: [
            HysteriaProfile(
              name: 'Server',
              server: '127.0.0.1',
              port: 443,
              password: 'secret',
              serverName: 'example.com',
            ),
          ],
        ),
      );
      await controller.addSubscription('https://example.com/sub');
      const policy = RoutingPolicy(
        enabled: true,
        direction: RoutingAction.vpn,
        rules: [RoutingRule(match: RoutingMatch.domain, target: 'example.com')],
      );
      await controller.setRoutingPolicy(policy);
      expect(controller.error, isNull);
      final path = engine.lastValidatedPath!;
      final config = jsonDecode(await File(path).readAsString()) as Map;
      expect(config['route']['final'], 'direct');
      expect(config['route']['rules'].last['action'], 'route');
      expect(config['route']['rules'].last['outbound'], 'proxy');
      expect(store.data.routingPolicy.defaultAction, RoutingAction.direct);
      engine.rejectValidation = true;
      await controller.setRoutingPolicy(
        const RoutingPolicy(enabled: true, direction: RoutingAction.direct),
      );
      expect(controller.errorFor(ConnectionErrorScope.routing), isNotNull);
      expect(controller.routingPolicy.defaultAction, RoutingAction.direct);
      expect(store.data.routingPolicy.defaultAction, RoutingAction.direct);
      expect(File(path).existsSync(), isTrue);
      await controller.shutdown();
      controller.dispose();
    },
  );

  test('Startup removes legacy rules before loading subscriptions', () async {
    const url = 'https://example.com/sub';
    final store = MemorySettingsStore()
      ..data = const AppSettingsData(
        subscriptions: [SavedSubscription(url)],
        activeSubscriptionUrl: url,
        killSwitchEnabled: true,
      );
    final guard = MemoryKillSwitch()..armed = true;
    var loads = 0;
    final engine = ControlledEngine();
    final controller = ConnectionController(
      engine: engine,
      settingsStore: store,
      killSwitch: guard,
      subscriptionLoader: (_) async {
        expect(guard.armed, isFalse);
        loads++;
        return SubscriptionLoadResult(
          profiles: [
            HysteriaProfile(
              name: 'Server',
              server: '127.0.0.1',
              port: 443,
              password: 'secret',
              serverName: 'example.com',
            ),
          ],
        );
      },
    );
    await controller.restore();
    expect(guard.disarmCalls, 1);
    expect(guard.armed, isFalse);
    expect(guard.armCalls, 0);
    expect(controller.killSwitchEnabled, isTrue);
    expect(store.data.killSwitchEnabled, isTrue);
    expect(loads, 1);
    final protected =
        jsonDecode(await File(engine.lastValidatedPath!).readAsString()) as Map;
    expect((protected['inbounds'] as List).single['strict_route'], isTrue);
    await controller.setKillSwitchEnabled(false);
    expect(controller.killSwitchEnabled, isFalse);
    expect(store.data.killSwitchEnabled, isFalse);
    expect(guard.armCalls, 0);
    expect(controller.error, isNull);
    final unprotected =
        jsonDecode(await File(engine.lastValidatedPath!).readAsString()) as Map;
    expect((unprotected['inbounds'] as List).single['strict_route'], isFalse);
    await controller.shutdown();
    controller.dispose();
  });

  test('Requires an explicit core switch for pinned nodes', () async {
    final singBox = ControlledEngine();
    final xray = ControlledEngine();
    final controller = ConnectionController(
      engine: singBox,
      xrayEngine: xray,
      subscriptionLoader: (_) async => SubscriptionLoadResult(
        profiles: [
          HysteriaProfile(
            name: 'HY2',
            server: '127.0.0.1',
            port: 443,
            password: 'secret',
            serverName: 'example.com',
          ),
          XrayVlessProfile(
            name: 'Pinned',
            server: '127.0.0.1',
            port: 443,
            uuid: 'bf000d23-0752-40b4-affe-68f7707a9661',
            serverName: 'example.com',
            pinnedPeerCertSha256: 'ab' * 32,
            serviceName: 'vpn',
          ),
        ],
      ),
    );
    await controller.addSubscription('https://example.com/sub');
    expect(controller.activeCore, CoreKind.singBox);
    expect(singBox.validationCalls, 1);
    await controller.selectProfile(controller.profiles[1]);
    expect(controller.activeCore, CoreKind.singBox);
    expect(controller.selectedRequiresDifferentCore, isTrue);
    expect(controller.canConnect, isFalse);
    expect(xray.validationCalls, 0);
    await controller.setCore(CoreKind.xray);
    expect(controller.activeCore, CoreKind.xray);
    expect(controller.canConnect, isTrue);
    expect(xray.validationCalls, 1);
    await controller.validate();
    expect(xray.validationCalls, 2);
    await controller.selectProfile(controller.profiles[0]);
    expect(controller.activeCore, CoreKind.xray);
    expect(controller.selectedRequiresDifferentCore, isTrue);
    expect(controller.canConnect, isFalse);
    expect(singBox.validationCalls, 1);
    await controller.setCore(CoreKind.singBox);
    expect(controller.canConnect, isTrue);
    expect(singBox.validationCalls, 2);
    await controller.shutdown();
    expect(singBox.disposalCalls, 1);
    expect(xray.disposalCalls, 1);
    controller.dispose();
  });
  test('Restores multiple links, active server and connection mode', () async {
    const sweden = 'https://provider-one.example/sub/token';
    const germany = 'https://provider-two.example/sub/token';
    final store = MemorySettingsStore();
    Future<SubscriptionLoadResult> load(String url) async =>
        SubscriptionLoadResult(
          skippedCount: url == germany ? 2 : 0,
          profiles: [
            for (final name
                in url == sweden ? ['Sweden 1', 'Sweden 2'] : ['Germany 1'])
              HysteriaProfile(
                name: name,
                server: '127.0.0.1',
                port: 443,
                password: 'secret',
                serverName: 'example.com',
              ),
          ],
        );

    final first = ConnectionController(
      engine: ControlledEngine(),
      settingsStore: store,
      subscriptionLoader: load,
    );
    await first.addSubscription(sweden);
    await first.selectProfile(first.profiles[1]);
    await first.addSubscription(germany);
    expect(first.skippedCountFor(germany), 2);
    await first.setMode(ConnectionMode.proxy);
    await first.setCore(CoreKind.xray);
    await first.activateSubscription(sweden);
    expect(first.error, isNull);
    expect(first.selected?.name, 'Sweden 2');
    await first.shutdown();
    first.dispose();

    final restored = ConnectionController(
      engine: ControlledEngine(),
      settingsStore: store,
      subscriptionLoader: load,
    );
    await restored.restore();
    expect(restored.error, isNull);
    expect(restored.subscriptions, hasLength(2));
    expect(restored.activeSubscriptionUrl, sweden);
    expect(restored.selected?.name, 'Sweden 2');
    expect(restored.mode, ConnectionMode.proxy);
    expect(restored.core, CoreKind.xray);
    await restored.removeSubscription(sweden);
    expect(restored.subscriptions, hasLength(1));
    expect(restored.activeSubscriptionUrl, isNull);
    expect(restored.selected, isNull);
    await restored.shutdown();
    restored.dispose();
  });

  test('Validation failure exposes an error and re-enables controls', () async {
    final engine = ControlledEngine()..rejectValidation = true;
    final controller = ConnectionController(
      engine: engine,
      configPath: 'test.json',
    );
    await controller.validate();
    expect(controller.error, contains('Invalid configuration'));
    expect(
      controller.errorFor(ConnectionErrorScope.connection),
      contains('Invalid configuration'),
    );
    expect(controller.errorFor(ConnectionErrorScope.subscriptions), isNull);
    expect(controller.errorFor(ConnectionErrorScope.settings), isNull);
    expect(controller.busy, isFalse);
    expect(controller.canConnect, isTrue);
    await controller.shutdown();
    controller.dispose();
  });

  test('Subscription failure is scoped to Subscriptions', () async {
    final controller = ConnectionController(
      engine: ControlledEngine(),
      subscriptionLoader: (_) async =>
          throw const FormatException('Unsupported link option.'),
    );
    await controller.addSubscription('https://example.test/sub');
    expect(
      controller.errorFor(ConnectionErrorScope.subscriptions),
      contains('Unsupported link option'),
    );
    expect(controller.errorFor(ConnectionErrorScope.connection), isNull);
    expect(controller.errorFor(ConnectionErrorScope.settings), isNull);
    await controller.shutdown();
    controller.dispose();
  });

  test(
    'Shutdown waits for pending work and disposes the engine only once',
    () async {
      final gate = Completer<void>();
      final engine = ControlledEngine()..validationGate = gate;
      final controller = ConnectionController(
        engine: engine,
        configPath: 'test.json',
      );
      final operation = controller.validate();
      expect(controller.busy, isTrue);
      final shutdown = controller.shutdown();
      expect(identical(shutdown, controller.shutdown()), isTrue);
      expect(engine.disposalCalls, 0);
      gate.complete();
      await operation;
      await shutdown;
      expect(engine.disposalCalls, 1);
      controller.dispose();
      expect(engine.disposalCalls, 1);
    },
  );
}
