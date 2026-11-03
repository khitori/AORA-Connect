// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A softly red-tinted card, rounded like the boxes around it, with a warning
/// icon, a short message and an optional small red action button.
class WarningNotice extends StatelessWidget {
  const WarningNotice({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;

  /// Keep it short (one or two words): long labels squeeze the message into
  /// several lines in some languages.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Color.alphaBlend(
        AppColors.accent.withValues(alpha: 0.08),
        AppColors.card,
      ),
      borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
    ),
    child: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppTheme.contentPadding,
        10,
        actionLabel == null ? AppTheme.contentPadding : 10,
        10,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: AppColors.accentDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(width: 12),
              SizedBox(
                height: 32,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: onAction,
                  child: Text(label),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
