import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../ads/banner_ad_widget.dart';
import '../../ads/remove_ads_link.dart';
import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../domain/load_calculator.dart' as calc;
import '../../domain/progress_index.dart';
import '../../providers.dart';
import '../../widgets/labels.dart' show disciplineLabel;
import '../../widgets/segmented_proportion_bar.dart';
import '../../widgets/stat_tile.dart';
import 'consistency_heatmap.dart';
import 'mat_time_chart.dart';
import 'progress_index_chart.dart';

const _kMinSessionsForCharts = 3;
const _kWeeksShown = 8;
const _kHeatmapWeeks = 10;

enum ProgressRange { fourWeeks, twelveWeeks, oneYear, allTime }

String _rangeLabel(ProgressRange r) => switch (r) {
      ProgressRange.fourWeeks => '4 weeks',
      ProgressRange.twelveWeeks => '12 weeks',
      ProgressRange.oneYear => '1 year',
      ProgressRange.allTime => 'All time',
    };

/// Progress (spec §2, screen 7; redesigned per user request against the
/// Winter Arc reference): time-range tabs, a work summary, a progress-index
/// chart, and the original mat-time/sparring/discipline/consistency charts,
/// now scoped to the selected range. Definition of done (spec §10): every
/// chart is computed from real Session/Round data, correct empty states
/// below 3 logged sessions.
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
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.critical))),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.critical))),
      ),
    );
  }
}

class _ProgressBody extends StatefulWidget {
  const _ProgressBody({required this.sessions, required this.rounds});

  final List<SessionRow> sessions;
  final List<RoundRow> rounds;

  @override
  State<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends State<_ProgressBody> {
  ProgressRange _range = ProgressRange.twelveWeeks;

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;
    if (sessions.length < _kMinSessionsForCharts) {
      return _EmptyState(sessionsLogged: sessions.length);
    }

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final earliestSession = sessions.map((s) => s.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final rangeStart = switch (_range) {
      ProgressRange.fourWeeks => todayMidnight.subtract(const Duration(days: 28)),
      ProgressRange.twelveWeeks => todayMidnight.subtract(const Duration(days: 84)),
      ProgressRange.oneYear => todayMidnight.subtract(const Duration(days: 365)),
      ProgressRange.allTime => DateTime(earliestSession.year, earliestSession.month, earliestSession.day),
    };

    final rangedSessions = sessions.where((s) => !s.date.isBefore(rangeStart)).toList();
    final rangedSessionIds = rangedSessions.map((s) => s.id).toSet();
    final rangedRounds = widget.rounds.where((r) => rangedSessionIds.contains(r.session)).toList();

    final matMinutes = rangedSessions.fold(0, (t, s) => t + s.matTime) ~/ 60;
    final totalLoad = rangedSessions.fold(0, (t, s) => t + s.loadScore);
    final avgLoad = rangedSessions.isEmpty ? 0 : totalLoad ~/ rangedSessions.length;

    final useMonthlyBuckets = _range == ProgressRange.oneYear || _range == ProgressRange.allTime;
    final buckets = useMonthlyBuckets
        ? bucketLoadByMonth(
            sessions: rangedSessions.map((s) => (date: s.date, loadScore: s.loadScore)),
            from: rangeStart,
            to: todayMidnight,
          )
        : bucketLoadByWeek(
            sessions: rangedSessions.map((s) => (date: s.date, loadScore: s.loadScore)),
            from: rangeStart,
            to: todayMidnight,
          );
    final currentIndex = buckets.isEmpty ? 0 : buckets.last.totalLoad;
    final startIndex = buckets.isEmpty ? 0 : buckets.first.totalLoad;
    final delta = currentIndex - startIndex;

    final firstWeekStart = todayMidnight
        .subtract(Duration(days: todayMidnight.weekday - 1))
        .subtract(const Duration(days: 7 * (_kWeeksShown - 1)));
    final weeks = List.generate(_kWeeksShown, (i) {
      final start = firstWeekStart.add(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final minutes = sessions
          .where((s) => !s.date.isBefore(start) && s.date.isBefore(end))
          .fold(0, (total, s) => total + s.matTime ~/ 60);
      return WeekMatTime(weekStart: start, minutes: minutes);
    });

    final sparRatio = calc.sparringRatio(
      roundDurationsSeconds: rangedRounds.map((r) => r.duration),
      roundModes: rangedRounds.map((r) => r.mode),
    );

    final matTimeByDiscipline = <Discipline, int>{for (final d in Discipline.values) d: 0};
    final sessionCountByDay = <DateTime, int>{};
    for (final s in rangedSessions) {
      matTimeByDiscipline[s.discipline] = (matTimeByDiscipline[s.discipline] ?? 0) + s.matTime;
    }
    for (final s in sessions) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      sessionCountByDay[day] = (sessionCountByDay[day] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Progress',
          style: TextStyle(color: AppColors.onBackground, fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${rangedSessions.length} session${rangedSessions.length == 1 ? '' : 's'} in the ${_range == ProgressRange.allTime ? 'full log' : 'last ${_rangeLabel(_range)}'}',
          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13.5),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ProgressRange.values
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_rangeLabel(r)),
                      selected: _range == r,
                      onSelected: (_) => setState(() => _range = r),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('The work'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: StatTile(label: 'Mat time', value: '$matMinutes', unit: 'min')),
            const SizedBox(width: 12),
            Expanded(child: StatTile(label: 'Sessions', value: '${rangedSessions.length}')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Rounds',
                value: '${rangedSessions.fold(0, (t, s) => t + s.roundsPlanned)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: StatTile(label: 'Avg load', value: '$avgLoad')),
          ],
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Progress index'),
        const SizedBox(height: 4),
        const Text(
          'Total training load (sRPE × mat time) per period — a rising line means '
          'you are accumulating more quality work, not just more time on the mat.',
          style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$currentIndex', style: AppTextStyles.numeral(fontSize: 34, color: AppColors.gold)),
            const SizedBox(width: 10),
            if (buckets.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: delta >= 0 ? AppColors.goldWash : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${delta >= 0 ? '↑' : '↓'} ${delta.abs()} vs start',
                  style: TextStyle(
                    color: delta >= 0 ? AppColors.good : AppColors.onSurfaceMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ProgressIndexChart(buckets: buckets),
        const SizedBox(height: 32),
        const _SectionTitle('Mat time by week'),
        const SizedBox(height: 12),
        MatTimeChart(weeks: weeks),
        const SizedBox(height: 32),
        const _SectionTitle('Sparring vs. drilling'),
        const SizedBox(height: 12),
        SegmentedProportionBar(
          segments: [
            ProportionSegment(label: 'Sparring & rolling', value: sparRatio, color: AppColors.liveGreen),
            ProportionSegment(label: 'Drilling & technique', value: 1 - sparRatio, color: AppColors.surfaceRaised),
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
        ConsistencyHeatmap(sessionCountByDay: sessionCountByDay, weeks: _kHeatmapWeeks),
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
            const Icon(Icons.insights_outlined, color: AppColors.onSurfaceFaint, size: 40),
            const SizedBox(height: 16),
            Text(
              sessionsLogged == 0
                  ? 'Log your first session to start tracking progress.'
                  : 'Log $remaining more session${remaining == 1 ? '' : 's'} to unlock your charts.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
