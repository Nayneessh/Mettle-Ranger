import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../../widgets/goal_ring.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/stat_tile.dart';
import '../settings/settings_screen.dart';
import 'new_check_in_screen.dart';

/// Body (new tab): weight/body-fat/measurement check-ins. Reverses the
/// original spec's explicit non-goal excluding weight tracking — added
/// because the user asked for it after seeing the delivered app, referencing
/// the Winter Arc app's own Body screen.
class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInsAsync = ref.watch(allBodyCheckInsStreamProvider);
    final goalsAsync = ref.watch(goalsStreamProvider);

    return SafeArea(
      child: checkInsAsync.when(
        data: (checkIns) => goalsAsync.when(
          data: (goals) => _BodyBody(checkIns: checkIns, goals: goals),
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

class _BodyBody extends StatelessWidget {
  const _BodyBody({required this.checkIns, required this.goals});

  final List<BodyCheckInRow> checkIns;
  final GoalsRow goals;

  @override
  Widget build(BuildContext context) {
    final latest = checkIns.isEmpty ? null : checkIns.first;
    final latestWeight = latest?.weightKg;
    final latestBodyFat = latest?.bodyFatPercent;
    final leanMass = (latestWeight != null && latestBodyFat != null)
        ? latestWeight * (1 - latestBodyFat / 100)
        : null;
    final fatMass = (latestWeight != null && latestBodyFat != null)
        ? latestWeight * (latestBodyFat / 100)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text(
          'Body',
          style: TextStyle(
            color: AppColors.onBackground,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${checkIns.length} check-in${checkIns.length == 1 ? '' : 's'} recorded',
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 20),
        GradientButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NewCheckInScreen())),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add),
              SizedBox(width: 8),
              Text('LOG A CHECK-IN', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Targets'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                goals.targetWeightKg == null &&
                    goals.targetBodyFatPercent == null
                ? InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: AppColors.nightBlueStrong,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No targets set yet. Tap to add bodyweight and body-fat targets.',
                              style: TextStyle(color: AppColors.onSurfaceMuted),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.onSurfaceFaint,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TargetGauge(
                          label: 'Bodyweight',
                          current: latestWeight,
                          target: goals.targetWeightKg,
                          unit: 'kg',
                        ),
                        _TargetGauge(
                          label: 'Body fat',
                          current: latestBodyFat,
                          target: goals.targetBodyFatPercent,
                          unit: '%',
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Now'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Weight',
                value: latestWeight?.toStringAsFixed(1) ?? '—',
                unit: latestWeight != null ? 'kg' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Body fat',
                value: latestBodyFat?.toStringAsFixed(1) ?? '—',
                unit: latestBodyFat != null ? '%' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Lean mass',
                value: leanMass?.toStringAsFixed(1) ?? '—',
                unit: leanMass != null ? 'kg' : 'needs weight + fat %',
                accent: AppColors.good,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Fat mass',
                value: fatMass?.toStringAsFixed(1) ?? '—',
                unit: fatMass != null ? 'kg' : 'needs weight + fat %',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Check-ins'),
        const SizedBox(height: 10),
        if (checkIns.isEmpty)
          const Text(
            'No check-ins yet.',
            style: TextStyle(color: AppColors.onSurfaceMuted),
          )
        else
          ...checkIns.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CheckInTile(checkIn: c),
            ),
          ),
      ],
    );
  }
}

class _TargetGauge extends StatelessWidget {
  const _TargetGauge({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
  });

  final double? current;
  final double? target;
  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final progress =
        (current != null && target != null && current! > 0 && target! > 0)
        ? (current! < target! ? current! / target! : target! / current!)
        : 0.0;
    return Column(
      children: [
        GoalRing(
          progress: progress,
          centerValue: current?.toStringAsFixed(0) ?? '—',
          centerUnit: unit,
          size: 108,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (target != null)
          Text(
            '→ ${target!.toStringAsFixed(0)} $unit',
            style: const TextStyle(
              color: AppColors.onSurfaceFaint,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _CheckInTile extends StatelessWidget {
  const _CheckInTile({required this.checkIn});
  final BodyCheckInRow checkIn;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (checkIn.weightKg != null)
        '${checkIn.weightKg!.toStringAsFixed(1)} kg',
      if (checkIn.bodyFatPercent != null)
        '${checkIn.bodyFatPercent!.toStringAsFixed(1)}% fat',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('d MMM yyyy').format(checkIn.date),
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            parts.isEmpty ? 'Measurements only' : parts.join(' · '),
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (checkIn.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              checkIn.notes,
              style: const TextStyle(
                color: AppColors.onSurfaceFaint,
                fontSize: 12,
              ),
            ),
          ],
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
