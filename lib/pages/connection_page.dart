// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/connection_button.dart';
import '../components/core_mismatch_notice.dart';
import '../components/server_selector.dart';
import '../controllers/connection_controller.dart';
import '../controllers/node_ping_controller.dart';
import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import '../core/tunnel_engine.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

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
                ? context.l10n.serverRequiresCore(
                    isolateTechnicalValue(
                      context.l10n,
                      connection.selected!.coreKind.label,
                    ),
                  )
                : context.l10n.loadSubscriptionFirst,
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
                Visibility(
                  key: const ValueKey('connection-server-selector-slot'),
                  visible: connection.profiles.isNotEmpty,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: ServerSelector(
                    pings: pings,
                    profiles: connection.profiles,
                    selected: connection.selected,
                    onChanged: connection.canEdit
                        ? connection.selectProfile
                        : null,
                  ),
                ),
                if (connection.selected?.insecure == true)
                  Text(context.l10n.insecureProfile),
                if (connection.selectedRequiresDifferentCore) ...[
                  const SizedBox(height: 12),
                  CoreMismatchNotice(connection: connection),
                ],
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
                _ConnectionStatus(
                  parts: [
                    connection.mode == ConnectionMode.tun
                        ? 'TUN'
                        : context.l10n.modeProxyShort,
                    _capitalized(connection.state.localizedLabel(context.l10n)),
                    connection.core.label,
                  ],
                  // Red when disconnected, green when connected; while it
                  // is connecting or stopping, the usual text color.
                  stateColor: switch (connection.state) {
                    TunnelState.stopped =>
                      AppColors.connectionstatusDisconnected,
                    TunnelState.running => AppColors.connectionstatusConnected,
                    _ => null,
                  },
                ),
                const SizedBox(height: 8),
                // The connection check result; the line keeps its height
                // while empty so nothing moves when a result arrives.
                Tooltip(
                  message: connection.localizedProbeResult(context.l10n) ?? '',
                  child: Text(
                    connection.localizedProbeResult(context.l10n) ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.connectionstatusCheckText),
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

/// "disconnected" -> "Disconnected"; scripts without capitals are unchanged.
String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Mode, core and connection state in one rounded pill, divided by thin
/// lines: "TUN | Disconnected | sing-box". Shrinks rather than overflows
/// when a translation is long.
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.parts, this.stateColor});

  final List<String> parts;

  /// Color of the middle part (the state); the usual text color when null.
  final Color? stateColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.connectionstatusText);
    return Center(
      child: DecoratedBox(
        key: const ValueKey('connection-status'),
        decoration: ShapeDecoration(
          color: AppColors.connectionstatusBackground,
          shape: const StadiumBorder(),
        ),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, part) in parts.indexed) ...[
                    if (index > 0)
                      Container(
                        width: 1,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: AppColors.connectionstatusSeparator,
                      ),
                    Text(
                      part,
                      maxLines: 1,
                      style: index == 1 && stateColor != null
                          ? style?.copyWith(color: stateColor)
                          : style,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
