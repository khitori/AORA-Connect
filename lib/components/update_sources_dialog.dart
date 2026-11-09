// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/localized_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../updates/update_controller.dart';
import 'app_dialog.dart';
import 'pill_button.dart';
import 'pill_field.dart';

class UpdateSourcesDialog extends StatefulWidget {
  const UpdateSourcesDialog({super.key, required this.updates});

  final UpdateController updates;

  @override
  State<UpdateSourcesDialog> createState() => _UpdateSourcesDialogState();
}

class _UpdateSourcesDialogState extends State<UpdateSourcesDialog> {
  late final _input = TextEditingController(
    text: widget.updates.additionalSources.join('\n'),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.updates.setPreferences(
        sources: _input.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = localizedException(error, context.l10n);
      });
    }
  }

  // The glass dialog style of Add subscription: the help as subtext, the
  // links in a gray rounded box (several lines, so not a pill), an error
  // under it, and Save in blue above Cancel.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      title: context.l10n.updateSources,
      subtitle: context.l10n.updateSourcesHelp,
      stackActions: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.dialogInputBackground,
              borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sectionPadding,
                vertical: 14,
              ),
              child: TextField(
                controller: _input,
                textDirection: TextDirection.ltr,
                minLines: 3,
                maxLines: 5,
                enabled: !_saving,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: Theme.of(context).textTheme.bodyMedium,
                decoration:
                    pillFieldDecoration(
                      context,
                      hintText: context.l10n.metadataUrlPerLine,
                    ).copyWith(
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.dialogInputHint),
                    ),
              ),
            ),
          ),
          // Under the box, inset like the subtext.
          if (_error case final error?) ...[
            const SizedBox(height: AppTheme.sectionLabelGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        PillButton(
          label: _saving ? context.l10n.saving : context.l10n.save,
          multiplyColor: AppColors.dialogConfirmButton,
          textColor: AppColors.dialogConfirmButtonText,
          onPressed: _saving ? null : _save,
        ),
        PillButton(
          label: context.l10n.cancel,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
