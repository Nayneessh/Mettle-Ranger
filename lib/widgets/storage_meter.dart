import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../domain/storage_policy.dart';

/// Persistent storage readout used on Footage (spec §2, screen 5) and the
/// live readout on Session Player (screen 3).
///
/// Formats bytes the way a phone's own storage settings would — GB to one
/// decimal place — rather than raw byte counts nobody can size up at a
/// glance.
class StorageMeter extends StatelessWidget {
  const StorageMeter({
    super.key,
    required this.usedBytes,
    required this.freeBytes,
    this.compact = false,
  });

  final int usedBytes;
  final int freeBytes;
  final bool compact;

  static String formatGb(int bytes) =>
      '${(bytes / kBytesPerGigabyte).toStringAsFixed(1)} GB';

  @override
  Widget build(BuildContext context) {
    final total = usedBytes + freeBytes;
    final fraction = total == 0 ? 0.0 : (usedBytes / total).clamp(0.0, 1.0);
    final tight = freeBytes < kWarnFreeBytesThreshold;

    final barColor = freeBytes < kMinFreeBytesToStart
        ? AppColors.critical
        : tight
        ? AppColors.warning
        : AppColors.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: compact ? 6 : 10,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${formatGb(usedBytes)} used',
              style: TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: compact ? 11 : 13,
              ),
            ),
            Text(
              '${formatGb(freeBytes)} free',
              style: TextStyle(
                color: tight ? barColor : AppColors.onSurfaceMuted,
                fontSize: compact ? 11 : 13,
                fontWeight: tight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
