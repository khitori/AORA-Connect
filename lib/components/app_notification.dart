// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
        backgroundColor: AppColors.card,
        elevation: 3,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          side: BorderSide(color: AppColors.lineStrong),
        ),
        content: AppNotification(message: message, icon: icon),
        padding: const EdgeInsets.all(12),
        showCloseIcon: false,
        duration: const Duration(seconds: 4),
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
          tooltip: 'Close',
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(Icons.close_rounded, size: 20, color: AppColors.muted500),
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    ],
  );
}
