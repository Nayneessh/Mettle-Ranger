import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../../widgets/labels.dart' show disciplineLabelForKey;
import '../../widgets/stat_tile.dart';
import 'session_detail_screen.dart';

/// History (new tab, Winter Arc reference's History screen adapted): every
/// session ever logged, most recent first, grouped by month. "Lifetime
/// volume" and "total sets" in the reference become lifetime mat time and
/// total rounds here — the equivalents this app actually tracks.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsStreamProvider);

    return SafeArea(
      child: sessionsAsync.when(
        data: (sessions) => _HistoryBody(sessions: sessions),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppColors.critical)),
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.sessions});

  final List<SessionRow> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No sessions logged yet.',
            style: TextStyle(color: AppColors.onSurfaceMuted),
          ),
        ),
      );
    }

    final lifetimeMatMinutes = sessions.fold(0, (t, s) => t + s.matTime) ~/ 60;
    final totalRounds = sessions.fold(0, (t, s) => t + s.roundsPlanned);

    final groups = <String, List<SessionRow>>{};
    for (final s in sessions) {
      final key = DateFormat('MMMM yyyy').format(s.date);
      groups.putIfAbsent(key, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text(
          'History',
          style: TextStyle(
            color: AppColors.onBackground,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${sessions.length} session${sessions.length == 1 ? '' : 's'} recorded',
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Lifetime mat time',
                value: '$lifetimeMatMinutes',
                unit: 'min',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(label: 'Total rounds', value: '$totalRounds'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final entry in groups.entries) ...[
          _MonthHeader(label: entry.key, sessions: entry.value),
          const SizedBox(height: 10),
          ...entry.value.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SessionRow(
                session: s,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(sessionId: s.id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label, required this.sessions});

  final String label;
  final List<SessionRow> sessions;

  @override
  Widget build(BuildContext context) {
    final minutes = sessions.fold(0, (t, s) => t + s.matTime) ~/ 60;
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${sessions.length} · ${minutes}m',
          style: const TextStyle(
            color: AppColors.onSurfaceFaint,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final SessionRow session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final matMinutes = session.matTime ~/ 60;
    final durationMinutes = session.duration ~/ 60;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: colorForDisciplineKey(session.discipline),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Text(
                    '${session.date.day}',
                    style: AppTextStyles.numeral(fontSize: 18),
                  ),
                  Text(
                    DateFormat('E').format(session.date).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.onSurfaceFaint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disciplineLabelForKey(session.discipline),
                    style: const TextStyle(
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.roundsPlanned} rounds · ${matMinutes}m mat time',
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${session.loadScore}',
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${durationMinutes}m',
                  style: const TextStyle(
                    color: AppColors.onSurfaceFaint,
                    fontSize: 11.5,
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
