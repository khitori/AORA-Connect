// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'window_controls.dart';

/// Diagnostics actions as wide islands, like the top bar's buttons: Check and
/// Test share a line, Copy diagnostics takes the whole line below.
class ConnectionControls extends StatelessWidget {
  const ConnectionControls({
    super.key,
    this.onValidate,
    this.onTest,
    this.onCopy,
  });
  final VoidCallback? onValidate;
  final VoidCallback? onTest;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: IslandButton(
              expanded: true,
              onPressed: onValidate,
              icon: Icons.fact_check_rounded,
              label: context.l10n.validate,
            ),
          ),
          const SizedBox(width: AppTheme.sectionButtonGap),
          Expanded(
            child: IslandButton(
              expanded: true,
              onPressed: onTest,
              icon: Icons.network_check_rounded,
              label: context.l10n.testConnection,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppTheme.sectionButtonGap),
      IslandButton(
        expanded: true,
        onPressed: onCopy,
        icon: Icons.copy_rounded,
        label: context.l10n.copyDiagnostics,
      ),
    ],
  );
}
