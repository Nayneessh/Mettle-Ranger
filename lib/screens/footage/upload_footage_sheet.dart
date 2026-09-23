import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/labels.dart' show disciplineLabel;

/// Lets the user bring in a video already on their device — filmed with the
/// stock camera app, downloaded, AirDropped in, whatever — as footage, the
/// same way an in-app recording would be. Because [Recordings] is always
/// 1:1 with a [Sessions] row (spec §4), an upload gets its own minimal
/// session rather than guessing an existing one to attach to; its "Uploaded
/// footage" note says so plainly, and nothing about mat time or rounds is
/// fabricated for it.
///
/// The picked file is copied into the same app-private
/// `recordings/<sessionId>/` layout `PlayerSessionController` uses for a
/// live capture and gets one [Segments] row covering its whole length, so
/// `ClipReviewScreen` plays it back with no branching for "how was this
/// footage produced."
Future<void> pickAndUploadFootage(BuildContext context, WidgetRef ref) async {
  FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(type: FileType.video);
  } catch (e) {
    if (!context.mounted) return;
    _showSnack(context, 'Could not open the file picker: $e');
    return;
  }
  final path = picked?.files.single.path;
  if (path == null) return; // user cancelled

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UploadFootageSheet(sourceFile: File(path)),
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _UploadFootageSheet extends ConsumerStatefulWidget {
  const _UploadFootageSheet({required this.sourceFile});

  final File sourceFile;

  @override
  ConsumerState<_UploadFootageSheet> createState() =>
      _UploadFootageSheetState();
}

class _UploadFootageSheetState extends ConsumerState<_UploadFootageSheet> {
  String _discipline = Discipline.values.first.name;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    File? destFile;
    try {
      final db = ref.read(databaseProvider);

      // The directory a recording lives under is named after its session,
      // so the session row has to exist first — same order
      // PlayerSessionController uses for a live capture.
      final sessionId = await db.sessionDao.createSession(
        SessionsCompanion.insert(
          date: _date,
          discipline: _discipline,
          roundsPlanned: 0,
          notes: const Value('Uploaded footage'),
        ),
      );

      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'recordings', '$sessionId'));
      await dir.create(recursive: true);
      final fileName = 'upload${p.extension(widget.sourceFile.path)}';
      destFile = await widget.sourceFile.copy(p.join(dir.path, fileName));
      final sizeBytes = await destFile.length();

      final probe = VideoPlayerController.file(destFile);
      int durationMs;
      String resolution;
      try {
        await probe.initialize();
        durationMs = probe.value.duration.inMilliseconds;
        final size = probe.value.size;
        resolution = '${size.width.round()}x${size.height.round()}';
      } finally {
        await probe.dispose();
      }

      await db.transaction(() async {
        final recordingId = await db.recordingDao.createRecording(
          RecordingsCompanion.insert(
            session: sessionId,
            localPath: dir.path,
            duration: durationMs,
            sizeBytes: sizeBytes,
            resolution: resolution,
            createdAt: DateTime.now(),
          ),
        );
        await db.recordingDao.insertSegments(recordingId, [
          SegmentsCompanion.insert(
            recording: recordingId,
            segmentIndex: 0,
            fileName: fileName,
            startOffsetMs: 0,
            durationMs: durationMs,
            sizeBytes: sizeBytes,
          ),
        ]);
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (destFile != null) {
        try {
          await destFile.delete();
        } catch (_) {
          // Best-effort cleanup only — the DB write never happened, so
          // nothing else references this file either way.
        }
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not add this footage: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        // Keyboard (viewInsets) and system nav bar (padding) are two
        // different reserved areas — a sheet sitting above the nav bar
        // still needs its own clearance from it even with no keyboard up.
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload footage',
            style: TextStyle(
              color: AppColors.onBackground,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.basename(widget.sourceFile.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'DISCIPLINE',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...Discipline.values.map((d) {
                final key = d.name;
                return ChoiceChip(
                  label: Text(disciplineLabel(d)),
                  selected: _discipline == key,
                  onSelected: (_) => setState(() => _discipline = key),
                );
              }),
              ...(ref.watch(allCustomDisciplinesStreamProvider).valueOrNull ??
                      const [])
                  .map(
                    (c) => ChoiceChip(
                      label: Text(c.name),
                      selected: _discipline == c.name,
                      onSelected: (_) => setState(() => _discipline = c.name),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'DATE',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
              '${_date.day.toString().padLeft(2, '0')}',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.critical, fontSize: 13),
            ),
          ],
          const SizedBox(height: 28),
          GradientButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF241B00),
                    ),
                  )
                : const Text('ADD FOOTAGE', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
