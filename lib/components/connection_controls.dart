// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

class ConnectionControls extends StatelessWidget {
  const ConnectionControls({super.key, this.onValidate, this.onTest});
  final VoidCallback? onValidate;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      OutlinedButton(onPressed: onValidate, child: const Text('Validate')),
      OutlinedButton(onPressed: onTest, child: const Text('Test connection')),
    ],
  );
}
