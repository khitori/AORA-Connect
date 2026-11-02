// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/windows_startup_controller.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_expansion_card.dart';
import 'app_toggle.dart';
import 'section_row_bleed.dart';
import 'settings_label.dart';

class WindowsStartupSettings extends StatefulWidget {
  const WindowsStartupSettings({super.key, required this.controller});
  final WindowsStartupController controller;
  @override
  State<WindowsStartupSettings> createState() => _WindowsStartupSettingsState();
}

class _WindowsStartupSettingsState extends State<WindowsStartupSettings> {
  WindowsStartupController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    unawaited(controller.initialize());
  }

  Widget _toggle(
    String title,
    String help,
    bool value,
    ValueChanged<bool> change,
  ) {
    final enabled = controller.loaded && !controller.busy;
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
          title: Text(title),
          subtitle: Text(help),
          onTap: enabled ? () => change(!value) : null,
          trailing: AppToggle(
            semanticLabel: title,
            value: value,
            onChanged: enabled ? change : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => AppExpansionCard(
      title: context.l10n.startup,
      storageId: 'startup',
      subtitle: !controller.loaded
          ? context.l10n.notAvailable
          : controller.startWithWindows
          ? context.l10n.startWithWindows
          : context.l10n.manualStart,
      icon: Icons.launch_rounded,
      children: [
        SettingsLabel(context.l10n.startupBehaviorLabel),
        const SizedBox(height: AppTheme.sectionLabelGap),
        _toggle(
          context.l10n.startWithWindows,
          context.l10n.startWithWindowsHelp,
          controller.startWithWindows,
          (value) => controller.update(startWithWindows: value),
        ),
        _toggle(
          context.l10n.startMinimized,
          context.l10n.startMinimizedHelp,
          controller.startMinimized,
          (value) => controller.update(startMinimized: value),
        ),
        if (controller.failed) ...[
          const SizedBox(height: AppTheme.sectionGap),
          Text(
            controller.loaded
                ? context.l10n.startupSaveFailed
                : context.l10n.startupLoadFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: controller.busy ? null : controller.initialize,
            child: Text(context.l10n.refresh),
          ),
        ],
      ],
    ),
  );
}
