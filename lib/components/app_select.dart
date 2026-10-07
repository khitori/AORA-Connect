// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared selector. Its popup is anchored below the field and scrolls there.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final _focusNode = FocusNode();
  bool _open = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    if (_open || widget.onChanged == null || widget.items.isEmpty) return;
    // If the field is near the bottom of a scrolled page, first bring it up.
    final initialBox = context.findRenderObject()! as RenderBox;
    final initialBottom =
        initialBox.localToGlobal(Offset.zero).dy + initialBox.size.height;
    if (MediaQuery.sizeOf(context).height - initialBottom < 160) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0,
        duration: const Duration(milliseconds: 120),
      );
    }
    if (!mounted || widget.onChanged == null) return;
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(context);
    final top = anchor.bottom + 4;
    final availableHeight =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        top -
        12;
    if (availableHeight <= 0) return;
    setState(() => _open = true);
    final selected = await showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close selector',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (_, _, _, child) => child,
      pageBuilder: (menuContext, animation, _) => Stack(
        children: [
          Positioned(
            left: anchor.left,
            top: top,
            width: anchor.width,
            child: FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: Material(
                  key: const ValueKey('app-select-menu'),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: availableHeight),
                    child: Focus(
                      autofocus: true,
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.escape) {
                          Navigator.of(menuContext).pop();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: widget.items
                            .map(
                              (item) => InkWell(
                                onTap: item.enabled
                                    ? () =>
                                          Navigator.of(menuContext)
                                              .pop(item.value)
                                    : null,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  color: item.value == widget.value
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.08)
                                      : null,
                                  child: DefaultTextStyle(
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: item.enabled
                                              ? null
                                              : Theme.of(context).disabledColor,
                                        ),
                                    child: item.child,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    _focusNode.requestFocus();
    if (selected != null) widget.onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.items.where((item) => item.value == widget.value);
    return Semantics(
      button: true,
      enabled: widget.onChanged != null,
      expanded: _open,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: _focusNode,
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onChanged == null ? null : _show,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: widget.onChanged == null
                            ? Theme.of(context).disabledColor
                            : null,
                      ),
                      child: selected.isEmpty
                          ? const SizedBox.shrink()
                          : selected.first.child,
                    ),
                  ),
                  Icon(
                    _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: widget.onChanged == null
                        ? Theme.of(context).disabledColor
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
