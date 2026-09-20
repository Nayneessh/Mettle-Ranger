import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../../widgets/labels.dart' show disciplineLabel;
import 'movement_labels.dart';

/// New movement (Winter Arc reference's "New movement" screen, adapted):
/// name, optional detail, discipline, and category. Anything added here can
/// be placed on any Programme day or referenced from a session's notes —
/// same billing the reference app gives its own catalog entries.
class NewMovementScreen extends ConsumerStatefulWidget {
  const NewMovementScreen({super.key});

  @override
  ConsumerState<NewMovementScreen> createState() => _NewMovementScreenState();
}

class _NewMovementScreenState extends ConsumerState<NewMovementScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  Discipline? _discipline;
  MovementCategory _category = MovementCategory.technique;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isValid => _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    await ref.read(movementDaoProvider).addMovement(
          MovementsCompanion.insert(
            name: _nameController.text.trim(),
            discipline: Value(_discipline),
            category: _category,
            notes: Value(_notesController.text.trim()),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New movement'),
        actions: [
          TextButton(
            onPressed: _isValid && !_saving ? _save : null,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text(
              'Anything you add here can be used on any Programme day.',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.onBackground),
              decoration: const InputDecoration(
                hintText: 'Name',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: AppColors.onBackground),
              decoration: const InputDecoration(
                hintText: 'Notes (e.g. "Collar-tie entry")',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Discipline'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _discipline == null,
                  onSelected: (_) => setState(() => _discipline = null),
                ),
                ...Discipline.values.map(
                  (d) => ChoiceChip(
                    label: Text(disciplineLabel(d)),
                    selected: _discipline == d,
                    onSelected: (_) => setState(() => _discipline = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Category'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MovementCategory.values.map((c) {
                return ChoiceChip(
                  label: Text(movementCategoryLabel(c)),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isValid && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF241B00),
                        ),
                      )
                    : const Text('ADD MOVEMENT', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
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
