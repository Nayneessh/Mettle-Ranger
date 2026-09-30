import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ads/ad_slot.dart';
import '../../ads/banner_ad_widget.dart';
import '../../ads/remove_ads_link.dart';
import '../../app_theme.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../platform/capture_providers.dart';
import '../../providers.dart';
import '../../widgets/storage_meter.dart';
import '../clip/clip_review_screen.dart';
import '../../widgets/labels.dart' show disciplineLabel;
import 'clip_tile.dart';
import 'delete_footage.dart';
import 'upload_footage_sheet.dart';

/// Footage (spec §2, screen 5): clip grid, persistent storage meter,
/// discipline filter chips. Definition of done (spec §10): grid reflects
/// real recorded sessions, storage meter reflects real device usage, filter
/// chips actually filter.
class FootageScreen extends ConsumerStatefulWidget {
  const FootageScreen({super.key});

  @override
  ConsumerState<FootageScreen> createState() => _FootageScreenState();
}

class _FootageScreenState extends ConsumerState<FootageScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(allRecordingsStreamProvider);
    final sessionsAsync = ref.watch(allSessionsStreamProvider);
    final usedAsync = ref.watch(totalStorageBytesProvider);
    final freeAsync = ref.watch(freeStorageBytesProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Footage',
                    style: TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => pickAndUploadFootage(context, ref),
                  icon: const Icon(Icons.upload_rounded, color: AppColors.gold),
                  tooltip: 'Upload footage',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: usedAsync.when(
              data: (used) => freeAsync.when(
                data: (free) => StorageMeter(usedBytes: used, freeBytes: free),
                loading: () => const _MeterSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              loading: () => const _MeterSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
            child: recordingsAsync.when(
              data: (recordings) => sessionsAsync.when(
                data: (sessions) => _DateGroupedList(
                  recordings: recordings,
                  sessions: sessions,
                  filter: _filter,
                ),
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
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
              child: Column(
                children: [
                  BannerAdWidget(slot: AdSlot.footage),
                  SizedBox(height: 4),
                  RemoveAdsLink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _FootageItem = ({RecordingRow recording, SessionRow session});

/// Groups Footage cards by the session's calendar date, newest day first —
/// "today: 3 rounds of punching bag" at a glance, rather than one undated
/// grid a user has to guess their way through.
class _DateGroupedList extends ConsumerWidget {
  const _DateGroupedList({
    required this.recordings,
    required this.sessions,
    required this.filter,
  });

  final List<RecordingRow> recordings;
  final List<SessionRow> sessions;
  final String? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsById = {for (final s in sessions) s.id: s};
    final items = recordings
        .map((r) => (recording: r, session: sessionsById[r.session]))
        .where((pair) => pair.session != null)
        .map((pair) => (recording: pair.recording, session: pair.session!))
        .where((pair) => filter == null || pair.session.discipline == filter)
        .toList();

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No footage yet. Recorded sessions show up here — or tap '
            'upload above to add a video already on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceMuted),
          ),
        ),
      );
    }

    final byDate = <DateTime, List<_FootageItem>>{};
    for (final item in items) {
      final day = DateTime(
        item.session.date.year,
        item.session.date.month,
        item.session.date.day,
      );
      byDate.putIfAbsent(day, () => []).add(item);
    }
    final days = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final dayItems = byDate[day]!;
        return Padding(
          padding: EdgeInsets.only(bottom: i == days.length - 1 ? 0 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateHeading(day),
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemCount: dayItems.length,
                itemBuilder: (context, j) {
                  final item = dayItems[j];
                  return ClipTile(
                    recording: item.recording,
                    session: item.session,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ClipReviewScreen(recordingId: item.recording.id),
                      ),
                    ),
                    onDelete: () =>
                        confirmAndDeleteRecording(context, ref, item.recording),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _dateHeading(DateTime day) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final diff = todayMidnight.difference(day).inDays;
    if (diff == 0) return 'TODAY · ${DateFormat('MMM d').format(day)}';
    if (diff == 1) return 'YESTERDAY · ${DateFormat('MMM d').format(day)}';
    return DateFormat('EEEE · MMM d').format(day).toUpperCase();
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

class _MeterSkeleton extends StatelessWidget {
  const _MeterSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 34);
}
