// SPDX-License-Identifier: GPL-3.0-or-later
import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import 'server_profile.dart';

/// VLESS links requiring Xray's full-certificate SHA-256 pinning.
class XrayVlessProfile extends ServerProfile {
  const XrayVlessProfile({
    required super.name,
    required super.server,
    required super.port,
    required this.uuid,
    required this.serverName,
    required this.pinnedPeerCertSha256,
    required this.serviceName,
    this.fingerprint,
    this.alpn,
  });

  final String uuid;
  final String serverName;
  final String pinnedPeerCertSha256;
  final String serviceName;
  final String? fingerprint;
  final List<String>? alpn;

  @override
  String get protocol => 'vless';
  @override
  CoreKind get coreKind => CoreKind.xray;

  @override
  Map<String, Object?> outbound({String? serverAddress}) => {
    'protocol': 'vless',
    'tag': 'proxy',
    'settings': {
      'address': serverAddress ?? server,
      'port': port,
      'id': uuid,
      'encryption': 'none',
    },
    'streamSettings': {
      'method': 'grpc',
      'security': 'tls',
      'tlsSettings': {
        'serverName': serverName,
        'allowInsecure': false,
        'pinnedPeerCertSha256': pinnedPeerCertSha256,
        if (fingerprint != null) 'fingerprint': fingerprint,
        if (alpn != null) 'alpn': alpn,
      },
      'grpcSettings': {'serviceName': serviceName, 'multiMode': false},
    },
  };

  @override
  Map<String, Object?> config({
    int listenPort = 17890,
    ConnectionMode mode = ConnectionMode.tun,
    String? serverAddress,
    bool leakProtection = true,
  }) => {
    'log': {'loglevel': 'warning'},
    'inbounds': [
      if (mode == ConnectionMode.proxy)
        {
          'tag': 'local-proxy',
          'listen': '127.0.0.1',
          'port': listenPort,
          'protocol': 'http',
        },
      if (mode == ConnectionMode.tun)
        {
          'tag': 'vpn-tun',
          'protocol': 'tun',
          'settings': {
            'name': 'AORA VPN',
            'desc': 'AORA VPN',
            'mtu': 1500,
            'gateway': ['172.29.0.1/30', 'fdfe:dcba:9876::1/126'],
            'dns': ['1.1.1.1'],
            'autoSystemRoutingTable': ['0.0.0.0/0', '::/0'],
            'autoOutboundsInterface': 'auto',
            if (leakProtection)
              'autoSystemWfpBlockLeak': ['dns', 'misconfigtun'],
          },
        },
    ],
    'outbounds': [outbound(serverAddress: serverAddress)],
    'routing': {'domainStrategy': 'IPIfNonMatch'},
  };
}
