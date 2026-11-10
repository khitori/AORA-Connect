// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/window_controls.dart';
import '../components/app_dialog.dart';
import '../components/app_select.dart';
import '../components/compact_outline_icon_button.dart';
import '../components/connection_edit_notification.dart';
import '../components/pill_button.dart';
import '../components/server_node_details.dart';
import '../components/subscription_error.dart';
import '../components/subscription_input.dart';
import '../components/subscription_refresh_button.dart';
import '../components/subscription_timing.dart';
import '../controllers/connection_controller.dart';
import '../controllers/node_ping_controller.dart';
import '../l10n/l10n.dart';
import '../storage/app_settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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

  /// The link field opens in a dialog. The link typed there is kept when the
  /// dialog is closed, and the dialog closes itself once the link is added.
  /// An error it showed goes away with it.
  Future<void> _openAddDialog() async {
    if (!_allowEdit()) return;
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: widget.connection,
        builder: (dialogContext, _) {
          final connection = widget.connection;
          final error = connection.errorFor(ConnectionErrorScope.subscriptions);
          final onConfirm = connection.supported && connection.canEdit
              ? () => _addSubscription(dialogContext)
              : null;
          return AppDialog(
            title: context.l10n.addSubscription,
            subtitle: context.l10n.addSubscriptionHelp,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SubscriptionInput(
                  controller: widget.subscriptionUrl,
                  enabled: connection.canEdit,
                  onLoad: onConfirm,
                  showButtons: false,
                ),
                if (connection.busy) ...[
                  const SizedBox(height: AppTheme.sectionGap),
                  const LinearProgressIndicator(),
                ],
                if (error != null) ...[
                  const SizedBox(height: AppTheme.sectionGap),
                  // Inset like the subtext above.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SelectableText(
                      describeSubscriptionError(error, context.l10n),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            stackActions: true,
            actions: [
              PillButton(
                key: const ValueKey('paste-subscription'),
                label: context.l10n.paste,
                textColor: AppColors.dialogPasteButtonText,
                onPressed: connection.canEdit
                    ? () => pasteSubscriptionLink(
                        dialogContext,
                        widget.subscriptionUrl,
                        canApply: () => widget.connection.canEdit,
                      )
                    : null,
              ),
              PillButton(
                key: const ValueKey('confirm-subscription'),
                label: context.l10n.confirm,
                multiplyColor: AppColors.dialogConfirmButton,
                textColor: AppColors.dialogConfirmButtonText,
                onPressed: onConfirm,
              ),
              PillButton(
                label: context.l10n.cancel,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          );
        },
      ),
    );
    widget.connection.clearError(ConnectionErrorScope.subscriptions);
  }

  Future<void> _addSubscription(BuildContext dialogContext) async {
    if (!_allowEdit()) return;
    final url = widget.subscriptionUrl.text.trim();
    await widget.connection.addSubscription(url);
    if (!dialogContext.mounted || widget.connection.error != null) return;
    widget.subscriptionUrl.clear();
    Navigator.pop(dialogContext);
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
                // Without subscriptions, a full-width button below that new
                // users can't miss; after that, a small "+" in this row, like
                // the refresh and delete buttons under the select.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.newSubscription,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (subscriptions.isNotEmpty)
                      CompactOutlineIconButton(
                        key: const ValueKey('add-subscription-toggle'),
                        tooltip: context.l10n.addSubscription,
                        icon: Icons.add_rounded,
                        onPressed: _openAddDialog,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.sectionLabelGap),
                if (subscriptions.isEmpty)
                  _AddSubscriptionButton(onPressed: _openAddDialog)
                else
                  _SavedSubscriptionSelector(connection: connection),
                if (profiles.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.activeSubscriptionNodes,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.sectionLabelGap),
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: AppColors.subscriptionrowBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.sectionRowRadius,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _editControl(
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.contentPadding,
                          vertical: 4,
                        ),
                        title: ServerNodeDetails(
                          profile: profile,
                          pings: widget.pings,
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: AppColors.subscriptionrowCheck,
                              )
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
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (subscriptionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(
                      describeSubscriptionError(
                        subscriptionError,
                        context.l10n,
                      ),
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
            pill: true,
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Styled like the "Subscription" heading; red when servers
                // were skipped.
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: skipped > 0
                      ? Theme.of(context).colorScheme.error
                      : null,
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SubscriptionTiming(
              updatedAt: active.updatedAt,
              expiresAt: active.expiresAt,
            ),
          ),
        if (details?.description != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.contentPadding,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: AppColors.subscriptiondescriptionBackground,
                borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        size: 16,
                        color: AppColors.subscriptiondescriptionIcon,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.l10n.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.subscriptiondescriptionLabel,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
  Widget build(BuildContext context) => IslandButton(
    tooltip: url == null
        ? context.l10n.linkNotProvided(label)
        : context.l10n.openLink(label),
    icon: icon,
    label: label,
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
  );
}

/// The full-width 48 px "Add subscription" pill shown before any subscription
/// is added; it opens the Add subscription dialog.
class _AddSubscriptionButton extends StatelessWidget {
  const _AddSubscriptionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton(
      key: const ValueKey('add-subscription-toggle'),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.addsubscriptionbuttonBackground,
        foregroundColor: AppColors.addsubscriptionbuttonText,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sectionPadding,
        ),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(context.l10n.addSubscription, maxLines: 1),
      ),
    ),
  );
}
