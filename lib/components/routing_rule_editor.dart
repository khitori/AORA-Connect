// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../routing/routing_policy.dart';
import 'app_select.dart';
import 'installed_application_picker.dart';
import 'running_application_picker.dart';

Future<RoutingRule?> showRoutingRuleEditor(
  BuildContext context, {
  RoutingRule? initial,
}) async {
  var match = initial?.match ?? RoutingMatch.application;
  var target = initial?.target ?? '';
  var selectionRevision = 0;
  String? error;
  return await showDialog<RoutingRule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsOverflowButtonSpacing: 8,
        title: Text(
          initial == null
              ? context.l10n.addRoutingRule
              : context.l10n.editRoutingRule,
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.match),
                const SizedBox(height: 8),
                AppSelect<RoutingMatch>(
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
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(selectionRevision),
                  initialValue: target,
                  textDirection: TextDirection.ltr,
                  onChanged: (value) => target = value,
                  decoration: InputDecoration(
                    labelText: context.l10n.value,
                    hintText:
                        Platform.isAndroid && match == RoutingMatch.application
                        ? 'com.android.chrome'
                        : match.hint,
                    errorText: error,
                  ),
                ),
                if (match == RoutingMatch.application &&
                    (Platform.isWindows || Platform.isAndroid)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.apps_rounded),
                    label: Text(
                      context.l10n.chooseApplication,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          OutlinedButton(
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
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ),
  );
}
