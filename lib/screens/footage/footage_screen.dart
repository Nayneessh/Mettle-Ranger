import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../train/last_session_card.dart' show disciplineLabel;
import 'clip_tile.dart';

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
  Discipline? _filter;

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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Footage',
              style: TextStyle(
                color: AppColors.onBackground,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
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
                  ...Discipline.values.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: disciplineLabel(d),
                        selected: _filter == d,
                        onTap: () => setState(() => _filter = d),
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
                data: (sessions) => _Grid(
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

class _Grid extends StatelessWidget {
  const _Grid({
    required this.recordings,
    required this.sessions,
    required this.filter,
  });

  final List<RecordingRow> recordings;
  final List<SessionRow> sessions;
  final Discipline? filter;

  @override
  Widget build(BuildContext context) {
    final sessionsById = {for (final s in sessions) s.id: s};
    final items = recordings
        .map((r) => (recording: r, session: sessionsById[r.session]))
        .where((pair) => pair.session != null)
        .where((pair) => filter == null || pair.session!.discipline == filter)
        .toList();

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No footage yet. Recorded sessions will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceMuted),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return ClipTile(
          recording: item.recording,
          session: item.session!,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ClipReviewScreen(recordingId: item.recording.id),
              ),
            );
          },
        );
      },
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

class _MeterSkeleton extends StatelessWidget {
  const _MeterSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 34);
}
