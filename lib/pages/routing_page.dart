// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../components/app_expansion_card.dart';
import '../components/app_select.dart';
import '../components/app_toggle.dart';
import '../components/connection_edit_notification.dart';
import '../components/routing_rule_card.dart';
import '../components/routing_rule_editor.dart';
import '../components/installed_application_picker.dart';
import '../controllers/connection_controller.dart';
import '../routing/routing_policy.dart';
import '../theme/app_colors.dart';

class RoutingPage extends StatefulWidget {
  const RoutingPage({
    super.key,
    required this.connection,
    this.applicationLoader,
  });
  final ConnectionController connection;
  final Future<List<InstalledApplication>> Function()? applicationLoader;

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  static const _sectionGap = 16.0;
  ConnectionController get connection => widget.connection;
  // Resolve display metadata once per page, not once for every rule/rebuild.
  late final Future<List<InstalledApplication>>? _applications =
      widget.applicationLoader != null
      ? widget.applicationLoader!()
      : Platform.isAndroid
      ? InstalledApplication.load()
      : null;

  bool _allowEdit() => allowConnectionEdit(
    context,
    connection,
    'Disconnect before editing routing rules.',
  );

  Widget _editControl(Widget child) => DisabledControlNotice(
    disabled: !connection.canEdit,
    onTap: _allowEdit,
    label: 'Disconnect before editing routing rules.',
    child: child,
  );

  Future<void> _saveRules(List<RoutingRule> rules) async {
    if (!_allowEdit()) return;
    await connection.setRoutingPolicy(
      RoutingPolicy(
        enabled: connection.routingPolicy.enabled,
        direction: connection.routingPolicy.direction,
        rules: List.unmodifiable(rules),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [int? index]) async {
    if (!_allowEdit()) return;
    final rule = await showRoutingRuleEditor(
      context,
      initial: index == null ? null : connection.routingPolicy.rules[index],
    );
    if (rule == null || !context.mounted || !_allowEdit()) return;
    final rules = List.of(connection.routingPolicy.rules);
    if (index == null) {
      rules.add(rule);
    } else {
      rules[index] = rule;
    }
    await _saveRules(rules);
  }

  void _move(int index, int delta) {
    if (!_allowEdit()) return;
    final rules = List.of(connection.routingPolicy.rules);
    final rule = rules.removeAt(index);
    rules.insert(index + delta, rule);
    _saveRules(rules);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<InstalledApplication>>(
        future: _applications,
        builder: (context, snapshot) => _buildRules(context, {
          for (final app in snapshot.data ?? <InstalledApplication>[])
            app.packageName: app,
        }),
      );

  Widget _buildRules(
    BuildContext context,
    Map<String, InstalledApplication> applications,
  ) {
    final policy = connection.routingPolicy;
    final error = connection.errorFor(ConnectionErrorScope.routing);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, _sectionGap),
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
                  titleAction: _editControl(
                    AppToggle(
                      semanticLabel: 'Routing',
                      value: policy.enabled,
                      onChanged: connection.canEdit
                          ? (enabled) {
                              if (!_allowEdit()) return;
                              connection.setRoutingPolicy(
                                RoutingPolicy(
                                  enabled: enabled,
                                  direction: policy.direction,
                                  rules: policy.rules,
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                  children: [
                    const Text('Route listed applications and addresses'),
                    const SizedBox(height: 8),
                    _editControl(
                      AppSelect<RoutingAction>(
                        onBeforeOpen: _allowEdit,
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
                                if (action != null && _allowEdit()) {
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
                const SizedBox(height: _sectionGap),
                _editControl(
                  OutlinedButton.icon(
                    onPressed: connection.canEdit ? () => _edit(context) : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add rule'),
                  ),
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
              final application = rule.match == RoutingMatch.application
                  ? applications[rule.target]
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoutingRuleCard(
                  editingEnabled: connection.canEdit,
                  onEditingBlocked: _allowEdit,
                  rule: rule,
                  application: application,
                  onEnabledChanged: (enabled) {
                    final rules = List.of(policy.rules);
                    rules[index] = rule.withEnabled(enabled);
                    _saveRules(rules);
                  },
                  onMoveUp: index > 0 ? () => _move(index, -1) : null,
                  onMoveDown: index < policy.rules.length - 1
                      ? () => _move(index, 1)
                      : null,
                  onEdit: () => _edit(context, index),
                  onDelete: () {
                    final rules = List.of(policy.rules)..removeAt(index);
                    _saveRules(rules);
                  },
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
