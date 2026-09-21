import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A circular progress ring with a value centered inside it — the Today
/// screen's weekly-goal gauge (Winter Arc reference's milestone dial,
/// adapted: martial arts logged here has no per-lift weight/PR to plot
/// against, so this tracks the one number the app already has an honest
/// weekly target for for — mat minutes toward [Goals.weeklyMatMinutesTarget]).
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.progress,
    required this.centerValue,
    required this.centerUnit,
    this.size = 96,
    this.strokeWidth = 8,
  });

  /// 0–1. Values above 1 are clamped — a goal met is full, not overflowing.
  final double progress;
  final String centerValue;
  final String centerUnit;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              color: AppColors.nightBlueWash,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: strokeWidth,
              backgroundColor: Colors.transparent,
              color: AppColors.gold,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: AppTextStyles.numeral(
                  fontSize: 20,
                  color: AppColors.gold,
                ),
              ),
              Text(
                centerUnit,
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
