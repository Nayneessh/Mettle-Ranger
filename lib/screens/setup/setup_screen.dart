import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../providers.dart';
import '../player/player_screen.dart';
import '../train/last_session_card.dart' show disciplineLabel;
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
  late SessionDraft _draft;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final defaultQuality =
        ref.read(settingsStreamProvider).valueOrNull?.defaultQuality ??
        CaptureQuality.p720;
    _draft = SessionDraft.defaultsFor(Discipline.bjj, quality: defaultQuality);
  }

  void _setDiscipline(Discipline d) {
    setState(() {
      final quality = _draft.quality;
      _draft = SessionDraft.defaultsFor(d, quality: quality)
        ..recordEnabled = _draft.recordEnabled;
    });
  }

  Future<void> _begin() async {
    if (!_draft.isValid || _starting) return;
    setState(() => _starting = true);

    final sessionDao = ref.read(sessionDaoProvider);
    final sessionId = await sessionDao.createSession(
      SessionsCompanion.insert(
        date: DateTime.now(),
        discipline: _draft.discipline,
        giFlag: Value(_draft.giFlag),
        roundsPlanned: _draft.roundCount,
      ),
    );

    final roundIds = <int>[];
    for (var i = 1; i <= _draft.roundCount; i++) {
      final id = await sessionDao.addRound(
        RoundsCompanion.insert(
          session: sessionId,
          number: i,
          duration: _draft.roundLengthSeconds,
          mode: _draft.roundMode,
        ),
      );
      roundIds.add(id);
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          sessionId: sessionId,
          roundIds: roundIds,
          draft: _draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                final selected = d == _draft.discipline;
                return ChoiceChip(
                  label: Text(disciplineLabel(d)),
                  selected: selected,
                  onSelected: (_) => _setDiscipline(d),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _SwitchRow(
              label: 'Gi',
              value: _draft.giFlag,
              onChanged: (v) => setState(() => _draft.giFlag = v),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Round type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RoundMode.values.map((m) {
                final selected = m == _draft.roundMode;
                return ChoiceChip(
                  label: Text(_roundModeLabel(m)),
                  selected: selected,
                  onSelected: (_) => setState(() => _draft.roundMode = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _StepperRow(
              label: 'Round length',
              valueLabel: _formatMinSec(_draft.roundLengthSeconds),
              onDecrement: () => setState(
                () => _draft.roundLengthSeconds =
                    (_draft.roundLengthSeconds - 30).clamp(30, 1800),
              ),
              onIncrement: () => setState(
                () => _draft.roundLengthSeconds =
                    (_draft.roundLengthSeconds + 30).clamp(30, 1800),
              ),
            ),
            const SizedBox(height: 12),
            _StepperRow(
              label: 'Rest length',
              valueLabel: _formatMinSec(_draft.restLengthSeconds),
              onDecrement: () => setState(
                () => _draft.restLengthSeconds = (_draft.restLengthSeconds - 15)
                    .clamp(0, 600),
              ),
              onIncrement: () => setState(
                () => _draft.restLengthSeconds = (_draft.restLengthSeconds + 15)
                    .clamp(0, 600),
              ),
            ),
            const SizedBox(height: 12),
            _StepperRow(
              label: 'Rounds',
              valueLabel: '${_draft.roundCount}',
              onDecrement: () => setState(
                () => _draft.roundCount = (_draft.roundCount - 1).clamp(1, 20),
              ),
              onIncrement: () => setState(
                () => _draft.roundCount = (_draft.roundCount + 1).clamp(1, 20),
              ),
            ),
            const SizedBox(height: 24),
            _SwitchRow(
              label: 'Record this session',
              value: _draft.recordEnabled,
              onChanged: (v) => setState(() => _draft.recordEnabled = v),
            ),
            if (_draft.recordEnabled) ...[
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
                    selected: {_draft.quality},
                    onSelectionChanged: (s) =>
                        setState(() => _draft.quality = s.first),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _draft.isValid && !_starting ? _begin : null,
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

String _roundModeLabel(RoundMode m) => switch (m) {
  RoundMode.technique => 'Technique',
  RoundMode.drill => 'Drill',
  RoundMode.pads => 'Pads',
  RoundMode.bag => 'Bag',
  RoundMode.spar => 'Spar',
  RoundMode.roll => 'Roll',
  RoundMode.conditioning => 'Conditioning',
};

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
