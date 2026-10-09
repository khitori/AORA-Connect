// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppExpansionCard extends StatelessWidget {
  const AppExpansionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.titleAction,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? titleAction;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    elevation: 1,
    shadowColor: AppColors.islandShadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      side: BorderSide(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('section-$title'),
        initiallyExpanded: initiallyExpanded,
        minTileHeight: 64,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        ),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.paperDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted400),
                  ),
                ],
              ),
            ),
            ?titleAction,
          ],
        ),
        children: [
          Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
