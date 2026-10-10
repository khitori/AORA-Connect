// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../components/app_expansion_card.dart';
import '../components/app_select.dart';
import '../components/app_toggle.dart';
import '../components/compact_outline_icon_button.dart';
import '../components/routing_rule_editor.dart';
import '../controllers/connection_controller.dart';
import '../routing/routing_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class RoutingPage extends StatelessWidget {
  const RoutingPage({super.key, required this.connection});
  final ConnectionController connection;

  Future<void> _saveRules(List<RoutingRule> rules) =>
      connection.setRoutingPolicy(
        RoutingPolicy(
          enabled: connection.routingPolicy.enabled,
          direction: connection.routingPolicy.direction,
          rules: List.unmodifiable(rules),
        ),
      );

  Future<void> _edit(BuildContext context, [int? index]) async {
    final rule = await showRoutingRuleEditor(
      context,
      initial: index == null ? null : connection.routingPolicy.rules[index],
    );
    if (rule == null || !context.mounted || !connection.canEdit) return;
    final rules = List.of(connection.routingPolicy.rules);
    if (index == null) {
      rules.add(rule);
    } else {
      rules[index] = rule;
    }
    await _saveRules(rules);
  }

  void _move(int index, int delta) {
    final rules = List.of(connection.routingPolicy.rules);
    final rule = rules.removeAt(index);
    rules.insert(index + delta, rule);
    _saveRules(rules);
  }

  @override
  Widget build(BuildContext context) {
    final policy = connection.routingPolicy;
    final error = connection.errorFor(ConnectionErrorScope.routing);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppExpansionCard(
                  title: 'Routing',
                  subtitle: policy.enabled
                      ? 'Applications and addresses'
                      : 'Off',
                  icon: Icons.alt_route_rounded,
                  initiallyExpanded: true,
                  titleAction: AppToggle(
                    semanticLabel: 'Routing',
                    value: policy.enabled,
                    onChanged: connection.canEdit
                        ? (enabled) => connection.setRoutingPolicy(
                            RoutingPolicy(
                              enabled: enabled,
                              direction: policy.direction,
                              rules: policy.rules,
                            ),
                          )
                        : null,
                  ),
                  children: [
                    const Text('Route listed applications and addresses'),
                    const SizedBox(height: 8),
                    AppSelect<RoutingAction>(
                      value: policy.direction,
                      items: [
                        for (final action in RoutingAction.values)
                          DropdownMenuItem(
                            value: action,
                            child: Text(action.label),
                          ),
                      ],
                      onChanged: connection.canEdit
                          ? (action) {
                              if (action != null) {
                                connection.setRoutingPolicy(
                                  RoutingPolicy(
                                    enabled: policy.enabled,
                                    direction: action,
                                    rules: policy.rules,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      policy.direction == RoutingAction.vpn
                          ? 'Listed items go through the tunnel. Everything else uses your normal connection.'
                          : 'Listed items use your normal connection. Everything else goes through the tunnel.',
                    ),
                    const SizedBox(height: 8),
                    const Text('Use VPN (TUN) mode to route system traffic.'),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: connection.canEdit ? () => _edit(context) : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add rule'),
                ),
                if (!connection.canEdit)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Disconnect before editing routing rules.'),
                  ),
                if (!policy.enabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Routing rules are off. Traffic uses the selected VPN server.',
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(
                      error,
                      style: TextStyle(color: AppColors.accentDark),
                    ),
                  ),
                if (policy.rules.isEmpty && policy.enabled)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      policy.direction == RoutingAction.vpn
                          ? 'No items yet. Everything uses your normal connection.'
                          : 'No items yet. Everything goes through the tunnel.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: policy.rules.length,
            itemBuilder: (context, index) {
              final rule = policy.rules[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                    border: Border.all(color: AppColors.lineStrong),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.target,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${index + 1} · ${rule.match.label}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppToggle(
                            semanticLabel: 'Enable ${rule.target}',
                            value: rule.enabled,
                            onChanged: connection.canEdit
                                ? (enabled) {
                                    final rules = List.of(policy.rules);
                                    rules[index] = rule.withEnabled(enabled);
                                    _saveRules(rules);
                                  }
                                : null,
                          ),
                          const Spacer(),
                          CompactOutlineIconButton(
                            tooltip: 'Move up',
                            icon: Icons.keyboard_arrow_up_rounded,
                            onPressed: connection.canEdit && index > 0
                                ? () => _move(index, -1)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          CompactOutlineIconButton(
                            tooltip: 'Move down',
                            icon: Icons.keyboard_arrow_down_rounded,
                            onPressed:
                                connection.canEdit &&
                                    index < policy.rules.length - 1
                                ? () => _move(index, 1)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          CompactOutlineIconButton(
                            tooltip: 'Edit rule',
                            icon: Icons.edit_outlined,
                            onPressed: connection.canEdit
                                ? () => _edit(context, index)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          CompactOutlineIconButton(
                            tooltip: 'Delete rule',
                            icon: Icons.delete_outline_rounded,
                            onPressed: connection.canEdit
                                ? () {
                                    final rules = List.of(policy.rules)
                                      ..removeAt(index);
                                    _saveRules(rules);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}
