import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';

const _kDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// "Give it a name and the days it runs on. Movements come next." — the
/// Winter Arc reference sheet's own subtitle, and exactly the scope here:
/// this creates the routine and its selected days, empty. Movements are
/// added per day afterward, in [RoutineDayEditorScreen].
Future<void> showNewRoutineSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NewRoutineSheet(),
  );
}

class _NewRoutineSheet extends ConsumerStatefulWidget {
  const _NewRoutineSheet();

  @override
  ConsumerState<_NewRoutineSheet> createState() => _NewRoutineSheetState();
}

class _NewRoutineSheetState extends ConsumerState<_NewRoutineSheet> {
  final _nameController = TextEditingController();
  final Set<int> _selectedDays = {};
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty && _selectedDays.isNotEmpty;

  Future<void> _create() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    final routineDao = ref.read(routineDaoProvider);
    final routineId = await routineDao.createRoutine(
      RoutinesCompanion.insert(
        name: _nameController.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await routineDao.setActive(routineId);
    for (final weekday in _selectedDays) {
      await routineDao.upsertDay(
        RoutineDaysCompanion.insert(routine: routineId, weekday: weekday),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'New routine',
            style: TextStyle(
              color: AppColors.onBackground,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Give it a name and the days it runs on. Movements come next.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.onBackground),
            decoration: const InputDecoration(
              hintText: 'Routine name',
              filled: true,
              fillColor: AppColors.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const Text(
            'DAYS',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final selected = _selectedDays.contains(i);
              return InkWell(
                onTap: () => setState(
                  () =>
                      selected ? _selectedDays.remove(i) : _selectedDays.add(i),
                ),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.goldWash
                        : AppColors.surfaceRaised,
                    border: Border.all(
                      color: selected ? AppColors.gold : AppColors.line,
                    ),
                  ),
                  child: Text(
                    _kDayLetters[i],
                    style: TextStyle(
                      color: selected
                          ? AppColors.gold
                          : AppColors.onSurfaceMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isValid && !_saving ? _create : null,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF241B00),
                      ),
                    )
                  : const Text('CREATE', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
