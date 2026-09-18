import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// GitHub-style consistency heatmap (spec §2, screen 7): one column per
/// week, Monday at the top, darker gold for more sessions that day. A
/// sequential magnitude encoding — one hue, light to dark — never a
/// categorical rainbow, because "more sessions" is a single ordered
/// quantity, not a set of identities.
class ConsistencyHeatmap extends StatelessWidget {
  const ConsistencyHeatmap({
    super.key,
    required this.sessionCountByDay,
    required this.weeks,
  });

  /// Session count keyed by the UTC midnight of each day.
  final Map<DateTime, int> sessionCountByDay;

  /// How many weeks back to show.
  final int weeks;

  static const _cell = 13.0;
  static const _gap = 3.0;

  Color _colorFor(int count) {
    if (count <= 0) return AppColors.lineSoft;
    if (count == 1) return AppColors.gold.withValues(alpha: 0.45);
    if (count == 2) return AppColors.gold.withValues(alpha: 0.75);
    return AppColors.goldStrong;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final currentWeekStart = todayMidnight.subtract(
      Duration(days: todayMidnight.weekday - 1),
    );
    final firstWeekStart = currentWeekStart.subtract(
      Duration(days: 7 * (weeks - 1)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: List.generate(weeks, (week) {
          final weekStart = firstWeekStart.add(Duration(days: 7 * week));
          return Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: Column(
              children: List.generate(7, (dow) {
                final day = weekStart.add(Duration(days: dow));
                final count = sessionCountByDay[day] ?? 0;
                final isFuture = day.isAfter(todayMidnight);
                return Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: Container(
                    width: _cell,
                    height: _cell,
                    decoration: BoxDecoration(
                      color: isFuture ? Colors.transparent : _colorFor(count),
                      borderRadius: BorderRadius.circular(3),
                      border: isFuture
                          ? Border.all(color: AppColors.lineSoft)
                          : null,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
