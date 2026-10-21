// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/localized_exception.dart';
import '../updates/update_controller.dart';
import 'app_action_button.dart';
import 'app_dialog.dart';

class UpdateSourcesDialog extends StatefulWidget {
  const UpdateSourcesDialog({super.key, required this.updates});

  final UpdateController updates;

  @override
  State<UpdateSourcesDialog> createState() => _UpdateSourcesDialogState();
}

class _UpdateSourcesDialogState extends State<UpdateSourcesDialog> {
  // Keep the controller alive through the route's closing animation.
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      title: context.l10n.updateSources,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.updateSourcesHelp),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            textDirection: TextDirection.ltr,
            minLines: 2,
            maxLines: 4,
            enabled: !_saving,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              hintText: context.l10n.metadataUrlPerLine,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        AppActionButton(
          label: context.l10n.cancel,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        AppActionButton(
          label: _saving ? context.l10n.saving : context.l10n.save,
          onPressed: _saving ? null : _save,
        ),
      ],
    ),
  );
}
