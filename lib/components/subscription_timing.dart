// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SubscriptionTiming extends StatelessWidget {
  const SubscriptionTiming({super.key, this.updatedAt, this.expiresAt});

  final DateTime? updatedAt;
  final DateTime? expiresAt;

  String _date(BuildContext context, DateTime value) {
    final local = value.toLocal();
    return MaterialLocalizations.of(context).formatCompactDate(local);
  }

  @override
  Widget build(BuildContext context) {
    final updated = updatedAt?.toLocal();
    final remaining = expiresAt?.difference(DateTime.now());
    final days = remaining == null
        ? null
        : (remaining.inMilliseconds / Duration.millisecondsPerDay).ceil();
    return Row(
      children: [
        Expanded(
          child: _card(
            context,
            title: context.l10n.lastUpdated,
            icon: Icons.update_rounded,
            value: updated == null
                ? context.l10n.notUpdated
                : _date(context, updated),
            detail: updated == null
                ? ''
                : MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(updated),
                    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                      context,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _card(
            context,
            title: context.l10n.expires,
            icon: Icons.event_outlined,
            value: expiresAt == null
                ? context.l10n.notProvided
                : _date(context, expiresAt!),
            detail: remaining == null
                ? ''
                : remaining <= Duration.zero
                ? context.l10n.expired
                : context.l10n.daysLeft(days!),
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String value,
    required String detail,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      border: Border.all(color: AppColors.lineStrong),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.muted500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted500),
        ),
      ],
    ),
  );
}
