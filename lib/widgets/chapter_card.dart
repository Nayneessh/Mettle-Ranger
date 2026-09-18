import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/database.dart';

String formatChapterOffset(int offsetMs) {
  final d = Duration(milliseconds: offsetMs);
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// One chapter in the Clip review chapter-jump list, and one entry in the
/// Player screen's live chapter strip (spec §2, screens 3 and 6).
///
/// A MARK chapter (no [ChapterRow.roundRef]) and a round chapter read
/// differently on purpose — a viewer scanning the strip needs to tell "the
/// round changed" from "I flagged this" without reading the label.
class ChapterCard extends StatelessWidget {
  const ChapterCard({
    super.key,
    required this.chapter,
    required this.selected,
    required this.onTap,
  });

  final ChapterRow chapter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMark = chapter.roundRef == null;
    final label = isMark ? 'MARK' : 'Round';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldWash : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMark ? Icons.push_pin : Icons.sports_mma,
              size: 16,
              color: chapter.flagged
                  ? AppColors.gold
                  : AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.goldStrong : AppColors.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              formatChapterOffset(chapter.startOffset),
              style: const TextStyle(
                color: AppColors.onSurfaceFaint,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
