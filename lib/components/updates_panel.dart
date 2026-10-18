// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../updates/update_controller.dart';
import '../theme/app_theme.dart';
import 'app_action_button.dart';
import 'app_dialog.dart';
import 'app_expansion_card.dart';
import 'app_notification.dart';
import 'app_toggle.dart';
import 'update_sources_dialog.dart';

class UpdatesPanel extends StatelessWidget {
  const UpdatesPanel({
    super.key,
    required this.updates,
    required this.connection,
    required this.onInstall,
  });

  final UpdateController updates;
  final ConnectionController connection;
  final Future<void> Function() onInstall;

  Future<void> _import(BuildContext context) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          if (updates.isAndroid)
            const XTypeGroup(
              label: 'AORA Android APK',
              extensions: ['apk'],
              mimeTypes: ['application/vnd.android.package-archive'],
            )
          else
            const XTypeGroup(
              label: 'AORA update installer',
              extensions: ['exe'],
            ),
        ],
      );
      if (file != null) await updates.importFile(file.path);
    } catch (error) {
      if (context.mounted) AppNotification.show(context, '$error');
    }
  }

  Future<void> _confirmInstall(BuildContext context) async {
    if (!connection.canEdit) {
      AppNotification.show(context, 'Disconnect before installing an update.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Install ${updates.release!.version.split('+').first}?',
        content: Text(
          updates.isAndroid
              ? 'Android will ask you to confirm installation. Your settings, subscriptions and routing rules will be kept.'
              : 'AORA Connect will close and reopen after installation. Your settings and subscriptions will be kept.',
        ),
        actions: [
          AppActionButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppActionButton(
            label: 'Install',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (approved == true) await onInstall();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final disabled = updates.busy || updates.installing;
      return AppExpansionCard(
        title: 'Updates',
        subtitle: 'Version ${updates.displayVersion}',
        icon: Icons.system_update_alt_rounded,
        // The toggle's transparent hit-area padding counts toward the gap.
        contentTopPadding:
            AppTheme.sectionContentTopPadding -
            AppToggle.compactVerticalPadding,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTheme.controlHeight,
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Check automatically at startup'),
                  ),
                ),
              ),
              AppToggle(
                compact: true,
                value: updates.automaticChecks,
                semanticLabel: 'Check for updates automatically',
                onChanged: disabled
                    ? null
                    : (value) async {
                        try {
                          await updates.setPreferences(automatic: value);
                        } catch (error) {
                          if (context.mounted) {
                            AppNotification.show(context, '$error');
                          }
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(updates.status),
          if (updates.busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: updates.progress),
          ],
          if (updates.release?.notes.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(updates.release!.notes),
          ],
          if (updates.error != null) ...[
            const SizedBox(height: 8),
            Text(
              updates.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppActionButton(
                  key: const ValueKey('check-updates'),
                  label: 'Check for updates',
                  icon: Icons.refresh_rounded,
                  onPressed: disabled ? null : updates.check,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppActionButton(
                  key: const ValueKey('update-from-file'),
                  label: 'Update from file',
                  icon: Icons.folder_open_rounded,
                  onPressed: disabled ? null : () => _import(context),
                ),
              ),
            ],
          ),
          if (updates.release != null && updates.package == null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppActionButton(
                label: 'Download update',
                icon: Icons.download_rounded,
                onPressed: disabled ? null : updates.download,
              ),
            ),
          ],
          if (updates.package != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppActionButton(
                label: 'Install update',
                icon: updates.isAndroid
                    ? Icons.install_mobile_rounded
                    : Icons.install_desktop_rounded,
                onPressed: disabled ? null : () => _confirmInstall(context),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppActionButton(
              label: updates.additionalSources.isEmpty
                  ? 'Additional sources (optional)'
                  : '${updates.additionalSources.length} additional sources',
              icon: Icons.language_rounded,
              onPressed: disabled
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => UpdateSourcesDialog(updates: updates),
                    ),
            ),
          ),
        ],
      );
    },
  );
}
