// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../profiles/subscription_loader.dart';
import 'window_controls.dart';
import '../theme/app_theme.dart';
import 'app_notification.dart';
import 'pill_field.dart';

/// Puts a subscription link from the clipboard into [controller]. Nothing
/// changes if the field was edited meanwhile or [canApply] says no once the
/// clipboard is read; anything that is not a link is reported instead.
Future<void> pasteSubscriptionLink(
  BuildContext context,
  TextEditingController controller, {
  bool Function()? canApply,
}) async {
  final previous = controller.value;
  try {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (!context.mounted ||
        canApply?.call() == false ||
        controller.value != previous) {
      return;
    }
    if (value == null || !isSupportedSubscriptionInput(value)) {
      AppNotification.show(context, context.l10n.copyLinkFirst);
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  } catch (_) {
    if (context.mounted) {
      AppNotification.show(context, context.l10n.clipboardReadFailed);
    }
  }
}

class SubscriptionInput extends StatefulWidget {
  const SubscriptionInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onLoad,
    this.showButtons = true,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onLoad;

  /// Without them the row is only the link field, drawn as the dialog's gray
  /// 48 px pill without a border; the caller offers its own Paste and Add
  /// buttons (like the Add subscription dialog's pills).
  final bool showButtons;

  @override
  State<SubscriptionInput> createState() => _SubscriptionInputState();
}

class _SubscriptionInputState extends State<SubscriptionInput> {
  bool _reading = false;

  Future<void> _paste() async {
    if (_reading || !widget.enabled) return;
    final controller = widget.controller;
    setState(() => _reading = true);
    try {
      await pasteSubscriptionLink(
        context,
        controller,
        canApply: () => widget.enabled && widget.controller == controller,
      );
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Widget _pillAround(Widget field) =>
      widget.showButtons ? field : PillFieldBox(child: field);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.showButtons ? AppTheme.controlHeight : 48,
    child: Row(
      children: [
        // Paste and Add are islands, the same component as Settings and
        // Refresh in the top bar.
        if (widget.showButtons) ...[
          RoundIconButton(
            key: const ValueKey('paste-subscription'),
            tooltip: context.l10n.pasteClipboard,
            icon: Icons.content_paste_rounded,
            onPressed: widget.enabled && !_reading ? _paste : null,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: _pillAround(
            TextField(
              controller: widget.controller,
              textDirection: TextDirection.ltr,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enabled: widget.enabled,
              style: widget.showButtons ? null : pillFieldTextStyle(context),
              decoration: widget.showButtons
                  ? InputDecoration(labelText: context.l10n.subscriptionLink)
                  : pillFieldDecoration(context, hintText: context.l10n.link),
            ),
          ),
        ),
        if (widget.showButtons) ...[
          const SizedBox(width: 8),
          IslandButton(label: context.l10n.add, onPressed: widget.onLoad),
        ],
      ],
    ),
  );
}
