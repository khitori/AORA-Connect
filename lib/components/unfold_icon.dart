// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Expand/collapse indicator for sections and dropdowns: a rounded arrow
/// that points down while closed and turns to point up while open.
class UnfoldIcon extends StatelessWidget {
  const UnfoldIcon({super.key, required this.open, this.color});

  final bool open;

  /// Defaults to the surrounding icon color.
  final Color? color;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.5 : 0,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
    child: Icon(Icons.expand_more_rounded, color: color),
  );
}
