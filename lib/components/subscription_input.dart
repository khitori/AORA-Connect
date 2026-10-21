// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../profiles/subscription_loader.dart';
import '../theme/app_theme.dart';
import 'app_notification.dart';

class SubscriptionInput extends StatefulWidget {
  const SubscriptionInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onLoad,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onLoad;

  @override
  State<SubscriptionInput> createState() => _SubscriptionInputState();
}

class _SubscriptionInputState extends State<SubscriptionInput> {
  bool _reading = false;

  Future<void> _paste() async {
    if (_reading || !widget.enabled) return;
    final controller = widget.controller;
    final previous = controller.value;
    setState(() => _reading = true);
    try {
      final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text
          ?.trim();
      if (!mounted ||
          !widget.enabled ||
          widget.controller != controller ||
          controller.value != previous) {
        return;
      }
      if (value == null || !isSupportedSubscriptionInput(value)) {
        AppNotification.show(context, context.l10n.copyLinkFirst);
        return;
      }
      widget.controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    } catch (_) {
      if (mounted) {
        AppNotification.show(context, context.l10n.clipboardReadFailed);
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppTheme.controlHeight,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: context.l10n.pasteClipboard,
          child: SizedBox(
            width: AppTheme.controlHeight,
            child: OutlinedButton(
              key: const ValueKey('paste-subscription'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: widget.enabled && !_reading ? _paste : null,
              child: const Icon(Icons.content_paste_rounded, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            textDirection: TextDirection.ltr,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: context.l10n.subscriptionLink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: widget.onLoad, child: Text(context.l10n.add)),
      ],
    ),
  );
}
