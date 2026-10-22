// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'server_profile.dart';
import 'xray_vless_profile.dart';

const _uuidPattern =
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

ServerProfile parseServerLink(String link) {
  final separator = link.indexOf('://');
  if (separator < 1) {
    throw const FormatException('Invalid server link.');
  }
  final scheme = link.substring(0, separator).toLowerCase();
  if (!RegExp(r'^[a-z][a-z0-9+.-]*$').hasMatch(scheme)) {
    throw const FormatException('Invalid server link.');
  }
  try {
    return switch (scheme) {
      'vless' => _parseVless(link),
      'trojan' => _parseTrojan(link),
      'ss' => _parseShadowsocks(link),
      'vmess' => _parseVmess(link),
      _ => throw FormatException('Unsupported server protocol: $scheme.'),
    };
  } on FormatException catch (error) {
    if (error.message.startsWith('Unsupported') ||
        error.message.startsWith('Missing') ||
        error.message.startsWith('Invalid')) {
      throw FormatException(error.message);
    }
    throw FormatException('Invalid $scheme server link.');
  } catch (_) {
    throw FormatException('Invalid $scheme server link.');
  }
}

ServerProfile _parseVless(String link) {
  final uri = _uri(link, 'vless');
  final q = uri.queryParameters;
  _checkKeys(q, {
    'type',
    'security',
    'sni',
    'fp',
    'flow',
    'host',
    'path',
    'serviceName',
    'pbk',
    'sid',
    'alpn',
    'allowInsecure',
    'encryption',
    'mode',
    'headerType',
    'pcs',
  });
  final uuid = Uri.decodeComponent(uri.userInfo);
  if (!RegExp(_uuidPattern).hasMatch(uuid)) {
    throw const FormatException('Invalid VLESS UUID.');
  }
  if (q['encryption'] != null && q['encryption'] != 'none') {
    throw const FormatException('Unsupported VLESS encryption.');
  }
  final flow = q['flow'];
  if (flow != null && flow.isNotEmpty && flow != 'xtls-rprx-vision') {
    throw const FormatException('Unsupported VLESS flow.');
  }
  final tls = _tls(uri, defaultSecurity: 'none');
  if (flow == 'xtls-rprx-vision' && tls == null) {
    throw const FormatException('Invalid VLESS flow without TLS.');
  }
  final transport = _transport(q);
  if (q.containsKey('pcs')) {
    final hashes = q['pcs']!.split(',').map((value) => value.trim()).toList();
    if (hashes.isEmpty ||
        hashes.any(
          (hash) => !RegExp(
            r'^(?:[0-9a-fA-F]{2}:){31}[0-9a-fA-F]{2}$|^[0-9a-fA-F]{64}$',
          ).hasMatch(hash),
        )) {
      throw const FormatException('Invalid certificate pin (pcs).');
    }
    if (q['security'] != 'tls' ||
        q['type'] != 'grpc' ||
        flow != null && flow.isNotEmpty ||
        tls?['insecure'] == true ||
        q.containsKey('pbk') ||
        q.containsKey('sid')) {
      throw const FormatException('Unsupported pinned VLESS transport.');
    }
    return XrayVlessProfile(
      name: _name(uri),
      server: uri.host,
      port: uri.port,
      uuid: uuid,
      serverName: q['sni'] ?? uri.host,
      pinnedPeerCertSha256: hashes
          .map((hash) => hash.replaceAll(':', '').toLowerCase())
          .join(','),
      serviceName: q['serviceName'] ?? q['path'] ?? '',
      fingerprint: (q['fp'] ?? '').isEmpty ? null : q['fp'],
      alpn: (q['alpn'] ?? '').isEmpty ? null : q['alpn']!.split(','),
    );
  }
  return MappedServerProfile(
    name: _name(uri),
    server: uri.host,
    port: uri.port,
    protocol: 'vless',
    insecure: tls?['insecure'] == true,
    fields: {
      'uuid': uuid,
      if (flow != null && flow.isNotEmpty) 'flow': flow,
      'tls': ?tls,
      'transport': ?transport,
    },
  );
}

MappedServerProfile _parseTrojan(String link) {
  final uri = _uri(link, 'trojan');
  final q = uri.queryParameters;
  _checkKeys(q, {
    'type',
    'security',
    'sni',
    'fp',
    'host',
    'path',
    'serviceName',
    'pbk',
    'sid',
    'alpn',
    'allowInsecure',
    'mode',
    'headerType',
    'pcs',
  });
  if (q.containsKey('pcs')) {
    throw const FormatException(
      'Unsupported certificate pinning (pcs) in this sing-box core.',
    );
  }
  final password = Uri.decodeComponent(uri.userInfo);
  if (password.isEmpty) throw const FormatException('Missing Trojan password.');
  final tls = _tls(uri, defaultSecurity: 'tls');
  if (tls == null) throw const FormatException('Invalid Trojan TLS setting.');
  final transport = _transport(q);
  return MappedServerProfile(
    name: _name(uri),
    server: uri.host,
    port: uri.port,
    protocol: 'trojan',
    insecure: tls['insecure'] == true,
    fields: {'password': password, 'tls': tls, 'transport': ?transport},
  );
}

