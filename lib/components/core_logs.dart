// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';
import 'app_notification.dart';
import 'pill_button.dart';

/// Lines shown in the Diagnostics preview; the dialog shows them all.
const _previewLines = 8;

const _logStyle = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);

/// The latest core log lines in a rounded box. Clicking it opens every line
/// in a dialog, where they can be copied.
class CoreLogs extends StatelessWidget {
  const CoreLogs({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final preview = lines.length > _previewLines
        ? lines.sublist(lines.length - _previewLines)
        : lines;
    return SizedBox(
      height: 168,
      child: Material(
        color: AppColors.logspreviewBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppTheme.sectionRowRadius),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('core-logs-open'),
          overlayColor: AppTheme.overlay(
            AppColors.logspreviewHover,
            AppColors.logspreviewPressed,
          ),
          onTap: () => showAppDialog<void>(
            context: context,
            builder: (_) => _CoreLogsDialog(lines: lines),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.contentPadding,
              vertical: 18,
            ),
            child: SizedBox.expand(
              // The newest lines stay in view; older ones fade out above.
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, 0.25],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Text(
                    lines.isEmpty ? context.l10n.noLogs : preview.join('\n'),
                    textDirection: lines.isEmpty ? null : TextDirection.ltr,
                    style: lines.isEmpty ? null : _logStyle,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every log line in the glass dialog, selectable, with Copy (blue) above
/// Close. Copying closes the dialog and confirms with a notification.
class _CoreLogsDialog extends StatelessWidget {
  const _CoreLogsDialog({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.coreLogs,
    subtitle: context.l10n.coreLogsHelp,
    stackActions: true,
    content: SizedBox(
      height: 320,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.logsdialogBackground,
          borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
        ),
        child: SingleChildScrollView(
          // Opens at the newest lines.
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.contentPadding,
            vertical: 18,
          ),
          child: SizedBox(
            width: double.infinity,
            child: SelectableText(
              lines.isEmpty ? context.l10n.noLogs : lines.join('\n'),
              textDirection: lines.isEmpty ? null : TextDirection.ltr,
              style: lines.isEmpty ? null : _logStyle,
            ),
          ),
        ),
      ),
    ),
    actions: [
      PillButton(
        key: const ValueKey('copy-core-logs'),
        label: context.l10n.copy,
        multiplyColor: AppColors.dialogConfirmButton,
        textColor: AppColors.dialogConfirmButtonText,
        onPressed: lines.isEmpty
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: lines.join('\n')));
                if (!context.mounted) return;
                Navigator.pop(context);
                AppNotification.show(context, context.l10n.logsCopied);
              },
      ),
      PillButton(
        label: context.l10n.close,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
