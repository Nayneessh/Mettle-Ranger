import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../data/database.dart';
import '../providers.dart';

/// The scoring log: a running total plus quick-tap point buttons, shared by
/// Player (live, while sparring) and Clip Review (after the fact) via the
/// same session id — a point logged in one place shows up immediately in
/// the other, since both watch [scoresStreamProvider] for that session.
class ScoreBar extends ConsumerWidget {
  const ScoreBar({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(scoresStreamProvider(sessionId));
    final scores = scoresAsync.valueOrNull ?? const <ScoreRow>[];
    final total = scores.fold(0, (t, s) => t + s.points);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text(
            'SCORE',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$total',
            style: AppTextStyles.numeral(fontSize: 20, color: AppColors.gold),
          ),
          const Spacer(),
          for (final points in [1, 2, 5])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: OutlinedButton(
                onPressed: () => ref
                    .read(scoreDaoProvider)
                    .addScore(
                      ScoresCompanion.insert(
                        session: sessionId,
                        points: points,
                        createdAt: DateTime.now(),
                      ),
                    ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 0),
                ),
                child: Text('+$points', style: const TextStyle(fontSize: 12)),
              ),
            ),
          if (scores.isNotEmpty)
            IconButton(
              onPressed: () =>
                  ref.read(scoreDaoProvider).deleteScore(scores.last.id),
              icon: const Icon(
                Icons.undo,
                size: 18,
                color: AppColors.onSurfaceFaint,
              ),
              tooltip: 'Undo last point',
            ),
        ],
      ),
    );
  }
}
