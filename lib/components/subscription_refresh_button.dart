// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../l10n/l10n.dart';
import 'connection_edit_notification.dart';
import 'window_controls.dart';

class SubscriptionRefreshButton extends StatelessWidget {
  const SubscriptionRefreshButton({
    super.key,
    required this.connection,
    this.enabled = true,
    this.errorScope = ConnectionErrorScope.subscriptions,
  });

  final ConnectionController connection;
  final bool enabled;
  final ConnectionErrorScope errorScope;

  /// The bare action, for grouping inside an [IconIsland] with other actions.
  Widget action(BuildContext context) => IslandAction(
    tooltip: context.l10n.refreshSubscription,
    active: connection.refreshing,
    icon: Icons.refresh_rounded,
    onPressed:
        enabled && !connection.busy && connection.activeSubscriptionUrl != null
        ? () {
            if (!allowConnectionEdit(
              context,
              connection,
              context.l10n.disconnectRefresh,
            )) {
              return;
            }
            connection.refreshSubscription(
              connection.activeSubscriptionUrl!,
              errorScope: errorScope,
            );
          }
        : null,
  );

  @override
  Widget build(BuildContext context) => IconIsland(children: [action(context)]);
}