MappedServerProfile _parseShadowsocks(String link) {
  final content = link.substring('ss://'.length).split('#').first;
  if (content.contains('?')) {
    throw const FormatException('Unsupported Shadowsocks plugin or option.');
  }
  final hash = link.indexOf('#');
  final label = hash < 0 ? '' : Uri.decodeComponent(link.substring(hash + 1));
  String credentials;
  String authority;
  if (content.contains('@')) {
    final separator = content.lastIndexOf('@');
    credentials = content.substring(0, separator);
    authority = content.substring(separator + 1);
    if (!credentials.contains(':')) credentials = _base64Text(credentials);
  } else {
    final decoded = _base64Text(content);
    final separator = decoded.lastIndexOf('@');
    if (separator < 0) throw const FormatException('Invalid Shadowsocks link.');
    credentials = decoded.substring(0, separator);
    authority = decoded.substring(separator + 1);
  }
  final colon = credentials.indexOf(':');
  if (colon < 1 || colon == credentials.length - 1) {
    throw const FormatException('Invalid Shadowsocks credentials.');
  }
  final method = Uri.decodeComponent(credentials.substring(0, colon));
  const supportedMethods = {
    '2022-blake3-aes-128-gcm',
    '2022-blake3-aes-256-gcm',
    '2022-blake3-chacha20-poly1305',
    'none',
    'aes-128-gcm',
    'aes-192-gcm',
    'aes-256-gcm',
    'chacha20-ietf-poly1305',
    'xchacha20-ietf-poly1305',
    'aes-128-ctr',
    'aes-192-ctr',
    'aes-256-ctr',
    'aes-128-cfb',
    'aes-192-cfb',
    'aes-256-cfb',
    'rc4-md5',
    'chacha20-ietf',
    'xchacha20',
  };
  if (!supportedMethods.contains(method)) {
    throw const FormatException('Unsupported Shadowsocks method.');
  }
  final password = Uri.decodeComponent(credentials.substring(colon + 1));
  final uri = _uri('ss://user@$authority', 'ss');
  return MappedServerProfile(
    name: label.isEmpty ? uri.host : label,
    server: uri.host,
    port: uri.port,
    protocol: 'shadowsocks',
    fields: {'method': method, 'password': password},
  );
}

MappedServerProfile _parseVmess(String link) {
  final encoded = link.substring('vmess://'.length).split('#').first;
  final value = jsonDecode(_base64Text(encoded));
  if (value is! Map) throw const FormatException('Invalid VMess link.');
  final server = value['add'];
  final port = int.tryParse('${value['port']}');
  final uuid = value['id'];
  if (server is! String ||
      server.isEmpty ||
      port == null ||
      port < 1 ||
      port > 65535 ||
      uuid is! String ||
      !RegExp(_uuidPattern).hasMatch(uuid)) {
    throw const FormatException('Invalid VMess server fields.');
  }
  final security = value['scy']?.toString() ?? 'auto';
  if (!{
    'auto',
    'none',
    'zero',
    'aes-128-gcm',
    'chacha20-poly1305',
    'aes-128-ctr',
  }.contains(security)) {
    throw const FormatException('Unsupported VMess security.');
  }
  final alterId = int.tryParse('${value['aid'] ?? 0}');
  if (alterId == null || alterId < 0) {
    throw const FormatException('Invalid VMess alter ID.');
  }
  final net = value['net']?.toString() ?? 'tcp';
  final tlsMode = value['tls']?.toString() ?? '';
  if (tlsMode.isNotEmpty && tlsMode != 'tls') {
    throw const FormatException('Unsupported VMess TLS mode.');
  }
  final parameters = {
    'type': net,
    'host': value['host']?.toString() ?? '',
    'path': value['path']?.toString() ?? '',
    'serviceName': value['path']?.toString() ?? '',
  };
  final transport = _transport(parameters);
  final tls = tlsMode == 'tls'
      ? <String, Object?>{
          'enabled': true,
          'server_name': (value['sni']?.toString().isNotEmpty ?? false)
              ? value['sni'].toString()
              : server,
          'insecure': false,
          if ((value['fp']?.toString() ?? '').isNotEmpty)
            'utls': {'enabled': true, 'fingerprint': value['fp'].toString()},
        }
      : null;
  return MappedServerProfile(
    name: (value['ps']?.toString() ?? '').isEmpty
        ? server
        : value['ps'].toString(),
    server: server,
    port: port,
    protocol: 'vmess',
    fields: {
      'uuid': uuid,
      'security': security,
      'alter_id': alterId,
      'tls': ?tls,
      'transport': ?transport,
    },
  );
}

