// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';
import 'section_row_bleed.dart';

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
    this.hoverHighlight = true,
    this.plain = false,
    this.pill = false,
    this.fieldColor,
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double horizontalPadding;

  // Plain rows and pill fields share the 48 px pill: its side padding, value
  // text, and a menu with the same corners and 48 px items.
  bool get _pill => plain || pill;

  // Plain rows use the section row padding, so their value lines up with the
  // section content; the row reaches out by the same amount.
  double get _sidePadding =>
      _pill ? AppTheme.sectionPadding : horizontalPadding;

  // A pill's menu has the same corners as the pill's ends.
  double get _menuRadius => _pill ? AppTheme.sectionRowRadius : menuRadius;
  final double height;
  final Widget? hint;
  final Widget? selectedChild;
  final ValueChanged<bool>? onOpenChanged;
  final bool Function()? onBeforeOpen;
  final Object? tapRegionGroupId;
  final bool readOnly;

  /// Draws the field like outlined buttons: white with the white glass edge
  /// ([GlassBorder]), no grey outline. Without it the field is borderless.
  final bool showOutline;
  final BorderRadius borderRadius;

  /// Corner radius of the opened list.
  final double menuRadius;

  /// Centers the selected value in the field and the items in the open list.
  /// Outlined fields are centered by default; borderless ones (such as the
  /// server row) keep their content at the leading edge, full width.
  final bool? centerText;
  bool get _centered => centerText ?? (showOutline && !plain);

  /// Tints the field while the mouse is over it. Pressed and keyboard focus
  /// tints stay either way.
  final bool hoverHighlight;

  /// The Settings row: no field around it, the value at the leading edge with
  /// the same side padding as the menu items, and the arrow at the end. It
  /// tints as a pill on hover.
  final bool plain;

  /// The Settings row's 48 px pill as a white outlined field (with
  /// [showOutline]), for selects outside sections. Its text stays centered
  /// unless [centerText] says otherwise.
  final bool pill;

  /// Fill of an outlined field; white when not given. Glass dialogs pass
  /// their see-through gray ([AppColors.glassControl]).
  final Color? fieldColor;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  final _menuFocus = FocusNode(debugLabel: 'AppSelect menu');
  final _defaultGroup = Object();
  late final AnimationController _menuAnimation;
  late final CurvedAnimation _menuCurve;
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
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _menuCurve = CurvedAnimation(
      parent: _menuAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
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
    _removeMenu();
    _menuCurve.dispose();
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
    setState(() => _open = false);
    // The menu plays its opening backwards, ignoring the pointer, and is
    // removed afterwards. Reopening meanwhile replaces it at once.
    final closing = _menuEntry?..markNeedsBuild();
    _menuAnimation.reverse().whenCompleteOrCancel(() {
      if (!_open && identical(_menuEntry, closing)) _removeMenu();
    });
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

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry?.dispose();
    _menuEntry = null;
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
    var anchor = box.localToGlobal(Offset.zero) & box.size;
    // The list lines up with the reached-out row, not its slot.
    if (widget.plain) {
      anchor = Rect.fromLTRB(
        anchor.left - AppTheme.sectionPadding,
        anchor.top,
        anchor.right + AppTheme.sectionPadding,
        anchor.bottom,
      );
    }
    final media = MediaQuery.of(context);
    final top = anchor.bottom + 4;
    final availableHeight =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        top -
        12;
    if (availableHeight <= 0) return;
    _removeMenu();
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
                child: IgnorePointer(
                  ignoring: !_open,
                  // Pops out of the field: grows from 90% at its top edge
                  // while dropping the last few pixels into place.
                  child: AnimatedBuilder(
                    animation: _menuCurve,
                    builder: (_, child) {
                      final t = _menuCurve.value;
                      return Transform.translate(
                        offset: Offset(0, -6 * (1 - t)),
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * t,
                          alignment: Alignment.topCenter,
                          child: CustomPaint(
                            foregroundPainter: GlassEdgePainter(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  widget._menuRadius,
                                ),
                              ),
                              cornerWidth: widget._menuRadius,
                              outline: AppColors.line,
                              opacity: t,
                            ),
                            // Frosted glass: translucent, blurring what is
                            // behind it. The blur grows with the fade instead
                            // of sitting inside it: a blur inside a fading
                            // layer has nothing behind it to blur.
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                widget._menuRadius,
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 6 * t,
                                  sigmaY: 6 * t,
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: FadeTransition(
                      opacity: _menuCurve,
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
                                    overlayColor: AppTheme.controlOverlayColor,
                                    onTap: item.enabled
                                        ? () => _hide(selected: item.value)
                                        : null,
                                    child: Container(
                                      // A plain row's items are as tall as
                                      // the row itself.
                                      constraints: BoxConstraints(
                                        minHeight: widget._pill ? 48 : 44,
                                      ),
                                      alignment: widget._centered
                                          ? Alignment.center
                                          : AlignmentDirectional.centerStart,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: widget._sidePadding,
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
              left: widget._sidePadding,
              right: widget._sidePadding,
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
            overlayColor: widget.hoverHighlight
                ? AppTheme.controlOverlayColor
                : WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) &&
                            !states.contains(WidgetState.pressed) &&
                            !states.contains(WidgetState.focused)
                        ? Colors.transparent
                        : AppTheme.controlOverlayColor.resolve(states),
                  ),
            // Pills tint as a pill.
            customBorder: widget._pill ? const StadiumBorder() : null,
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
              height: widget._pill ? 48 : widget.height,
              decoration: widget.showOutline || widget.plain
                  ? null
                  : BoxDecoration(
                      color: AppColors.card,
                      borderRadius: widget.borderRadius,
                    ),
              child: SizedBox(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget._sidePadding,
                  ),
                  child: Row(
                    children: [
                      // Balances the arrow so centered text is truly centered.
                      if (widget._centered) const SizedBox(width: 24),
                      Expanded(
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontSize: widget._pill ? 16 : null,
                                // Settings rows are regular; a pill field's
                                // chosen value is bold.
                                fontWeight: widget.plain
                                    ? FontWeight.w400
                                    : widget.pill
                                    ? FontWeight.w600
                                    : null,
                                color: !_enabled
                                    ? Theme.of(context).disabledColor
                                    : widget._pill
                                    ? AppColors.selectValue
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
                      // Points right, and down at the list while it is open.
                      AnimatedRotation(
                        turns: _open ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: !_enabled
                              ? Theme.of(context).disabledColor
                              : AppColors.muted500,
                        ),
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
    if (widget.plain) return SectionRowBleed(child: field);
    if (!widget.showOutline) return field;
    // Material draws the shape's borders over the content, so hover
    // highlights stay under them.
    return SizedBox(
      height: widget._pill ? 48 : widget.height,
      child: Material(
        color: widget.fieldColor ?? AppColors.card,
        // A pill field is plain white, without the glass edge.
        shape: widget._pill
            ? const StadiumBorder()
            : const GlassBorder(
                radius: AppTheme.controlRadius,
                side: BorderSide.none,
              ),
        clipBehavior: Clip.antiAlias,
        child: field,
      ),
    );
  }
}
