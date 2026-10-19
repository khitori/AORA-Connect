// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'app_action_button.dart';

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
            child: AppActionButton(
              onPressed: onValidate,
              icon: Icons.fact_check_outlined,
              label: 'Validate',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppActionButton(
              onPressed: onTest,
              icon: Icons.network_check_rounded,
              label: 'Test connection',
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      AppActionButton(
        onPressed: onCopy,
        icon: Icons.copy_rounded,
        label: 'Copy diagnostics',
      ),
    ],
  );
}
