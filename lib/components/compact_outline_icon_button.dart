// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'window_controls.dart';

/// The app's small single-icon action, drawn as a round island like the
/// top bar's Settings button.
class CompactOutlineIconButton extends StatelessWidget {
  const CompactOutlineIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      RoundIconButton(tooltip: tooltip, icon: icon, onPressed: onPressed);
}
