import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';
import 'trim_on_save.dart';

/// Recap (spec §2, screen 4): sRPE, notes, partner count, trim-on-save,
/// Save. Definition of done (spec §10): sRPE and notes save to the Session
/// record, trim-on-save actually deletes unflagged segments when chosen,
/// Save returns to Train with the new session visible immediately.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  final _notesController = TextEditingController();
  double _sRpe = 5;
  int _partnerCount = 1;
  bool _trimRequested = false;
  bool _saving = false;

  SessionRow? _session;
  RecordingRow? _recording;
  TrimPreview? _trimPreview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await ref
        .read(sessionDaoProvider)
        .sessionById(widget.sessionId);
    final recording = await ref
        .read(recordingDaoProvider)
        .forSession(widget.sessionId);
    TrimPreview? preview;
    if (recording != null) {
      preview = await TrimOnSave(ref.read(databaseProvider)).preview(recording);
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _recording = recording;
      _trimPreview = preview;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final session = _session;
    if (session != null) {
      await db.sessionDao.updateSession(
        session.copyWith(
          sRpe: Value(_sRpe.round()),
          notes: _notesController.text.trim(),
          partnerCount: _partnerCount,
        ),
      );
      await db.sessionDao.recalculateLoad(widget.sessionId);
    }

    if (_trimRequested && _recording != null) {
      await TrimOnSave(db).apply(_recording!);
    }

    ref.invalidate(totalStorageBytesProvider);

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Recap')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _Label('How hard was it? (sRPE)'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${_sRpe.round()}',
                  style: AppTextStyles.numeral(
                    fontSize: 28,
                    color: AppColors.gold,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _sRpe,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${_sRpe.round()}',
                    onChanged: (v) => setState(() => _sRpe = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Label('Partners'),
            const SizedBox(height: 8),
            Row(
              children: [
                _CountButton(
                  icon: Icons.remove,
                  onTap: () => setState(
                    () => _partnerCount = (_partnerCount - 1).clamp(0, 20),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '$_partnerCount',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.numeral(fontSize: 20),
                  ),
                ),
                _CountButton(
                  icon: Icons.add,
                  onTap: () => setState(
                    () => _partnerCount = (_partnerCount + 1).clamp(0, 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Label('Notes'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.onBackground),
              decoration: const InputDecoration(
                hintText: 'What worked, what to fix next time…',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            if (_recording != null && _trimPreview != null) ...[
              const SizedBox(height: 24),
              _TrimCard(
                preview: _trimPreview!,
                value: _trimRequested,
                onChanged: (v) => setState(() => _trimRequested = v),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF241B00),
                        ),
                      )
                    : const Text('Save', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _CountButton extends StatelessWidget {
  const _CountButton({required this.icon, required this.onTap});
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

class _TrimCard extends StatelessWidget {
  const _TrimCard({
    required this.preview,
    required this.value,
    required this.onChanged,
  });

  final TrimPreview preview;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final body = preview.wholeRecordingDropped
        ? 'No rounds are flagged. Trimming will delete this session\'s entire recording — '
              'the session itself stays in your log either way.'
        : 'Keep the ${preview.flaggedChapterCount} flagged moment'
              '${preview.flaggedChapterCount == 1 ? '' : 's'} and discard the rest '
              '(${preview.segmentsToDrop} of ${preview.segmentsToKeep + preview.segmentsToDrop} clip files). '
              'This cannot be undone.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trim on save',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
