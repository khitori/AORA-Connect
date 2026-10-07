// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/subscription_input.dart';
import '../components/server_selector.dart';
import '../components/connection_button.dart';
import '../components/connection_controls.dart';
import '../components/core_logs.dart';
import '../controllers/connection_controller.dart';
import '../core/connection_mode.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({
    super.key,
    required this.connection,
    required this.subscriptionUrl,
  });
  final ConnectionController connection;
  final TextEditingController subscriptionUrl;

  void _toggleConnection(BuildContext context) {
    if (connection.canStop) {
      connection.stop();
    } else if (connection.canConnect) {
      connection.connect();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Load a subscription and select a server first.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubscriptionInput(
                controller: subscriptionUrl,
                enabled: connection.canEdit,
                onLoad: connection.supported && connection.canEdit
                    ? () => connection.load(subscriptionUrl.text)
                    : null,
              ),
              if (connection.profiles.isNotEmpty)
                ServerSelector(
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
                'Core: ${connection.state.name}',
                textAlign: TextAlign.center,
              ),
              if (connection.probeResult != null)
                Text(connection.probeResult!, textAlign: TextAlign.center),
              if (connection.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(
                    connection.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Diagnostics'),
                children: [
                  ConnectionControls(
                    onValidate: connection.canConnect
                        ? connection.validate
                        : null,
                    onTest: connection.canTest
                        ? connection.testConnection
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Core logs'),
                  const SizedBox(height: 8),
                  CoreLogs(lines: connection.logs),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
