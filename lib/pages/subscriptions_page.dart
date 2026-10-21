// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/app_select.dart';
import '../components/compact_outline_icon_button.dart';
import '../components/connection_edit_notification.dart';
import '../components/server_node_details.dart';
import '../components/subscription_input.dart';
import '../components/subscription_refresh_button.dart';
import '../components/subscription_timing.dart';
import '../controllers/connection_controller.dart';
import '../controllers/node_ping_controller.dart';
import '../l10n/l10n.dart';
import '../storage/app_settings_store.dart';
import '../theme/app_colors.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({
    super.key,
    required this.connection,
    required this.subscriptionUrl,
    required this.pings,
  });

  final ConnectionController connection;
  final TextEditingController subscriptionUrl;
  final NodePingController pings;

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  late bool _addExpanded;

  bool _allowEdit() => allowConnectionEdit(
    context,
    widget.connection,
    context.l10n.disconnectSubscriptions,
  );

  Widget _editControl(Widget child, {String? message}) => DisabledControlNotice(
    disabled: !widget.connection.canEdit,
    onTap: () => allowConnectionEdit(
      context,
      widget.connection,
      message ?? context.l10n.disconnectSubscriptions,
    ),
    label: message ?? context.l10n.disconnectSubscriptions,
    child: child,
  );

  @override
  void initState() {
    super.initState();
    _addExpanded = widget.subscriptionUrl.text.isNotEmpty;
  }

  Future<void> _addSubscription() async {
    if (!_allowEdit()) return;
    final url = widget.subscriptionUrl.text.trim();
    await widget.connection.addSubscription(url);
    if (!mounted || widget.connection.error != null) return;
    widget.subscriptionUrl.clear();
    setState(() => _addExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final profiles = connection.profiles;
    final subscriptions = connection.subscriptions;
    final subscriptionError = connection.errorFor(
      ConnectionErrorScope.subscriptions,
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    key: const ValueKey('add-subscription-toggle'),
                    style: OutlinedButton.styleFrom(
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      if (_addExpanded || _allowEdit()) {
                        setState(() => _addExpanded = !_addExpanded);
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          _addExpanded
                              ? Icons.remove_rounded
                              : Icons.add_rounded,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              context.l10n.addSubscription,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _addExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _editControl(
                            SubscriptionInput(
                              controller: widget.subscriptionUrl,
                              enabled: connection.canEdit,
                              onLoad: connection.supported && connection.canEdit
                                  ? _addSubscription
                                  : null,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.savedSubscriptions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (subscriptions.isEmpty)
                  Text(context.l10n.noSubscriptions)
                else
                  _SavedSubscriptionSelector(connection: connection),
                if (profiles.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.activeSubscriptionNodes,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        if (profiles.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final selected = identical(profile, connection.selected);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.55)
                            : AppColors.lineStrong,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _editControl(
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: ServerNodeDetails(
                          profile: profile,
                          pings: widget.pings,
                        ),
                        trailing: selected
                            ? Icon(Icons.check_rounded, color: AppColors.accent)
                            : null,
                        onTap: connection.canEdit
                            ? () {
                                if (allowConnectionEdit(
                                  context,
                                  connection,
                                  context.l10n.disconnectServers,
                                )) {
                                  connection.selectProfile(profile);
                                }
                              }
                            : null,
                      ),
                      message: context.l10n.disconnectServers,
                    ),
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (connection.busy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (subscriptionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(
                      subscriptionError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedSubscriptionSelector extends StatelessWidget {
  const _SavedSubscriptionSelector({required this.connection});

  final ConnectionController connection;

  bool _allowEdit(BuildContext context) => allowConnectionEdit(
    context,
    connection,
    context.l10n.disconnectSubscriptions,
  );

  Widget _editControl(
    BuildContext context,
    Widget child, {
    bool available = true,
  }) => DisabledControlNotice(
    disabled: !connection.canEdit && available,
    onTap: () => _allowEdit(context),
    label: context.l10n.disconnectSubscriptions,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final activeUrl = connection.activeSubscriptionUrl;
    SavedSubscription? active;
    for (final subscription in connection.subscriptions) {
      if (subscription.url == activeUrl) active = subscription;
    }
    final count = active == null
        ? null
        : connection.profileCountFor(active.url);
    final skipped = active == null
        ? 0
        : connection.skippedCountFor(active.url) ?? 0;
    final details = active == null
        ? null
        : connection.subscriptionDetailsFor(active.url);
    final summary = active == null
        ? context.l10n.selectSubscription
        : '${count == null ? context.l10n.notLoaded : context.l10n.serverCount(count)}${skipped > 0 ? ' · ${context.l10n.skippedServers(skipped)}' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _editControl(
          context,
          AppSelect<String>(
            onBeforeOpen: () => _allowEdit(context),
            key: const ValueKey('saved-subscription-select'),
            value: activeUrl,
            hint: Text(context.l10n.chooseSubscription),
            items: [
              for (final subscription in connection.subscriptions)
                DropdownMenuItem(
                  value: subscription.url,
                  child: Text(
                    subscription.label,
                    textDirection: textDirectionFor(subscription.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: connection.canEdit
                ? (url) {
                    if (url != null &&
                        url != activeUrl &&
                        _allowEdit(context)) {
                      connection.activateSubscription(url);
                    }
                  }
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: skipped > 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            SubscriptionRefreshButton(connection: connection),
            const SizedBox(width: 6),
            _editControl(
              context,
              CompactOutlineIconButton(
                tooltip: context.l10n.removeSubscription,
                onPressed: active != null && connection.canEdit
                    ? () {
                        if (_allowEdit(context)) {
                          connection.removeSubscription(active!.url);
                        }
                      }
                    : null,
                icon: Icons.delete_outline_rounded,
              ),
              available: active != null,
            ),
          ],
        ),
        if (active != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SubscriptionTiming(
              updatedAt: active.updatedAt,
              expiresAt: active.expiresAt,
            ),
          ),
        if (details?.description != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lineStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppColors.muted500,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.l10n.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details!.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        if (active != null)
          Wrap(
            spacing: 8,
            children: [
              _SubscriptionLinkButton(
                label: context.l10n.website,
                icon: Icons.language_rounded,
                url: details?.webPageUrl,
              ),
              _SubscriptionLinkButton(
                label: context.l10n.support,
                icon: Icons.support_agent_rounded,
                url: details?.supportUrl,
              ),
            ],
          ),
      ],
    );
  }
}

class _SubscriptionLinkButton extends StatelessWidget {
  const _SubscriptionLinkButton({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String? url;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: url == null
        ? context.l10n.linkNotProvided(label)
        : context.l10n.openLink(label),
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: url == null
          ? null
          : () async {
              try {
                if (!await launchUrl(
                  Uri.parse(url!),
                  mode: LaunchMode.externalApplication,
                )) {
                  throw StateError('Could not open link.');
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.openNamedLinkFailed(label)),
                    ),
                  );
                }
              }
            },
      icon: Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}
