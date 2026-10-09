// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../profiles/server_profile.dart';
import '../controllers/node_ping_controller.dart';
import '../controllers/connection_controller.dart';
import '../core/ping_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_select.dart';
import 'compact_outline_icon_button.dart';
import 'server_node_details.dart';

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
    if (time == null) return 'Not checked';
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return 'Last check $hours:$minutes';
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
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
                            ? 'Checking servers'
                            : pings.lastCheckedAt?.toLocal().toString() ??
                                  'No completed server check yet',
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
                      CompactOutlineIconButton(
                        tooltip: 'Refresh selected subscription',
                        icon: Icons.refresh_rounded,
                        onPressed:
                            pings.connection.canEdit &&
                                !pings.busy &&
                                pings.connection.activeSubscriptionUrl != null
                            ? () => pings.connection.refreshSubscription(
                                pings.connection.activeSubscriptionUrl!,
                                errorScope: ConnectionErrorScope.connection,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      CompactOutlineIconButton(
                        tooltip: pings.busy
                            ? 'Cancel server checks'
                            : '${_menuOpen ? 'Check all servers' : 'Check selected server'} · ${pings.connection.pingType.label}',
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
                  // Leave room for the enclosing card's 1px outline so the
                  // selector's bottom curve aligns with the card's inner edge.
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
