// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_notification.dart';
import '../components/connection_edit_notification.dart';
import '../core/android_quick_settings.dart';
import '../core/android_tunnel_engine.dart';
import '../core/diagnostics_report.dart';

import '../components/app_select.dart';
import '../components/app_toggle.dart';
import '../components/app_expansion_card.dart';
import '../components/connection_controls.dart';
import '../components/core_logs.dart';
import '../components/statistics_panel.dart';
import '../components/updates_panel.dart';
import '../updates/update_controller.dart';

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
    this.updates,
    this.onInstallUpdate,
  });
  final ConnectionController connection;
  final StatisticsController statistics;
  final UpdateController? updates;
  final Future<void> Function()? onInstallUpdate;

  bool _allowEdit(BuildContext context, String action) =>
      allowConnectionEdit(context, connection, 'Disconnect before $action.');

  Widget _editControl(
    BuildContext context,
    String action,
    Widget child, {
    bool available = true,
  }) => DisabledControlNotice(
    disabled: !connection.canEdit && available,
    onTap: () => _allowEdit(context, action),
    label: 'Disconnect before $action.',
    child: child,
  );

  Future<void> _copyDiagnostics(BuildContext context) async {
    try {
      Map<String, dynamic> details = const {};
      if (Platform.isAndroid) {
        details =
            await AndroidTunnelEngine.channel.invokeMapMethod<String, dynamic>(
              'reportDetails',
            ) ??
            {};
      }
      final report = buildDiagnosticsReport(
        connection,
        version:
            details['version'] as String? ??
            (updates?.currentVersion.isNotEmpty == true
                ? updates!.currentVersion
                : 'Not available'),
        platform: details['platform'] as String? ?? Platform.operatingSystem,
        network: details['network'] as String? ?? 'Not available',
        coreError: details['coreError'] as String?,
      );
      await Clipboard.setData(ClipboardData(text: report));
      if (context.mounted) AppNotification.show(context, 'Diagnostics copied.');
    } catch (_) {
      if (context.mounted) {
        AppNotification.show(context, 'Could not copy diagnostics.');
      }
    }
  }

  Future<void> _addTile(BuildContext context) async {
    try {
      final result = await AndroidQuickSettings.addTile();
      if (!context.mounted) return;
      AppNotification.show(context, switch (result) {
        'added' => 'AORA Connect added to Quick Settings.',
        'alreadyAdded' => 'AORA Connect is already in Quick Settings.',
        'manual' => 'Open Quick Settings, tap Edit, then drag AORA Connect into your tiles.',
        'declined' => 'Quick Settings tile was not added.',
        _ => 'Could not add the tile. Open Quick Settings and add AORA Connect using Edit.',
      });
    } catch (_) {
      if (context.mounted) {
        AppNotification.show(
          context,
          'Could not add the tile. Open Quick Settings and add AORA Connect using Edit.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
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
          _editControl(
            context,
            'changing the core',
            AppSelect<CoreKind>(
              onBeforeOpen: () => _allowEdit(context, 'changing the core'),
              value: connection.core,
              items: [
                for (final core in CoreKind.values)
                  DropdownMenuItem(
                    value: core,
                    enabled: connection.supportsCore(core),
                    child: Text(core.displayName),
                  ),
              ],
              onChanged: connection.canEdit
                  ? (core) {
                      if (core != null &&
                          _allowEdit(context, 'changing the core')) {
                        connection.setCore(core);
                      }
                    }
                  : null,
            ),
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
          _editControl(
            context,
            'changing connection mode',
            AppSelect<ConnectionMode>(
              onBeforeOpen: () =>
                  _allowEdit(context, 'changing connection mode'),
              value: connection.mode,
              items: [
                const DropdownMenuItem(
                  value: ConnectionMode.tun,
                  child: Text('VPN (TUN)'),
                ),
                DropdownMenuItem(
                  value: ConnectionMode.proxy,
                  enabled: connection.supportsMode(ConnectionMode.proxy),
                  child: const Text('Local proxy'),
                ),
              ],
              onChanged: connection.canEdit
                  ? (mode) {
                      if (mode != null &&
                          _allowEdit(context, 'changing connection mode')) {
                        connection.setMode(mode);
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'VPN (TUN) routes system traffic automatically. Local proxy requires proxy configuration in your applications.',
          ),
          const SizedBox(height: 12),
          _editControl(
            context,
            'changing Kill Switch',
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
                    ? () {
                        if (!_allowEdit(context, 'changing Kill Switch')) {
                          return;
                        }
                        connection.setKillSwitchEnabled(
                          !connection.killSwitchEnabled,
                        );
                      }
                    : null,
                trailing: AppToggle(
                  semanticLabel: 'Kill Switch',
                  value: connection.killSwitchEnabled,
                  onChanged:
                      connection.canEdit && connection.killSwitchAvailable
                      ? (enabled) {
                          if (_allowEdit(context, 'changing Kill Switch')) {
                            connection.setKillSwitchEnabled(enabled);
                          }
                        }
                      : null,
                ),
              ),
            ),
            available: connection.killSwitchAvailable,
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (Platform.isAndroid) ...[
        AppExpansionCard(
          title: 'Quick Settings',
          subtitle: 'Connect from the Android panel',
          icon: Icons.dashboard_customize_outlined,
          children: [
            const Text(
              'Use the AORA Connect tile to connect to your selected server or disconnect. Hold the tile to open the app.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addTile(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add to Quick Settings'),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      AppExpansionCard(
        title: 'DNS',
        subtitle: connection.dnsProvider.label,
        icon: Icons.dns_outlined,
        children: [
          Text('DNS server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _editControl(
            context,
            'changing DNS',
            AppSelect<DnsProvider>(
              onBeforeOpen: () => _allowEdit(context, 'changing DNS'),
              value: connection.dnsProvider,
              items: [
                for (final provider in DnsProvider.values)
                  DropdownMenuItem(
                    value: provider,
                    child: Text(provider.label),
                  ),
              ],
              onChanged: connection.canEdit
                  ? (provider) {
                      if (provider != null &&
                          _allowEdit(context, 'changing DNS')) {
                        connection.setDnsProvider(provider);
                      }
                    }
                  : null,
            ),
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
            onValidate: connection.canValidate ? connection.validate : null,
            onTest: connection.canTest ? connection.testConnection : null,
            onCopy: () => _copyDiagnostics(context),
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
      if (updates != null && onInstallUpdate != null) ...[
        UpdatesPanel(
          updates: updates!,
          connection: connection,
          onInstall: onInstallUpdate!,
        ),
        const SizedBox(height: 12),
      ],
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
