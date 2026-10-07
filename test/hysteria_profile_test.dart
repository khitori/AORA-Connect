// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/core/connection_mode.dart';

void main() {
  const link =
      'hysteria2://test%3Apassword@node.example:443/'
      '?sni=tls.example#Test%20server';

  test(
    'Default VPN config captures both IP families and uses tunneled DNS',
    () {
      final config = HysteriaProfile.parse(link).config();
      final inbound = (config['inbounds'] as List).single as Map;
      expect(inbound['type'], 'tun');
      expect(inbound['auto_route'], isTrue);
      expect(inbound['strict_route'], isTrue);
      expect(inbound['address'], hasLength(2));
      final dns = config['dns'] as Map;
      expect(dns['final'], 'vpn-dns');
      expect((dns['servers'] as List).last['detour'], 'proxy');
      expect((config['route'] as Map)['auto_detect_interface'], isTrue);
    },
  );

  test('URI authentication and TLS settings become a proxy-only config', () {
    final profile = HysteriaProfile.parse(link);
    expect(profile.name, 'Test server');
    expect(profile.password, 'test:password');
    final config = profile.config(
      listenPort: 12345,
      mode: ConnectionMode.proxy,
    );
    final outbound = (config['outbounds'] as List).single as Map;
    expect(outbound['type'], 'hysteria2');
    expect(outbound['password'], 'test:password');
    expect(outbound['tls'], {
      'enabled': true,
      'server_name': 'tls.example',
      'insecure': false,
    });
    expect((config['inbounds'] as List).single['listen'], '127.0.0.1');
    expect((config['inbounds'] as List).single['listen_port'], 12345);
    expect((config['route'] as Map)['final'], 'proxy');
  });

  test('Plain and base64 URI lists produce matching profiles', () {
    final plain = parseSubscription('$link\n$link\n');
    final encoded = parseSubscription(
      base64.encode(utf8.encode('$link\n$link')),
    );
    expect(plain.length, 2);
    expect(
      encoded.map((profile) => profile.server),
      plain.map((profile) => profile.server),
    );
    expect(HysteriaProfile.parse('hy2://demo@node.example').port, 443);
  });

  test('Unsupported security parameters are rejected instead of discarded', () {
    expect(
      () => HysteriaProfile.parse('hy2://secret@node.example/?pinSHA256=abc'),
      throwsFormatException,
    );
    expect(
      () => HysteriaProfile.parse('hy2://secret@node.example/?obfs=salamander'),
      throwsFormatException,
    );
    expect(() => parseSubscription(''), throwsFormatException);
    try {
      HysteriaProfile.parse('hy2://secret@node.example:invalid/');
      fail('Invalid port must be rejected');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('secret')));
    }
  });
}
