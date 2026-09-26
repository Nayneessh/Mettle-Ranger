import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/segment_resolver.dart';
import '../../providers.dart';
import '../../widgets/chapter_card.dart';
import '../../widgets/note_dialogs.dart';
import '../../widgets/score_bar.dart';

const _kFrameStepMs = 33; // ~1 frame at 30fps — video_player has no true
// frame-step API, so this is the closest approximation available to it.

enum _ClipReviewTab { chapters, notes }

/// Clip review (spec §2, screen 6): chapter-jump player, 0.25×/0.5× speed,
/// frame step, chapter loop, explicit play/pause/stop, timestamped notes,
/// and a scoring log. Definition of done (spec §10): chapters match the
/// recording's real timestamps, tapping one seeks to it, speed and loop
/// work correctly.
///
/// Plays across segment files via `domain/segment_resolver.dart`. A chapter
/// that spans a segment boundary plays only to the end of that segment —
/// the resolver's documented limitation, not a bug here.
class ClipReviewScreen extends ConsumerStatefulWidget {
  const ClipReviewScreen({super.key, required this.recordingId});

  final int recordingId;

  @override
  ConsumerState<ClipReviewScreen> createState() => _ClipReviewScreenState();
}

class _ClipReviewScreenState extends ConsumerState<ClipReviewScreen> {
  static const _resolver = SegmentResolver();

  RecordingRow? _recording;
  List<ChapterRow> _chapters = [];
  List<SegmentInfo> _segments = [];
  int _selectedChapterIndex = -1;
  int? _loadedSegmentIndex;
  VideoPlayerController? _video;
  bool _loop = false;
  bool _loading = true;
  String? _error;
  _ClipReviewTab _tab = _ClipReviewTab.chapters;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final recording = await db.recordingDao.byId(widget.recordingId);
    if (recording == null) {
      setState(() {
        _loading = false;
        _error = 'This recording no longer exists.';
      });
      return;
    }
    final chapters = await db.chapterDao.forRecording(widget.recordingId);
    final segmentRows = await db.recordingDao.segmentsForRecording(
      widget.recordingId,
    );
    final segments = segmentRows
        .map(
          (s) => SegmentInfo(
            index: s.segmentIndex,
            fileName: s.fileName,
            startOffsetMs: s.startOffsetMs,
            durationMs: s.durationMs,
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _recording = recording;
      _chapters = chapters;
      _segments = segments;
      _loading = false;
    });

