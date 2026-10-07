// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

class CoreLogs extends StatelessWidget {
  const CoreLogs({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox.expand(
        child: SingleChildScrollView(
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
