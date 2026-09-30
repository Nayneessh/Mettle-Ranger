import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../domain/enums.dart';
import '../providers.dart';
import 'labels.dart' show roundModeLabel;
import 'lookup_dialogs.dart';

/// A bottom sheet to pick a round type — built-in [RoundMode]s, any custom
/// round types already added, and an "Add" chip for a new one. Shared by
/// Setup's own inline picker and the Player screen's "change round type"
/// control, so there is exactly one round-type picking experience in the
/// app, not two that could drift apart.
///
/// Returns the chosen mode's stored key, or null if the sheet was dismissed
/// without picking one.
Future<String?> showRoundModePicker(
  BuildContext context,
  WidgetRef ref, {
  required String currentMode,
  String title = 'Round type',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) =>
        _RoundModePickerSheet(currentMode: currentMode, title: title),
  );
}

class _RoundModePickerSheet extends ConsumerWidget {
  const _RoundModePickerSheet({required this.currentMode, required this.title});

  final String currentMode;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customModes =
        ref.watch(allCustomRoundModesStreamProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
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
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...RoundMode.values.map((m) {
                final key = m.name;
                return ChoiceChip(
                  label: Text(roundModeLabel(m)),
                  selected: key == currentMode,
                  onSelected: (_) => Navigator.of(context).pop(key),
                );
              }),
              ...customModes.map(
                (c) => ChoiceChip(
                  label: Text(c.name),
                  selected: c.name == currentMode,
                  onSelected: (_) => Navigator.of(context).pop(c.name),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: () async {
                  final added = await addCustomRoundMode(context, ref);
                  if (added != null && context.mounted) {
                    Navigator.of(context).pop(added);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
