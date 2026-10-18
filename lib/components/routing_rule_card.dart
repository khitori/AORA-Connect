// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../routing/routing_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_toggle.dart';
import 'installed_application_picker.dart';

class RoutingRuleCard extends StatelessWidget {
  const RoutingRuleCard({
    super.key,
    required this.rule,
    this.application,
    this.onEnabledChanged,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
  });

  final RoutingRule rule;
  final InstalledApplication? application;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  IconData get _fallbackIcon => switch (rule.match) {
    RoutingMatch.application => Icons.apps_rounded,
    RoutingMatch.ip => Icons.lan_outlined,
    _ => Icons.language_rounded,
  };

  Widget _action({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      foregroundColor: AppColors.muted500,
      disabledForegroundColor: AppColors.lineStrong,
      minimumSize: const Size(36, 36),
      maximumSize: const Size(36, 36),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = application?.label ?? rule.target;
    final subtitle = application != null ? rule.target : rule.match.label;
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: application?.icon == null
                      ? Icon(_fallbackIcon, size: 24, color: AppColors.muted500)
                      : Image.memory(
                          application!.icon!,
                          width: 32,
                          height: 32,
                          errorBuilder: (_, _, _) => Icon(
                            _fallbackIcon,
                            size: 24,
                            color: AppColors.muted500,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: title,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: rule.enabled
                                    ? AppColors.ink
                                    : AppColors.muted500,
                              ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Tooltip(
                        message: subtitle,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                color: AppColors.muted500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppToggle(
                  value: rule.enabled,
                  semanticLabel: 'Enable ${rule.target}',
                  onChanged: onEnabledChanged,
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.line),
          ColoredBox(
            color: AppColors.paper.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _action(
                    tooltip: 'Move up',
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressed: onMoveUp,
                  ),
                  _action(
                    tooltip: 'Move down',
                    icon: Icons.keyboard_arrow_down_rounded,
                    onPressed: onMoveDown,
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Edit rule',
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted500,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _action(
                    tooltip: 'Delete rule',
                    icon: Icons.delete_outline_rounded,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
