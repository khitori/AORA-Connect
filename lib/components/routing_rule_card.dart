// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routing/routing_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';
import 'app_toggle.dart';
import 'connection_edit_notification.dart';
import 'glass_popover_button.dart';
import 'installed_application_picker.dart';

/// Side inset of the card's content, the same as in section cards.
const _inset = 16 + AppTheme.sectionPadding;

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
    RoutingMatch.ip => Icons.lan_rounded,
    _ => Icons.language_rounded,
  };

  // One action in the glass bubble; it closes the bubble once it has run.
  Widget _action(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required VoidCallback close,
  }) => _editControl(
    context,
    IconButton(
      tooltip: tooltip,
      onPressed: editingEnabled && onPressed != null
          ? () {
              close();
              onPressed();
            }
          : null,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.routingruleActionIcon,
        disabledForegroundColor: AppColors.routingruleActionIconDisabled,
        minimumSize: const Size(36, 36),
        maximumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
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
    // No border, and the Subscriptions page rows' rounding.
    return Material(
      color: AppColors.routingruleBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // The section header's side inset and gaps, a little shorter: 16 px
            // above and below the icon, 20 px between icon, text and switch.
            padding: const EdgeInsets.symmetric(
              horizontal: _inset,
              vertical: 16,
            ),
            child: Row(
              children: [
                // The section headers' glass icon box: a heavily rounded
                // square.
                GlassSurface(
                  backgroundTop: AppColors.routingruleiconboxBackgroundTop,
                  backgroundBottom:
                      AppColors.routingruleiconboxBackgroundBottom,
                  innerBorder: AppColors.routingruleiconboxInnerBorder,
                  outerBorder: AppColors.routingruleiconboxOuterBorder,
                  shadow: AppColors.routingruleiconboxShadow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  cornerWidth: 14,
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(6),
                    child: application?.icon == null
                        ? Icon(
                            _fallbackIcon,
                            size: 24,
                            color: AppColors.routingruleIcon,
                          )
                        : Image.memory(
                            application!.icon!,
                            width: 32,
                            height: 32,
                            errorBuilder: (_, _, _) => Icon(
                              _fallbackIcon,
                              size: 24,
                              color: AppColors.routingruleIcon,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppTheme.sectionGap),
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
                                    ? AppColors.routingruleTitle
                                    : AppColors.routingruleTitleDisabled,
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
                                color: AppColors.routingruleSubtitle,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.sectionGap),
                _editControl(
                  context,
                  AppToggle(
                    value: rule.enabled,
                    semanticLabel: context.l10n.enableTarget(rule.target),
                    onChanged: editingEnabled ? onEnabledChanged : null,
                  ),
                  available: onEnabledChanged != null,
                ),
                const SizedBox(width: 8),
                // One settings icon next to the switch; the actions open in a
                // glass bubble above it, in a row.
                GlassPopoverButton(
                  icon: Icons.settings_outlined,
                  tooltip: context.l10n.ruleActions,
                  actions: (context, close) => [
                    _action(
                      context,
                      tooltip: context.l10n.moveUp,
                      icon: Icons.keyboard_arrow_up_rounded,
                      onPressed: onMoveUp,
                      close: close,
                    ),
                    _action(
                      context,
                      tooltip: context.l10n.moveDown,
                      icon: Icons.keyboard_arrow_down_rounded,
                      onPressed: onMoveDown,
                      close: close,
                    ),
                    _action(
                      context,
                      tooltip: context.l10n.editRule,
                      icon: Icons.edit_rounded,
                      onPressed: onEdit,
                      close: close,
                    ),
                    _action(
                      context,
                      tooltip: context.l10n.deleteRule,
                      icon: Icons.delete_outline_rounded,
                      onPressed: onDelete,
                      close: close,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
