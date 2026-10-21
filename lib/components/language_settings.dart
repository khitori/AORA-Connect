// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/locale_controller.dart';
import 'app_expansion_card.dart';
import 'app_notification.dart';
import 'app_select.dart';

class LanguageSettings extends StatelessWidget {
  const LanguageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return AppExpansionCard(
      title: context.l10n.language,
      storageId: 'language',
      subtitle: controller.language == null
          ? context.l10n.systemDefault
          : LocaleController.nativeName(controller.language!),
      icon: Icons.translate_rounded,
      children: [
        Text(
          context.l10n.interfaceLanguage,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        AppSelect<String>(
          key: const ValueKey('language-selector'),
          value: controller.language ?? 'system',
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(context.l10n.systemDefault),
            ),
            for (final locale in AppLocalizations.supportedLocales)
              DropdownMenuItem(
                value: locale.toLanguageTag(),
                child: Text(
                  LocaleController.nativeName(locale.toLanguageTag()),
                ),
              ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            try {
              await controller.select(value == 'system' ? null : value);
            } catch (_) {
              if (context.mounted) {
                AppNotification.show(context, context.l10n.languageSaveFailed);
              }
            }
          },
        ),
      ],
    );
  }
}
