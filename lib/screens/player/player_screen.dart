import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../platform/capture_providers.dart';
import '../../providers.dart';
import '../../widgets/chapter_card.dart';
import '../../widgets/round_clock.dart';
import '../../widgets/storage_meter.dart';
import '../recap/recap_screen.dart';
import '../setup/session_draft.dart';
import 'player_session_controller.dart';

/// Session Player (spec §2, screen 3): full-screen round timer, MARK
/// button, live chapter strip, storage readout. Definition of done (spec
/// §10): timer accurate to the second, MARK writes a flagged chapter, round
/// boundaries auto-chapter with no user input, storage readout is live.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.sessionId,
    required this.roundIds,
    required this.draft,
  });

  final int sessionId;
  final List<int> roundIds;
  final SessionDraft draft;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerSessionController _controller;
  bool _navigatedToRecap = false;

  @override
  void initState() {
    super.initState();
    _controller = PlayerSessionController(
      db: ref.read(databaseProvider),
      captureController: ref.read(captureControllerProvider),
      sessionId: widget.sessionId,
      roundIds: widget.roundIds,
      roundPlan: widget.draft.roundPlan,
      recordEnabled: widget.draft.recordEnabled,
      quality: widget.draft.quality,
    );
    _controller.addListener(_onControllerChanged);
    _controller.start();
  }

  void _onControllerChanged() {
    if (_controller.sessionFinished && !_navigatedToRecap) {
      _navigatedToRecap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecapScreen(sessionId: widget.sessionId),
          ),
        );
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmEndEarly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End session early?'),
        content: const Text(
          "Rounds completed so far are saved. Rounds you haven't reached yet are not.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep training'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.endEarly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tick = _controller.tick;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmEndEarly();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          // MARK is tapped mid-round with one thumb — give it more real
          // clearance from the system nav than the other screens' CTAs.
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                _StatusHeader(controller: _controller, draft: widget.draft),
                const Spacer(),
                if (tick != null)
                  RoundClock(tick: tick, totalRounds: widget.draft.roundCount)
                else
                  const CircularProgressIndicator(color: AppColors.gold),
                const Spacer(),
                if (widget.draft.recordEnabled) ...[
                  _ChapterStrip(chapters: _controller.liveChapters),
                  const SizedBox(height: 20),
                  _MarkButton(
                    enabled: _controller.recordingActive,
                    onTap: _controller.markTapped,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.controller, required this.draft});

  final PlayerSessionController controller;
  final SessionDraft draft;

  @override
  Widget build(BuildContext context) {
    if (!draft.recordEnabled) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Timing only — not recording',
          style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              controller.recordingActive
                  ? Icons.fiber_manual_record
                  : Icons.videocam_off_outlined,
              color: controller.recordingActive
                  ? AppColors.critical
                  : AppColors.onSurfaceFaint,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              controller.startingCapture
                  ? 'Starting camera…'
                  : controller.recordingActive
                  ? 'Recording'
                  : 'Not recording',
              style: TextStyle(
                color: controller.recordingActive
                    ? AppColors.critical
                    : AppColors.onSurfaceFaint,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (controller.recordingActive) ...[
          const SizedBox(height: 8),
          StorageMeter(
            usedBytes: controller.usedBytes,
            freeBytes: (controller.freeBytes - controller.usedBytes).clamp(
              0,
              1 << 62,
            ),
            compact: true,
          ),
        ],
        if (controller.captureWarning != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  controller.captureWarning!,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChapterStrip extends StatelessWidget {
  const _ChapterStrip({required this.chapters});

  final List<ChapterRow> chapters;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const Text(
        'Chapters appear here as rounds end, or when you tap MARK.',
        style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 11.5),
        textAlign: TextAlign.center,
      );
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chapters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chapter = chapters[i];
          return ChapterCard(chapter: chapter, selected: false, onTap: () {});
        },
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Spec §7: one tap, large target, >=100dp.
    return SizedBox(
      width: 120,
      height: 120,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: AppColors.critical,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceRaised,
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin, size: 28),
            SizedBox(height: 4),
            Text(
              'MARK',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}
