// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.card,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      side: BorderSide(color: AppColors.line),
    ),
    insetPadding: const EdgeInsets.all(24),
    titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    title: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
    content: SizedBox(width: 320, child: SingleChildScrollView(child: content)),
    actions: [
      Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: actions[i]),
          ],
        ],
      ),
    ],
  );
}
