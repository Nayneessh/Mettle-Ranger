import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A short "type a note, Save or Cancel" prompt — shared by Player's MARK
/// button (live) and Clip Review's note-add button (after the fact), so a
/// note tied to a moment in a recording is written the same way from
/// either place. Typed only, no voice recording, per explicit product
/// decision. Returns the trimmed text, or null if cancelled or left blank.
Future<String?> promptForNoteText(
  BuildContext context, {
  String title = 'Note at this moment',
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
        maxLines: 4,
        style: const TextStyle(color: AppColors.onBackground),
        decoration: const InputDecoration(
          hintText: 'e.g. "Missed the underhook here"',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved != true) return null;
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}
