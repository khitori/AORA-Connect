// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_expansion_card.dart';
import '../components/app_notification.dart';
import '../components/app_select.dart';
import '../components/app_toggle.dart';
import '../components/connection_controls.dart';
import '../components/connection_edit_notification.dart';
import '../components/core_logs.dart';
import '../components/language_settings.dart';
import '../components/statistics_panel.dart';
import '../components/updates_panel.dart';
import '../controllers/connection_controller.dart';
import '../controllers/statistics_controller.dart';
import '../core/android_quick_settings.dart';
import '../core/android_tunnel_engine.dart';
import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import '../core/diagnostics_report.dart';
import '../core/dns_provider.dart';
import '../core/ping_type.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../updates/update_controller.dart';

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

  bool _allowEdit(BuildContext context, String action) => allowConnectionEdit(
    context,
    connection,
    context.l10n.disconnectBeforeAction(action),
  );

  Widget _editControl(
    BuildContext context,
    String action,
    Widget child, {
    bool available = true,
  }) => DisabledControlNotice(
    disabled: !connection.canEdit && available,
    onTap: () => _allowEdit(context, action),
    label: context.l10n.disconnectBeforeAction(action),
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
      if (!context.mounted) return;
      final report = buildDiagnosticsReport(
        connection,
        version:
            details['version'] as String? ??
            (updates?.currentVersion.isNotEmpty == true
                ? updates!.currentVersion
                : context.l10n.notAvailable),
        platform: details['platform'] as String? ?? Platform.operatingSystem,
        network: details['network'] as String? ?? context.l10n.notAvailable,
        coreError: details['coreError'] as String?,
      );
      await Clipboard.setData(ClipboardData(text: report));
      if (context.mounted) {
        AppNotification.show(context, context.l10n.diagnosticsCopied);
      }
    } catch (_) {
      if (context.mounted) {
        AppNotification.show(context, context.l10n.diagnosticsCopyFailed);
      }
    }
  }

  Future<void> _addTile(BuildContext context) async {
    try {
      final result = await AndroidQuickSettings.addTile();
      if (!context.mounted) return;
      AppNotification.show(context, switch (result) {
        'added' => context.l10n.tileAdded,
        'alreadyAdded' => context.l10n.tileAlreadyAdded,
        'manual' => context.l10n.tileManual,
        'declined' => context.l10n.tileDeclined,
        _ => context.l10n.tileFailed,
      });
    } catch (_) {
      if (context.mounted) {
        AppNotification.show(context, context.l10n.tileFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
    children: [
      const LanguageSettings(),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: context.l10n.core,
        storageId: 'core',
        subtitle: connection.core.displayName,
        icon: Icons.memory_rounded,
        children: [
          Text(
            context.l10n.networkingCore,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _editControl(
            context,
            context.l10n.changingCore,
            AppSelect<CoreKind>(
              onBeforeOpen: () =>
                  _allowEdit(context, context.l10n.changingCore),
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
                          _allowEdit(context, context.l10n.changingCore)) {
                        connection.setCore(core);
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.coreHelp),
          if (connection.selectedRequiresDifferentCore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.selectedRequiresCore(
                  isolateTechnicalValue(
                    context.l10n,
                    connection.selected!.coreKind.label,
                  ),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: context.l10n.connection,
        storageId: 'connection',
        subtitle: connection.mode == ConnectionMode.tun
            ? context.l10n.vpnTun
            : context.l10n.localProxy,
        icon: Icons.lan_outlined,
        children: [
          Text(
            context.l10n.connectionMode,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _editControl(
            context,
            context.l10n.changingMode,
            AppSelect<ConnectionMode>(
              onBeforeOpen: () =>
                  _allowEdit(context, context.l10n.changingMode),
              value: connection.mode,
              items: [
                DropdownMenuItem(
                  value: ConnectionMode.tun,
                  child: Text(context.l10n.vpnTun),
                ),
                DropdownMenuItem(
                  value: ConnectionMode.proxy,
                  enabled: connection.supportsMode(ConnectionMode.proxy),
                  child: Text(context.l10n.localProxy),
                ),
              ],
              onChanged: connection.canEdit
                  ? (mode) {
                      if (mode != null &&
                          _allowEdit(context, context.l10n.changingMode)) {
                        connection.setMode(mode);
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.connectionModeHelp),
          const SizedBox(height: 12),
          _editControl(
            context,
            context.l10n.changingKillSwitch,
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
                title: Text(context.l10n.killSwitch),
                subtitle: Text(
                  connection.mode == ConnectionMode.tun
                      ? context.l10n.killSwitchHelp
                      : context.l10n.availableTun,
                ),
                onTap: connection.canEdit && connection.killSwitchAvailable
                    ? () {
                        if (!_allowEdit(
                          context,
                          context.l10n.changingKillSwitch,
                        )) {
                          return;
                        }
                        connection.setKillSwitchEnabled(
                          !connection.killSwitchEnabled,
                        );
                      }
                    : null,
                trailing: AppToggle(
                  semanticLabel: context.l10n.killSwitch,
                  value: connection.killSwitchEnabled,
                  onChanged:
                      connection.canEdit && connection.killSwitchAvailable
                      ? (enabled) {
                          if (_allowEdit(
                            context,
                            context.l10n.changingKillSwitch,
                          )) {
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
          title: context.l10n.quickSettings,
          storageId: 'quickSettings',
          subtitle: context.l10n.quickSettingsSubtitle,
          icon: Icons.dashboard_customize_outlined,
          children: [
            Text(context.l10n.quickSettingsHelp),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addTile(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.l10n.addQuickSettings),
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
          Text(
            context.l10n.dnsServer,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _editControl(
            context,
            context.l10n.changingDns,
            AppSelect<DnsProvider>(
              onBeforeOpen: () => _allowEdit(context, context.l10n.changingDns),
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
                          _allowEdit(context, context.l10n.changingDns)) {
                        connection.setDnsProvider(provider);
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.dnsHelp),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: context.l10n.serverChecks,
        storageId: 'serverChecks',
        subtitle: connection.pingType.localizedLabel(context.l10n),
        icon: Icons.network_check_rounded,
        children: [
          Text(
            context.l10n.serverPingMethod,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AppSelect<PingType>(
            value: connection.pingType,
            items: [
              for (final type in PingType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(type.localizedLabel(context.l10n)),
                ),
            ],
            onChanged: connection.busy
                ? null
                : (type) {
                    if (type != null) connection.setPingType(type);
                  },
          ),
          const SizedBox(height: 8),
          Text(context.l10n.serverChecksHelp),
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
        title: context.l10n.diagnostics,
        storageId: 'diagnostics',
        subtitle: context.l10n.diagnosticsSubtitle,
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
              Text(
                context.l10n.coreLogs,
                style: Theme.of(context).textTheme.labelLarge,
              ),
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
        title: context.l10n.about,
        storageId: 'about',
        subtitle: 'AORA Connect',
        icon: Icons.info_outline_rounded,
        children: [
          Text(
            'AORA Connect',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.aboutClient),
          const SizedBox(height: 12),
          Text(context.l10n.license),
          const SizedBox(height: 12),
          Text(context.l10n.coresLicense),
        ],
      ),
    ],
  );
}
