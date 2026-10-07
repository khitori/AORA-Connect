// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../core/tunnel_engine.dart';

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({
    super.key,
    required this.state,
    required this.busy,
    required this.onPressed,
  });
  final TunnelState state;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final running = state == TunnelState.running;
    final label = state == TunnelState.stopping
        ? 'Stopping…'
        : busy || state == TunnelState.starting
        ? 'Connecting…'
        : running
        ? 'Disconnect'
        : 'Connect';
    return SizedBox(
      width: 184,
      height: 184,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(24),
          foregroundColor: Colors.grey.shade400,
          backgroundColor: running
              ? Theme.of(context).colorScheme.tertiary
              : Colors.grey.shade100,
          side: BorderSide(
            color: Colors.grey.shade400,
            width: 1,
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              const Icon(Icons.power_settings_new, size: 56),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