Uri _uri(String link, String scheme) {
  final uri = Uri.parse(link);
  if (uri.scheme != scheme ||
      uri.host.isEmpty ||
      !uri.hasPort ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw FormatException('Invalid $scheme server address.');
  }
  return uri;
}

String _name(Uri uri) =>
    uri.fragment.isEmpty ? uri.host : Uri.decodeComponent(uri.fragment);

void _checkKeys(Map<String, String> values, Set<String> allowed) {
  for (final key in values.keys) {
    if (!allowed.contains(key)) {
      final safeName = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,39}$').hasMatch(key);
      throw FormatException(
        safeName
            ? 'Unsupported link option: $key.'
            : 'Unsupported link option.',
      );
    }
  }
}

Map<String, Object?>? _tls(Uri uri, {required String defaultSecurity}) {
  final q = uri.queryParameters;
  final security = q['security'] ?? defaultSecurity;
  if (security == 'none') {
    if (q.keys.any(
      (key) =>
          {'sni', 'fp', 'pbk', 'sid', 'alpn', 'allowInsecure'}.contains(key),
    )) {
      throw const FormatException('Invalid TLS options without TLS.');
    }
    return null;
  }
  if (security != 'tls' && security != 'reality') {
    throw const FormatException('Unsupported TLS security mode.');
  }
  final insecureValue = q['allowInsecure'] ?? '0';
  if (!{'0', '1', 'false', 'true'}.contains(insecureValue)) {
    throw const FormatException('Invalid TLS verification option.');
  }
  if (security == 'tls' && (q.containsKey('pbk') || q.containsKey('sid'))) {
    throw const FormatException('Invalid Reality options without Reality.');
  }
  if (security == 'reality' && (q['pbk'] ?? '').isEmpty) {
    throw const FormatException('Missing Reality public key.');
  }
  return {
    'enabled': true,
    'server_name': q['sni'] ?? uri.host,
    'insecure': insecureValue == '1' || insecureValue == 'true',
    if ((q['fp'] ?? '').isNotEmpty)
      'utls': {'enabled': true, 'fingerprint': q['fp']!},
    if ((q['alpn'] ?? '').isNotEmpty) 'alpn': q['alpn']!.split(','),
    if (security == 'reality')
      'reality': {
        'enabled': true,
        'public_key': q['pbk']!,
        'short_id': q['sid'] ?? '',
      },
  };
}

Map<String, Object?>? _transport(Map<String, String> q) {
  final type = q['type'] ?? 'tcp';
  final mode = q['mode'];
  final headerType = q['headerType'];
  if (mode != null && (type != 'grpc' || mode != 'gun')) {
    throw const FormatException('Unsupported transport mode.');
  }
  if (headerType != null && (type != 'tcp' || headerType != 'none')) {
    throw const FormatException('Unsupported TCP header type.');
  }
  final host = q['host'] ?? '';
  final path = q['path'] ?? '';
  final service = q['serviceName'] ?? '';
  switch (type) {
    case 'tcp':
      if (host.isNotEmpty || path.isNotEmpty || service.isNotEmpty) {
        throw const FormatException('Unsupported TCP transport options.');
      }
      return null;
    case 'ws':
      return {
        'type': 'ws',
        if (path.isNotEmpty) 'path': path,
        if (host.isNotEmpty) 'headers': {'Host': host},
      };
    case 'grpc':
      if (host.isNotEmpty) {
        throw const FormatException('Unsupported gRPC host option.');
      }
      return {'type': 'grpc', 'service_name': service.isEmpty ? path : service};
    case 'httpupgrade':
      return {
        'type': 'httpupgrade',
        if (host.isNotEmpty) 'host': host,
        if (path.isNotEmpty) 'path': path,
      };
    case 'http':
    case 'h2':
      return {
        'type': 'http',
        if (host.isNotEmpty) 'host': [host],
        if (path.isNotEmpty) 'path': path,
      };
    default:
      throw FormatException('Unsupported transport type: $type.');
  }
}

String _base64Text(String value) {
  try {
    return utf8.decode(base64.decode(base64.normalize(value)));
  } on FormatException {
    throw const FormatException('Invalid base64 server link.');
  }
}
