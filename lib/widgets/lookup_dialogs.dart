import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../domain/enums.dart';
import '../providers.dart';
import 'labels.dart'
    show disciplineLabel, movementCategoryLabel, roundModeLabel;

/// A minimal "type a name, Add or Cancel" prompt — the same shape every
/// custom lookup list (disciplines, movement categories, round types) needs
/// to add an entry. Returns the trimmed name, or null if cancelled or left
/// empty.
Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  required String hintText,
}) async {
  final controller = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.onBackground),
        decoration: InputDecoration(hintText: hintText),
        onSubmitted: (_) => Navigator.pop(ctx, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (saved != true) return null;
  final name = controller.text.trim();
  return name.isEmpty ? null : name;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Prompts for a new custom discipline, adds it, and returns its name so the
/// caller can select it immediately — or null if the user cancelled, left it
/// blank, or it collided with an existing name. Shared by Settings, Today's
/// quick-add, Setup, and the Movements catalog/New movement screens, so
/// "add a discipline" exists in exactly one flow.
Future<String?> addCustomDiscipline(BuildContext context, WidgetRef ref) async {
  final name = await _promptForName(
    context,
    title: 'New discipline',
    hintText: 'e.g. "Kickboxing"',
  );
  if (name == null || !context.mounted) return null;

  // A custom discipline is stored as its own name (see
  // `Sessions.discipline`'s doc comment), so a name matching a built-in's
  // key or label would be indistinguishable from that built-in everywhere
  // the key is resolved back to a label/color.
  final collidesWithBuiltin = Discipline.values.any(
    (d) =>
        d.name.toLowerCase() == name.toLowerCase() ||
        disciplineLabel(d).toLowerCase() == name.toLowerCase(),
  );
  if (collidesWithBuiltin) {
    _showSnack(context, '"$name" is already built in.');
    return null;
  }

  try {
    await ref.read(customDisciplineDaoProvider).addDiscipline(name);
    return name;
  } catch (_) {
    if (context.mounted) _showSnack(context, '"$name" already exists.');
    return null;
  }
}

/// Same shape as [addCustomDiscipline], for movement categories.
Future<String?> addCustomMovementCategory(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await _promptForName(
    context,
    title: 'New category',
    hintText: 'e.g. "Clinch work"',
  );
  if (name == null || !context.mounted) return null;

  final collidesWithBuiltin = MovementCategory.values.any(
    (c) =>
        c.name.toLowerCase() == name.toLowerCase() ||
        movementCategoryLabel(c).toLowerCase() == name.toLowerCase(),
  );
  if (collidesWithBuiltin) {
    _showSnack(context, '"$name" is already built in.');
    return null;
  }

  try {
    await ref.read(customMovementCategoryDaoProvider).addCategory(name);
    return name;
  } catch (_) {
    if (context.mounted) _showSnack(context, '"$name" already exists.');
    return null;
  }
}

/// Same shape as [addCustomDiscipline], for round types. A custom round
/// type never counts as "live" in the sparring ratio — see
/// `Rounds.mode`'s doc comment in data/tables.dart.
Future<String?> addCustomRoundMode(BuildContext context, WidgetRef ref) async {
  final name = await _promptForName(
    context,
    title: 'New round type',
    hintText: 'e.g. "Clinch rounds"',
  );
  if (name == null || !context.mounted) return null;

  final collidesWithBuiltin = RoundMode.values.any(
    (m) =>
        m.name.toLowerCase() == name.toLowerCase() ||
        roundModeLabel(m).toLowerCase() == name.toLowerCase(),
  );
  if (collidesWithBuiltin) {
    _showSnack(context, '"$name" is already built in.');
    return null;
  }

  try {
    await ref.read(customRoundModeDaoProvider).addRoundMode(name);
    return name;
  } catch (_) {
    if (context.mounted) _showSnack(context, '"$name" already exists.');
    return null;
  }
}
