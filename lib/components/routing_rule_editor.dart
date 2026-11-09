// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routing/routing_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';
import 'app_select.dart';
import 'installed_application_picker.dart';
import 'pill_button.dart';
import 'pill_field.dart';
import 'running_application_picker.dart';
import 'settings_label.dart';

/// Space between the dialog's groups (a name with its control).
const _groupGap = 12.0;

Future<RoutingRule?> showRoutingRuleEditor(
  BuildContext context, {
  RoutingRule? initial,
}) async {
  var match = initial?.match ?? RoutingMatch.application;
  var target = initial?.target ?? '';
  var selectionRevision = 0;
  String? error;
  // The glass dialog shell; its fields and buttons keep their old style for
  // now. Each control has a subsection name above it, inset like the title.
  Widget label(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: SettingsLabel(text, color: AppColors.dialogLabel),
  );
  return await showAppDialog<RoutingRule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AppDialog(
        title: initial == null
            ? context.l10n.addRoutingRule
            : context.l10n.editRoutingRule,
        subtitle: context.l10n.routingRuleHelp,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label(context.l10n.match),
            const SizedBox(height: AppTheme.sectionLabelGap),
            AppSelect<RoutingMatch>(
              pill: true,
              fieldColor: AppColors.dialogSelectBackground,
              value: match,
              items: [
                for (final type in RoutingMatch.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.localizedLabel(context.l10n)),
                  ),
              ],
              onChanged: (value) => update(() {
                if (value != null) match = value;
                error = null;
              }),
            ),
            const SizedBox(height: _groupGap),
            label(context.l10n.value),
            const SizedBox(height: AppTheme.sectionLabelGap),
            // The gray pill of the Add subscription dialog's link field.
            PillFieldBox(
              child: TextFormField(
                key: ValueKey(selectionRevision),
                initialValue: target,
                textDirection: TextDirection.ltr,
                onChanged: (value) => target = value,
                style: pillFieldTextStyle(context),
                decoration: pillFieldDecoration(
                  context,
                  hintText:
                      Platform.isAndroid && match == RoutingMatch.application
                      ? 'com.android.chrome'
                      : match.hint,
                ),
              ),
            ),
            // Under the pill, inset like the subtext.
            if (error != null) ...[
              const SizedBox(height: AppTheme.sectionLabelGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (match == RoutingMatch.application &&
                (Platform.isWindows || Platform.isAndroid)) ...[
              const SizedBox(height: _groupGap),
              label(context.l10n.pickApplicationLabel),
              const SizedBox(height: AppTheme.sectionLabelGap),
              PillButton(
                label: context.l10n.chooseApplication,
                onPressed: () async {
                  final selected = Platform.isAndroid
                      ? await showInstalledApplicationPicker(context)
                      : await showRunningApplicationPicker(context);
                  if (selected == null || !context.mounted) return;
                  update(() {
                    target = selected;
                    selectionRevision++;
                    error = null;
                  });
                },
              ),
            ],
          ],
        ),
        // The pill column of the Add subscription dialog: Save on top in the
        // confirm blue, Cancel below.
        stackActions: true,
        actions: [
          PillButton(
            label: context.l10n.save,
            multiplyColor: AppColors.dialogConfirmButton,
            textColor: AppColors.dialogConfirmButtonText,
            onPressed: () {
              final rule = RoutingRule(
                match: match,
                target:
                    match == RoutingMatch.domain ||
                        match == RoutingMatch.exactDomain
                    ? target.trim().toLowerCase()
                    : target.trim(),
                enabled: initial?.enabled ?? true,
              );
              if (rule.validationError != null) {
                update(
                  () => error = rule.validationIssue?.localizedLabel(
                    context.l10n,
                  ),
                );
              } else {
                Navigator.pop(context, rule);
              }
            },
          ),
          PillButton(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
