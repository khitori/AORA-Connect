// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../core/tunnel_engine.dart';
import '../l10n/l10n.dart';
import 'app_notification.dart';

bool allowConnectionEdit(
  BuildContext context,
  ConnectionController connection,
  String message,
) {
  if (connection.canEdit) return true;
  AppNotification.show(
    context,
    connection.state == TunnelState.stopped
        ? context.l10n.waitCurrentOperation
        : message,
  );
  return false;
}

class DisabledControlNotice extends StatelessWidget {
  const DisabledControlNotice({
    super.key,
    required this.disabled,
    required this.onTap,
    required this.child,
    this.label,
  });
  final bool disabled;
  final VoidCallback onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: disabled ? label : null,
    onTap: disabled ? onTap : null,
    child: ExcludeSemantics(
      excluding: disabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: disabled ? onTap : null,
        child: ExcludeFocus(
          excluding: disabled,
          child: AbsorbPointer(absorbing: disabled, child: child),
        ),
      ),
    ),
  );
}
