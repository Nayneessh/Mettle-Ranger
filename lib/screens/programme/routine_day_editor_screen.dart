import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/daos/routine_dao.dart';
import '../../data/database.dart';
import '../../providers.dart';
import 'movement_labels.dart';

const _kWeekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Edits one day of a routine: its label, rest-day flag, and the movements
/// placed on it. Pushed from the Programme screen when a day card is tapped.
class RoutineDayEditorScreen extends ConsumerStatefulWidget {
  const RoutineDayEditorScreen({
    super.key,
    required this.routineId,
    required this.weekday,
  });

  final int routineId;

  /// 0 = Monday .. 6 = Sunday.
  final int weekday;

  @override
  ConsumerState<RoutineDayEditorScreen> createState() =>
      _RoutineDayEditorScreenState();
}

class _RoutineDayEditorScreenState
    extends ConsumerState<RoutineDayEditorScreen> {
  final _labelController = TextEditingController();
  bool _restDay = false;
  int? _dayId;
  List<RoutineMovementWithDetails> _placements = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final withDays = await ref
        .read(routineDaoProvider)
        .routineWithDays(widget.routineId);
    final day = withDays?.days[widget.weekday];
    if (!mounted) return;
    setState(() {
      _dayId = day?.day.id;
      _labelController.text = day?.day.label ?? '';
      _restDay = day?.day.restDay ?? false;
      _placements = day?.movements ?? [];
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(routineDaoProvider)
        .upsertDay(
          RoutineDaysCompanion.insert(
            routine: widget.routineId,
            weekday: widget.weekday,
            label: Value(_labelController.text.trim()),
            restDay: Value(_restDay),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _addMovement() async {
    final dayId =
        _dayId ??
        await ref
            .read(routineDaoProvider)
            .upsertDay(
              RoutineDaysCompanion.insert(
                routine: widget.routineId,
                weekday: widget.weekday,
              ),
            );
    if (!mounted) return;
    final picked = await showModalBottomSheet<MovementRow>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => const _MovementPickerSheet(),
    );
    if (picked == null) return;

    await ref
        .read(routineDaoProvider)
        .addMovementToDay(
          RoutineMovementsCompanion.insert(
            routineDay: dayId,
            movement: picked.id,
            position: _placements.length,
          ),
        );
    setState(() => _dayId = dayId);
    await _load();
  }

  Future<void> _removePlacement(RoutineMovementWithDetails placement) async {
    await ref
        .read(routineDaoProvider)
        .removeMovementFromDay(placement.placement.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_kWeekdayNames[widget.weekday]),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TextField(
                    controller: _labelController,
                    style: const TextStyle(color: AppColors.onBackground),
                    decoration: const InputDecoration(
                      hintText: 'Day label (e.g. "Sparring Day")',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Rest day',
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _restDay,
                        onChanged: (v) => setState(() => _restDay = v),
                      ),
                    ],
                  ),
                  if (!_restDay) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel('Movements'),
                        TextButton.icon(
                          onPressed: _addMovement,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_placements.isEmpty)
                      const Text(
                        'Nothing added yet.',
                        style: TextStyle(color: AppColors.onSurfaceMuted),
                      )
                    else
                      ..._placements.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.movement.name,
                                    style: const TextStyle(
                                      color: AppColors.onBackground,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _removePlacement(p),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.onSurfaceFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MovementPickerSheet extends ConsumerWidget {
  const _MovementPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(allMovementsStreamProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: movementsAsync.when(
          data: (movements) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = movements[i];
              return ListTile(
                title: Text(
                  m.name,
                  style: const TextStyle(color: AppColors.onBackground),
                ),
                subtitle: Text(
                  movementCategoryLabel(m.category),
                  style: const TextStyle(color: AppColors.onSurfaceMuted),
                ),
                onTap: () => Navigator.of(context).pop(m),
              );
            },
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, _) => Center(child: Text('$e')),
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
