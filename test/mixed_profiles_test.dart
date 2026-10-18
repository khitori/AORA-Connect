// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';

void main() {
  final vmess =
      'vmess://${base64.encode(utf8.encode(jsonEncode({'v': '2', 'ps': 'VMess server', 'add': '127.0.0.1', 'port': '443', 'id': 'bf000d23-0752-40b4-affe-68f7707a9661', 'aid': '0', 'scy': 'auto', 'net': 'tcp', 'tls': ''})))}';
  final links = [
    'hy2://secret@127.0.0.1:443?alpn=h3&insecure=0#Sweden',
    'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=ws&sni=example.com&path=%2Fvpn#VLESS',
    'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=reality&sni=example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=0123456789abcdef&fp=chrome&flow=xtls-rprx-vision#Reality',
    'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=reality&sni=example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&fp=chrome&flow=xtls-rprx-vision&type=tcp&headerType=none#Reality%20TCP',
    'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&sni=example.com&type=grpc&serviceName=vpn&mode=gun#VLESS%20gRPC',
    'trojan://secret@127.0.0.1:443?security=tls&sni=example.com#Trojan',
    'trojan://secret@127.0.0.1:443?security=tls&sni=example.com&type=grpc&serviceName=vpn#Trojan%20gRPC',
    'ss://${base64.encode(utf8.encode('aes-128-gcm:secret'))}@127.0.0.1:443#Shadowsocks',
    vmess,
  ];

  test('Imports mixed plain and base64 URI subscriptions', () {
    final plain = parseSubscription(links.join('\n'));
    final encoded = parseSubscription(
      base64.encode(utf8.encode(links.join('\n'))),
    );
    expect(plain.map((node) => node.protocol), [
      'hysteria2',
      'vless',
      'vless',
      'vless',
      'vless',
      'trojan',
      'trojan',
      'shadowsocks',
      'vmess',
    ]);
    expect(encoded.map((node) => node.name), plain.map((node) => node.name));
    final vless = plain[1].outbound();
    expect((vless['transport'] as Map)['type'], 'ws');
    expect((vless['tls'] as Map)['server_name'], 'example.com');
    expect((plain[2].outbound()['tls'] as Map)['reality'], isNotNull);
    expect((plain[0].outbound()['tls'] as Map)['alpn'], ['h3']);
    expect(plain[3].outbound().containsKey('transport'), isFalse);
    expect((plain[4].outbound()['transport'] as Map)['type'], 'grpc');
    expect(plain[7].outbound()['method'], 'aes-128-gcm');
  });

  test('Reads subscription announcements and links from body metadata', () {
    final message = base64.encode(utf8.encode('Your subscription is active'));
    final expiry = DateTime.utc(2027, 5, 7);
    final body = [
      '#profile-title: Example VPN',
      '#announce: base64:$message',
      '#support-url: https://example.com/support',
      '#profile-web-page-url: https://example.com/account',
      '#subscription-userinfo: upload=0; download=100; total=1000; expire=${expiry.millisecondsSinceEpoch ~/ 1000}',
      links.first,
    ].join('\n');
    for (final source in [body, base64.encode(utf8.encode(body))]) {
      final result = parseSubscriptionDetailed(source);
      expect(result.profiles, hasLength(1));
      expect(result.skippedCount, 0);
      expect(result.title, 'Example VPN');
      expect(result.description, 'Your subscription is active');
      expect(result.supportUrl, 'https://example.com/support');
      expect(result.webPageUrl, 'https://example.com/account');
      expect(result.expiresAt, expiry);
    }
  });

  test('Missing or invalid subscription expiry stays unknown', () {
    for (final value in [
      null,
      '',
      'expire=0',
      'expire=-1',
      'expire=invalid',
      'expire=999999999999999999999',
    ]) {
      expect(subscriptionExpiry(value), isNull);
    }
    expect(
      subscriptionExpiry(' upload=10; EXPIRE = 1809648000 ; total=20'),
      DateTime.utc(2027, 5, 7),
    );
  });

  test('Connection leak protection follows the TUN setting for both cores', () {
    final singBox = parseSubscription(links.first).single;
    final xray = parseSubscription(
      'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&mode=gun&serviceName=vpn&pcs=${'ab' * 32}',
    ).single;
    for (final enabled in [true, false]) {
      final tun =
          (singBox.config(leakProtection: enabled)['inbounds'] as List).single
              as Map;
      expect(tun['strict_route'], enabled);
      final settings =
          ((xray.config(leakProtection: enabled)['inbounds'] as List).single
                  as Map)['settings']
              as Map;
      expect(
        settings['autoSystemWfpBlockLeak'],
        enabled ? ['dns', 'misconfigtun'] : null,
      );
    }
    for (final profile in [singBox, xray]) {
      final proxy =
          (profile.config(mode: ConnectionMode.proxy)['inbounds'] as List)
                  .single
              as Map;
      expect(proxy['strict_route'], isNull);
      expect(proxy['settings'], isNull);
    }
  });

  test('Routes certificate-pinned VLESS gRPC nodes to Xray', () {
    final pinned =
        'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&mode=gun&serviceName=vpn&pcs=${'ab' * 32}';
    final result = parseSubscriptionDetailed(
      '${links[3]}\n$pinned\n${links[4]}',
    );
    expect(result.profiles, hasLength(3));
    expect(result.skippedCount, 0);
    expect(result.profiles[1].coreKind, CoreKind.xray);
    final outbound = result.profiles[1].outbound();
    final stream = outbound['streamSettings'] as Map;
    final tls = stream['tlsSettings'] as Map;
    expect(tls['pinnedPeerCertSha256'], 'ab' * 32);
    expect(tls['allowInsecure'], false);
    expect(stream['method'], 'grpc');
    expect(result.profiles[0].coreKind, CoreKind.singBox);
    expect(
      () => parseSubscription(pinned.replaceFirst('ab' * 32, 'bad')),
      throwsFormatException,
    );
    expect(
      () => parseSubscription(links[4].replaceFirst('mode=gun', 'mode=multi')),
      throwsFormatException,
    );
  });

  test('Bundled Xray accepts pinned VLESS TUN and proxy configurations', () async {
    if (!Platform.isWindows) return;
    final core = File('cores/windows/xray-v26.9.30-windows-64/xray.exe');
    if (!await core.exists()) return;
    final profile = parseSubscription(
      'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&mode=gun&serviceName=vpn&pcs=${'ab' * 32}',
    ).single;
    final directory = await Directory.systemTemp.createTemp('aoravpn-xray-');
    addTearDown(() => directory.delete(recursive: true));
    for (final mode in ConnectionMode.values) {
      final config = File('${directory.path}/${mode.name}.json');
      await config.writeAsString(jsonEncode(profile.config(mode: mode)));
      final result = await Process.run(core.absolute.path, [
        'run',
        '-test',
        '-c',
        config.path,
      ]);
      expect(
        result.exitCode,
        0,
        reason: '${mode.name}: ${result.stdout}\n${result.stderr}',
      );
    }
  });

  test('Accepts each supported server link directly', () async {
    for (final link in links) {
      final profiles = await loadSubscription(link);
      expect(profiles, hasLength(1));
    }
  });

  test('Rejects unsupported options without exposing credentials', () {
    try {
      parseSubscription(
        'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?type=quic&token=private',
      );
      fail('Unsupported option must fail.');
    } on FormatException catch (error) {
      expect(error.message, 'Unsupported link option: token.');
      expect(error.toString(), isNot(contains('private')));
    }
    expect(
      () => parseSubscription(
        'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?secret%40example.com=private',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Unsupported link option.',
        ),
      ),
    );
    expect(
      () => parseSubscription(
        'ss://aes-128-gcm:secret@127.0.0.1:443?plugin=obfs-local',
      ),
      throwsFormatException,
    );
  });

  test('Bundled sing-box accepts generated TUN and proxy configurations', () async {
    if (!Platform.isWindows) return;
    final core = File(
      'cores/windows/sing-box-1.14.2-windows-amd64/sing-box.exe',
    );
    if (!await core.exists()) return;
    final directory = await Directory.systemTemp.createTemp(
      'aoravpn-protocol-',
    );
    addTearDown(() => directory.delete(recursive: true));
    for (final profile in parseSubscription(links.join('\n'))) {
      for (final mode in ConnectionMode.values) {
        final config = File(
          '${directory.path}/${profile.protocol}-${mode.name}.json',
        );
        await config.writeAsString(jsonEncode(profile.config(mode: mode)));
        final result = await Process.run(core.absolute.path, [
          'check',
          '-c',
          config.path,
          '--disable-color',
        ]);
        expect(
          result.exitCode,
          0,
          reason:
              '${profile.protocol} ${mode.name}: ${result.stdout}\n${result.stderr}',
        );
      }
    }
  });
}