    if (segments.isEmpty) {
      setState(
        () => _error = 'No playable footage remains for this recording.',
      );
      return;
    }
    if (chapters.isNotEmpty) {
      await _selectChapter(0);
    } else {
      await _loadSegment(segments.first, seekToMs: 0, play: false);
    }
  }

  Future<void> _selectChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    final chapter = _chapters[index];
    final resolved = _resolver.resolve(
      segments: _segments,
      globalOffsetMs: chapter.startOffset,
    );
    setState(() => _selectedChapterIndex = index);
    await _loadSegment(
      resolved.segment,
      seekToMs: resolved.localOffsetMs,
      play: true,
    );
  }

  Future<void> _seekToNote(RecordingNoteRow note) async {
    final resolved = _resolver.resolve(
      segments: _segments,
      globalOffsetMs: note.offsetMs,
    );
    setState(() => _selectedChapterIndex = -1);
    await _loadSegment(
      resolved.segment,
      seekToMs: resolved.localOffsetMs,
      play: false,
    );
  }

  Future<void> _loadSegment(
    SegmentInfo segment, {
    required int seekToMs,
    required bool play,
  }) async {
    final recording = _recording;
    if (recording == null) return;

    if (_loadedSegmentIndex != segment.index) {
      final old = _video;
      final file = File(p.join(recording.localPath, segment.fileName));
      final controller = VideoPlayerController.file(file);
      _video = controller;
      _loadedSegmentIndex = segment.index;
      try {
        await controller.initialize();
        await controller.seekTo(Duration(milliseconds: seekToMs));
        controller.addListener(_onPositionChanged);
        if (play) await controller.play();
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not open this clip: $e');
      } finally {
        await old?.dispose();
      }
    } else {
      final controller = _video;
      if (controller == null) return;
      await controller.seekTo(Duration(milliseconds: seekToMs));
      if (play) await controller.play();
    }
  }

  void _onPositionChanged() {
    if (!_loop || _selectedChapterIndex < 0) return;
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;

    final chapter = _chapters[_selectedChapterIndex];
    final resolvedStart = _resolver.resolve(
      segments: _segments,
      globalOffsetMs: chapter.startOffset,
    );
    // Loop only holds within the chapter's own segment — consistent with
    // the resolver's cross-segment limitation.
    final localEndMs =
        resolvedStart.localOffsetMs + (chapter.endOffset - chapter.startOffset);

    if (controller.value.position.inMilliseconds >= localEndMs) {
      controller.seekTo(Duration(milliseconds: resolvedStart.localOffsetMs));
    }
  }

  Future<void> _step(int deltaMs) async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.pause();
    final next = controller.value.position + Duration(milliseconds: deltaMs);
    await controller.seekTo(next < Duration.zero ? Duration.zero : next);
  }

  /// Pause-and-rewind — distinct from pause alone, matching what a "stop"
  /// button means on any other player: playback halts and the position
  /// resets, rather than just holding where it was.
  Future<void> _stop() async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.pause();
    await controller.seekTo(Duration.zero);
  }

  /// The current play position on the recording's global timeline — the
  /// same units [ChapterRow.startOffset] and [RecordingNotes.offsetMs] use
  /// — or null while nothing has finished loading yet.
  int? get _currentGlobalOffsetMs {
    final controller = _video;
    final segmentIndex = _loadedSegmentIndex;
    if (controller == null ||
        segmentIndex == null ||
        !controller.value.isInitialized) {
      return null;
    }
    final segment = _segments.firstWhere((s) => s.index == segmentIndex);
    return segment.startOffsetMs + controller.value.position.inMilliseconds;
  }

  Future<void> _addNoteAtCurrentPosition() async {
    final recording = _recording;
    final offsetMs = _currentGlobalOffsetMs;
    if (recording == null || offsetMs == null) return;
    await _video?.pause();
    if (!mounted) return;

    final text = await promptForNoteText(context);
    if (text == null) return;

    await ref
        .read(recordingNoteDaoProvider)
        .addNote(
          RecordingNotesCompanion.insert(
            recording: recording.id,
            offsetMs: offsetMs,
            body: text,
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) setState(() => _tab = _ClipReviewTab.notes);
  }

  /// Hands the recording's segment files to the OS share sheet — the
  /// standard, honest way to "post to Instagram/WhatsApp/Facebook": this
  /// app has no Meta developer credentials to post directly, but the share
  /// sheet lets the user pick any of those apps themselves. Most sessions
  /// are one segment, which every receiving app treats as a single video;
  /// multiple segments still share fine as multiple attachments.
  Future<void> _share() async {
    final recording = _recording;
    if (recording == null || _segments.isEmpty) return;
    final files = _segments
        .map((s) => XFile(p.join(recording.localPath, s.fileName)))
        .toList();
    await SharePlus.instance.share(ShareParams(files: files));
  }

  @override
  void dispose() {
    _video?.removeListener(_onPositionChanged);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recording;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clip review'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share this footage',
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.critical),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _Player(
                video: _video,
                chapters: _chapters,
                selectedChapterIndex: _selectedChapterIndex,
                loop: _loop,
                tab: _tab,
                recordingId: recording!.id,
                sessionId: recording.session,
                onSelectChapter: _selectChapter,
                onSelectNote: _seekToNote,
                onToggleLoop: () => setState(() => _loop = !_loop),
                onSpeedChanged: (speed) => _video?.setPlaybackSpeed(speed),
                onStepBack: () => _step(-_kFrameStepMs),
                onStepForward: () => _step(_kFrameStepMs),
                onStop: _stop,
                onAddNote: _addNoteAtCurrentPosition,
                onTabChanged: (t) => setState(() => _tab = t),
              ),
      ),
    );
  }
}

class _Player extends ConsumerWidget {
  const _Player({
    required this.video,
    required this.chapters,
    required this.selectedChapterIndex,
    required this.loop,
    required this.tab,
    required this.recordingId,
    required this.sessionId,
    required this.onSelectChapter,
    required this.onSelectNote,
    required this.onToggleLoop,
    required this.onSpeedChanged,
    required this.onStepBack,
    required this.onStepForward,
    required this.onStop,
    required this.onAddNote,
    required this.onTabChanged,
  });

