// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/app_select.dart';

import '../controllers/connection_controller.dart';
import '../core/connection_mode.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.connection});
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Connection mode', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      AppSelect<ConnectionMode>(
        value: connection.mode,
        items: const [
          DropdownMenuItem(value: ConnectionMode.tun, child: Text('VPN (TUN)')),
          DropdownMenuItem(
            value: ConnectionMode.proxy,
            child: Text('Local proxy'),
          ),
        ],
        onChanged: connection.canEdit
            ? (mode) {
                if (mode != null) connection.setMode(mode);
              }
            : null,
      ),
      const SizedBox(height: 8),
      const Text(
        'VPN (TUN) routes system traffic automatically. Local proxy requires proxy configuration in your applications.',
      ),
      if (!connection.canEdit)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Stop the connection before changing its mode.'),
        ),
      if (connection.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(
            connection.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 32),
      const Divider(),
      const SizedBox(height: 16),
      Text('About', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Text('AORA VPN', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('An open-source, universal VPN client.'),
      const SizedBox(height: 12),
      const Text('License: GNU GPL version 3 or later.'),
      const SizedBox(height: 12),
      const Text(
        'Networking core: sing-box. This project is not affiliated with or endorsed by SagerNet.',
      ),
    ],
  );
}
