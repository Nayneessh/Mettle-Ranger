import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/daos/routine_dao.dart';
import '../../data/database.dart';
import '../../domain/streak_calculator.dart';
import '../../providers.dart';
import '../../widgets/goal_ring.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/week_strip.dart';
import '../history/session_detail_screen.dart';
import '../programme/movements_catalog_screen.dart';
import '../programme/programme_screen.dart';
import '../settings/settings_screen.dart';
import '../setup/setup_screen.dart';
import '../train/backup_prompt_card.dart';
import '../train/last_session_card.dart';

/// Today — the Train tab's redesign per the Winter Arc reference: a priority
/// card for what's planned today, a week strip, this-week stats, a weekly
/// goal ring, the last session, and quick links into Programme/Movements.
///
/// Falls back to a plain "ready to train" card whenever there is no active
/// routine or no plan for today — a routine is optional here, never a
/// requirement to use the app, consistent with the original build's
/// discipline-agnostic defaults (spec §11).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsStreamProvider);
    final goalsAsync = ref.watch(goalsStreamProvider);
    final activeRoutineAsync = ref.watch(activeRoutineStreamProvider);

    return sessionsAsync.when(
      data: (sessions) => goalsAsync.when(
        data: (goals) => activeRoutineAsync.when(
          data: (routine) => _TodayBody(sessions: sessions, goals: goals, routine: routine),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.critical))),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.critical))),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (error, _) => Center(
        child: Text(
          'Could not load sessions.\n$error',
          style: const TextStyle(color: AppColors.critical),
        ),
      ),
    );
  }
}

class _TodayBody extends ConsumerStatefulWidget {
  const _TodayBody({required this.sessions, required this.goals, required this.routine});

  final List<SessionRow> sessions;
  final GoalsRow goals;
  final RoutineRow? routine;

  @override
  ConsumerState<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends ConsumerState<_TodayBody> {
  Future<RoutineDayWithMovements?>? _todayPlanFuture;
  int? _loadedForRoutineId;

  @override
  void didUpdateWidget(covariant _TodayBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadPlan();
  }

  @override
  void initState() {
    super.initState();
    _maybeLoadPlan();
  }

  void _maybeLoadPlan() {
    final routine = widget.routine;
    if (routine == null) {
      _todayPlanFuture = null;
      _loadedForRoutineId = null;
      return;
    }
    if (_loadedForRoutineId == routine.id) return;
    _loadedForRoutineId = routine.id;
    final weekday = DateTime.now().weekday - 1;
    _todayPlanFuture = ref
        .read(routineDaoProvider)
        .routineWithDays(routine.id)
        .then((withDays) => withDays?.days[weekday]);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final weekStart = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final sessionsThisWeek = widget.sessions.where(
      (s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd),
    );
    final weekMatSeconds = sessionsThisWeek.fold(0, (total, s) => total + s.matTime);
    final weekMatMinutes = weekMatSeconds ~/ 60;
    final daysWithSession = sessionsThisWeek
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day).difference(weekStart).inDays)
        .where((d) => d >= 0 && d < 7)
        .toSet();

    final streak = weeklyStreak(sessionDates: widget.sessions.map((s) => s.date), today: today);
    final lastSession = widget.sessions.isEmpty ? null : widget.sessions.first;

    final matGoalMinutes = widget.goals.weeklyMatMinutesTarget;
    final ringProgress = matGoalMinutes == 0 ? 0.0 : weekMatMinutes / matGoalMinutes;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'METTLE RANGER',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE d MMMM').format(today),
                            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProgrammeScreen()),
                      ),
                      icon: const Icon(Icons.calendar_month_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceRaised,
                        shape: const CircleBorder(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceRaised,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PriorityCard(
                  planFuture: _todayPlanFuture,
                  onStart: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  ),
                ),
                const SizedBox(height: 20),
                WeekStrip(weekStart: weekStart, daysWithSession: daysWithSession, today: today),
                const SizedBox(height: 24),
                const _SectionLabel('This week'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(label: 'Streak', value: '${streak.current}', unit: 'wks'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Sessions',
                        value: '${sessionsThisWeek.length}',
                        unit: 'of ${widget.goals.weeklySessionTarget}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(label: 'Mat time', value: '$weekMatMinutes', unit: 'min'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('The priority'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      GoalRing(
                        progress: ringProgress,
                        centerValue: '$weekMatMinutes',
                        centerUnit: 'of $matGoalMinutes min',
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weekly mat time',
                              style: TextStyle(
                                color: AppColors.onBackground,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              matGoalMinutes == 0
                                  ? 'Set a weekly target in Settings.'
                                  : (weekMatMinutes >= matGoalMinutes
                                      ? 'Goal met for this week.'
                                      : "${matGoalMinutes - weekMatMinutes} minutes left to hit this week's goal."),
                              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.sessions.length >= 3) ...[
                  const BackupPromptCard(),
                  const SizedBox(height: 24),
                ],
                const _SectionLabel('Last session'),
                const SizedBox(height: 10),
                if (lastSession != null)
                  LastSessionCard(
                    session: lastSession,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(sessionId: lastSession.id),
                      ),
                    ),
                  )
                else
                  const _EmptyLastSession(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MovementsCatalogScreen()),
                        ),
                        icon: const Icon(Icons.fitness_center),
                        label: const Text('Exercises'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProgrammeScreen()),
                        ),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Programme'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.planFuture, required this.onStart});

  final Future<RoutineDayWithMovements?>? planFuture;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (planFuture == null) {
      return _PriorityCardShell(
        badge: 'TODAY',
        headline: 'Ready to train',
        subtitle: 'No routine set — log a session whenever you\'re ready.',
        onStart: onStart,
        startLabel: 'START SESSION',
      );
    }
    return FutureBuilder<RoutineDayWithMovements?>(
      future: planFuture,
      builder: (context, snapshot) {
        final plan = snapshot.data;
        if (plan == null || plan.day.restDay) {
          return _PriorityCardShell(
            badge: 'TODAY',
            headline: plan == null ? 'Ready to train' : 'Rest day',
            subtitle: plan == null
                ? 'Nothing planned — log a session whenever you\'re ready.'
                : 'Your routine has today marked as a rest day.',
            onStart: onStart,
            startLabel: 'START SESSION',
          );
        }
        final label = plan.day.label.trim().isNotEmpty ? plan.day.label : 'Training day';
        final movementNames = plan.movements.map((m) => m.movement.name).join(' · ');
        final estMinutes = plan.movements.fold<int>(
          0,
          (total, m) => total + ((m.placement.targetDurationSeconds ?? 300) ~/ 60),
        );
        return _PriorityCardShell(
          badge: 'TODAY · PRIORITY',
          headline: label,
          subtitle: plan.movements.isEmpty
              ? 'No movements added to this day yet.'
              : movementNames,
          stats: plan.movements.isEmpty
              ? null
              : '${plan.movements.length} movements · ~$estMinutes minutes',
          onStart: onStart,
          startLabel: 'START ${label.toUpperCase()}',
        );
      },
    );
  }
}

class _PriorityCardShell extends StatelessWidget {
  const _PriorityCardShell({
    required this.badge,
    required this.headline,
    required this.subtitle,
    required this.onStart,
    required this.startLabel,
    this.stats,
  });

  final String badge;
  final String headline;
  final String subtitle;
  final String? stats;
  final VoidCallback onStart;
  final String startLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13.5)),
          if (stats != null) ...[
            const SizedBox(height: 10),
            Text(
              stats!,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(startLabel, style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLastSession extends StatelessWidget {
  const _EmptyLastSession();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineSoft),
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
