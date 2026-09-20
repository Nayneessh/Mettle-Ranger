import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_theme.dart';
import '../../backup/backup_providers.dart';
import '../../backup/export_service.dart';
import '../../backup/sign_in_sheet.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';

const _kExportService = ExportService();

/// Settings (new screen): units/behaviour, weekly and body targets, cloud
/// backup, CSV export, and reset. Adapted from the Winter Arc reference's
/// own Settings screen — "Weight step" and "Start rest automatically" are
/// left out (nothing in this app's round-based training maps to a
/// per-set weight increment or a rest timer separate from the round timer
/// already built), and "Lift goals" is left out entirely: this app tracks
/// techniques and rounds, not loaded lifts, so a 3-stage weight-progression
/// goal has no honest equivalent here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsStreamProvider);
    final goalsAsync = ref.watch(goalsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: settingsAsync.when(
          data: (settings) => goalsAsync.when(
            data: (goals) => _SettingsBody(settings: settings, goals: goals),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.critical))),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.critical))),
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings, required this.goals});

  final SettingsRow settings;
  final GoalsRow goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInStreamProvider).valueOrNull ?? false;
    final client = ref.watch(backupClientProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionLabel('Units and behaviour'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WEIGHT UNIT',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              SegmentedButton<UnitSystem>(
                segments: const [
                  ButtonSegment(value: UnitSystem.metric, label: Text('Kilograms')),
                  ButtonSegment(value: UnitSystem.imperial, label: Text('Pounds')),
                ],
                selected: {settings.units},
                onSelectionChanged: (s) => ref
                    .read(settingsDaoProvider)
                    .save(SettingsCompanion(units: Value(s.first))),
              ),
              const SizedBox(height: 6),
              const Text(
                'Everything is stored in kilograms whatever you choose here, so switching never rewrites a recorded check-in.',
                style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 11.5, height: 1.3),
              ),
              const Divider(height: 28),
              _SwitchRow(
                label: 'Keep the screen awake',
                sublabel: 'Only while a session is actually in progress',
                value: settings.keepScreenAwake,
                onChanged: (v) => ref
                    .read(settingsDaoProvider)
                    .save(SettingsCompanion(keepScreenAwake: Value(v))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Targets'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              _TargetRow(
                label: 'Sessions per week',
                value: '${goals.weeklySessionTarget}',
                onTap: () => _editIntTarget(
                  context,
                  ref,
                  title: 'Sessions per week',
                  initial: goals.weeklySessionTarget,
                  onSave: (v) => ref
                      .read(goalsDaoProvider)
                      .save(GoalsCompanion(weeklySessionTarget: Value(v))),
                ),
              ),
              const Divider(height: 1),
              _TargetRow(
                label: 'Mat time per week',
                value: '${goals.weeklyMatMinutesTarget} min',
                onTap: () => _editIntTarget(
                  context,
                  ref,
                  title: 'Mat time per week (minutes)',
                  initial: goals.weeklyMatMinutesTarget,
                  onSave: (v) => ref
                      .read(goalsDaoProvider)
                      .save(GoalsCompanion(weeklyMatMinutesTarget: Value(v))),
                ),
              ),
              const Divider(height: 1),
              _TargetRow(
                label: 'Bodyweight',
                value: goals.targetWeightKg == null ? 'Not set' : '${goals.targetWeightKg!.toStringAsFixed(0)} kg',
                onTap: () => _editDoubleTarget(
                  context,
                  ref,
                  title: 'Target bodyweight (kg)',
                  initial: goals.targetWeightKg,
                  onSave: (v) =>
                      ref.read(goalsDaoProvider).save(GoalsCompanion(targetWeightKg: Value(v))),
                ),
              ),
              const Divider(height: 1),
              _TargetRow(
                label: 'Body fat',
                value: goals.targetBodyFatPercent == null
                    ? 'Not set'
                    : '${goals.targetBodyFatPercent!.toStringAsFixed(0)}%',
                onTap: () => _editDoubleTarget(
                  context,
                  ref,
                  title: 'Target body fat (%)',
                  initial: goals.targetBodyFatPercent,
                  onSave: (v) => ref
                      .read(goalsDaoProvider)
                      .save(GoalsCompanion(targetBodyFatPercent: Value(v))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Your data'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your training log lives on this phone. Footage never leaves it. '
                'Cloud backup covers the log only — sign in so it survives a lost phone.',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (!client.isConfigured)
                const Text(
                  'Cloud backup is not configured in this build.',
                  style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 12.5),
                )
              else if (signedIn) ...[
                _DataButton(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Back up now',
                  onTap: () async {
                    await ref.read(backupServiceProvider).backupNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Backed up.')));
                    }
                  },
                ),
                const SizedBox(height: 10),
                _DataButton(
                  icon: Icons.logout,
                  label: 'Sign out (${client.signedInEmail ?? ''})',
                  onTap: () => ref.read(backupClientProvider).signOut(),
                ),
              ] else
                _DataButton(
                  icon: Icons.cloud_outlined,
                  label: 'Sign in to back up',
                  onTap: () => showBackupSignInSheet(context, ref),
                ),
              const SizedBox(height: 10),
              _DataButton(
                icon: Icons.download_outlined,
                label: 'Export every session (CSV)',
                onTap: () async {
                  final sessions = await ref.read(sessionDaoProvider).allSessions();
                  await _kExportService.exportSessions(sessions);
                },
              ),
              const SizedBox(height: 10),
              _DataButton(
                icon: Icons.download_outlined,
                label: 'Export body data (CSV)',
                onTap: () async {
                  final checkIns = await ref.read(bodyCheckInDaoProvider).allCheckIns();
                  await _kExportService.exportBodyCheckIns(checkIns);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Reset'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Erases every session, routine, movement and check-in on this device and '
                'puts the app back to how it shipped. Footage on disk is deleted too. '
                'Back up first if you want to keep any of it.',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.critical,
                    side: const BorderSide(color: AppColors.critical),
                  ),
                  onPressed: () => _confirmReset(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Erase everything and start over'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editIntTarget(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int initial,
    required void Function(int) onSave,
  }) async {
    final controller = TextEditingController(text: '$initial');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppColors.onBackground),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) onSave(result);
  }

  Future<void> _editDoubleTarget(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required double? initial,
    required void Function(double?) onSave,
  }) async {
    final controller = TextEditingController(text: initial?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: AppColors.onBackground),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    onSave(result.isEmpty ? null : double.tryParse(result));
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Erase everything?'),
        content: const Text(
          'This cannot be undone. Every session, routine, movement and check-in on this device will be gone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(databaseProvider).resetEverything();
    await _deleteRecordingFiles();
    ref.invalidate(totalStorageBytesProvider);
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _deleteRecordingFiles() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/recordings');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.onBackground, fontSize: 15)),
              const SizedBox(height: 2),
              Text(sublabel, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.onBackground, fontSize: 15)),
            ),
            Text(value, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceFaint, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DataButton extends StatelessWidget {
  const _DataButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}
