// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';

class AppNotification extends StatelessWidget {
  const AppNotification({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  final String message;
  final IconData icon;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // The snack bar itself is clear; the glass is drawn by the content.
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
        content: _GlassNotification(
          child: AppNotification(message: message, icon: icon),
        ),
        padding: EdgeInsets.zero,
        showCloseIcon: false,
        duration: const Duration(seconds: 4),
      ),
      // No fade of its own while appearing: the notification fades in itself,
      // inside the blur. A blur inside a fading layer has nothing behind it to
      // blur, so it would only appear once the fade ended.
      snackBarAnimationStyle: const AnimationStyle(
        duration: Duration.zero,
        reverseDuration: Duration(milliseconds: 150),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.muted500),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.ink),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          tooltip: context.l10n.close,
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ).copyWith(overlayColor: AppTheme.controlOverlayColor),
          icon: Icon(Icons.close_rounded, size: 20, color: AppColors.muted500),
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    ],
  );
}

const _radius = BorderRadius.all(Radius.circular(AppTheme.sectionRowRadius));
const _shape = RoundedRectangleBorder(borderRadius: _radius);

/// The bottom navigation's glass around a notification: translucent white
/// over a blur, a grey outline and the white edge on the top and bottom,
/// fading over the rounded corners. It pops in like the dropdown menus,
/// growing from 90% while blur, glass and borders fade in together.
class _GlassNotification extends StatefulWidget {
  const _GlassNotification({required this.child});

  final Widget child;

  @override
  State<_GlassNotification> createState() => _GlassNotificationState();
}

class _GlassNotificationState extends State<_GlassNotification>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) {
      final t = _curve.value;
      return Transform.scale(
        scale: 0.9 + 0.1 * t,
        child: CustomPaint(
          foregroundPainter: GlassEdgePainter(
            _shape,
            cornerWidth: AppTheme.sectionRowRadius,
            outline: AppColors.lineStrong,
            opacity: t,
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
              child: Opacity(opacity: t, child: child),
            ),
          ),
        ),
      );
    },
    child: ColoredBox(
      color: AppColors.glass.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTheme.contentPadding,
          8,
          8,
          8,
        ),
        child: widget.child,
      ),
    ),
  );
}
