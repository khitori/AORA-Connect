// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppToggle extends StatefulWidget {
  static const compactVerticalPadding = 5.0;

  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final bool compact;

  @override
  State<AppToggle> createState() => _AppToggleState();
}

class _AppToggleState extends State<AppToggle> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final base = widget.value ? AppColors.accent : AppColors.lineStrong;
    final track = enabled && (_hovered || _focused || _pressed)
        ? Color.alphaBlend(
            AppColors.ink.withValues(alpha: _pressed ? 0.12 : 0.06),
            base,
          )
        : base;
    void toggle() => widget.onChanged?.call(!widget.value);
    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? toggle : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? toggle : null,
            customBorder: const StadiumBorder(),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 2,
                vertical: widget.compact
                    ? AppToggle.compactVerticalPadding
                    : 11,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 26,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: enabled ? track : track.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: widget.value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      boxShadow: enabled
                          ? [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.12),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
