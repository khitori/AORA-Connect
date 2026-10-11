// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/server_selector.dart';
import '../components/connection_button.dart';
import '../controllers/connection_controller.dart';
import '../controllers/node_ping_controller.dart';
import '../core/connection_mode.dart';
import '../core/core_kind.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({
    super.key,
    required this.connection,
    required this.pings,
  });
  final ConnectionController connection;
  final NodePingController pings;

  void _toggleConnection(BuildContext context) {
    if (connection.canStop) {
      connection.stop();
    } else if (connection.canConnect) {
      connection.connect();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connection.selectedRequiresDifferentCore
                ? 'This server requires ${connection.selected!.coreKind.label}. Select it in Settings.'
                : 'Load a subscription on the Subscriptions tab first.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewport.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (connection.profiles.isNotEmpty)
                  ServerSelector(
                    pings: pings,
                    profiles: connection.profiles,
                    selected: connection.selected,
                    onChanged: connection.canEdit
                        ? connection.selectProfile
                        : null,
                  ),
                if (connection.selected?.insecure == true)
                  const Text(
                    'This profile disables TLS certificate verification.',
                  ),
                if (connection.selectedRequiresDifferentCore)
                  Text(
                    'This server requires ${connection.selected!.coreKind.label}. Select it in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!connection.supported)
                  const Text('This milestone supports Windows only.'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: ConnectionButton(
                        state: connection.state,
                        busy: connection.busy,
                        onPressed: connection.supported
                            ? () => _toggleConnection(context)
                            : null,
                      ),
                    ),
                  ),
                ),
                Text(
                  connection.mode == ConnectionMode.tun
                      ? 'VPN (TUN)'
                      : 'Local proxy',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${connection.core.displayName}: ${connection.state.name}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Reserve this line while connecting so a successful check
                // does not change the space centering the connection button.
                Tooltip(
                  message: connection.probeResult ?? '',
                  child: Text(
                    connection.probeResult ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (connection.errorFor(ConnectionErrorScope.connection) !=
                    null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(
                      connection.errorFor(ConnectionErrorScope.connection)!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
