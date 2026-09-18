import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/segment_resolver.dart';
import '../../providers.dart';
import '../../widgets/chapter_card.dart';

const _kFrameStepMs = 33; // ~1 frame at 30fps — video_player has no true
// frame-step API, so this is the closest approximation available to it.

/// Clip review (spec §2, screen 6): chapter-jump player, 0.25×/0.5× speed,
/// frame step, chapter loop. Definition of done (spec §10): chapters match
/// the recording's real timestamps, tapping one seeks to it, speed and loop
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

  @override
  void dispose() {
    _video?.removeListener(_onPositionChanged);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Clip review')),
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
                onSelectChapter: _selectChapter,
                onToggleLoop: () => setState(() => _loop = !_loop),
                onSpeedChanged: (speed) => _video?.setPlaybackSpeed(speed),
                onStepBack: () => _step(-_kFrameStepMs),
                onStepForward: () => _step(_kFrameStepMs),
              ),
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({
    required this.video,
    required this.chapters,
    required this.selectedChapterIndex,
    required this.loop,
    required this.onSelectChapter,
    required this.onToggleLoop,
    required this.onSpeedChanged,
    required this.onStepBack,
    required this.onStepForward,
  });

  final VideoPlayerController? video;
  final List<ChapterRow> chapters;
  final int selectedChapterIndex;
  final bool loop;
  final ValueChanged<int> onSelectChapter;
  final VoidCallback onToggleLoop;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onStepBack;
  final VoidCallback onStepForward;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              for (final speed in [0.25, 0.5, 1.0])
                _SpeedButton(speed: speed, onTap: () => onSpeedChanged(speed)),
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
        const Divider(height: 1),
        Expanded(
          child: chapters.isEmpty
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
                ),
        ),
      ],
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
