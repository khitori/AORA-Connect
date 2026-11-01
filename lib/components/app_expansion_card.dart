// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_surface.dart';
import 'unfold_icon.dart';

/// The same large corner radius whether collapsed or expanded.
const _radius = 24.0;
const _iconBoxRadius = 10.0;
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
        color: AppColors.card,
        elevation: 1,
        shadowColor: AppColors.islandShadow,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // No hover on the section header. Its contents get the normal
          // theme back below, so their own controls keep hover.
          data: theme.copyWith(
            dividerColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: ExpansionTile(
            key: PageStorageKey('section-${widget.storageId ?? widget.title}'),
            controller: _expansion,
            initiallyExpanded: widget.initiallyExpanded,
            minTileHeight: 64,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: radius),
            collapsedShape: RoundedRectangleBorder(borderRadius: radius),
            // Arrow down while collapsed, up while expanded.
            trailing: UnfoldIcon(open: open > 0.5),
            // The icon box uses the islands' glass style.
            leading: GlassSurface(
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
                  shadows: [
                    Shadow(
                      color: AppColors.accent.withValues(alpha: 0.45 * open),
                      blurRadius: 9,
                    ),
                  ],
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted400),
                      ),
                    ],
                  ),
                ),
                ?widget.titleAction,
              ],
            ),
            children: [
              Divider(height: 1, color: AppColors.line),
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
