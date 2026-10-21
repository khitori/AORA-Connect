// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/connection_button.dart';
import '../components/server_selector.dart';
import '../controllers/connection_controller.dart';
import '../controllers/node_ping_controller.dart';
import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import '../l10n/l10n.dart';

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
                // Measure the real selector even before subscriptions restore,
                // so its arrival cannot recenter the Connect button. Keeping the
                // actual widget also respects theme and text scaling naturally.
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
                if (connection.selectedRequiresDifferentCore)
                  Text(
                    context.l10n.serverRequiresCore(
                      isolateTechnicalValue(
                        context.l10n,
                        connection.selected!.coreKind.label,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
                      ? context.l10n.vpnTun
                      : context.l10n.localProxy,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${connection.core.displayName}: ${connection.state.localizedLabel(context.l10n)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Reserve this line while connecting so a successful check
                // does not change the space centering the connection button.
                Tooltip(
                  message: connection.localizedProbeResult(context.l10n) ?? '',
                  child: Text(
                    connection.localizedProbeResult(context.l10n) ?? '',
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
