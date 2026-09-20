import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../../widgets/labels.dart' show disciplineLabel, roundModeLabel;
import '../clip/clip_review_screen.dart';

/// Full detail for one session: everything a tap on a session card used to
/// go nowhere for. Metadata, every round, notes, and a way into the
/// footage — the bug report was literally "nothing happens," so this
/// screen's whole job is to be something.
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  SessionRow? _session;
  List<RoundRow> _rounds = [];
  RecordingRow? _recording;
  int _chapterCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final session = await db.sessionDao.sessionById(widget.sessionId);
    final rounds = await db.sessionDao.roundsForSession(widget.sessionId);
    final recording = await db.recordingDao.forSession(widget.sessionId);
    var chapterCount = 0;
    if (recording != null) {
      chapterCount = (await db.chapterDao.forRecording(recording.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _rounds = rounds;
      _recording = recording;
      _chapterCount = chapterCount;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          session == null ? 'Session' : disciplineLabel(session.discipline),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : session == null
            ? const Center(
                child: Text(
                  'This session no longer exists.',
                  style: TextStyle(color: AppColors.critical),
                ),
              )
            : _Body(
                session: session,
                rounds: _rounds,
                recording: _recording,
                chapterCount: _chapterCount,
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.session,
    required this.rounds,
    required this.recording,
    required this.chapterCount,
  });

  final SessionRow session;
  final List<RoundRow> rounds;
  final RecordingRow? recording;
  final int chapterCount;

  @override
  Widget build(BuildContext context) {
    final matMinutes = session.matTime ~/ 60;
    final durationMinutes = session.duration ~/ 60;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          DateFormat('EEEE, MMM d, yyyy').format(session.date),
          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
        ),
        if (session.giFlag && session.discipline == Discipline.bjj) ...[
          const SizedBox(height: 4),
          const Text(
            'Gi',
            style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            _Stat(label: 'Mat time', value: '$matMinutes', unit: 'min'),
            const SizedBox(width: 12),
            _Stat(label: 'Duration', value: '$durationMinutes', unit: 'min'),
            const SizedBox(width: 12),
            _Stat(label: 'Partners', value: '${session.partnerCount}'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
              label: 'sRPE',
              value: session.sRpe?.toString() ?? '—',
              accent: AppColors.liveGreen,
            ),
            const SizedBox(width: 12),
            _Stat(
              label: 'Load',
              value: '${session.loadScore}',
              accent: AppColors.liveGreen,
            ),
            const SizedBox(width: 12),
            _Stat(label: 'Rounds', value: '${rounds.length}'),
          ],
        ),
        const SizedBox(height: 28),
        _FootageCard(recording: recording, chapterCount: chapterCount),
        const SizedBox(height: 28),
        const _SectionLabel('Rounds'),
        const SizedBox(height: 12),
        if (rounds.isEmpty)
          const Text(
            'No rounds logged.',
            style: TextStyle(color: AppColors.onSurfaceMuted),
          )
        else
          ...rounds.map((r) => _RoundTile(round: r)),
        if (session.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionLabel('Notes'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              session.notes,
              style: const TextStyle(
                color: AppColors.onBackground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FootageCard extends StatelessWidget {
  const _FootageCard({required this.recording, required this.chapterCount});

  final RecordingRow? recording;
  final int chapterCount;

  @override
  Widget build(BuildContext context) {
    final rec = recording;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: rec == null
          ? const Row(
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  color: AppColors.onSurfaceFaint,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This session was not recorded.',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  color: AppColors.gold,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Footage',
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$chapterCount chapter${chapterCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClipReviewScreen(recordingId: rec.id),
                    ),
                  ),
                  child: const Text('Watch'),
                ),
              ],
            ),
    );
  }
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({required this.round});
  final RoundRow round;

  @override
  Widget build(BuildContext context) {
    final minutes = round.duration ~/ 60;
    final seconds = round.duration % 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${round.number}',
                style: AppTextStyles.numeral(
                  fontSize: 16,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                roundModeLabel(round.mode),
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (round.intensity != null) ...[
              Icon(Icons.bolt, size: 13, color: AppColors.onSurfaceFaint),
              const SizedBox(width: 2),
              Text(
                '${round.intensity}',
                style: const TextStyle(
                  color: AppColors.onSurfaceFaint,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.unit,
    this.accent = AppColors.gold,
  });

  final String label;
  final String value;
  final String? unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.onSurfaceFaint,
                fontSize: 10,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTextStyles.numeral(fontSize: 20, color: accent),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit!,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.onSurfaceMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
  );
}
