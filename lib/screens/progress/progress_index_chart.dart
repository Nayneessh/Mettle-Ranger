import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../domain/progress_index.dart';

/// The Progress tab's load-over-time line: the martial-arts "strength
/// index" (reference app's own name for its equivalent chart) — a filled
/// gold line tracking total training load per bucket across the selected
/// range.
class ProgressIndexChart extends StatelessWidget {
  const ProgressIndexChart({super.key, required this.buckets});

  final List<LoadBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxLoad = buckets.fold(
      0,
      (m, b) => b.totalLoad > m ? b.totalLoad : m,
    );
    final chartMax = (maxLoad == 0 ? 100 : maxLoad * 1.2).toDouble();
    final spots = [
      for (var i = 0; i < buckets.length; i++)
        FlSpot(i.toDouble(), buckets[i].totalLoad.toDouble()),
    ];

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: chartMax,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: chartMax / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.lineSoft, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${s.y.round()}',
                      const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.gold,
              barWidth: 2.5,
              dotData: FlDotData(
                show: spots.length <= 1,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(radius: 3, color: AppColors.gold),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.25),
                    AppColors.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
