// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/windows_core_engine.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/routing/routing_policy.dart';
import 'package:aoravpn/storage/app_settings_store.dart';

const rules = [
  RoutingRule(match: RoutingMatch.application, target: 'chrome.exe'),
  RoutingRule(match: RoutingMatch.domain, target: 'example.com'),
  RoutingRule(match: RoutingMatch.exactDomain, target: 'exact.example'),
  RoutingRule(match: RoutingMatch.ip, target: '192.168.0.0/16'),
  RoutingRule(match: RoutingMatch.ip, target: '::1'),
];

void main() {
  test('Routing configs start both cores without changing system networking', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp(
      'aora-routing-start-',
    );
    addTearDown(() => directory.delete(recursive: true));
    for (final link in [
      'hy2://secret@127.0.0.1:443#Server',
      'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&mode=gun&serviceName=vpn&pcs=${'ab' * 32}',
    ]) {
      final profile = parseSubscription(link).single;
      final kind = profile.coreKind;
      final executable = File(
        kind == CoreKind.singBox
            ? 'cores/windows/sing-box-${kind.configuredVersion}-windows-amd64/sing-box.exe'
            : 'cores/windows/xray-v${kind.configuredVersion}-windows-64/xray.exe',
      );
      expect(
        executable.existsSync(),
        isTrue,
        reason: 'Bundled ${kind.name} is required.',
      );
      for (final direction in RoutingAction.values) {
        for (final rule in rules) {
          final reserved = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final port = reserved.port;
          await reserved.close();
          final config = applyRouting(
            profile.config(mode: ConnectionMode.proxy, listenPort: port),
            kind,
            RoutingPolicy(direction: direction, rules: [rule]),
          );
          final file = File('${directory.path}/config.json');
          await file.writeAsString(jsonEncode(config));
          final engine = WindowsCoreEngine(
            executablePath: executable.absolute.path,
            hostPath: 'missing-host.exe',
            coreKind: kind,
          );
          final logs = <String>[];
          final subscription = engine.logs.listen(logs.add);
          try {
            await engine.start(file.path);
            expect(engine.state, TunnelState.running);
            final socket = await Socket.connect(
              InternetAddress.loopbackIPv4,
              port,
            );
            socket.destroy();
            await engine.stop();
          } catch (error) {
            fail(
              '${kind.name} / ${direction.name} / ${rule.match.name}: $error\n${logs.join('\n')}',
            );
          } finally {
            await engine.dispose();
            await subscription.cancel();
          }
        }
      }
    }
  });
  test('Fresh routing is enabled and empty list keeps traffic through VPN', () {
    const policy = RoutingPolicy();
    expect(policy.enabled, isTrue);
    expect(policy.direction, RoutingAction.direct);
    expect(policy.defaultAction, RoutingAction.vpn);
    expect(RoutingPolicy.fromJson({'enabled': false}).enabled, isFalse);
  });
  final singBox = parseSubscription('hy2://secret@127.0.0.1:443#Server').single;
  final xray = parseSubscription(
    'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&mode=gun&serviceName=vpn&pcs=${'ab' * 32}',
  ).single;

  test('Android application rules match package names in traffic and DNS', () {
    for (final direction in RoutingAction.values) {
      final config = applyRouting(
        singBox.config(),
        CoreKind.singBox,
        RoutingPolicy(
          direction: direction,
          rules: const [
            RoutingRule(
              match: RoutingMatch.application,
              target: 'com.android.chrome',
            ),
          ],
        ),
        android: true,
      );
      final appRule = ((config['route'] as Map)['rules'] as List).last;
      expect(appRule['package_name'], ['com.android.chrome']);
      expect(appRule.containsKey('process_name'), isFalse);
      expect(
        appRule['outbound'],
        direction == RoutingAction.vpn ? 'proxy' : 'direct',
      );
      final dnsRule = ((config['dns'] as Map)['rules'] as List).last;
      expect(dnsRule['package_name'], ['com.android.chrome']);
      expect(
        dnsRule['server'],
        direction == RoutingAction.vpn ? 'vpn-dns' : 'direct-dns',
      );
    }
  });

  test(
    'Android rejects executable paths instead of silently ignoring app rules',
    () {
      for (final target in ['chrome.exe/path', r'C:\Chrome\chrome.exe']) {
        expect(
          () => applyRouting(
            singBox.config(),
            CoreKind.singBox,
            RoutingPolicy(
              rules: [
                RoutingRule(match: RoutingMatch.application, target: target),
              ],
            ),
            android: true,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('Both list modes route matches one way and everything else the opposite way', () {
    for (final direction in RoutingAction.values) {
      final policy = RoutingPolicy(
        enabled: true,
        direction: direction,
        rules: rules,
      );
      final sing = applyRouting(singBox.config(), CoreKind.singBox, policy);
      final routes = (sing['route'] as Map)['rules'] as List;
      expect(routes[0]['action'], 'sniff');
      expect(routes[2]['process_name'], ['chrome.exe']);
      expect(routes[3]['domain_suffix'], ['example.com']);
      expect(routes[4]['domain'], ['exact.example']);
      expect(routes[6]['ip_cidr'], ['::1/128']);
      final matchedTag = direction == RoutingAction.vpn ? 'proxy' : 'direct';
      final unmatchedTag = direction == RoutingAction.vpn ? 'direct' : 'proxy';
      for (final rule in routes.skip(2)) {
        expect(rule['action'], 'route');
        expect(rule['outbound'], matchedTag);
      }
      expect((sing['route'] as Map)['final'], unmatchedTag);
      expect(
        (sing['dns'] as Map)['final'],
        unmatchedTag == 'proxy' ? 'vpn-dns' : 'direct-dns',
      );
      expect(
        ((sing['dns'] as Map)['rules'] as List)[1]['server'],
        matchedTag == 'proxy' ? 'vpn-dns' : 'direct-dns',
      );
      expect(jsonEncode(sing).contains('reject'), isFalse);

      final xr = applyRouting(xray.config(), CoreKind.xray, policy);
      final xrRules = (xr['routing'] as Map)['rules'] as List;
      expect(xrRules[0]['process'], ['chrome']);
      expect(xrRules[1]['domain'], ['domain:example.com']);
      expect(xrRules[2]['domain'], ['full:exact.example']);
      for (final rule in xrRules.take(rules.length)) {
        expect(rule['outboundTag'], matchedTag);
      }
      expect(xrRules.last['outboundTag'], unmatchedTag);
      expect(jsonEncode(xr).contains('blackhole'), isFalse);
      expect((xr['inbounds'] as List).first['sniffing']['routeOnly'], isTrue);
    }
  });

  test('Disabled routing does not add rules or change the proxy default', () {
    final config = singBox.config();
    final result = applyRouting(
      config,
      CoreKind.singBox,
      const RoutingPolicy(
        enabled: false,
        direction: RoutingAction.direct,
        rules: rules,
      ),
    );
    expect((result['route'] as Map)['final'], 'proxy');
    expect(result['outbounds'], hasLength(1));
  });

  test('Empty routing lists keep traffic in the VPN and old blocking actions are discarded', () {
    for (final direction in RoutingAction.values) {
      final policy = RoutingPolicy(enabled: true, direction: direction);
      final config = applyRouting(singBox.config(), CoreKind.singBox, policy);
      expect((config['route'] as Map)['final'], 'proxy');
      expect(jsonEncode(config).contains('reject'), isFalse);
    }
    for (final profile in [singBox, xray]) {
      for (final direction in RoutingAction.values) {
        for (final ruleList in [
          <RoutingRule>[],
          [rules.first.withEnabled(false)],
        ]) {
          final policy = RoutingPolicy(direction: direction, rules: ruleList);
          final config = applyRouting(
            profile.config(),
            profile.coreKind,
            policy,
          );
          expect(policy.defaultAction, RoutingAction.vpn);
          expect(config['outbounds'], hasLength(1));
          if (profile.coreKind == CoreKind.singBox) {
            expect(config['route'], containsPair('final', 'proxy'));
            expect(config['dns'], containsPair('final', 'vpn-dns'));
          } else {
            expect((config['outbounds'] as List).single['tag'], 'proxy');
            expect((config['routing'] as Map)['rules'], isNull);
          }
        }
      }
    }
    final migrated = RoutingPolicy.fromJson({
      'enabled': true,
      'defaultAction': 'block',
      'rules': [
        {'match': 'domain', 'target': 'example.com', 'action': 'block'},
      ],
    });
    expect(migrated.direction, RoutingAction.vpn);
    expect(migrated.rules.single.target, 'example.com');
    final config = applyRouting(xray.config(), CoreKind.xray, migrated);
    final migratedRules = (config['routing'] as Map)['rules'] as List;
    expect(migratedRules.first['outboundTag'], 'proxy');
    expect(migratedRules.last['outboundTag'], 'direct');
    expect(jsonEncode(config).contains('blackhole'), isFalse);
    expect(jsonEncode(migrated.toJson()).contains('block'), isFalse);
  });

  test('Stored policies preserve ordered rules and disabled rules', () {
    final policy = RoutingPolicy(
      enabled: true,
      direction: RoutingAction.direct,
      rules: [rules.first.withEnabled(false), rules.last],
    );
    final restored = AppSettingsData.fromJson(
      jsonDecode(jsonEncode(AppSettingsData(routingPolicy: policy).toJson()))
          as Map<String, dynamic>,
    );
    expect(restored.routingPolicy.direction, RoutingAction.direct);
    expect(restored.routingPolicy.defaultAction, RoutingAction.vpn);
    expect(restored.routingPolicy.rules.first.enabled, isFalse);
    expect(restored.routingPolicy.rules.last.target, '::1');
    expect(
      AppSettingsData.fromJson({'version': 1}).routingPolicy.rules,
      isEmpty,
    );
    expect(
      const RoutingRule(
        match: RoutingMatch.ip,
        target: '10.0.0.1/33',
      ).validationError,
      isNotNull,
    );
    expect(
      const RoutingRule(
        match: RoutingMatch.domain,
        target: 'https://example.com/path',
      ).validationError,
      isNotNull,
    );
  });

  test('Both bundled cores validate all routing actions without starting a VPN', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp(
      'aoravpn-routing-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    for (final profile in [singBox, xray]) {
      final kind = profile.coreKind;
      final executable = File(
        kind == CoreKind.singBox
            ? 'cores/windows/sing-box-${kind.configuredVersion}-windows-amd64/sing-box.exe'
            : 'cores/windows/xray-v${kind.configuredVersion}-windows-64/xray.exe',
      );
      if (!executable.existsSync()) continue;
      for (final action in RoutingAction.values) {
        final config = applyRouting(
          profile.config(),
          kind,
          RoutingPolicy(enabled: true, direction: action, rules: rules),
        );
        final file = File('${directory.path}/${kind.name}-${action.name}.json');
        await file.writeAsString(jsonEncode(config));
        final result = await Process.run(
          executable.absolute.path,
          kind == CoreKind.xray
              ? ['run', '-test', '-c', file.path]
              : ['check', '-c', file.path, '--disable-color'],
        );
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      }
    }
  });
}
