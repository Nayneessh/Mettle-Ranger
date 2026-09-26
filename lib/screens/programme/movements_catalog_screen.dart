import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../../widgets/labels.dart'
    show disciplineLabel, disciplineLabelForKey, movementCategoryLabelForKey;
import 'new_movement_screen.dart';

/// Movements catalog: every technique, combo, drill, conditioning piece or
/// sparring block a Programme day can reference. Seeded with a starter set
/// per discipline; users add their own alongside it (Winter Arc reference's
/// "Movements" screen, adapted from a muscle/equipment split to a
/// discipline/category one).
class MovementsCatalogScreen extends ConsumerStatefulWidget {
  const MovementsCatalogScreen({super.key});

  @override
  ConsumerState<MovementsCatalogScreen> createState() =>
      _MovementsCatalogScreenState();
}

class _MovementsCatalogScreenState
    extends ConsumerState<MovementsCatalogScreen> {
  String? _filter;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addMovement() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewMovementScreen()));
  }

  Future<void> _confirmDelete(MovementRow movement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${movement.name}"?'),
        content: const Text(
          'Removing it also takes it off any Programme day it is placed on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(movementDaoProvider).deleteCustomMovement(movement.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(allMovementsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Movements'),
        actions: [
          IconButton(
            onPressed: _addMovement,
            icon: const Icon(Icons.add),
            tooltip: 'New movement',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.onBackground),
                decoration: InputDecoration(
                  hintText: 'Search movements',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    ...Discipline.values.map((d) {
                      final key = d.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: disciplineLabel(d),
                          selected: _filter == key,
                          onTap: () => setState(() => _filter = key),
                        ),
                      );
                    }),
                    ...(ref
                                .watch(allCustomDisciplinesStreamProvider)
                                .valueOrNull ??
                            const [])
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: c.name,
                              selected: _filter == c.name,
                              onTap: () => setState(() => _filter = c.name),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: movementsAsync.when(
                data: (movements) {
                  final filtered = movements.where((m) {
                    final matchesFilter =
                        _filter == null ||
                        m.discipline == _filter ||
                        m.discipline == null;
                    final matchesQuery =
                        _query.isEmpty ||
                        m.name.toLowerCase().contains(_query.toLowerCase());
                    return matchesFilter && matchesQuery;
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No movements match this filter.',
                        style: TextStyle(color: AppColors.onSurfaceMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _MovementTile(
                      movement: filtered[i],
                      onDelete: filtered[i].isCustom
                          ? () => _confirmDelete(filtered[i])
                          : null,
                    ),
                  );
                },
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
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, this.onDelete});

  final MovementRow movement;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.name,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (movement.discipline != null)
                      disciplineLabelForKey(movement.discipline!),
                    movementCategoryLabelForKey(movement.category),
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 12.5,
                  ),
                ),
                if (movement.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    movement.notes,
                    style: const TextStyle(
                      color: AppColors.onSurfaceFaint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.onSurfaceFaint,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
