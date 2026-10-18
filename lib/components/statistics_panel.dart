// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/statistics_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_expansion_card.dart';
import 'app_toggle.dart';

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({super.key, required this.statistics});

  final StatisticsController statistics;

  String _pingText(Duration duration) =>
      duration.inMilliseconds == 0 ? '<1 ms' : '${duration.inMilliseconds} ms';

  String _subtitle() {
    if (!statistics.connection.statisticsEnabled) return 'Off';
    if (statistics.active) {
      if (statistics.completedSamples == 0) return 'Server ping · measuring…';
      final latest = statistics.latest;
      return latest == null
          ? 'Server ping · no reply'
          : 'Server ping · ${_pingText(latest)}';
    }
    return 'Connect to view live ICMP statistics';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([statistics, statistics.connection]),
    builder: (context, _) {
      final active = statistics.active;
      final latest = statistics.latest;
      final samples = statistics.samples;
      return AppExpansionCard(
        title: 'Statistics',
        titleAction: AppToggle(
          key: const ValueKey('statistics-toggle'),
          semanticLabel: 'Statistics',
          value: statistics.connection.statisticsEnabled,
          onChanged:
              statistics.connection.busy ||
                  !statistics.connection.serverChecksSupported
              ? null
              : statistics.connection.setStatisticsEnabled,
        ),
        subtitle: _subtitle(),
        icon: Icons.show_chart_rounded,
        children: [
          if (statistics.connection.selectedServerAddress != null) ...[
            Text(
              'Target: ${statistics.connection.selectedServerAddress}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted500),
            ),
            const SizedBox(height: 8),
          ],
          if (active) ...[
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 18, color: AppColors.muted500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latest == null
                        ? statistics.completedSamples == 0
                              ? 'Measuring…'
                              : 'No reply'
                        : _pingText(latest),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statistics.completedSamples == 0
                        ? 'Waiting for samples'
                        : '${statistics.successfulSamples}/${statistics.completedSamples} replies',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Server ping history. '
                  '${statistics.successfulSamples} of ${statistics.completedSamples} completed checks succeeded.',
              child: SizedBox(
                height: 124,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(painter: _LatencyChartPainter(samples)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Server ping every second · last 30 samples. Gaps mean no reply.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted500),
            ),
            if (statistics.liveError != null)
              Text(
                statistics.liveError!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ] else ...[
            Text(
              statistics.connection.statisticsEnabled
                  ? 'Connect to collect live ICMP samples.'
                  : 'Statistics is off.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted500),
            ),
          ],
        ],
      );
    },
  );
}

class _LatencyChartPainter extends CustomPainter {
  const _LatencyChartPainter(this.samples);

  final List<LatencySample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.lineStrong
      ..strokeWidth = 1;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (samples.isEmpty) return;
    final maxMilliseconds = math.max(
      100.0,
      samples.fold<double>(
            0,
            (max, sample) =>
                math.max(max, sample.duration?.inMilliseconds.toDouble() ?? 0),
          ) *
          1.2,
    );
    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = AppColors.accent;
    final failurePaint = Paint()..color = AppColors.accentDark;
    Offset? previous;
    for (var index = 0; index < samples.length; index++) {
      final x = samples.length == 1
          ? size.width / 2
          : index * size.width / (samples.length - 1);
      final duration = samples[index].duration;
      if (duration == null) {
        canvas.drawCircle(Offset(x, size.height - 3), 3, failurePaint);
        previous = null;
        continue;
      }
      final y =
          size.height -
          (duration.inMilliseconds / maxMilliseconds).clamp(0.0, 1.0) *
              (size.height - 8) -
          4;
      final point = Offset(x, y);
      if (previous != null) canvas.drawLine(previous, point, linePaint);
      canvas.drawCircle(point, 2.5, pointPaint);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _LatencyChartPainter oldDelegate) =>
      !identical(oldDelegate.samples, samples);
}
