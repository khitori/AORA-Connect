// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:aoravpn/core/connection_diagnostics.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Logs only the numeric endpoint, protocol and core from sing-box', () {
    final summary = connectionConfigurationSummary(
      jsonEncode({
        'outbounds': [
          {
            'tag': 'proxy',
            'type': 'hysteria2',
            'server': '192.0.2.1',
            'server_port': 8443,
            'password': 'secret-password',
            'tls': {'server_name': 'private-sni.example'},
            'subscription': 'https://private.example/token',
          },
        ],
      }),
      CoreKind.singBox,
    );
    expect(summary, contains('hysteria2'));
    expect(summary, contains('192.0.2.1:8443'));
    for (final secret in [
      'secret-password',
      'private-sni',
      'private.example',
      'token',
    ]) {
      expect(summary, isNot(contains(secret)));
    }
  });

  test('Logs Xray IPv6 endpoints without user identifiers', () {
    final summary = connectionConfigurationSummary(
      jsonEncode({
        'outbounds': [
          {
            'tag': 'proxy',
            'protocol': 'vless',
            'settings': {
              'vnext': [
                {
                  'address': '2001:db8::1',
                  'port': 443,
                  'users': [
                    {'id': 'secret-user-id'},
                  ],
                },
              ],
            },
          },
        ],
      }),
      CoreKind.xray,
    );
    expect(summary, contains('[2001:db8::1]:443'));
    expect(summary, contains('protocol=vless'));
    expect(summary, isNot(contains('secret-user-id')));
  });

  test(
    'Untrusted strings are not copied to protocol or endpoint diagnostics',
    () {
      final summary = connectionConfigurationSummary(
        jsonEncode({
          'outbounds': [
            {
              'tag': 'proxy',
              'type': 'secret-type\npassword=secret',
              'server': 'https://secret:password@host.example/token',
              'server_port': 'secret-port',
            },
          ],
        }),
        CoreKind.singBox,
      );
      expect(summary, contains('protocol=unknown'));
      expect(summary, contains('(hostname omitted):?'));
      expect(summary, isNot(contains('secret')));
      expect(summary, isNot(contains('password')));
    },
  );

  test('Invalid configurations produce no configuration dump', () {
    expect(
      connectionConfigurationSummary('secret-config', CoreKind.singBox),
      allOf(contains('unavailable'), isNot(contains('secret-config'))),
    );
  });
}
