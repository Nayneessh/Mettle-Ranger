import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../player/player_screen.dart';
import '../../widgets/labels.dart' show disciplineLabel, roundModeLabel;
import 'session_draft.dart';

/// Session setup (spec §2, screen 2): discipline, gi, round length/rest/
/// count, record toggle. Begin persists the pending session and navigates to
/// a correctly configured Player (spec §10).
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  SessionDraft? _draft;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialDraft());
  }

  /// Defaults to whatever the user actually trains, not a fixed discipline —
  /// the app is not "heavily inclined towards" any one martial art, so
  /// nothing here hardcodes an always-selected default the way defaulting to
  /// [Discipline.bjj] on every open did before. Falls back to the first
  /// listed discipline only when there is no session history yet to learn
  /// from — a brand-new install has no "usual" discipline to default to.
  Future<void> _loadInitialDraft() async {
    final defaultQuality =
        ref.read(settingsStreamProvider).valueOrNull?.defaultQuality ??
        CaptureQuality.p720;
    final sessions = await ref.read(sessionDaoProvider).allSessions();
    final discipline = sessions.isNotEmpty ? sessions.first.discipline : Discipline.values.first;
    if (!mounted) return;
    setState(() {
      _draft = SessionDraft.defaultsFor(discipline, quality: defaultQuality);
    });
  }

  void _setDiscipline(Discipline d) {
    final current = _draft;
    if (current == null) return;
    setState(() {
      _draft = SessionDraft.defaultsFor(d, quality: current.quality)
        ..recordEnabled = current.recordEnabled;
    });
  }

  Future<void> _begin() async {
    final draft = _draft;
    if (draft == null || !draft.isValid || _starting) return;
    setState(() => _starting = true);

    final sessionDao = ref.read(sessionDaoProvider);
    final sessionId = await sessionDao.createSession(
      SessionsCompanion.insert(
        date: DateTime.now(),
        discipline: draft.discipline,
        giFlag: Value(draft.giFlag),
        roundsPlanned: draft.roundCount,
      ),
    );

    final roundIds = <int>[];
    for (var i = 1; i <= draft.roundCount; i++) {
      final id = await sessionDao.addRound(
        RoundsCompanion.insert(
          session: sessionId,
          number: i,
          duration: draft.roundLengthSeconds,
          mode: draft.roundMode,
        ),
      );
      roundIds.add(id);
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(sessionId: sessionId, roundIds: roundIds, draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Session Setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _SectionLabel('Discipline'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Discipline.values.map((d) {
                final selected = d == draft.discipline;
                return ChoiceChip(
                  label: Text(disciplineLabel(d)),
                  selected: selected,
                  onSelected: (_) => _setDiscipline(d),
                );
              }).toList(),
            ),
            // Gi only means anything for BJJ — showing it for every
            // discipline was what made the app read as BJJ-first even
            // though it welcomes every martial art equally.
            if (draft.discipline == Discipline.bjj) ...[
              const SizedBox(height: 24),
              _SwitchRow(
                label: 'Gi',
                value: draft.giFlag,
                onChanged: (v) => setState(() => draft.giFlag = v),
              ),
            ],
            const SizedBox(height: 24),
            const _SectionLabel('Round type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RoundMode.values.map((m) {
                final selected = m == draft.roundMode;
                return ChoiceChip(
                  label: Text(roundModeLabel(m)),
                  selected: selected,
                  onSelected: (_) => setState(() => draft.roundMode = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _StepperRow(
              label: 'Round length',
              valueLabel: _formatMinSec(draft.roundLengthSeconds),
              onDecrement: () => setState(
                () => draft.roundLengthSeconds =
                    (draft.roundLengthSeconds - 30).clamp(30, 1800),
              ),
              onIncrement: () => setState(
                () => draft.roundLengthSeconds =
                    (draft.roundLengthSeconds + 30).clamp(30, 1800),
              ),
            ),
            const SizedBox(height: 12),
            _StepperRow(
              label: 'Rest length',
              valueLabel: _formatMinSec(draft.restLengthSeconds),
              onDecrement: () => setState(
                () => draft.restLengthSeconds = (draft.restLengthSeconds - 15)
                    .clamp(0, 600),
              ),
              onIncrement: () => setState(
                () => draft.restLengthSeconds = (draft.restLengthSeconds + 15)
                    .clamp(0, 600),
              ),
            ),
            const SizedBox(height: 12),
            _StepperRow(
              label: 'Rounds',
              valueLabel: '${draft.roundCount}',
              onDecrement: () => setState(
                () => draft.roundCount = (draft.roundCount - 1).clamp(1, 20),
              ),
              onIncrement: () => setState(
                () => draft.roundCount = (draft.roundCount + 1).clamp(1, 20),
              ),
            ),
            const SizedBox(height: 24),
            _SwitchRow(
              label: 'Record this session',
              value: draft.recordEnabled,
              onChanged: (v) => setState(() => draft.recordEnabled = v),
            ),
            if (draft.recordEnabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Quality',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<CaptureQuality>(
                    segments: const [
                      ButtonSegment(
                        value: CaptureQuality.p720,
                        label: Text('720p'),
                      ),
                      ButtonSegment(
                        value: CaptureQuality.p1080,
                        label: Text('1080p'),
                      ),
                    ],
                    selected: {draft.quality},
                    onSelectionChanged: (s) =>
                        setState(() => draft.quality = s.first),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: draft.isValid && !_starting ? _begin : null,
                child: _starting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF241B00),
                        ),
                      )
                    : const Text('Begin', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMinSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
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
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.onBackground, fontSize: 15),
        ),
        const Spacer(),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String valueLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.onBackground, fontSize: 15),
        ),
        const Spacer(),
        _RoundIconButton(icon: Icons.remove, onTap: onDecrement),
        SizedBox(
          width: 64,
          child: Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.numeral(fontSize: 20),
          ),
        ),
        _RoundIconButton(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.onBackground),
      ),
    );
  }
}
