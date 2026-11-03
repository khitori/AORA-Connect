// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../core/core_kind.dart';
import '../l10n/l10n.dart';
import 'connection_edit_notification.dart';
import 'warning_notice.dart';

/// Shown under the server panel when the selected server needs the other
/// core: the red warning card with a button that switches to that core right
/// here, as the Settings select would.
class CoreMismatchNotice extends StatelessWidget {
  const CoreMismatchNotice({super.key, required this.connection});

  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    final core = connection.selected!.coreKind;
    // A non-breaking hyphen keeps "sing-box" on one line when the text wraps.
    final name = isolateTechnicalValue(
      context.l10n,
      core.label.replaceAll('-', '‑'),
    );
    return WarningNotice(
      message: context.l10n.serverNeedsCore(name),
      actionLabel: context.l10n.switchCore,
      onAction: connection.supportsCore(core)
          ? () {
              if (allowConnectionEdit(
                context,
                connection,
                context.l10n.changingCore,
              )) {
                connection.setCore(core);
              }
            }
          : null,
    );
  }
}
