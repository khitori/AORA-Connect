// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CoreLogs extends StatelessWidget {
  const CoreLogs({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      ),
      child: SizedBox.expand(
        child: SingleChildScrollView(
          key: const PageStorageKey('core-logs-scroll'),
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            lines.isEmpty ? 'No logs yet.' : lines.join('\n'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ),
    ),
  );
}
