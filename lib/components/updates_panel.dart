// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../updates/update_controller.dart';
import 'app_dialog.dart';
import 'app_expansion_card.dart';
import 'app_notification.dart';
import 'app_toggle.dart';
import 'pill_button.dart';
import 'section_row_bleed.dart';
import 'update_sources_dialog.dart';
import 'warning_notice.dart';

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
    // The glass dialog's pill column: Install in blue, Cancel below.
    final approved = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.installVersion(
          isolateTechnicalValue(
            context.l10n,
            updates.release!.version.split('+').first,
          ),
        ),
        subtitle: updates.isAndroid
            ? context.l10n.androidInstallHelp
            : context.l10n.windowsInstallHelp,
        content: const SizedBox.shrink(),
        stackActions: true,
        actions: [
          PillButton(
            label: context.l10n.install,
            multiplyColor: AppColors.confirm,
            textColor: AppColors.card,
            onPressed: () => Navigator.pop(context, true),
          ),
          PillButton(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (approved == true) await onInstall();
  }

  // The automatic check as a toggle row, like Start with Windows.
  Widget _automaticRow(BuildContext context, bool disabled) {
    Future<void> change(bool value) async {
      try {
        await updates.setPreferences(automatic: value);
      } catch (error) {
        if (context.mounted) AppNotification.show(context, '$error');
      }
    }

    return SectionRowBleed(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sectionPadding,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
          ),
          hoverColor: AppColors.ink.withValues(alpha: 0.06),
          title: Text(context.l10n.automaticUpdates),
          subtitle: Text(context.l10n.automaticUpdatesHelp),
          onTap: disabled ? null : () => change(!updates.automaticChecks),
          trailing: AppToggle(
            value: updates.automaticChecks,
            semanticLabel: context.l10n.automaticUpdatesSemantics,
            onChanged: disabled ? null : change,
          ),
        ),
      ),
    );
  }

  // The installed version and where the update stands, in one gray box,
  // with the release notes of a found update and the download progress.
  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    final release = updates.release;
    final found = release != null && updates.error == null;
    return DecoratedBox(
      key: const ValueKey('update-status'),
      decoration: BoxDecoration(
        color: AppColors.controlGray,
        borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.contentPadding,
          vertical: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  found ? Icons.new_releases_outlined : Icons.verified_outlined,
                  size: 20,
                  color: found ? AppColors.confirm : AppColors.muted500,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.version(
                          isolateTechnicalValue(
                            context.l10n,
                            updates.displayVersion,
                          ),
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        updates.localizedStatus(context.l10n),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: found ? AppColors.confirm : AppColors.muted500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (found && release.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                release.notes.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted500,
                ),
              ),
            ],
            if (updates.busy) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: updates.progress,
                  minHeight: 6,
                  color: AppColors.confirm,
                  backgroundColor: AppColors.card,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final disabled = updates.busy || updates.installing;
      // One main action that follows the update along: check, then
      // download what was found, then install it.
      final (label, icon, action) = updates.package != null
          ? (
              context.l10n.installUpdate,
              updates.isAndroid
                  ? Icons.install_mobile_rounded
                  : Icons.install_desktop_rounded,
              () => _confirmInstall(context),
            )
          : updates.release != null
          ? (
              context.l10n.downloadUpdate,
              Icons.download_rounded,
              updates.download,
            )
          : (
              context.l10n.checkForUpdates,
              Icons.refresh_rounded,
              updates.check,
            );
      return AppExpansionCard(
        title: context.l10n.updates,
        storageId: 'updates',
        subtitle: context.l10n.version(
          isolateTechnicalValue(context.l10n, updates.displayVersion),
        ),
        icon: Icons.system_update_alt_rounded,
        children: [
          _automaticRow(context, disabled),
          const SizedBox(height: AppTheme.sectionGap),
          _statusCard(context),
          if (updates.error case final error?) ...[
            const SizedBox(height: AppTheme.sectionButtonGap),
            WarningNotice(
              message: error,
              actionLabel: context.l10n.retry,
              onAction: disabled ? null : action,
            ),
          ],
          const SizedBox(height: AppTheme.sectionGap),
          PillButton(
            key: const ValueKey('check-updates'),
            label: label,
            icon: icon,
            multiplyColor: AppColors.confirm,
            textColor: AppColors.card,
            onPressed: disabled ? null : action,
          ),
          const SizedBox(height: AppTheme.sectionButtonGap),
          PillButton(
            key: const ValueKey('update-from-file'),
            color: AppColors.controlGray,
            label: context.l10n.importUpdate,
            icon: Icons.folder_open_rounded,
            onPressed: disabled ? null : () => _import(context),
          ),
          // Its own line: the label is long in several languages.
          const SizedBox(height: AppTheme.sectionButtonGap),
          PillButton(
            key: const ValueKey('update-sources'),
            color: AppColors.controlGray,
            label: updates.additionalSources.isEmpty
                ? context.l10n.additionalSources
                : context.l10n.additionalSourcesCount(
                    updates.additionalSources.length.toString(),
                  ),
            icon: Icons.language_rounded,
            onPressed: disabled
                ? null
                : () => showAppDialog<void>(
                    context: context,
                    builder: (_) => UpdateSourcesDialog(updates: updates),
                  ),
          ),
        ],
      );
    },
  );
}
