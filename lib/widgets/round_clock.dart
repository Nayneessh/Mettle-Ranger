import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../domain/round_timer.dart';

/// The Session Player's full-screen round clock (spec §2, screen 3).
///
/// Large enough to read from arm's length mid-round, which is the whole
/// point — nobody stops sparring to squint at a phone.
class RoundClock extends StatelessWidget {
  const RoundClock({super.key, required this.tick, required this.totalRounds});

  final TimerTick tick;
  final int totalRounds;

  @override
  Widget build(BuildContext context) {
    final remaining = Duration(milliseconds: tick.remainingInPhaseMs);
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isResting = tick.phase == TimerPhase.resting;
    final isFinished = tick.phase == TimerPhase.finished;

    final phaseColor = isFinished
        ? AppColors.gold
        : isResting
        ? AppColors.onSurfaceMuted
        : AppColors.liveGreen;
    final phaseLabel = isFinished
        ? 'SESSION COMPLETE'
        : isResting
        ? 'REST'
        : 'WORKING';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ROUND ${tick.roundNumber} OF $totalRounds',
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$minutes:$seconds',
          style: AppTextStyles.numeral(fontSize: 96, color: phaseColor),
        ),
        const SizedBox(height: 4),
        Text(
          phaseLabel,
          style: TextStyle(
            color: phaseColor,
            fontSize: 16,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
