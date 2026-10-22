// SPDX-License-Identifier: GPL-3.0-or-later
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:aoravpn/profiles/server_profile.dart';
import 'package:aoravpn/profiles/xray_vless_profile.dart';

Future<void> main() async {
  final directory = Directory('build/android-vpn-smoke')
    ..createSync(recursive: true);
  String secret(int count) =>
      base64Encode(List.generate(count, (_) => Random.secure().nextInt(256)));
  final password = secret(16);
  final nonce = secret(24);
  const uuid = 'bf000d23-0752-40b4-affe-68f7707a9661';
  final certificate = File('${directory.absolute.path}/gateway.crt');
  final key = File('${directory.absolute.path}/gateway.key');
  final openssl = Platform.isWindows
      ? 'C:/Program Files/Git/usr/bin/openssl.exe'
      : 'openssl';
  final generated = await Process.run(openssl, [
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    key.path,
    '-out',
    certificate.path,
    '-days',
    '2',
    '-subj',
    '/CN=aora-test',
    '-addext',
    'subjectAltName=DNS:aora-test',
  ]);
  if (generated.exitCode != 0) {
    throw StateError('Test certificate generation failed.');
  }
  final der = base64Decode(
    (await certificate.readAsString())
        .split('\n')
        .where((line) => !line.startsWith('---'))
        .join()
        .trim(),
  );
  final pin = sha256.convert(der).toString();
  final config = MappedServerProfile(
    name: 'Local Android smoke test',
    server: '127.0.0.1',
    port: 17991,
    protocol: 'shadowsocks',
    fields: {'method': '2022-blake3-aes-128-gcm', 'password': password},
  ).config();
  final xray = XrayVlessProfile(
    name: 'Local Xray smoke test',
    server: '127.0.0.1',
    port: 17992,
    uuid: uuid,
    serverName: 'aora-test',
    pinnedPeerCertSha256: pin,
    serviceName: 'aora-test',
  );
  final xrayConfig = xray.config();
  final tun =
      ((xrayConfig['inbounds'] as List).single as Map)['settings'] as Map;
  for (final option in [
    'autoSystemRoutingTable',
    'autoOutboundsInterface',
    'autoSystemWfpBlockLeak',
  ]) {
    tun.remove(option);
  }
  final links =
      'ss://${base64Url.encode(utf8.encode('2022-blake3-aes-128-gcm:$password'))}@127.0.0.1:17991#Local-sing-box\n'
      'vless://$uuid@127.0.0.1:17992?security=tls&type=grpc&serviceName=aora-test&sni=aora-test&pcs=$pin#Local-Xray';
  await File('${directory.path}/defines.json').writeAsString(
    jsonEncode({
      'AORA_SMOKE_CONFIG': base64Encode(utf8.encode(jsonEncode(config))),
      'AORA_SMOKE_NONCE': nonce,
      'AORA_SMOKE_XRAY_CONFIG': base64Encode(
        utf8.encode(jsonEncode(xrayConfig)),
      ),
      'AORA_SMOKE_LINKS': base64Encode(utf8.encode(links)),
    }),
  );
  await File('${directory.path}/gateway.json').writeAsString(
    jsonEncode({
      'log': {'level': 'error'},
      'inbounds': [
        {
          'type': 'shadowsocks',
          'listen': '127.0.0.1',
          'listen_port': 17991,
          'method': '2022-blake3-aes-128-gcm',
          'password': password,
        },
        {
          'type': 'vless',
          'listen': '127.0.0.1',
          'listen_port': 17992,
          'users': [
            {'uuid': uuid},
          ],
          'tls': {
            'enabled': true,
            'certificate_path': certificate.path,
            'key_path': key.path,
          },
          'transport': {'type': 'grpc', 'service_name': 'aora-test'},
        },
      ],
      'outbounds': [
        {'type': 'direct', 'tag': 'direct'},
      ],
      'route': {
        'rules': [
          {
            'ip_cidr': ['198.18.0.2/32', '2001:db8::2/128'],
            'action': 'route',
            'outbound': 'direct',
            'override_address': '127.0.0.1',
            'override_port': 18080,
          },
        ],
      },
    }),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18080);
  print('AORA_GATEWAY_READY');
  await for (final request in server) {
    request.response.write(nonce);
    await request.response.close();
  }
}
