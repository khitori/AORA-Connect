// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'core_kind.dart';

/// An allowlist, not a redacted dump: never include URLs, names, SNI or secrets.
String connectionConfigurationSummary(String configuration, CoreKind core) {
  try {
    final config = jsonDecode(configuration) as Map;
    final outbounds = config['outbounds'] as List? ?? const [];
    final proxy = outbounds
        .whereType<Map>()
        .where((outbound) => outbound['tag'] == 'proxy')
        .firstOrNull;
    final protocol = proxy?[core == CoreKind.xray ? 'protocol' : 'type'];
    const knownProtocols = {
      'hysteria2',
      'hysteria',
      'tuic',
      'vless',
      'vmess',
      'trojan',
      'shadowsocks',
      'socks',
      'http',
      'wireguard',
    };
    Object? address = proxy?['server'];
    Object? port = proxy?['server_port'];
    if (core == CoreKind.xray) {
      final settings = proxy?['settings'] as Map?;
      final servers = settings?['vnext'] ?? settings?['servers'];
      if (servers is List && servers.isNotEmpty && servers.first is Map) {
        address = (servers.first as Map)['address'];
        port = (servers.first as Map)['port'];
      }
    }
    final ip = address is String ? InternetAddress.tryParse(address) : null;
    final host = ip == null
        ? '(hostname omitted)'
        : ip.type == InternetAddressType.IPv6
        ? '[${ip.address}]'
        : ip.address;
    final safePort = port is int && port > 0 && port <= 65535 ? '$port' : '?';
    return 'VPN outbound: core=${core.displayName}; '
        'protocol=${knownProtocols.contains(protocol) ? protocol : 'unknown'}; '
        'server=$host:$safePort.';
  } catch (_) {
    return 'VPN outbound: core=${core.displayName}; endpoint details unavailable.';
  }
}
