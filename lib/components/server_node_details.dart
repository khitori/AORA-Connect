// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../controllers/node_ping_controller.dart';
import '../core/core_kind.dart';
import '../l10n/l10n.dart';
import '../profiles/server_profile.dart';
import '../theme/app_colors.dart';
import 'server_node_label.dart';

class ServerNodeDetails extends StatelessWidget {
  const ServerNodeDetails({
    super.key,
    required this.profile,
    required this.pings,
    this.compact = false,
  });

  final ServerProfile profile;
  final NodePingController pings;
  final bool compact;

  List<String> get _subtitleParts {
    final outbound = profile.outbound();
    final transport = outbound['transport'];
    final stream = outbound['streamSettings'];
    final tls = outbound['tls'];
    final transportType = transport is Map ? transport['type'] : null;
    final streamType = stream is Map ? stream['method'] : null;
    final security = stream is Map ? stream['security'] : null;
    final reality = tls is Map && tls['reality'] is Map;
    final labels = <String>[
      profile.coreKind.label,
      switch (profile.protocol) {
        'hysteria2' => 'Hysteria2',
        'shadowsocks' => 'Shadowsocks',
        final protocol => protocol.toUpperCase(),
      },
      if (profile.protocol == 'hysteria2')
        'UDP'
      else if (streamType == 'grpc' || transportType == 'grpc')
        'gRPC'
      else if (transportType == 'ws')
        'WS'
      else if (transportType == 'httpupgrade')
        'HTTP Upgrade'
      else if (transportType == 'http')
        'HTTP'
      else if (profile.protocol == 'shadowsocks')
        'TCP/UDP'
      else
        'TCP',
      if (reality) 'Reality' else if (tls is Map || security == 'tls') 'TLS',
    ];
    return labels;
  }

  Color get _protocolColor => switch (profile.protocol) {
    'hysteria2' => AppColors.protocolHysteria2,
    'vless' => AppColors.protocolVless,
    'trojan' => AppColors.protocolTrojan,
    'shadowsocks' => AppColors.protocolShadowsocks,
    'vmess' => AppColors.protocolVmess,
    _ => AppColors.muted500,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pings,
    builder: (context, _) {
      final result = pings.resultFor(profile);
      final ping = result == null
          ? null
          : Tooltip(
              message:
                  result.error ??
                  context.l10n.serverCheck(
                    pings.connection.pingType.localizedLabel(context.l10n),
                  ),
              child: Text(
                result.localizedLabel(context.l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: result.error == null
                      ? AppColors.muted500
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            );
      final name = ServerNodeLabel(
        name: profile.name,
        subtitleParts: _subtitleParts,
        protocolColor: _protocolColor,
      );
      final nameRow = Row(
        children: [
          Expanded(child: name),
          if (ping != null) ...[const SizedBox(width: 8), ping],
        ],
      );
      if (compact) {
        return nameRow;
      }
      return nameRow;
    },
  );
}
