import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Seven days, Monday first, each marked if a session happened that day.
/// The Train screen's week strip (spec §2, screen 1).
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.daysWithSession,
    required this.today,
  });

  /// The Monday that starts this week.
  final DateTime weekStart;

  /// Which of the 7 days (0 = Monday .. 6 = Sunday) had at least one session.
  final Set<int> daysWithSession;
  final DateTime today;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final isToday =
            day.year == today.year &&
            day.month == today.month &&
            day.day == today.day;
        final trained = daysWithSession.contains(i);
        final isFuture = day.isAfter(today);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 11,
                color: isToday ? AppColors.gold : AppColors.onSurfaceFaint,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: trained ? AppColors.gold : Colors.transparent,
                border: Border.all(
                  color: isToday
                      ? AppColors.gold
                      : (isFuture ? AppColors.lineSoft : AppColors.line),
                  width: isToday ? 1.5 : 1,
                ),
              ),
              child: trained
                  ? const Icon(Icons.check, size: 16, color: Color(0xFF241B00))
                  : Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isFuture
                            ? AppColors.onSurfaceFaint
                            : AppColors.onSurfaceMuted,
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}
