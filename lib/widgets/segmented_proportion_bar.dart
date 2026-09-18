import 'package:flutter/material.dart';

import '../app_theme.dart';

class ProportionSegment {
  const ProportionSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// A single horizontal bar split into proportional segments, with a legend
/// below carrying the percentage as a direct label. Used for the Progress
/// tab's sparring-to-drilling ratio and discipline split (spec §2, screen
/// 7) — a stacked bar reads shares more accurately than a pie once there
/// are more than two or three of them, and never needs arc-label collision
/// handling.
///
/// Colors are assigned by the caller in a fixed order (never cycled here),
/// and every segment carries its own text label — identity is never color
/// alone.
class SegmentedProportionBar extends StatelessWidget {
  const SegmentedProportionBar({super.key, required this.segments});

  final List<ProportionSegment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0.0, (sum, s) => sum + s.value);
    final visible = segments.where((s) => s.value > 0).toList();

    if (total <= 0 || visible.isEmpty) {
      return const Text(
        'Not enough data yet.',
        style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 12.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final segment in visible)
                  Expanded(
                    flex: (segment.value / total * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: segment.color,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final segment in visible)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: segment.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${segment.label} ${(segment.value / total * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
