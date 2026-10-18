// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../routing/routing_policy.dart';
import 'app_select.dart';
import 'running_application_picker.dart';
import 'installed_application_picker.dart';

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
        title: Text(initial == null ? 'Add routing rule' : 'Edit routing rule'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Match'),
                const SizedBox(height: 8),
                AppSelect<RoutingMatch>(
                  value: match,
                  items: [
                    for (final type in RoutingMatch.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
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
                  onChanged: (value) => target = value,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    labelText: 'Value',
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.apps_rounded),
                    label: const Text(
                      'Choose application',
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
            child: const Text('Cancel'),
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
                update(() => error = rule.validationError);
              } else {
                Navigator.pop(context, rule);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
