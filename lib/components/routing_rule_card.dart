// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routing/routing_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_toggle.dart';
import 'connection_edit_notification.dart';
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
    this.editingEnabled = true,
    this.onEditingBlocked,
  });

  final RoutingRule rule;
  final InstalledApplication? application;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool editingEnabled;
  final VoidCallback? onEditingBlocked;

  Widget _editControl(
    BuildContext context,
    Widget child, {
    bool available = true,
  }) => DisabledControlNotice(
    disabled: !editingEnabled && available && onEditingBlocked != null,
    onTap: () => onEditingBlocked?.call(),
    label: context.l10n.disconnectRouting,
    child: child,
  );

  IconData get _fallbackIcon => switch (rule.match) {
    RoutingMatch.application => Icons.apps_rounded,
    RoutingMatch.ip => Icons.lan_outlined,
    _ => Icons.language_rounded,
  };

  Widget _action(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => _editControl(
    context,
    IconButton(
      tooltip: tooltip,
      onPressed: editingEnabled ? onPressed : null,
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
    ),
    available: onPressed != null,
  );

  @override
  Widget build(BuildContext context) {
    final title = application?.label ?? rule.target;
    final subtitle = application != null
        ? rule.target
        : rule.match.localizedLabel(context.l10n);
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
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
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
                          textDirection: textDirectionFor(title),
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
                          textDirection: application != null
                              ? TextDirection.ltr
                              : null,
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
                _editControl(
                  context,
                  AppToggle(
                    value: rule.enabled,
                    semanticLabel: context.l10n.enableTarget(rule.target),
                    onChanged: editingEnabled ? onEnabledChanged : null,
                  ),
                  available: onEnabledChanged != null,
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
                    context,
                    tooltip: context.l10n.moveUp,
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressed: onMoveUp,
                  ),
                  _action(
                    context,
                    tooltip: context.l10n.moveDown,
                    icon: Icons.keyboard_arrow_down_rounded,
                    onPressed: onMoveDown,
                  ),
                  const Spacer(),
                  _editControl(
                    context,
                    Tooltip(
                      message: context.l10n.editRule,
                      child: TextButton.icon(
                        onPressed: editingEnabled ? onEdit : null,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(context.l10n.edit),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted500,
                          disabledForegroundColor: AppColors.lineStrong,
                          minimumSize: const Size(0, 36),
                          visualDensity: VisualDensity.standard,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    available: onEdit != null,
                  ),
                  const SizedBox(width: 4),
                  _action(
                    context,
                    tooltip: context.l10n.deleteRule,
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
