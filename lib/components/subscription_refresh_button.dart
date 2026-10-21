// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../l10n/l10n.dart';
import 'compact_outline_icon_button.dart';
import 'connection_edit_notification.dart';

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

  @override
  Widget build(BuildContext context) => CompactOutlineIconButton(
    tooltip: context.l10n.refreshSubscription,
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
}
