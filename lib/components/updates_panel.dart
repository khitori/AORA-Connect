// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../updates/update_controller.dart';
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
            XTypeGroup(
              label: context.l10n.androidApk,
              extensions: ['apk'],
              mimeTypes: ['application/vnd.android.package-archive'],
            )
          else
            XTypeGroup(
              label: context.l10n.windowsInstaller,
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
      AppNotification.show(context, context.l10n.disconnectInstall);
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.installVersion(
          isolateTechnicalValue(
            context.l10n,
            updates.release!.version.split('+').first,
          ),
        ),
        content: Text(
          updates.isAndroid
              ? context.l10n.androidInstallHelp
              : context.l10n.windowsInstallHelp,
        ),
        actions: [
          AppActionButton(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppActionButton(
            label: context.l10n.install,
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
        title: context.l10n.updates,
        storageId: 'updates',
        subtitle: context.l10n.version(
          isolateTechnicalValue(context.l10n, updates.displayVersion),
        ),
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
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(context.l10n.automaticUpdates),
                  ),
                ),
              ),
              AppToggle(
                compact: true,
                value: updates.automaticChecks,
                semanticLabel: context.l10n.automaticUpdatesSemantics,
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
          Text(updates.localizedStatus(context.l10n)),
          if (updates.busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: updates.progress),
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
                  label: context.l10n.checkUpdates,
                  icon: Icons.refresh_rounded,
                  onPressed: disabled ? null : updates.check,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppActionButton(
                  key: const ValueKey('update-from-file'),
                  label: context.l10n.importUpdate,
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
                label: context.l10n.downloadUpdate,
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
                label: context.l10n.installUpdate,
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
                  ? context.l10n.additionalSources
                  : context.l10n.additionalSourcesCount(
                      updates.additionalSources.length.toString(),
                    ),
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
