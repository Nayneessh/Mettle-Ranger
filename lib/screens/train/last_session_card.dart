import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../widgets/labels.dart' show disciplineLabelForKey;

/// The Train screen's "last session" card (spec §2, screen 1) — the most
/// recent entry in the log, always real data, never a placeholder number.
class LastSessionCard extends StatelessWidget {
  const LastSessionCard({super.key, required this.session, this.onTap});

  final SessionRow session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final matMinutes = session.matTime ~/ 60;
    final dateLabel = DateFormat('EEE, MMM d').format(session.date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.goldWash,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                disciplineLabelForKey(session.discipline).characters.first,
                style: const TextStyle(
                  color: AppColors.goldStrong,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disciplineLabelForKey(session.discipline),
                    style: const TextStyle(
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateLabel · ${matMinutes}m mat time',
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (session.sRpe != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'RPE ${session.sRpe}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceFaint,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
