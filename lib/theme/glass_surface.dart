// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The glass style for clickable foreground elements: a top-to-bottom light
/// gradient, a soft shadow, and a grey outline with a white edge inside it on
/// the top and bottom, both fading out toward the left and right ends.
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
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.innerBorder,
    required this.outerBorder,
    required this.shadow,
    required this.child,
  });

  final OutlinedBorder shape;
  final double? cornerWidth;
  final Color backgroundTop, backgroundBottom, innerBorder, shadow;
  final Color? outerBorder;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      shape: shape,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundTop, backgroundBottom],
      ),
      // Drop shadow: X 0, Y 1, blur 9, spread 0.
      shadows: [
        BoxShadow(color: shadow, blurRadius: 9, offset: const Offset(0, 1)),
      ],
    ),
    // The edge is painted over the content so hover highlights never leave
    // a seam along the curved border. Like the bottom navigation, a grey
    // outline sits outside the white edge on the top and bottom, fading out
    // over the rounded ends.
    child: CustomPaint(
      foregroundPainter: GlassEdgePainter(
        shape,
        cornerWidth: cornerWidth,
        innerBorder: innerBorder,
        outline: outerBorder,
        fadeOutlineEnds: true,
      ),
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
/// over the rounded left and right ends. In the dark theme it is a thinner,
/// warm line all the way around. Use as a `foregroundPainter`.
///
/// With [outline], a full 1 px border of that color is drawn on the very
/// outside and the white edge sits just inside it, so both stay visible.
class GlassEdgePainter extends CustomPainter {
  /// [cornerWidth] is how far the rounded ends reach in from each side;
  /// by default half the height, which fits pills and circles.
  const GlassEdgePainter(
    this.shape, {
    this.cornerWidth,
    this.outline,
    this.opacity = 1,
    this.fadeOutlineEnds = false,
    required this.innerBorder,
  });

  final OutlinedBorder shape;
  final double? cornerWidth;
  final Color? outline;
  final Color innerBorder;

  /// Fades both borders, for surfaces that animate in.
  final double opacity;

  /// Fades the [outline] out over the rounded ends like the white edge,
  /// leaving it only on the straight top and bottom.
  final bool fadeOutlineEnds;
  static const _width = 1.5;
  static const _darkWidth = 1.0;
  static const _outlineWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    var bounds = outer;
    var inset = 0.0;
    final dark = AppColors.isDark;
    final fade = size.width <= 0
        ? 0.5
        : ((cornerWidth ?? size.height / 2) / size.width).clamp(0.0, 0.5);
    if (outline case final color?) {
      final line = color.withValues(alpha: color.a * opacity);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineWidth
        ..color = line;
      if (fadeOutlineEnds && !dark) {
        paint.shader = _endFade(line, fade, bounds);
      }
      canvas.drawPath(_insetPath(outer, _outlineWidth / 2), paint);
      bounds = bounds.deflate(_outlineWidth);
      inset = _outlineWidth;
    }
    final edge = innerBorder.withValues(alpha: innerBorder.a * opacity);
    final width = dark ? _darkWidth : _width;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = edge;
    if (!dark) edgePaint.shader = _endFade(edge, fade, bounds);
    canvas.drawPath(_insetPath(outer, inset + width / 2), edgePaint);
  }

  /// The shape's outline moved [inset] inward. Rounded rectangles also get
  /// smaller corners, so lines stacked inside each other stay the same
  /// distance apart around the curve. Pills and circles do this by themselves.
  Path _insetPath(Rect outer, double inset) => switch (shape) {
    RoundedRectangleBorder(:final borderRadius) =>
      Path()..addRRect(
        borderRadius.resolve(TextDirection.ltr).toRRect(outer).deflate(inset),
      ),
    _ => shape.getOuterPath(outer.deflate(inset)),
  };

  static Shader _endFade(Color color, double fade, Rect bounds) =>
      LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color,
          color.withValues(alpha: 0),
        ],
        stops: [0, fade, 1 - fade, 1],
      ).createShader(bounds);

  @override
  bool shouldRepaint(GlassEdgePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.cornerWidth != cornerWidth ||
      oldDelegate.outline != outline ||
      oldDelegate.innerBorder != innerBorder ||
      oldDelegate.opacity != opacity ||
      oldDelegate.fadeOutlineEnds != fadeOutlineEnds;
}

/// The navigation panel's two borders as a reusable [OutlinedBorder]: the
/// outline in [side]'s color on the outside and the white glass edge just
/// inside it, with [radius] corners. Usable wherever Flutter takes a shape,
/// such as button themes and decorations.
class GlassBorder extends OutlinedBorder {
  const GlassBorder({this.radius = 12, required this.innerBorder, super.side});

  final double radius;
  final Color innerBorder;

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
      innerBorder: innerBorder,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  @override
  GlassBorder copyWith({BorderSide? side}) => GlassBorder(
    radius: radius,
    innerBorder: innerBorder,
    side: side ?? this.side,
  );

  @override
  ShapeBorder scale(double t) => GlassBorder(
    radius: radius * t,
    innerBorder: innerBorder,
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other is GlassBorder &&
      other.radius == radius &&
      other.innerBorder == innerBorder &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, innerBorder, side);
}
