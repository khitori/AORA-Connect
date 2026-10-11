// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../updates/update_controller.dart';
import 'app_expansion_card.dart';
import 'app_notification.dart';
import 'app_toggle.dart';

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

  Future<void> _sources(BuildContext context) async {
    final input = TextEditingController(
      text: updates.additionalSources.join('\n'),
    );
    try {
      final sources = await showDialog<List<String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Additional update sources'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Optional HTTPS links to signed update metadata. GitHub is tried first.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'One metadata URL per line',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                context,
                input.text
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList(),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (sources != null) await updates.setPreferences(sources: sources);
    } catch (error) {
      if (context.mounted) AppNotification.show(context, '$error');
    } finally {
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) => AppExpansionCard(
      title: 'Updates',
      subtitle: 'Version ${updates.currentVersion}',
      icon: Icons.system_update_alt_rounded,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Check automatically at startup')),
            AppToggle(
              value: updates.automaticChecks,
              semanticLabel: 'Check for updates automatically',
              onChanged: updates.busy
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: updates.busy || updates.installing
                  ? null
                  : updates.check,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check for updates'),
            ),
            OutlinedButton.icon(
              onPressed: updates.busy || updates.installing
                  ? null
                  : () async {
                      try {
                        final file = await openFile(
                          acceptedTypeGroups: [
                            const XTypeGroup(
                              label: 'AORA update installer',
                              extensions: ['exe'],
                            ),
                          ],
                        );
                        if (file != null) await updates.importFile(file.path);
                      } catch (error) {
                        if (context.mounted) {
                          AppNotification.show(context, '$error');
                        }
                      }
                    },
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Update from file'),
            ),
            if (updates.release != null && updates.package == null)
              OutlinedButton.icon(
                onPressed: updates.busy ? null : updates.download,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download update'),
              ),
            if (updates.package != null)
              OutlinedButton.icon(
                onPressed: updates.busy || updates.installing
                    ? null
                    : () async {
                        if (!connection.canEdit) {
                          AppNotification.show(
                            context,
                            'Disconnect before installing an update.',
                          );
                          return;
                        }
                        final approved = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Install ${updates.release!.version}?'),
                            content: const Text(
                              'AORA Connect will close and reopen after installation. Your settings and subscriptions will be kept.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Install'),
                              ),
                            ],
                          ),
                        );
                        if (approved == true) await onInstall();
                      },
                icon: const Icon(Icons.install_desktop_rounded),
                label: const Text('Install update'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: updates.busy || updates.installing
              ? null
              : () => _sources(context),
          child: Text(
            updates.additionalSources.isEmpty
                ? 'Additional sources (optional)'
                : '${updates.additionalSources.length} additional sources',
          ),
        ),
      ],
    ),
  );
}
