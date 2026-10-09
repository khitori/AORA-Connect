// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shared selector. Its popup is anchored below the field and scrolls there.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.horizontalPadding = 12,
    this.height = AppTheme.controlHeight,
    this.hint,
    this.selectedChild,
    this.onOpenChanged,
    this.tapRegionGroupId,
    this.readOnly = false,
    this.showOutline = true,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppTheme.controlRadius),
    ),
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double horizontalPadding;
  final double height;
  final Widget? hint;
  final Widget? selectedChild;
  final ValueChanged<bool>? onOpenChanged;
  final Object? tapRegionGroupId;
  final bool readOnly;
  final bool showOutline;
  final BorderRadius borderRadius;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  final _defaultGroup = Object();
  late final AnimationController _menuAnimation;
  OverlayEntry? _menuEntry;
  Object get _group => widget.tapRegionGroupId ?? _defaultGroup;
  bool _open = false;
  bool get _enabled => widget.onChanged != null || widget.readOnly;

  @override
  void initState() {
    super.initState();
    _menuAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void didUpdateWidget(covariant AppSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_menuEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _menuEntry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    _menuEntry?.remove();
    _menuEntry?.dispose();
    _menuAnimation.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _hide([T? selected]) {
    if (!_open) return;
    _menuEntry?.remove();
    _menuEntry?.dispose();
    _menuEntry = null;
    _menuAnimation.stop();
    setState(() => _open = false);
    widget.onOpenChanged?.call(false);
    _focusNode.requestFocus();
    if (selected != null) widget.onChanged?.call(selected);
  }

  Future<void> _show() async {
    if (_open || !_enabled || widget.items.isEmpty) return;
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
    if (!mounted || !_enabled) return;
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
    widget.onOpenChanged?.call(true);
    _menuEntry = OverlayEntry(
      builder: (menuContext) => Stack(
        children: [
          Positioned(
            left: anchor.left,
            top: top,
            width: anchor.width,
            child: TapRegion(
              groupId: _group,
              onTapOutside: (_) => _hide(),
              child: FadeTransition(
                opacity: _menuAnimation,
                child: SizeTransition(
                  sizeFactor: _menuAnimation,
                  alignment: Alignment.topCenter,
                  child: Material(
                    key: const ValueKey('app-select-menu'),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.controlRadius,
                      ),
                      side: BorderSide(color: AppColors.lineStrong),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: availableHeight),
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: (_, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.escape) {
                            _hide();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: widget.items.length,
                          itemBuilder: (_, index) {
                            final item = widget.items[index];
                            return InkWell(
                              overlayColor: AppTheme.controlOverlayColor,
                              onTap: item.enabled
                                  ? () => _hide(item.value)
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
                                    ? AppTheme.selectedSurface
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
                            );
                          },
                        ),
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
    Overlay.of(context, rootOverlay: true).insert(_menuEntry!);
    _menuAnimation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.items.where((item) => item.value == widget.value);
    return TapRegion(
      groupId: _group,
      child: Semantics(
        button: true,
        enabled: _enabled,
        expanded: _open,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            focusNode: _focusNode,
            overlayColor: AppTheme.controlOverlayColor,
            borderRadius: widget.borderRadius,
            onTap: _enabled
                ? () {
                    if (_open) {
                      _hide();
                    } else {
                      _show();
                    }
                  }
                : null,
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: widget.borderRadius,
                border: widget.showOutline
                    ? Border.all(color: AppColors.lineStrong)
                    : null,
              ),
              child: SizedBox(
                height: widget.height,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.horizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                color: !_enabled
                                    ? Theme.of(context).disabledColor
                                    : null,
                              ),
                          child: selected.isEmpty
                              ? widget.hint ?? const SizedBox.shrink()
                              : widget.selectedChild ?? selected.first.child,
                        ),
                      ),
                      Icon(
                        _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: !_enabled
                            ? Theme.of(context).disabledColor
                            : null,
                      ),
                    ],
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
