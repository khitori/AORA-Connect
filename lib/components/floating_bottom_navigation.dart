// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';

const _itemHeight = 58.0;
const _motion = Duration(milliseconds: 320);
const _curve = Curves.easeOutCubic;

class FloatingBottomNavigation<T> extends StatelessWidget {
  const FloatingBottomNavigation({
    super.key,
    required this.selected,
    required this.destinations,
    required this.onSelected,
  });

  final T selected;
  final List<FloatingNavigationDestination<T>> destinations;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final index = destinations.indexWhere((item) => item.value == selected);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          shadows: [
            BoxShadow(
              color: AppColors.islandShadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // Grey outline plus the white glass edge, drawn over the content.
        // Both fade out over the rounded ends.
        child: CustomPaint(
          foregroundPainter: GlassEdgePainter(
            const StadiumBorder(),
            outline: AppColors.lineStrong,
            fadeOutlineEnds: true,
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: StadiumBorder()),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColoredBox(
                color: AppColors.glass.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final count = destinations.length;
                      final width = constraints.maxWidth / count;
                      return SizedBox(
                        height: _itemHeight,
                        child: Stack(
                          children: [
                            // The glass highlight glides to the selected page.
                            // It fades out on pages without a tab (Settings).
                            AnimatedPositionedDirectional(
                              duration: _motion,
                              curve: _curve,
                              top: 0,
                              bottom: 0,
                              width: width,
                              start: (index < 0 ? 0 : index) * width,
                              child: AnimatedOpacity(
                                duration: _motion,
                                curve: _curve,
                                opacity: index < 0 ? 0 : 1,
                                child: const GlassSurface(
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                for (var i = 0; i < count; i++)
                                  Expanded(
                                    child: _NavigationItem<T>(
                                      destination: destinations[i],
                                      selected: i == index,
                                      onTap: () =>
                                          onSelected(destinations[i].value),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

class FloatingNavigationDestination<T> {
  const FloatingNavigationDestination(
    this.value,
    this.label,
    this.icon, {
    this.id,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? id;
}

class _NavigationItem<T> extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavigationDestination<T> destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey(
      'bottom-nav-${destination.id ?? destination.label.toLowerCase()}',
    ),
    // Transparent: the sliding glass highlight shows the selected page.
    type: MaterialType.transparency,
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    // No ripple or pressed tint: the gliding glass is the click feedback, and
    // a grey flash before it arrived looked strange. Unselected tabs keep the
    // hover tint; the selected one never tints its glass.
    child: InkWell(
      // A new InkWell when selection changes: the old one would keep the
      // hover highlight it already drew while the cursor stays still.
      key: ValueKey(selected),
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            !selected &&
                (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused))
            ? AppTheme.controlOverlayColor.resolve({WidgetState.hovered})
            : Colors.transparent,
      ),
      child: Semantics(
        selected: selected,
        button: true,
        child: SizedBox(
          height: _itemHeight,
          // Color and glow fade in together with the moving highlight.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: selected ? 1 : 0),
            duration: _motion,
            curve: _curve,
            builder: (context, on, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  destination.icon,
                  size: 22,
                  color: Color.lerp(AppColors.muted500, AppColors.accent, on),
                  shadows: [
                    Shadow(
                      color: AppColors.accent.withValues(alpha: 0.55 * on),
                      blurRadius: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Color.lerp(
                          AppColors.muted500,
                          AppColors.ink,
                          on,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
