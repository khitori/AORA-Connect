// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_surface.dart';

const _motion = Duration(milliseconds: 180);
const _curve = Curves.easeOutCubic;

/// A switch in the app's glass style: a raised glass knob in a sunken track.
/// Off, the track is a light groove; on, it is red with a soft red glow.
class AppToggle extends StatefulWidget {
  static const compactVerticalPadding = 5.0;

  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final bool compact;

  @override
  State<AppToggle> createState() => _AppToggleState();
}

class _AppToggleState extends State<AppToggle> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final on = widget.value;
    // Groove in both states: darker at the top, as if light falls into a slot.
    const colors = [AppColors.toggleGrooveTop, AppColors.toggleGrooveBottom];
    final tint = enabled && (_hovered || _focused || _pressed)
        ? AppColors.ink.withValues(alpha: _pressed ? 0.12 : 0.06)
        : null;
    void toggle() => widget.onChanged?.call(!on);
    return Semantics(
      label: widget.semanticLabel,
      toggled: on,
      enabled: enabled,
      onTap: enabled ? toggle : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? toggle : null,
            customBorder: const StadiumBorder(),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 2,
                vertical: widget.compact
                    ? AppToggle.compactVerticalPadding
                    : 11,
              ),
              child: AnimatedOpacity(
                duration: _motion,
                opacity: enabled ? 1 : 0.45,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: on && enabled ? 1 : 0),
                  duration: _motion,
                  curve: _curve,
                  builder: (context, lit, _) => SizedBox(
                    width: 44,
                    height: 26,
                    child: Stack(
                      children: [
                        // The groove.
                        AnimatedContainer(
                          duration: _motion,
                          curve: _curve,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                for (final color in colors)
                                  tint == null
                                      ? color
                                      : Color.alphaBlend(tint, color),
                              ],
                            ),
                            border: Border.all(color: AppColors.line),
                          ),
                        ),
                        // The lit knob's hard glare across the groove,
                        // strongest at the knob and fading away from it.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.centerEnd,
                                  end: AlignmentDirectional.centerStart,
                                  stops: const [0, 0.35, 1],
                                  colors: [
                                    AppColors.accent.withValues(
                                      alpha: 0.5 * lit,
                                    ),
                                    AppColors.accent.withValues(
                                      alpha: 0.22 * lit,
                                    ),
                                    AppColors.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The knob, inside the 1 px outline and 3 px gap.
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AnimatedAlign(
                              duration: _motion,
                              curve: _curve,
                              alignment: on
                                  ? AlignmentDirectional.centerEnd
                                  : AlignmentDirectional.centerStart,
                              child: _Knob(lit: lit),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised glass knob. Off ([lit] 0) it is the islands' white glass; on
/// ([lit] 1) it is red glass with a soft red glow, like the active icons.
class _Knob extends StatelessWidget {
  const _Knob({required this.lit});

  final double lit;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    key: const ValueKey('app-toggle-knob'),
    dimension: 18,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // Lit like the white glass: deeper at the top, lighter below.
            Color.lerp(AppColors.glassTop, AppColors.accentDark, lit)!,
            Color.lerp(AppColors.glassBottom, AppColors.accent, lit)!,
          ],
        ),
        shadows: [
          BoxShadow.lerp(
            const BoxShadow(
              color: AppColors.glassShadow,
              blurRadius: 9,
              offset: Offset(0, 1),
            ),
            // A deep glow that reaches into the groove.
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.7),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            lit,
          )!,
        ],
      ),
      child: const CustomPaint(
        foregroundPainter: GlassEdgePainter(CircleBorder()),
      ),
    ),
  );
}
