// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/connection_plan.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/routing/routing_policy.dart';

void main() {
  final vmess = base64Encode(
    utf8.encode(
      jsonEncode({
        'v': '2',
        'add': '127.0.0.1',
        'port': '443',
        'id': 'bf000d23-0752-40b4-affe-68f7707a9661',
        'aid': 0,
        'scy': 'auto',
        'net': 'ws',
        'path': '/vpn',
        'host': 'example.com',
        'tls': 'tls',
        'sni': 'example.com',
        'fp': 'chrome',
      }),
    ),
  );
  const vless = 'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443';
  final links = [
    'hy2://secret@127.0.0.1:443?sni=example.com',
    'hy2://secret@127.0.0.1:443?sni=example.com&alpn=h3&obfs=salamander&obfs-password=secret&insecure=1',
    'trojan://secret@127.0.0.1:443?sni=example.com&type=grpc&serviceName=vpn',
    'trojan://secret@127.0.0.1:443?sni=example.com&type=httpupgrade&host=example.com&path=%2Fvpn',
    'ss://aes-128-gcm:secret@127.0.0.1:8388',
    '$vless?security=none',
    '$vless?security=tls&type=ws&sni=example.com&host=example.com&path=%2Fvpn',
    '$vless?security=tls&type=httpupgrade&sni=example.com&path=%2Fvpn',
    '$vless?security=tls&type=h2&host=example.com&path=%2Fvpn',
    '$vless?security=reality&type=tcp&sni=example.com&fp=chrome&pbk=${'a' * 43}&sid=abcd&flow=xtls-rprx-vision',
    '$vless?security=tls&type=grpc&serviceName=vpn&pcs=${'ab' * 32}&sni=example.com&fp=chrome&alpn=h2',
    'vmess://$vmess',
  ];
  const rules = [
    RoutingRule(match: RoutingMatch.domain, target: 'example.org'),
    RoutingRule(match: RoutingMatch.exactDomain, target: 'one.example.org'),
    RoutingRule(match: RoutingMatch.ip, target: '192.0.2.2'),
    RoutingRule(match: RoutingMatch.ip, target: '2001:db8::/32'),
    RoutingRule(
      match: RoutingMatch.application,
      target: 'C:/Program Files/App/APP.EXE',
    ),
    RoutingRule(match: RoutingMatch.application, target: 'APP.EXE'),
    RoutingRule(
      match: RoutingMatch.domain,
      target: 'disabled.example',
      enabled: false,
    ),
  ];
  const policies = [
    RoutingPolicy(),
    RoutingPolicy(enabled: false, rules: rules),
    RoutingPolicy(direction: RoutingAction.direct, rules: rules),
    RoutingPolicy(direction: RoutingAction.vpn, rules: rules),
    RoutingPolicy(direction: RoutingAction.vpn, rules: [rulesLast]),
  ];
  final cases = <Object>[];
  for (final link in links) {
    final profile = parseSubscription(link).single;
    for (final mode in ConnectionMode.values) {
      for (final dns in DnsProvider.values) {
        for (final leak in [false, true]) {
          for (final routing in policies) {
            final plan = ConnectionPlan(
              profile: profile,
              serverAddress: '127.0.0.1',
              mode: mode,
              dnsProvider: dns,
              leakProtection: leak,
              routing: routing,
            );
            cases.add({
              'plan': plan.toJson(),
              'expected': applyRouting(
                profile.config(
                  mode: mode,
                  serverAddress: '127.0.0.1',
                  leakProtection: leak,
                  dnsProvider: dns,
                ),
                profile.coreKind,
                routing,
                dnsProvider: dns,
                android: false,
              ),
            });
          }
        }
      }
    }
  }
  final file = File('.buildlog/connection-plan-fixtures.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(cases));
  stdout.writeln(
    'Generated ${cases.length} local connection-plan parity cases.',
  );
}

const rulesLast = RoutingRule(
  match: RoutingMatch.domain,
  target: 'disabled.example',
  enabled: false,
);
