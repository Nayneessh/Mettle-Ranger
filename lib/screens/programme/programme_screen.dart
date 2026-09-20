import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/daos/routine_dao.dart';
import '../../providers.dart';
import 'movements_catalog_screen.dart';
import 'new_routine_sheet.dart';
import 'routine_day_editor_screen.dart';

const _kWeekdayAbbrev = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// Programme (Winter Arc reference's routine screen, adapted): the active
/// routine's week, one card per day, each showing what is planned or "Rest".
/// "New routine" and "Movements" sit below, matching the reference layout.
class ProgrammeScreen extends ConsumerWidget {
  const ProgrammeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoutineAsync = ref.watch(activeRoutineStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Programme'),
        actions: [
          activeRoutineAsync.maybeWhen(
            data: (routine) => routine == null
                ? const SizedBox.shrink()
                : _RoutineSwitcher(activeRoutineId: routine.id),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: activeRoutineAsync.when(
          data: (routine) => routine == null
              ? const _NoRoutineEmptyState()
              : _RoutineWeek(routineId: routine.id, routineName: routine.name),
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
      ),
    );
  }
}

class _RoutineSwitcher extends ConsumerWidget {
  const _RoutineSwitcher({required this.activeRoutineId});
  final int activeRoutineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(allRoutinesStreamProvider);
    return routinesAsync.maybeWhen(
      data: (routines) {
        if (routines.length < 2) return const SizedBox.shrink();
        return PopupMenuButton<int>(
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Switch routine',
          onSelected: (id) => ref.read(routineDaoProvider).setActive(id),
          itemBuilder: (context) => routines
              .map(
                (r) => PopupMenuItem(
                  value: r.id,
                  child: Row(
                    children: [
                      if (r.id == activeRoutineId)
                        const Icon(Icons.check, size: 16, color: AppColors.gold)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(r.name),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _NoRoutineEmptyState extends ConsumerWidget {
  const _NoRoutineEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.onSurfaceFaint,
              size: 40,
            ),
            const SizedBox(height: 16),
            const Text(
              'No routine yet. Build a weekly plan so Today knows what to suggest.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showNewRoutineSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New routine'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MovementsCatalogScreen(),
                  ),
                ),
                icon: const Icon(Icons.fitness_center),
                label: const Text('Movements'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineWeek extends ConsumerStatefulWidget {
  const _RoutineWeek({required this.routineId, required this.routineName});

  final int routineId;
  final String routineName;

  @override
  ConsumerState<_RoutineWeek> createState() => _RoutineWeekState();
}

class _RoutineWeekState extends ConsumerState<_RoutineWeek> {
  late Future<RoutineWithDays?> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(routineDaoProvider).routineWithDays(widget.routineId);
  }

  Future<void> _reloadAndRefresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final routineId = widget.routineId;
    final routineName = widget.routineName;
    return FutureBuilder<RoutineWithDays?>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }
        final withDays = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              routineName,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(7, (weekday) {
              final day = withDays.days[weekday];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DayCard(
                  weekday: weekday,
                  day: day,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoutineDayEditorScreen(
                          routineId: routineId,
                          weekday: weekday,
                        ),
                      ),
                    );
                    await _reloadAndRefresh();
                  },
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showNewRoutineSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('New routine'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MovementsCatalogScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.fitness_center),
                    label: const Text('Movements'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.day,
    required this.onTap,
  });

  final int weekday;
  final RoutineDayWithMovements? day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRest = day == null || day!.day.restDay;
    final label = isRest
        ? 'Rest'
        : (day!.day.label.trim().isNotEmpty ? day!.day.label : 'Training day');
    final subtitle = isRest
        ? 'Nothing scheduled'
        : (day!.movements.isEmpty
              ? 'No movements added yet'
              : '${day!.movements.length} movement${day!.movements.length == 1 ? '' : 's'}');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: isRest ? AppColors.lineSoft : AppColors.gold,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                _kWeekdayAbbrev[weekday],
                style: const TextStyle(
                  color: AppColors.onSurfaceFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isRest
                          ? AppColors.onSurfaceMuted
                          : AppColors.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
