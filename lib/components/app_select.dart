// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';
import 'unfold_icon.dart';

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
    this.onBeforeOpen,
    this.tapRegionGroupId,
    this.readOnly = false,
    this.showOutline = true,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppTheme.controlRadius),
    ),
    this.menuRadius = AppTheme.controlRadius,
    this.centerText,
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double horizontalPadding;
  final double height;
  final Widget? hint;
  final Widget? selectedChild;
  final ValueChanged<bool>? onOpenChanged;
  final bool Function()? onBeforeOpen;
  final Object? tapRegionGroupId;
  final bool readOnly;

  /// Draws the field like outlined buttons and the navigation panel: white
  /// with two borders ([GlassBorder]). Without it the field is borderless.
  final bool showOutline;
  final BorderRadius borderRadius;

  /// Corner radius of the opened list.
  final double menuRadius;

  /// Centers the selected value in the field and the items in the open list.
  /// Outlined fields are centered by default; borderless ones (such as the
  /// server row) keep their content at the leading edge, full width.
  final bool? centerText;
  bool get _centered => centerText ?? showOutline;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  final _menuFocus = FocusNode(debugLabel: 'AppSelect menu');
  final _defaultGroup = Object();
  late final AnimationController _menuAnimation;
  OverlayEntry? _menuEntry;
  Object get _group => widget.tapRegionGroupId ?? _defaultGroup;
  bool _open = false;
  bool get _enabled => widget.onChanged != null || widget.readOnly;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (_, event) {
      if (_open &&
          event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _hide(restoreFocus: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
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
    _menuFocus.dispose();
    super.dispose();
  }

  /// Closes the menu. Focus returns to the field only for keyboard closing:
  /// focused fields show the hover color, so after a mouse click it looked
  /// as if the field stayed hovered.
  void _hide({T? selected, bool restoreFocus = false}) {
    if (!_open) return;
    _menuEntry?.remove();
    _menuEntry?.dispose();
    _menuEntry = null;
    _menuAnimation.stop();
    setState(() => _open = false);
    widget.onOpenChanged?.call(false);
    if (restoreFocus) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    if (selected != null) {
      if (widget.onBeforeOpen?.call() == false) return;
      widget.onChanged?.call(selected);
    }
  }

  Future<void> _show() async {
    if (_open || !_enabled || widget.items.isEmpty) return;
    if (widget.onBeforeOpen?.call() == false) return;
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
    if (widget.onBeforeOpen?.call() == false) return;
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
      builder: (menuContext) => Directionality(
        textDirection: Directionality.of(context),
        child: Stack(
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
                    // Frosted glass: translucent, blurring what is behind it.
                    child: CustomPaint(
                      foregroundPainter: GlassEdgePainter(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            widget.menuRadius,
                          ),
                        ),
                        cornerWidth: widget.menuRadius,
                        outline: AppColors.line,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.menuRadius),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Material(
                            key: const ValueKey('app-select-menu'),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            color: AppColors.menuGlass,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: availableHeight,
                              ),
                              child: Focus(
                                focusNode: _menuFocus,
                                onKeyEvent: (_, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.escape) {
                                    _hide(restoreFocus: true);
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: widget.items.length,
                                  itemBuilder: (_, index) {
                                    final item = widget.items[index];
                                    return _withSeparator(
                                      index,
                                      InkWell(
                                        overlayColor:
                                            AppTheme.controlOverlayColor,
                                        onTap: item.enabled
                                            ? () => _hide(selected: item.value)
                                            : null,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minHeight: 44,
                                          ),
                                          alignment: widget._centered
                                              ? Alignment.center
                                              : AlignmentDirectional
                                                    .centerStart,
                                          padding: EdgeInsets.symmetric(
                                            horizontal:
                                                widget.horizontalPadding,
                                            vertical: 10,
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
                                                      : Theme.of(context)
                                                            .disabledColor,
                                                ),
                                            child: item.child,
                                          ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_menuEntry!);
    _menuAnimation.forward(from: 0);
    // Explicit, not autofocus: autofocus is skipped while anything else in the
    // window has focus, which left Escape without a handler.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _menuFocus.requestFocus();
    });
  }

  /// Draws the item separator over the top edge of every row but the first.
  /// A separate 1 px row would have no background and show as a light gap
  /// between selected or hovered rows.
  Widget _withSeparator(int index, Widget row) => index == 0
      ? row
      : Stack(
          children: [
            row,
            Positioned(
              top: 0,
              left: widget.horizontalPadding,
              right: widget.horizontalPadding,
              height: 1,
              child: IgnorePointer(child: ColoredBox(color: AppColors.line)),
            ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final selected = widget.items.where((item) => item.value == widget.value);
    final field = TapRegion(
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
            borderRadius: widget.showOutline
                ? BorderRadius.circular(AppTheme.controlRadius)
                : widget.borderRadius,
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
              height: widget.height,
              decoration: widget.showOutline
                  ? null
                  : BoxDecoration(
                      color: AppColors.card,
                      borderRadius: widget.borderRadius,
                      border: widget.showOutline
                          ? Border.all(color: AppColors.lineStrong)
                          : null,
                    ),
              child: SizedBox(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.horizontalPadding,
                  ),
                  child: Row(
                    children: [
                      // Balances the arrow so centered text is truly centered.
                      if (widget._centered) const SizedBox(width: 24),
                      Expanded(
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                color: !_enabled
                                    ? Theme.of(context).disabledColor
                                    : null,
                              ),
                          // Only centered fields are wrapped: other values
                          // (like the server row) must keep the full width.
                          child: Builder(
                            builder: (context) {
                              final value = selected.isEmpty
                                  ? widget.hint ?? const SizedBox.shrink()
                                  : widget.selectedChild ??
                                        selected.first.child;
                              return widget._centered
                                  ? Center(child: value)
                                  : value;
                            },
                          ),
                        ),
                      ),
                      // Same indicator as the Settings sections.
                      UnfoldIcon(
                        open: _open,
                        color: !_enabled
                            ? Theme.of(context).disabledColor
                            : AppColors.muted500,
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
    // Outlined fields get the two-border style; the field itself is clear.
    if (!widget.showOutline) return field;
    // Material draws the shape's borders over the content, so hover
    // highlights stay under them.
    return SizedBox(
      height: widget.height,
      child: Material(
        color: AppColors.card,
        shape: GlassBorder(
          radius: AppTheme.controlRadius,
          side: BorderSide(color: AppColors.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: field,
      ),
    );
  }
}
