import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../widgets/storage_meter.dart';
import '../../widgets/labels.dart' show disciplineLabel;

/// One tile in the Footage clip grid (spec §2, screen 5).
class ClipTile extends StatelessWidget {
  const ClipTile({
    super.key,
    required this.recording,
    required this.session,
    required this.onTap,
  });

  final RecordingRow recording;
  final SessionRow session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: recording.duration);
    final durationLabel =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  color: AppColors.gold,
                  size: 28,
                ),
                const Spacer(),
                if (recording.trimmedFlag)
                  const Icon(
                    Icons.content_cut,
                    color: AppColors.onSurfaceFaint,
                    size: 14,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              disciplineLabel(session.discipline),
              style: const TextStyle(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM d').format(session.date),
              style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 11,
                  color: AppColors.onSurfaceFaint,
                ),
                const SizedBox(width: 3),
                Text(
                  durationLabel,
                  style: const TextStyle(
                    color: AppColors.onSurfaceFaint,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  StorageMeter.formatGb(recording.sizeBytes),
                  style: const TextStyle(
                    color: AppColors.onSurfaceFaint,
                    fontSize: 11,
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
