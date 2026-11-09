// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The glass dialogs' text field: a 48 px see-through gray pill without a
/// border, like their buttons. Put a text field in it built with
/// [pillFieldDecoration] and [pillFieldTextStyle].
///
/// The pill is painted around the field, since a filled dense field fills
/// only its text line, not the whole 48 px.
class PillFieldBox extends StatelessWidget {
  const PillFieldBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.dialogInputBackground,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sectionPadding,
        ),
        child: Center(child: child),
      ),
    ),
  );
}

/// The field's text weighs the same as the pill buttons' labels.
TextStyle? pillFieldTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium;

/// A field that draws nothing itself, for [PillFieldBox]. Errors are shown
/// under the pill by the caller, not inside it.
InputDecoration pillFieldDecoration(BuildContext context, {String? hintText}) =>
    InputDecoration(
      hintText: hintText,
      hintStyle: pillFieldTextStyle(context)
          ?.copyWith(color: AppColors.dialogInputHint),
      filled: false,
      isCollapsed: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
