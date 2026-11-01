// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';

/// Height of an island; its actions are smaller circles inside it.
const _height = 32.0;
const _innerSize = 24.0;
const _inset = (_height - _innerSize) / 2;

/// A glass pill ([GlassSurface]) that groups related [IslandAction]s.
/// With one action it is a circle.
class IconIsland extends StatelessWidget {
  const IconIsland({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height,
    child: GlassSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _inset),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// One icon action inside an [IconIsland]; only its own circle highlights.
class IslandAction extends StatelessWidget {
  const IslandAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconSize = 18,
    this.active = false,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double iconSize;

  /// The action is working right now (for example refreshing); its icon uses
  /// the active color with a glow, even if it cannot be pressed meanwhile.
  final bool active;

  /// The action's page is open (for example Settings); its icon is red with a
  /// soft glow, like the selected tab in the bottom navigation.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Working and selected icons both light up with a glow in their color.
    final base = onPressed == null && !active
        ? AppColors.muted300
        : AppColors.muted700;
    final lit = selected ? AppColors.accent : AppColors.active;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: _innerSize,
        child: InkWell(
          customBorder: const CircleBorder(),
          overlayColor: AppTheme.controlOverlayColor,
          onTap: onPressed,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: selected || active ? 1 : 0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, on, _) => Icon(
              icon,
              size: iconSize,
              color: Color.lerp(base, lit, on),
              shadows: [
                // Softer than the 22 px navigation icons' glow (0.55, blur
                // 10), so it looks equally strong on these 18 px icons.
                Shadow(color: lit.withValues(alpha: 0.4 * on), blurRadius: 7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single action in its own round island, like the top bar's Settings.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconIsland(
    children: [
      IslandAction(
        tooltip: tooltip,
        icon: icon,
        onPressed: onPressed,
        selected: selected,
      ),
    ],
  );
}

/// Hide and Close grouped in one island.
class WindowControls extends StatelessWidget {
  const WindowControls({
    super.key,
    required this.hideTooltip,
    required this.closeTooltip,
    required this.onHide,
    required this.onClose,
  });

  final String hideTooltip;
  final String closeTooltip;
  final VoidCallback? onHide;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => IconIsland(
    children: [
      IslandAction(
        tooltip: hideTooltip,
        icon: Icons.keyboard_arrow_down_rounded,
        iconSize: 20,
        onPressed: onHide,
      ),
      IslandAction(
        tooltip: closeTooltip,
        icon: Icons.close_rounded,
        onPressed: onClose,
      ),
    ],
  );
}

/// A text action in its own island, built exactly like the Settings and
/// Refresh islands: the same glass, 32 px height and 4 px inset, with an
/// inner pill that highlights on hover like the islands' inner circles.
class IslandButton extends StatelessWidget {
  const IslandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? AppColors.muted300 : AppColors.muted700;
    final button = IconIsland(
      children: [
        SizedBox(
          height: _innerSize,
          child: InkWell(
            customBorder: const StadiumBorder(),
            overlayColor: AppTheme.controlOverlayColor,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
