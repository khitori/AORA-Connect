// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../core/tunnel_engine.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

const _size = 184.0;
const _transition = Duration(milliseconds: 320);

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
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Surface: soft off-white glass when idle, red when connected. The
          // key makes a theme switch instant instead of fading.
          AnimatedContainer(
            key: ValueKey(AppColors.isDark),
            duration: _transition,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.4),
                radius: 1.25,
                colors: running
                    ? [
                        AppColors.connectbuttonBackgroundOnCenter,
                        AppColors.connectbuttonBackgroundOnEdge,
                      ]
                    : [
                        AppColors.connectbuttonBackground,
                        AppColors.connectbuttonBackground,
                      ],
              ),
              // Connected: an even red glow all around, like the glowing
              // icons. Faded in and out by AnimatedContainer.
              boxShadow: [
                BoxShadow(
                  color: running
                      ? AppColors.connectbuttonGlowOn
                      : AppColors.connectbuttonGlowOn.withValues(alpha: 0),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Inner shade and light that give the surface its glass depth,
          // tuned for the off-white idle surface and the red connected one.
          IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: running ? 1 : 0),
              duration: _transition,
              curve: Curves.easeOutCubic,
              builder: (context, connected, _) =>
                  CustomPaint(painter: _GlassPainter(connected)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(24),
              foregroundColor: running
                  ? AppColors.connectbuttonIconOn
                  : AppColors.connectbuttonIcon,
              disabledForegroundColor: AppColors.connectbuttonTextBusy,
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
                        ? SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.connectbuttonSpinner,
                            ),
                          )
                        : const Icon(
                            Icons.power_settings_new_rounded,
                            size: 44,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // The outline is drawn last, over the glass and hover, so no light
          // line can appear between them on the curved edge.
          IgnorePointer(
            child: AnimatedContainer(
              key: ValueKey(AppColors.isDark),
              duration: _transition,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: running
                      ? AppColors.connectbuttonBorderOn
                      : AppColors.connectbuttonBorder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft inner shadows: shade along the left edge and light along the
/// lower-right edge, clipped to the circle. [connected] blends from the
/// idle (0) to the red (1) colors.
class _GlassPainter extends CustomPainter {
  const _GlassPainter(this.connected);

  final double connected;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Offset.zero & size;
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    void inner(Color color, Offset shift, double blur) {
      final edge = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(circle.inflate(blur * 4))
        ..addOval(circle.shift(shift));
      canvas.drawPath(
        edge,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    inner(
      Color.lerp(
        AppColors.connectbuttonInnerShade,
        AppColors.connectbuttonInnerShadeOn,
        connected,
      )!,
      const Offset(8, 3),
      11,
    );
    inner(
      Color.lerp(
        AppColors.connectbuttonInnerLight,
        AppColors.connectbuttonInnerLightOn,
        connected,
      )!,
      const Offset(-7, -8),
      9,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) =>
      oldDelegate.connected != connected;
}
