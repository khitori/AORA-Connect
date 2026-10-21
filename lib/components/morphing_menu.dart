// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

class MorphingMenuEntry<T> {
  const MorphingMenuEntry(this.value, this.label, this.icon);
  final T value;
  final String label;
  final IconData icon;
}

/// One surface grows from the toolbar button into its naturally sized content.
class MorphingMenuShell<T> extends StatefulWidget {
  const MorphingMenuShell({
    super.key,
    required this.child,
    required this.entries,
    required this.selected,
    required this.onSelected,
    this.itemSpacing = 8,
    this.rightInset = 12,
    this.topInset = 6,
    this.barrierTopInset = 0,
  });
  final Widget child;
  final List<MorphingMenuEntry<T>> entries;
  final T selected;
  final ValueChanged<T> onSelected;
  final double itemSpacing;
  final double rightInset;
  final double topInset;
  final double barrierTopInset;

  @override
  State<MorphingMenuShell<T>> createState() => _MorphingMenuShellState<T>();
}

class _MorphingMenuShellState<T> extends State<MorphingMenuShell<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _menuFocus = FocusScopeNode();
  final _buttonFocus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      setState(() => _open = true);
      _controller.forward();
      _menuFocus.requestFocus();
    }
  }

  void _close() {
    setState(() => _open = false);
    _controller.reverse();
    _buttonFocus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _menuFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  Widget _menuItems(ColorScheme colors) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Column(
      spacing: widget.itemSpacing,
      mainAxisSize: MainAxisSize.min,
      children: widget.entries
          .map(
            (entry) => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    _close();
                    widget.onSelected(entry.value);
                  },
                  style: TextButton.styleFrom(
                    alignment: AlignmentDirectional.centerStart,
                    foregroundColor: colors.onSecondaryContainer,
                    backgroundColor: entry.value == widget.selected
                        ? AppTheme.selectedSurface
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.controlRadius,
                      ),
                    ),
                  ),
                  icon: Icon(entry.icon, size: 20),
                  label: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expandedWidth = math.min(
      208.0,
      MediaQuery.sizeOf(context).width - widget.rightInset - 12,
    );
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(_controller.value);
        final visible = _open || !_controller.isDismissed;
        final reveal = const Interval(
          0.35,
          1,
          curve: Curves.easeOut,
        ).transform(_controller.value);
        return Stack(
          children: [
            child!,
            if (visible)
              Positioned(
                top: widget.barrierTopInset,
                left: 0,
                right: 0,
                bottom: 0,
                child: ModalBarrier(
                  color: Colors.transparent,
                  dismissible: true,
                  onDismiss: _close,
                  semanticsLabel: context.l10n.closeMenu,
                ),
              ),
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + widget.topInset,
              end: widget.rightInset,
              child: FocusScope(
                node: _menuFocus,
                onKeyEvent: (_, event) {
                  if (_open &&
                      event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    _close();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: SizedBox(
                  width: lerpDouble(44, expandedWidth, progress),
                  child: Material(
                    key: const ValueKey('morphing-menu-surface'),
                    color: colors.secondaryContainer,
                    elevation: lerpDouble(0, 6, progress)!,
                    // --- Dropdown Rounded ---
                    borderRadius: BorderRadius.circular(
                      lerpDouble(22, 24, progress)!,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ClipRect(
                                child: Opacity(
                                  opacity: reveal,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 16,
                                    ),
                                    child: Text(
                                      context.l10n.menu,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              height: 44,
                              // --- Menu Button ---
                              child: IconButton(
                                focusNode: _buttonFocus,
                                tooltip: _open
                                    ? context.l10n.closeMenu
                                    : context.l10n.openMenu,
                                onPressed: _toggle,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    _open ? Icons.close : Icons.menu,
                                    key: ValueKey(_open),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (visible)
                          ClipRect(
                            child: Align(
                              alignment: Alignment.topRight,
                              // Reveal a fraction of the actual content height.
                              // Padding, spacing and button sizes participate in layout.
                              heightFactor: progress,
                              child: OverflowBox(
                                alignment: Alignment.topRight,
                                fit: OverflowBoxFit.deferToChild,
                                minWidth: expandedWidth,
                                maxWidth: expandedWidth,
                                child: IgnorePointer(
                                  ignoring: !_open || _controller.value < 0.9,
                                  child: ExcludeFocus(
                                    excluding: !_open,
                                    child: Opacity(
                                      opacity: reveal,
                                      child: _menuItems(colors),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
