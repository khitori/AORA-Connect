// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The 48 px pill of the "Add subscription" button, without the glass edge,
/// filling the width it is given. Gray by default, for use on white surfaces
/// such as dialogs.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.multiplyColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Fill color; the glass dialogs' see-through gray when not given.
  final Color? color;

  /// Instead of [color]: multiplies what is behind the button by this color.
  /// Light areas behind it turn this color at full saturation and darker ones
  /// show through as a darker shade, so the button stays see-through without
  /// being washed out the way a translucent fill is.
  final Color? multiplyColor;

  /// Label color; the outlined buttons' ink when not given. A disabled button
  /// shows it faded.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fill = multiplyColor != null
        ? Colors.transparent
        : color ?? AppColors.glassControl;
    final button = SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: fill,
          disabledBackgroundColor: fill,
          foregroundColor: textColor,
          disabledForegroundColor: textColor?.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sectionPadding,
          ),
          shape: const StadiumBorder(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
      ),
    );
    final multiply = multiplyColor;
    if (multiply == null) return button;
    // Expanded, so the button keeps the full width (and its label stays
    // centered) instead of shrinking to its label inside the stack.
    return SizedBox(
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: const ShapeBorderClipper(shape: StadiumBorder()),
            child: _MultiplyFill(color: multiply),
          ),
          button,
        ],
      ),
    );
  }
}

/// Multiplies the backdrop by [color]. While its dialog is still animating
/// in or out, or fading under another dialog, it is a plain fill instead: the
/// dialog fades as one layer then, and a backdrop filter inside a fading
/// layer has nothing behind it to filter. On the light glass the two look
/// nearly the same.
class _MultiplyFill extends StatelessWidget {
  const _MultiplyFill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) return _multiply();
    final animation = route.animation!;
    final covered = route.secondaryAnimation!;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, covered]),
      builder: (_, _) => animation.isCompleted && covered.isDismissed
          ? _multiply()
          : ColoredBox(color: color),
    );
  }

  Widget _multiply() => BackdropFilter(
    filter: ColorFilter.mode(color, BlendMode.multiply),
    child: const SizedBox.expand(),
  );
}
