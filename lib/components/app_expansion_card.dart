// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';
import 'unfold_icon.dart';

/// The same large corner radius whether collapsed or expanded.
const _radius = AppTheme.sectionRadius;

/// Corners of the 40 px header icon box: heavily rounded, not a circle.
const _iconBoxRadius = 14.0;
const _motion = Duration(milliseconds: 240);

class AppExpansionCard extends StatefulWidget {
  const AppExpansionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.titleAction,
    this.storageId,
    this.initiallyExpanded = false,
    this.contentTopPadding = AppTheme.sectionContentTopPadding,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? titleAction;
  final String? storageId;
  final bool initiallyExpanded;
  final double contentTopPadding;

  @override
  State<AppExpansionCard> createState() => _AppExpansionCardState();
}

class _AppExpansionCardState extends State<AppExpansionCard>
    with SingleTickerProviderStateMixin {
  // Also reports sections reopened from saved page state.
  final _expansion = ExpansibleController();
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: _motion,
    value: widget.initiallyExpanded ? 1 : 0,
  );
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _expansion.addListener(_expansionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _shown = true);
  }

  // The tile reports sections that start open while the page is still being
  // built, when rebuilding is not allowed, so the change is applied after the
  // frame. Before the card was first shown it snaps instead of animating.
  void _expansionChanged() {
    final animate = _shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _expansion.isExpanded ? 1.0 : 0.0;
      if (animate) {
        _open.animateTo(target, curve: Curves.easeOutCubic);
      } else {
        _open.value = target;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _expansion.removeListener(_expansionChanged);
    _expansion.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _open,
    builder: (context, _) {
      final open = _open.value;
      final radius = BorderRadius.circular(_radius);
      final theme = Theme.of(context);
      return Material(
        color: AppColors.sectionBackground,
        elevation: 1,
        shadowColor: AppColors.sectionShadow,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // No hover on the section header, and 20 px between its icon and
          // title. Its contents get the normal theme back below, so their own
          // controls keep hover and their rows keep the normal gap.
          data: theme.copyWith(
            dividerColor: Colors.transparent,
            hoverColor: Colors.transparent,
            listTileTheme: theme.listTileTheme.copyWith(horizontalTitleGap: 20),
          ),
          child: ExpansionTile(
            key: PageStorageKey('section-${widget.storageId ?? widget.title}'),
            controller: _expansion,
            textColor: AppColors.sectionTitle,
            collapsedTextColor: AppColors.sectionTitle,
            initiallyExpanded: widget.initiallyExpanded,
            minTileHeight: 64,
            // The header and the content are inset by the hoverable rows'
            // padding, so the icon, separator, names and text line up with the
            // text inside those rows.
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16 + AppTheme.sectionPadding,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              16 + AppTheme.sectionPadding,
              0,
              16 + AppTheme.sectionPadding,
              AppTheme.sectionContentTopPadding,
            ),
            shape: RoundedRectangleBorder(borderRadius: radius),
            collapsedShape: RoundedRectangleBorder(borderRadius: radius),
            // Arrow down while collapsed, up while expanded. A header switch
            // sits next to it as one group, so the text keeps the same gap
            // before it as after the icon and wraps before reaching it.
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.titleAction case final action?) ...[
                  action,
                  const SizedBox(width: 8),
                ],
                UnfoldIcon(
                  open: open > 0.5,
                  color: Color.lerp(
                    AppColors.sectionArrow,
                    AppColors.sectionArrowOpen,
                    open,
                  ),
                ),
              ],
            ),
            // The icon box uses the islands' glass style: a heavily rounded
            // square rather than a circle.
            leading: GlassSurface(
              backgroundTop: AppColors.sectioniconboxBackgroundTop,
              backgroundBottom: AppColors.sectioniconboxBackgroundBottom,
              innerBorder: AppColors.sectioniconboxInnerBorder,
              outerBorder: AppColors.sectioniconboxOuterBorder,
              shadow: AppColors.sectioniconboxShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_iconBoxRadius),
              ),
              cornerWidth: _iconBoxRadius,
              child: SizedBox(
                width: 40,
                height: 40,
                // The open section's icon turns red; it glows like the
                // other active icons.
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: Color.lerp(
                    AppColors.sectionIcon,
                    AppColors.sectionIconOpen,
                    open,
                  ),
                  shadows: [
                    Shadow(
                      color: AppColors.faded(AppColors.sectionIconGlow, open),
                      blurRadius: 9,
                    ),
                  ],
                ),
              ),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.sectionSubtitle),
                ),
              ],
            ),
            children: [
              Divider(height: 1, color: AppColors.sectionDivider),
              SizedBox(height: widget.contentTopPadding),
              for (final child in widget.children)
                Theme(data: theme, child: child),
            ],
          ),
        ),
      );
    },
  );
}
