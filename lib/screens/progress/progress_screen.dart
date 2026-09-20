import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../ads/banner_ad_widget.dart';
import '../../ads/remove_ads_link.dart';
import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../domain/load_calculator.dart' as calc;
import '../../providers.dart';
import '../../widgets/segmented_proportion_bar.dart';
import '../../widgets/labels.dart' show disciplineLabel;
import 'consistency_heatmap.dart';
import 'mat_time_chart.dart';

const _kMinSessionsForCharts = 3;
const _kWeeksShown = 8;
const _kHeatmapWeeks = 10;

/// Progress (spec §2, screen 7): mat time by week, sparring-to-drilling
/// ratio, discipline split, consistency heatmap. Definition of done (spec
/// §10): all four charts computed from real Session/Round data, correct
/// empty states below 3 logged sessions.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsStreamProvider);
    final roundsAsync = ref.watch(allRoundsStreamProvider);

    return SafeArea(
      child: sessionsAsync.when(
        data: (sessions) => roundsAsync.when(
          data: (rounds) => _ProgressBody(sessions: sessions, rounds: rounds),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, _) => Center(
            child: Text(
              '$e',
              style: const TextStyle(color: AppColors.critical),
            ),
          ),
        ),
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

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.sessions, required this.rounds});

  final List<SessionRow> sessions;
  final List<RoundRow> rounds;

  @override
  Widget build(BuildContext context) {
    if (sessions.length < _kMinSessionsForCharts) {
      return _EmptyState(sessionsLogged: sessions.length);
    }

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final currentWeekStart = todayMidnight.subtract(
      Duration(days: todayMidnight.weekday - 1),
    );
    final firstWeekStart = currentWeekStart.subtract(
      const Duration(days: 7 * (_kWeeksShown - 1)),
    );

    final weeks = List.generate(_kWeeksShown, (i) {
      final start = firstWeekStart.add(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final minutes = sessions
          .where((s) => !s.date.isBefore(start) && s.date.isBefore(end))
          .fold(0, (total, s) => total + s.matTime ~/ 60);
      return WeekMatTime(weekStart: start, minutes: minutes);
    });

    final sparRatio = calc.sparringRatio(
      roundDurationsSeconds: rounds.map((r) => r.duration),
      roundModes: rounds.map((r) => r.mode),
    );

    final matTimeByDiscipline = <Discipline, int>{
      for (final d in Discipline.values) d: 0,
    };
    final sessionCountByDay = <DateTime, int>{};
    for (final s in sessions) {
      matTimeByDiscipline[s.discipline] =
          (matTimeByDiscipline[s.discipline] ?? 0) + s.matTime;
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      sessionCountByDay[day] = (sessionCountByDay[day] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Progress',
          style: TextStyle(
            color: AppColors.onBackground,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Mat time by week'),
        const SizedBox(height: 12),
        MatTimeChart(weeks: weeks),
        const SizedBox(height: 32),
        const _SectionTitle('Sparring vs. drilling'),
        const SizedBox(height: 12),
        SegmentedProportionBar(
          segments: [
            ProportionSegment(
              label: 'Sparring & rolling',
              value: sparRatio,
              color: AppColors.liveGreen,
            ),
            ProportionSegment(
              label: 'Drilling & technique',
              value: 1 - sparRatio,
              color: AppColors.surfaceRaised,
            ),
          ],
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Discipline split'),
        const SizedBox(height: 12),
        SegmentedProportionBar(
          segments: [
            for (final d in Discipline.values)
              ProportionSegment(
                label: disciplineLabel(d),
                value: (matTimeByDiscipline[d] ?? 0).toDouble(),
                color: colorForDiscipline(d),
              ),
          ],
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Consistency'),
        const SizedBox(height: 12),
        ConsistencyHeatmap(
          sessionCountByDay: sessionCountByDay,
          weeks: _kHeatmapWeeks,
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: const [
              BannerAdWidget(slot: AdSlot.progress),
              SizedBox(height: 4),
              RemoveAdsLink(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.sessionsLogged});
  final int sessionsLogged;

  @override
  Widget build(BuildContext context) {
    final remaining = _kMinSessionsForCharts - sessionsLogged;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insights_outlined,
              color: AppColors.onSurfaceFaint,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              sessionsLogged == 0
                  ? 'Log your first session to start tracking progress.'
                  : 'Log $remaining more session${remaining == 1 ? '' : 's'} to unlock your charts.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
