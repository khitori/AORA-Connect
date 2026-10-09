// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

class SubscriptionInput extends StatelessWidget {
  const SubscriptionInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onLoad,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onLoad;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Subscription or server link...',
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onLoad, child: const Text('Add')),
      ],
    ),
  );
}
