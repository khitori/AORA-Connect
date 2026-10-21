// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class FloatingBottomNavigation<T> extends StatelessWidget {
  const FloatingBottomNavigation({
    super.key,
    required this.selected,
    required this.destinations,
    required this.onSelected,
  });

  final T selected;
  final List<FloatingNavigationDestination<T>> destinations;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.islandShadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.glass.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.lineStrong),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _NavigationItem<T>(
                        destination: destinations[index],
                        selected: destinations[index].value == selected,
                        onTap: () => onSelected(destinations[index].value),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FloatingNavigationDestination<T> {
  const FloatingNavigationDestination(
    this.value,
    this.label,
    this.icon, {
    this.id,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? id;
}

class _NavigationItem<T> extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavigationDestination<T> destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey(
      'bottom-nav-${destination.id ?? destination.label.toLowerCase()}',
    ),
    color: selected ? AppTheme.selectedSurface : Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      overlayColor: AppTheme.controlOverlayColor,
      child: Semantics(
        selected: selected,
        button: true,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                destination.icon,
                size: 22,
                color: selected ? AppColors.accent : AppColors.muted500,
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? AppColors.ink : AppColors.muted500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
