// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../controllers/node_ping_controller.dart';
import '../l10n/l10n.dart';
import '../profiles/server_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'compact_outline_icon_button.dart';
import 'server_node_details.dart';
import 'subscription_refresh_button.dart';

class ServerSelector extends StatefulWidget {
  const ServerSelector({
    super.key,
    required this.profiles,
    required this.selected,
    required this.onChanged,
    required this.pings,
  });
  final List<ServerProfile> profiles;
  final ServerProfile? selected;
  final ValueChanged<ServerProfile>? onChanged;
  final NodePingController pings;

  @override
  State<ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends State<ServerSelector> {
  final _menuGroup = Object();
  bool _menuOpen = false;
  NodePingController get pings => widget.pings;
  List<ServerProfile> get profiles => widget.profiles;
  ServerProfile? get selected => widget.selected;
  ValueChanged<ServerProfile>? get onChanged => widget.onChanged;

  String get _status {
    if (pings.busy) return '${pings.completed}/${pings.checkingCount}';
    final time = pings.lastCheckedAt;
    if (time == null) return context.l10n.notChecked;
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return context.l10n.lastCheck(hours, minutes);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: ListenableBuilder(
      listenable: pings,
      builder: (context, _) {
        final provider = pings.connection.activeProviderName;
        return TapRegion(
          groupId: _menuGroup,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppTheme.controlRadius),
              border: Border.all(color: AppColors.lineStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: provider,
                          child: Text(
                            provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: pings.busy
                            ? context.l10n.checkServers
                            : pings.lastCheckedAt?.toLocal().toString() ??
                                  context.l10n.noCompletedCheck,
                        child: Text(
                          _status,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.muted500,
                                fontSize: 11,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SubscriptionRefreshButton(
                        connection: pings.connection,
                        enabled: !pings.busy,
                        errorScope: ConnectionErrorScope.connection,
                      ),
                      const SizedBox(width: 6),
                      CompactOutlineIconButton(
                        tooltip: pings.busy
                            ? context.l10n.cancelChecks
                            : '${_menuOpen ? context.l10n.checkAllServers : context.l10n.checkSelectedServer} · ${pings.connection.pingType.localizedLabel(context.l10n)}',
                        icon: pings.busy
                            ? Icons.close_rounded
                            : Icons.network_check_rounded,
                        onPressed: pings.busy
                            ? pings.cancel
                            : pings.canCheck
                            ? _menuOpen
                                  ? pings.checkAll
                                  : selected != null
                                  ? pings.checkSelected
                                  : null
                            : null,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: AppColors.line),
                AppSelect<ServerProfile>(
                  tapRegionGroupId: _menuGroup,
                  onOpenChanged: (open) => setState(() => _menuOpen = open),
                  value: selected,
                  height: 56,
                  readOnly: onChanged == null,
                  showOutline: false,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppTheme.controlRadius - 1),
                  ),
                  items: [
                    for (final profile in profiles)
                      DropdownMenuItem(
                        value: profile,
                        child: ServerNodeDetails(
                          profile: profile,
                          pings: pings,
                        ),
                      ),
                  ],
                  horizontalPadding: 16,
                  selectedChild: selected == null
                      ? null
                      : ServerNodeDetails(
                          profile: selected!,
                          pings: pings,
                          compact: true,
                        ),
                  onChanged: onChanged == null
                      ? null
                      : (profile) {
                          if (profile != null) onChanged!(profile);
                        },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
