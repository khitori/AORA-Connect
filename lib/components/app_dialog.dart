// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';

/// Padding around a dialog's content, the same on every side.
const _padding = 18.0;

/// Width of a dialog's content. The title is held to the same width (less
/// its extra 8 px inset on each side), so a long subtext wraps instead of
/// widening the dialog.
const _contentWidth = 288.0;

/// Space above and below the content, between the title and the actions.
const _contentGap = 24.0;

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppTheme.sectionRadius)),
);

/// A dialog in the bottom navigation's glass: translucent over a blur of what
/// is behind it, a full grey outline, and the white glass edge on the top and
/// bottom only. It has the section cards' corners, [_padding] on every side,
/// and [_contentGap] between its title, content and actions.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.stackActions = false,
    this.subtitle,
  });

  final String title;

  /// A short line under the title.
  final String? subtitle;
  final Widget content;
  final List<Widget> actions;

  /// Puts the actions in a full-width column, in the given order, instead of
  /// side by side.
  final bool stackActions;

  Widget _actions() => stackActions
      ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.sectionButtonGap),
              actions[i],
            ],
          ],
        )
      : Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.sectionButtonGap),
              Expanded(child: actions[i]),
            ],
          ],
        );

  @override
  Widget build(BuildContext context) {
    // Opened with [showAppDialog], the route adds no fade of its own; the
    // dialog fades in itself, inside the blur. A blur inside a fading layer
    // has nothing behind it to blur, so it would only appear at the end.
    final route = ModalRoute.of(context);
    final animation = route?.animation ?? kAlwaysCompleteAnimation;
    // Runs while another dialog opens on top: this one fades away the same
    // way, so two glass dialogs never show through each other.
    final covered = route?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: _shape,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: _contentWidth + 2 * _padding,
        child: AnimatedBuilder(
          animation: Listenable.merge([animation, covered]),
          // Pops in like the dropdown menus: grows from 90% while the blur,
          // glass and borders fade in together.
          builder: (context, child) {
            final t =
                Curves.easeOutCubic.transform(animation.value) *
                (1 - Curves.easeOutCubic.transform(covered.value));
            return Transform.scale(
              scale: 0.9 + 0.1 * t,
              // The outline is drawn in full; the white edge fades out over
              // the rounded corners, leaving it on the top and bottom only.
              child: CustomPaint(
                foregroundPainter: GlassEdgePainter(
                  _shape,
                  cornerWidth: AppTheme.sectionRadius,
                  outline: AppColors.dialogOuterBorder,
                  innerBorder: AppColors.dialogInnerBorder,
                  opacity: t,
                ),
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: _shape),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
                    child: Opacity(opacity: t, child: child),
                  ),
                ),
              ),
            );
          },
          child: ColoredBox(
            color: AppColors.dialogBackground,
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The title text sits 8 px further in than the content.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dialogTitle,
                              ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.dialogSubtitle,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: _contentGap),
                  Flexible(child: SingleChildScrollView(child: content)),
                  SizedBox(height: stackActions ? _contentGap : _padding),
                  _actions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens an [AppDialog] (built by [builder]) without the usual route fade,
/// which would hide its blur until the fade ends; the dialog animates in by
/// itself instead. Taps outside close it, and nothing behind it is dimmed.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, _, _) => builder(context),
  transitionBuilder: (_, _, _, child) => child,
);
