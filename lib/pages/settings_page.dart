// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_expansion_card.dart';
import '../components/app_notification.dart';
import '../components/app_select.dart';
import '../components/app_toggle.dart';
import '../components/connection_controls.dart';
import '../components/core_mismatch_notice.dart';
import '../components/connection_edit_notification.dart';
import '../components/core_logs.dart';
import '../components/language_settings.dart';
import '../components/section_row_bleed.dart';
import '../components/settings_label.dart';
import '../components/updates_panel.dart';
import '../components/windows_startup_settings.dart';
import '../controllers/connection_controller.dart';
import '../controllers/windows_startup_controller.dart';
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
    this.updates,
    this.onInstallUpdate,
    this.startup,
  });
  final ConnectionController connection;
  final UpdateController? updates;
  final Future<void> Function()? onInstallUpdate;
  final WindowsStartupController? startup;

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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
    children: [
      const LanguageSettings(),
      const SizedBox(height: 12),
      if (Platform.isWindows && startup != null) ...[
        WindowsStartupSettings(controller: startup!),
        const SizedBox(height: 12),
      ],
      AppExpansionCard(
        title: context.l10n.core,
        storageId: 'core',
        subtitle: connection.core.displayName,
        icon: Icons.memory_rounded,
        children: [
          SettingsLabel(context.l10n.networkingCore),
          const SizedBox(height: AppTheme.sectionLabelGap),
          _editControl(
            context,
            context.l10n.changingCore,
            AppSelect<CoreKind>(
              plain: true,
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
          // The main page's notice, with its one-tap switch.
          if (connection.selectedRequiresDifferentCore) ...[
            const SizedBox(height: AppTheme.sectionGap),
            // As wide as the select above, which reaches out the same way.
            SectionRowBleed(child: CoreMismatchNotice(connection: connection)),
          ],
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: context.l10n.connection,
        storageId: 'connection',
        subtitle: connection.mode == ConnectionMode.tun
            ? context.l10n.vpnTun
            : context.l10n.localProxy,
        icon: Icons.lan_rounded,
        children: [
          SettingsLabel(context.l10n.connectionMode),
          const SizedBox(height: AppTheme.sectionLabelGap),
          _editControl(
            context,
            context.l10n.changingMode,
            AppSelect<ConnectionMode>(
              plain: true,
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
          const SizedBox(height: AppTheme.sectionGap),
          Text(context.l10n.connectionModeHelp),
          const SizedBox(height: AppTheme.sectionGap),
          _editControl(
            context,
            context.l10n.changingKillSwitch,
            SectionRowBleed(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sectionPadding,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.sectionRowRadius,
                    ),
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
            ),
            available: connection.killSwitchAvailable,
          ),
        ],
      ),
      const SizedBox(height: 12),
      AppExpansionCard(
        title: 'DNS',
        subtitle: connection.dnsProvider.label,
        icon: Icons.dns_rounded,
        children: [
          SettingsLabel(context.l10n.dnsServer),
          const SizedBox(height: AppTheme.sectionLabelGap),
          _editControl(
            context,
            context.l10n.changingDns,
            AppSelect<DnsProvider>(
              plain: true,
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
          const SizedBox(height: AppTheme.sectionGap),
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
          SettingsLabel(context.l10n.serverPingMethod),
          const SizedBox(height: AppTheme.sectionLabelGap),
          AppSelect<PingType>(
            plain: true,
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
          const SizedBox(height: AppTheme.sectionGap),
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
      AppExpansionCard(
        title: context.l10n.diagnostics,
        storageId: 'diagnostics',
        subtitle: context.l10n.diagnosticsSubtitle,
        icon: Icons.tune_rounded,
        children: [
          SettingsLabel(context.l10n.diagnosticToolsLabel),
          const SizedBox(height: AppTheme.sectionLabelGap),
          ConnectionControls(
            onValidate: connection.canValidate ? connection.validate : null,
            onTest: connection.canTest ? connection.testConnection : null,
            onCopy: () => _copyDiagnostics(context),
          ),
          const SizedBox(height: AppTheme.sectionGap),
          SettingsLabel(context.l10n.coreLogs),
          const SizedBox(height: AppTheme.sectionLabelGap),
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
          const SizedBox(height: AppTheme.sectionGap),
          Text(context.l10n.aboutClient),
          const SizedBox(height: AppTheme.sectionGap),
          Text(context.l10n.license),
          const SizedBox(height: AppTheme.sectionGap),
          Text(context.l10n.coresLicense),
        ],
      ),
    ],
  );
}
