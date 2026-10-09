// SPDX-License-Identifier: GPL-3.0-or-later
import '../core/connection_mode.dart';
import '../core/core_kind.dart';

abstract class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.server,
    required this.port,
    this.insecure = false,
  });

  final String name;
  final String server;
  final int port;
  final bool insecure;

  String get protocol;
  CoreKind get coreKind => CoreKind.singBox;
  Map<String, Object?> outbound({String? serverAddress});

  Map<String, Object?> config({
    int listenPort = 17890,
    ConnectionMode mode = ConnectionMode.tun,
    String? serverAddress,
    bool leakProtection = true,
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
          'strict_route': leakProtection,
          'dns_mode': 'hijack',
          'stack': 'mixed',
        },
    ],
    'outbounds': [outbound(serverAddress: serverAddress)],
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

class MappedServerProfile extends ServerProfile {
  const MappedServerProfile({
    required super.name,
    required super.server,
    required super.port,
    required this.protocol,
    required this.fields,
    super.insecure,
  });

  @override
  final String protocol;
  final Map<String, Object?> fields;

  @override
  Map<String, Object?> outbound({String? serverAddress}) => {
    'type': protocol,
    'tag': 'proxy',
    'server': serverAddress ?? server,
    'server_port': port,
    ...fields,
  };
}
