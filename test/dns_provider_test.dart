// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/routing/routing_policy.dart';

void main() {
  final singBox = parseSubscription('hy2://secret@127.0.0.1:443#Server').single;
  final xray = parseSubscription(
    'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&serviceName=vpn&pcs=${'ab' * 32}',
  ).single;

  test('Provider addresses and authenticated DoH endpoints', () {
    expect(DnsProvider.values.map((value) => value.address), [
      '1.1.1.1',
      '8.8.8.8',
      '9.9.9.9',
    ]);
    expect(DnsProvider.values.map((value) => value.tlsServerName), [
      'cloudflare-dns.com',
      'dns.google',
      'dns.quad9.net',
    ]);
  });

  for (final provider in DnsProvider.values) {
    test(
      '${provider.label} applies to both cores without changing protection',
      () {
        final sing = singBox.config(dnsProvider: provider);
        final resolver = (sing['dns'] as Map)['servers'].last as Map;
        expect(resolver['server'], provider.address);
        expect(resolver['type'], 'https');
        expect(resolver['detour'], 'proxy');
        expect(resolver['path'], '/dns-query');
        expect(resolver['tls'], {
          'enabled': true,
          'server_name': provider.tlsServerName,
        });
        expect((sing['inbounds'] as List).single['strict_route'], isTrue);
        final tun =
            (xray.config(dnsProvider: provider)['inbounds'] as List).single;
        expect(tun['settings']['dns'], [provider.address]);
        expect(tun['settings']['autoSystemWfpBlockLeak'], [
          'dns',
          'misconfigtun',
        ]);
        for (final direction in RoutingAction.values) {
          final routed = applyRouting(
            singBox.config(dnsProvider: provider),
            CoreKind.singBox,
            RoutingPolicy(
              direction: direction,
              rules: const [
                RoutingRule(match: RoutingMatch.domain, target: 'example.com'),
              ],
            ),
            dnsProvider: provider,
          );
          final servers = (routed['dns'] as Map)['servers'] as List;
          for (final server in servers.where(
            (item) => item['type'] == 'https',
          )) {
            expect(server['server'], provider.address);
            expect(server['tls']['server_name'], provider.tlsServerName);
          }
        }
        final proxy = singBox.config(
          mode: ConnectionMode.proxy,
          dnsProvider: provider,
        );
        expect((proxy['dns'] as Map)['final'], 'local-dns');
      },
    );
  }

  test('Bundled cores accept every provider, mode and routing direction', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('aora-dns-test-');
    addTearDown(() => directory.delete(recursive: true));
    for (final profile in [singBox, xray]) {
      final core = profile.coreKind;
      final executable = File(
        core == CoreKind.singBox
            ? 'cores/sing-box-${core.configuredVersion}-windows-amd64/sing-box.exe'
            : 'cores/xray-v${core.configuredVersion}-windows-64/xray.exe',
      );
      expect(
        executable.existsSync(),
        isTrue,
        reason: 'Development core required',
      );
      for (final provider in DnsProvider.values) {
        for (final mode in ConnectionMode.values) {
          for (final direction in [null, ...RoutingAction.values]) {
            var config = profile.config(mode: mode, dnsProvider: provider);
            if (direction != null) {
              config = applyRouting(
                config,
                core,
                RoutingPolicy(
                  direction: direction,
                  rules: const [
                    RoutingRule(
                      match: RoutingMatch.domain,
                      target: 'example.com',
                    ),
                  ],
                ),
                dnsProvider: provider,
              );
            }
            final file = File('${directory.path}/config.json');
            await file.writeAsString(jsonEncode(config));
            final result = await Process.run(
              executable.absolute.path,
              core == CoreKind.xray
                  ? ['run', '-test', '-c', file.path]
                  : ['check', '-c', file.path, '--disable-color'],
            );
            expect(
              result.exitCode,
              0,
              reason:
                  '${core.name}/${provider.name}/${mode.name}/$direction: ${result.stdout}${result.stderr}',
            );
          }
        }
      }
    }
  });
}
