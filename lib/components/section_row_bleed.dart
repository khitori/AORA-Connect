// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../theme/app_theme.dart';

/// Lets a hoverable row in a section reach [AppTheme.sectionPadding] past
/// both sides of the content, so its hover shape keeps its width while its
/// padded text lines up with the rest of the section. The extra edges are
/// drawn but take no pointer input.
class SectionRowBleed extends StatelessWidget {
  const SectionRowBleed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth + 2 * AppTheme.sectionPadding;
      return OverflowBox(
        minWidth: width,
        maxWidth: width,
        fit: OverflowBoxFit.deferToChild,
        child: child,
      );
    },
  );
}
