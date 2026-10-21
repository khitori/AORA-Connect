// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../core/tunnel_engine.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

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
        ? context.l10n.stopping
        : busy || state == TunnelState.starting
        ? context.l10n.connecting
        : running
        ? context.l10n.disconnect
        : context.l10n.connect;
    return SizedBox(
      width: 184,
      height: 184,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1.25,
            colors: running
                ? [AppColors.accent, AppColors.accentDark]
                : [AppColors.card, AppColors.paperDark],
          ),
          border: Border.all(
            color: running ? AppColors.accentDark : AppColors.lineStrong,
          ),
          boxShadow: running
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
            foregroundColor: running ? AppColors.card : AppColors.muted600,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            side: BorderSide.none,
          ),
          onPressed: busy ? null : onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Icon(Icons.power_settings_new, size: 56),
                ),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, softWrap: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
