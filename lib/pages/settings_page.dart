// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/app_select.dart';
import '../components/app_toggle.dart';
import '../components/app_expansion_card.dart';
import '../components/connection_controls.dart';
import '../components/core_logs.dart';
import '../components/statistics_panel.dart';

import '../controllers/connection_controller.dart';
import '../controllers/statistics_controller.dart';
import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import '../core/dns_provider.dart';
import '../core/ping_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.connection,
    required this.statistics,
  });
  final ConnectionController connection;
  final StatisticsController statistics;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
    children: [
      AppExpansionCard(
        title: 'Core',
        subtitle: connection.core.displayName,
        icon: Icons.memory_rounded,
        children: [
          Text(
            'Networking core',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AppSelect<CoreKind>(
            value: connection.core,
            items: [
              for (final core in CoreKind.values)
                DropdownMenuItem(value: core, child: Text(core.displayName)),
            ],
            onChanged: connection.canEdit
                ? (core) {
                    if (core != null) connection.setCore(core);
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the core manually. Each server shows its required core on the Subscriptions page.',
          ),
          if (connection.selectedRequiresDifferentCore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selected server requires ${connection.selected!.coreKind.label}.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: 'Connection',
        subtitle: connection.mode == ConnectionMode.tun
            ? 'VPN (TUN)'
            : 'Local proxy',
        icon: Icons.lan_outlined,
        children: [
          Text(
            'Connection mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AppSelect<ConnectionMode>(
            value: connection.mode,
            items: const [
              DropdownMenuItem(
                value: ConnectionMode.tun,
                child: Text('VPN (TUN)'),
              ),
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
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.controlRadius),
              ),
              hoverColor: AppColors.ink.withValues(alpha: 0.06),
              title: const Text('Kill Switch'),
              subtitle: Text(
                connection.mode == ConnectionMode.tun
                    ? 'Protects DNS and TUN routing while connected. Normal internet access resumes when disconnected.'
                    : 'Available in VPN (TUN) mode.',
              ),
              onTap: connection.canEdit && connection.killSwitchAvailable
                  ? () => connection.setKillSwitchEnabled(
                      !connection.killSwitchEnabled,
                    )
                  : null,
              trailing: AppToggle(
                semanticLabel: 'Kill Switch',
                value: connection.killSwitchEnabled,
                onChanged: connection.canEdit && connection.killSwitchAvailable
                    ? connection.setKillSwitchEnabled
                    : null,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: 'DNS',
        subtitle: connection.dnsProvider.label,
        icon: Icons.dns_outlined,
        children: [
          Text('DNS server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AppSelect<DnsProvider>(
            value: connection.dnsProvider,
            items: [
              for (final provider in DnsProvider.values)
                DropdownMenuItem(value: provider, child: Text(provider.label)),
            ],
            onChanged: connection.canEdit
                ? (provider) {
                    if (provider != null) connection.setDnsProvider(provider);
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'DNS provider for VPN (TUN). System-wide DNS is not configured in local proxy mode.',
          ),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: 'Server checks',
        subtitle: connection.pingType.label,
        icon: Icons.network_check_rounded,
        children: [
          Text(
            'Server ping method',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AppSelect<PingType>(
            value: connection.pingType,
            items: [
              for (final type in PingType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: connection.busy
                ? null
                : (type) {
                    if (type != null) connection.setPingType(type);
                  },
          ),
          const SizedBox(height: 8),
          const Text(
            'Applies to server checks throughout the app. Statistics uses live ICMP. Proxy checks request https://www.gstatic.com/generate_204 through each node.',
          ),
        ],
      ),
      if (!connection.canEdit)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Stop the connection before changing core, mode or DNS.'),
        ),
      if (connection.errorFor(ConnectionErrorScope.settings) != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(
            connection.errorFor(ConnectionErrorScope.settings)!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 12),
      StatisticsPanel(statistics: statistics),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: 'Diagnostics',
        subtitle: 'Validation, connection test and logs',
        icon: Icons.tune_rounded,
        children: [
          ConnectionControls(
            onValidate: connection.canConnect ? connection.validate : null,
            onTest: connection.canTest ? connection.testConnection : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.terminal_rounded, size: 18, color: AppColors.muted500),
              const SizedBox(width: 8),
              Text('Core logs', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          CoreLogs(lines: connection.logs),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: 'About',
        subtitle: 'AORA Connect',
        icon: Icons.info_outline_rounded,
        children: [
          Text(
            'AORA Connect',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('An open-source, universal VPN client.'),
          const SizedBox(height: 12),
          const Text('License: GNU GPL version 3 or later.'),
          const SizedBox(height: 12),
          const Text(
            'Networking cores: sing-box and Xray. Their binaries and licenses are separate from the app.',
          ),
        ],
      ),
    ],
  );
}
