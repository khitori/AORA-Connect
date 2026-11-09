// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_expansion_card.dart';
import 'app_notification.dart';
import 'app_select.dart';
import 'settings_label.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  String _label(BuildContext context, ThemeChoice choice) => switch (choice) {
    ThemeChoice.system => context.l10n.systemDefault,
    ThemeChoice.light => context.l10n.themeLight,
    ThemeChoice.dark => context.l10n.themeDark,
  };

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return AppExpansionCard(
      title: context.l10n.appearance,
      storageId: 'appearance',
      subtitle: _label(context, controller.choice),
      icon: Icons.palette_rounded,
      children: [
        SettingsLabel(context.l10n.theme),
        const SizedBox(height: AppTheme.sectionLabelGap),
        AppSelect<ThemeChoice>(
          plain: true,
          key: const ValueKey('theme-selector'),
          value: controller.choice,
          items: [
            for (final choice in ThemeChoice.values)
              DropdownMenuItem(
                value: choice,
                child: Text(_label(context, choice)),
              ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            try {
              await controller.select(value);
            } catch (_) {
              if (context.mounted) {
                AppNotification.show(context, context.l10n.themeSaveFailed);
              }
            }
          },
        ),
      ],
    );
  }
}
