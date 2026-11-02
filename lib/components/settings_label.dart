// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The name of a subsection inside a Settings section, such as "Interface
/// language" above its select. Every subsection in Settings uses it.
class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key, this.color});

  final String text;

  /// The Settings gray when not given. Glass dialogs pass a darker gray,
  /// which reads better over the blur.
  final Color? color;

  // Aligned itself: Settings sections center their contents.
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.subsectionLabel,
      ),
    ),
  );
}
