// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_surface.dart';
import 'window_controls.dart';

/// An icon button that opens a small glass bubble above it with a row of
/// actions, like a tooltip you can click into. The bubble pops in like the
/// dropdown menus (grows from 90% while blur, glass and borders fade in) and
/// closes on a tap outside it or once an action runs.
///
/// Opened as an overlay entry placed from the button's position, the same
/// way the dropdown menus open.
class GlassPopoverButton extends StatefulWidget {
  const GlassPopoverButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.actions,
  });

  final IconData icon;
  final String tooltip;

  /// Builds the bubble's buttons. Call `close` from an action to hide the
  /// bubble once it has run.
  final List<Widget> Function(BuildContext context, VoidCallback close) actions;

  @override
  State<GlassPopoverButton> createState() => _GlassPopoverButtonState();
}

class _GlassPopoverButtonState extends State<GlassPopoverButton>
    with SingleTickerProviderStateMixin {
  final _group = Object();
  OverlayEntry? _entry;
  bool _open = false;
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 120),
  );
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _show() {
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final anchor =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _remove();
    _open = true;
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        // Above the button, its end edges lined up.
        bottom: overlayBox.size.height - anchor.top + 6,
        left: rtl ? anchor.left : null,
        right: rtl ? null : overlayBox.size.width - anchor.right,
        child: _bubble(),
      ),
    );
    overlay.insert(_entry!);
    _animation.forward();
  }

  void _close() {
    if (!_open) return;
    _open = false;
    _entry?.markNeedsBuild();
    final entry = _entry;
    _animation.reverse().whenCompleteOrCancel(() {
      if (mounted && !_open && identical(entry, _entry)) _remove();
    });
  }

  @override
  void dispose() {
    _remove();
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  Widget _bubble() => TapRegion(
    groupId: _group,
    onTapOutside: (_) => _close(),
    child: IgnorePointer(
      ignoring: !_open,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value;
          final end = Directionality.of(this.context) == TextDirection.rtl
              ? Alignment.bottomLeft
              : Alignment.bottomRight;
          return Transform.translate(
            offset: Offset(0, 6 * (1 - t)),
            child: Transform.scale(
              scale: 0.9 + 0.1 * t,
              alignment: end,
              child: CustomPaint(
                foregroundPainter: GlassEdgePainter(
                  const StadiumBorder(),
                  outline: AppColors.popoverOuterBorder,
                  innerBorder: AppColors.popoverInnerBorder,
                  opacity: t,
                ),
                // The fade sits inside the blur: a blur inside a fading
                // layer has nothing behind it to blur.
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: StadiumBorder()),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
                    child: Opacity(opacity: t, child: child),
                  ),
                ),
              ),
            ),
          );
        },
        child: ColoredBox(
          // A light gray glass, so the white edge stands out even where the
          // bubble overlaps a white card.
          color: AppColors.popoverBackground,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, action)
                      in widget.actions(context, _close).indexed) ...[
                    if (index > 0) const SizedBox(width: 2),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // In the bubble's tap group, so tapping the button again closes the bubble
  // instead of closing and reopening it.
  @override
  // The top bar's round glass button, like Settings there.
  Widget build(BuildContext context) => TapRegion(
    groupId: _group,
    child: RoundIconButton(
      tooltip: widget.tooltip,
      icon: widget.icon,
      onPressed: () => _open ? _close() : _show(),
    ),
  );
}
