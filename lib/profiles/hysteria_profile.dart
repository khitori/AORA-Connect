// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import '../core/connection_mode.dart';

class HysteriaProfile {
  HysteriaProfile({
    required this.name,
    required this.server,
    required this.port,
    required this.password,
    required this.serverName,
    this.insecure = false,
    this.obfs,
    this.obfsPassword,
  });

  final String name;
  final String server;
  final int port;
  final String password;
  final String serverName;
  final bool insecure;
  final String? obfs;
  final String? obfsPassword;

  factory HysteriaProfile.parse(String value) {
    try {
      final uri = Uri.parse(value.trim());
      if (!['hysteria2', 'hy2'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const FormatException();
      }
      final parameters = uri.queryParameters;
      if (parameters.keys.any(
        (key) => !{'sni', 'insecure', 'obfs', 'obfs-password'}.contains(key),
      )) {
        throw const FormatException('Unsupported Hysteria2 URI parameter.');
      }
      final obfs = parameters['obfs'];
      if (obfs != null && !['salamander', 'gecko'].contains(obfs)) {
        throw const FormatException('Unsupported obfuscation type.');
      }
      if (obfs != null && (parameters['obfs-password'] ?? '').isEmpty) {
        throw const FormatException('Obfuscation password is missing.');
      }
      final insecure = parameters['insecure'];
      if (insecure != null && !['0', '1'].contains(insecure)) {
        throw const FormatException('Invalid insecure TLS flag.');
      }
      final port = uri.hasPort ? uri.port : 443;
      if (port < 1 || port > 65535) throw const FormatException();
      return HysteriaProfile(
        name: uri.fragment.isEmpty
            ? uri.host
            : Uri.decodeComponent(uri.fragment),
        server: uri.host,
        port: port,
        password: Uri.decodeComponent(uri.userInfo),
        serverName: parameters['sni'] ?? uri.host,
        insecure: insecure == '1',
        obfs: obfs,
        obfsPassword: parameters['obfs-password'],
      );
    } on FormatException catch (error) {
      // Never include the original URI, which contains credentials.
      throw FormatException(
        error.message.isEmpty
            ? 'Invalid Hysteria2 link; this importer supports single-port links.'
            : error.message.startsWith('Unsupported') ||
                  error.message.startsWith('Obfuscation') ||
                  error.message.startsWith('Invalid insecure')
            ? error.message
            : 'Invalid Hysteria2 link; this importer supports single-port links.',
      );
    }
  }

  Map<String, Object> config({
    int listenPort = 17890,
    ConnectionMode mode = ConnectionMode.tun,
    String? serverAddress,
  }) => {
    'log': {'level': 'info', 'timestamp': true},
    'dns': {
      'servers': [
        {'type': 'local', 'tag': 'local-dns'},
        if (mode == ConnectionMode.tun)
          {
            'type': 'https',
            'tag': 'vpn-dns',
            'server': '1.1.1.1',
            'path': '/dns-query',
            'detour': 'proxy',
          },
      ],
      'final': mode == ConnectionMode.tun ? 'vpn-dns' : 'local-dns',
    },
    'inbounds': [
      if (mode == ConnectionMode.proxy)
        {
          'type': 'mixed',
          'tag': 'local-proxy',
          'listen': '127.0.0.1',
          'listen_port': listenPort,
        },
      if (mode == ConnectionMode.tun)
        {
          'type': 'tun',
          'tag': 'vpn-tun',
          'interface_name': 'AORA VPN',
          'address': ['172.29.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 1500,
          'auto_route': true,
          'strict_route': true,
          'dns_mode': 'hijack',
          'stack': 'mixed',
        },
    ],
    'outbounds': [
      {
        'type': 'hysteria2',
        'tag': 'proxy',
        'server': serverAddress ?? server,
        'server_port': port,
        'password': password,
        'tls': {
          'enabled': true,
          'server_name': serverName,
          'insecure': insecure,
        },
        if (obfs != null) 'obfs': {'type': obfs!, 'password': obfsPassword!},
      },
    ],
    'route': {
      'final': 'proxy',
      'default_domain_resolver': 'local-dns',
      'auto_detect_interface': true,
      if (mode == ConnectionMode.tun)
        'rules': [
          {'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
        ],
    },
  };
}

List<HysteriaProfile> parseSubscription(String body) {
  var text = body.trim();
  if (!text.contains('://') && text.isNotEmpty) {
    try {
      text = utf8.decode(base64.decode(base64.normalize(text)));
    } on FormatException {
      throw const FormatException('Subscription is not a supported URI list.');
    }
  }
  final lines = const LineSplitter()
      .convert(text)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  if (lines.isEmpty) {
    throw const FormatException(
      'Subscription is empty. Check access or expiry.',
    );
  }
  return lines.map(HysteriaProfile.parse).toList();
}

Future<List<HysteriaProfile>> loadSubscription(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Enter a valid HTTPS subscription URL.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'Subscription request failed (HTTP ${response.statusCode}).',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('Subscription exceeds the 1 MiB limit.');
      }
    }
    return parseSubscription(utf8.decode(bytes));
  } on IOException {
    throw StateError(
      'Could not retrieve the subscription. Check network and TLS.',
    );
  } finally {
    client.close(force: true);
  }
}
