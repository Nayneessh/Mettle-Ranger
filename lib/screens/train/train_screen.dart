import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../ads/banner_ad_widget.dart';
import '../../ads/remove_ads_link.dart';
import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/week_strip.dart';
import '../setup/setup_screen.dart';
import 'backup_prompt_card.dart';
import 'last_session_card.dart';

/// Train (spec §2, screen 1): the default landing tab. Week's mat time, week
/// strip, Start Session, last session card — all from real Drift data, never
/// placeholder numbers (spec §10).
class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsStreamProvider);

    return sessionsAsync.when(
      data: (sessions) => _TrainBody(sessions: sessions),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (error, _) => Center(
        child: Text(
          'Could not load sessions.\n$error',
          style: const TextStyle(color: AppColors.critical),
        ),
      ),
    );
  }
}

class _TrainBody extends StatelessWidget {
  const _TrainBody({required this.sessions});

  final List<SessionRow> sessions;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final weekStart = todayMidnight.subtract(
      Duration(days: todayMidnight.weekday - 1),
    );
    final weekEnd = weekStart.add(const Duration(days: 7));

    final sessionsThisWeek = sessions.where(
      (s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd),
    );
    final weekMatSeconds = sessionsThisWeek.fold(
      0,
      (total, s) => total + s.matTime,
    );
    final daysWithSession = sessionsThisWeek
        .map(
          (s) => DateTime(
            s.date.year,
            s.date.month,
            s.date.day,
          ).difference(weekStart).inDays,
        )
        .where((d) => d >= 0 && d < 7)
        .toSet();

    final lastSession = sessions.isEmpty ? null : sessions.first;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Train',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                StatTile(
                  label: "This week's mat time",
                  value: '${weekMatSeconds ~/ 60}',
                  unit: 'min',
                ),
                const SizedBox(height: 20),
                WeekStrip(
                  weekStart: weekStart,
                  daysWithSession: daysWithSession,
                  today: today,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Start Session',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SetupScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                if (sessions.length >= 3) const BackupPromptCard(),
                if (lastSession != null) ...[
                  const Text(
                    'LAST SESSION',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LastSessionCard(session: lastSession),
                ] else
                  _EmptyState(),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: const [
                      BannerAdWidget(slot: AdSlot.train),
                      SizedBox(height: 4),
                      RemoveAdsLink(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineSoft, style: BorderStyle.solid),
      ),
      child: const Row(
        children: [
          Icon(Icons.sports_mma_outlined, color: AppColors.onSurfaceFaint),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No sessions logged yet. Tap Start Session to log your first one.',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