  final VideoPlayerController? video;
  final List<ChapterRow> chapters;
  final int selectedChapterIndex;
  final bool loop;
  final _ClipReviewTab tab;
  final int recordingId;
  final int sessionId;
  final ValueChanged<int> onSelectChapter;
  final ValueChanged<RecordingNoteRow> onSelectNote;
  final VoidCallback onToggleLoop;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onStepBack;
  final VoidCallback onStepForward;
  final VoidCallback onStop;
  final VoidCallback onAddNote;
  final ValueChanged<_ClipReviewTab> onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = video != null && video!.value.isInitialized;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: ready ? video!.value.aspectRatio : 16 / 9,
          child: ready
              ? GestureDetector(
                  onTap: () =>
                      video!.value.isPlaying ? video!.pause() : video!.play(),
                  child: VideoPlayer(video!),
                )
              : const ColoredBox(
                  color: AppColors.surfaceSunken,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                ),
        ),
        if (ready)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: video!,
            builder: (context, value, _) => VideoProgressIndicator(
              video!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.gold,
                bufferedColor: AppColors.line,
                backgroundColor: AppColors.surfaceRaised,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: onStepBack,
                icon: const Icon(
                  Icons.skip_previous,
                  color: AppColors.onBackground,
                ),
                tooltip: 'Step back a frame',
              ),
              if (ready)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: video!,
                  builder: (context, value, _) => IconButton(
                    onPressed: () =>
                        value.isPlaying ? video!.pause() : video!.play(),
                    icon: Icon(
                      value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: AppColors.gold,
                      size: 32,
                    ),
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                  ),
                ),
              IconButton(
                onPressed: ready ? onStop : null,
                icon: const Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.onBackground,
                ),
                tooltip: 'Stop',
              ),
              IconButton(
                onPressed: onStepForward,
                icon: const Icon(
                  Icons.skip_next,
                  color: AppColors.onBackground,
                ),
                tooltip: 'Step forward a frame',
              ),
              IconButton(
                onPressed: onToggleLoop,
                icon: Icon(
                  Icons.repeat,
                  color: loop ? AppColors.gold : AppColors.onSurfaceFaint,
                ),
                tooltip: 'Loop this chapter',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final speed in [0.25, 0.5, 1.0])
                _SpeedButton(speed: speed, onTap: () => onSpeedChanged(speed)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ScoreBar(sessionId: sessionId),
        const Divider(height: 1),
        Row(
          children: [
            Expanded(
              child: _TabButton(
                label: 'Chapters',
                selected: tab == _ClipReviewTab.chapters,
                onTap: () => onTabChanged(_ClipReviewTab.chapters),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'Notes',
                selected: tab == _ClipReviewTab.notes,
                onTap: () => onTabChanged(_ClipReviewTab.notes),
              ),
            ),
            IconButton(
              onPressed: ready ? onAddNote : null,
              icon: const Icon(Icons.note_add_outlined, color: AppColors.gold),
              tooltip: 'Add a note at this moment',
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: tab == _ClipReviewTab.chapters
              ? (chapters.isEmpty
                    ? const Center(
                        child: Text(
                          'No chapters in this recording.',
                          style: TextStyle(color: AppColors.onSurfaceMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: chapters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => ChapterCard(
                          chapter: chapters[i],
                          selected: i == selectedChapterIndex,
                          onTap: () => onSelectChapter(i),
                        ),
                      ))
              : _NotesList(
                  recordingId: recordingId,
                  onSelectNote: onSelectNote,
                ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.gold : AppColors.onSurfaceMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.recordingId, required this.onSelectNote});

  final int recordingId;
  final ValueChanged<RecordingNoteRow> onSelectNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(recordingNotesStreamProvider(recordingId));
    return notesAsync.when(
      data: (notes) => notes.isEmpty
          ? const Center(
              child: Text(
                'No notes yet — pause the video and tap the note icon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final note = notes[i];
                final position = Duration(milliseconds: note.offsetMs);
                final label =
                    '${position.inMinutes}:'
                    '${(position.inSeconds % 60).toString().padLeft(2, '0')}';
                return InkWell(
                  onTap: () => onSelectNote(note),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldWash,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.goldStrong,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            note.body,
                            style: const TextStyle(
                              color: AppColors.onBackground,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref
                              .read(recordingNoteDaoProvider)
                              .deleteNote(note.id),
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.onSurfaceFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(
        child: Text('$e', style: const TextStyle(color: AppColors.critical)),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onTap});

  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text('$speed×', style: const TextStyle(fontSize: 12)),
    );
  }
}
