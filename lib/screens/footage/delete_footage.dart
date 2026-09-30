import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';

/// Deletes a recording's segment files from disk, then the recording row
/// itself (and, by cascade, its chapters). The session and its rounds are
/// left untouched — RULE 1 of spec §4: losing footage to storage pressure
/// (or, here, a user freeing up space on purpose) must never cost a user
/// the training history that produced it.
Future<void> deleteRecordingAndFiles(
  MettleDatabase db,
  RecordingRow recording,
) async {
  final segments = await db.recordingDao.segmentsForRecording(recording.id);
  for (final segment in segments) {
    final file = File(p.join(recording.localPath, segment.fileName));
    if (await file.exists()) await file.delete();
  }
  await db.recordingDao.deleteRecording(recording.id);
}

/// Confirms, then deletes — the Footage grid's delete action. Wording is
/// explicit that the training log entry survives; only the video goes.
Future<void> confirmAndDeleteRecording(
  BuildContext context,
  WidgetRef ref,
  RecordingRow recording,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Delete this footage?'),
      content: const Text(
        'The video is removed and its storage freed. The session stays in '
        'your training history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await deleteRecordingAndFiles(ref.read(databaseProvider), recording);
  ref.invalidate(totalStorageBytesProvider);
}
