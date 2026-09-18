import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';

class WeekMatTime {
  const WeekMatTime({required this.weekStart, required this.minutes});
  final DateTime weekStart;
  final int minutes;
}

/// Mat time by week (spec §2, screen 7): a magnitude-over-time bar chart —
/// one sequential hue (gold), thin bars, recessive gridlines, and a value
/// only on touch rather than stamped on every bar.
class MatTimeChart extends StatelessWidget {
  const MatTimeChart({super.key, required this.weeks});

  final List<WeekMatTime> weeks;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = weeks.fold(0, (m, w) => w.minutes > m ? w.minutes : m);
    final chartMax = (maxMinutes == 0 ? 60 : (maxMinutes * 1.25)).toDouble();

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: chartMax / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.lineSoft, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  final label = 'W${i + 1}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.onSurfaceFaint,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    '${rod.toY.round()} min',
                    const TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < weeks.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: weeks[i].minutes.toDouble(),
                    color: AppColors.gold,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
