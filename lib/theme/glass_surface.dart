// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The glass style for clickable foreground elements: a top-to-bottom light
/// gradient, a soft shadow and a white edge on the top and bottom that fades
/// out toward the left and right ends.
///
/// Wrap any control in it and give it the control's [shape]; ink effects
/// (hover, press) of the child are clipped to that shape. For shapes other
/// than pills and circles, set [cornerWidth] to the corner radius so the white
/// edge fades over the corners only.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.shape = const StadiumBorder(),
    this.cornerWidth,
    required this.child,
  });

  final OutlinedBorder shape;
  final double? cornerWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      shape: shape,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.glassTop, AppColors.glassBottom],
      ),
      // Drop shadow: X 0, Y 1, blur 9, spread 0, black 10%.
      shadows: const [
        BoxShadow(
          color: AppColors.glassShadow,
          blurRadius: 9,
          offset: Offset(0, 1),
        ),
      ],
    ),
    // The edge is painted over the content so hover highlights never leave
    // a seam along the curved border.
    child: CustomPaint(
      foregroundPainter: GlassEdgePainter(shape, cornerWidth: cornerWidth),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ),
  );
}

/// The glass edge alone: white on the straight top and bottom, fading out
/// over the rounded left and right ends. Use as a `foregroundPainter`.
///
/// With [outline], a full 1 px border of that color is drawn on the very
/// outside and the white edge sits just inside it, so both stay visible.
class GlassEdgePainter extends CustomPainter {
  /// [cornerWidth] is how far the rounded ends reach in from each side;
  /// by default half the height, which fits pills and circles.
  const GlassEdgePainter(this.shape, {this.cornerWidth, this.outline});

  final OutlinedBorder shape;
  final double? cornerWidth;
  final Color? outline;
  static const _width = 1.5;
  static const _outlineWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    var bounds = Offset.zero & size;
    final fade = size.width <= 0
        ? 0.5
        : ((cornerWidth ?? size.height / 2) / size.width).clamp(0.0, 0.5);
    if (outline case final color?) {
      canvas.drawPath(
        shape.getOuterPath(bounds.deflate(_outlineWidth / 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _outlineWidth
          ..color = color,
      );
      bounds = bounds.deflate(_outlineWidth);
    }
    final edge = AppColors.glassEdge;
    canvas.drawPath(
      shape.getOuterPath(bounds.deflate(_width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..shader = LinearGradient(
          colors: [
            edge.withValues(alpha: 0),
            edge,
            edge,
            edge.withValues(alpha: 0),
          ],
          stops: [0, fade, 1 - fade, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(GlassEdgePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.cornerWidth != cornerWidth ||
      oldDelegate.outline != outline;
}

/// The navigation panel's two borders as a reusable [OutlinedBorder]: the
/// outline in [side]'s color on the outside and the white glass edge just
/// inside it, with [radius] corners. Usable wherever Flutter takes a shape,
/// such as button themes and decorations.
class GlassBorder extends OutlinedBorder {
  const GlassBorder({this.radius = 12, super.side});

  final double radius;

  RoundedRectangleBorder get _shape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    GlassEdgePainter(
      _shape,
      cornerWidth: radius,
      outline: side.style == BorderStyle.none ? null : side.color,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  @override
  GlassBorder copyWith({BorderSide? side}) =>
      GlassBorder(radius: radius, side: side ?? this.side);

  @override
  ShapeBorder scale(double t) =>
      GlassBorder(radius: radius * t, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      other is GlassBorder && other.radius == radius && other.side == side;

  @override
  int get hashCode => Object.hash(radius, side);
}
