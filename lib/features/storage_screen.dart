import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../core/device_capacity_provider.dart';
import '../providers.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'cleanup_dialogs.dart';
import 'library_screen.dart' show SeriesGroup, formatBytes;

/// What Storage shows, derived once per library emission rather than per
/// widget rebuild: `byteSize` already lives on every chapter row, so the
/// whole screen is arithmetic over data the library stream carries — no file
/// tree is walked here.
class StorageSummary {
  const StorageSummary({
    required this.totalBytes,
    required this.offlineChapters,
    required this.offlineSeries,
    required this.finishedOfflineChapters,
    required this.finishedOfflineBytes,
    required this.series,
  });

  final int totalBytes;
  final int offlineChapters;
  final int offlineSeries;
  final int finishedOfflineChapters;
  final int finishedOfflineBytes;

  /// Series holding offline bytes, largest first.
  final List<SeriesStorage> series;
}

class SeriesStorage {
  const SeriesStorage({
    required this.group,
    required this.bytes,
    required this.offlineChapters,
    required this.partialChapters,
  });

  final SeriesGroup group;
  final int bytes;
  final int offlineChapters;
  final int partialChapters;
}

/// Storage totals, derived from the same library stream everything else uses
/// so the numbers can never disagree with the shelf.
final storageSummaryProvider = Provider<AsyncValue<StorageSummary>>(
  (ref) => ref.watch(allSeriesGroupsProvider).whenData((groups) {
    final series = <SeriesStorage>[];
    var total = 0;
    var chapters = 0;
    var finished = 0;
    var finishedBytes = 0;

    for (final group in groups) {
      var bytes = 0;
      var offline = 0;
      var partial = 0;
      for (final c in group.chapters) {
        if (c.contentPath == null) continue;
        bytes += c.byteSize;
        offline++;
        if (c.captureStatus == 'partial') partial++;
        if (c.readStatus == 'completed') {
          finished++;
          finishedBytes += c.byteSize;
        }
      }
      if (offline == 0) continue;
      total += bytes;
      chapters += offline;
      series.add(
        SeriesStorage(
          group: group,
          bytes: bytes,
          offlineChapters: offline,
          partialChapters: partial,
        ),
      );
    }
    series.sort((a, b) => b.bytes.compareTo(a.bytes));
    return StorageSummary(
      totalBytes: total,
      offlineChapters: chapters,
      offlineSeries: series.length,
      finishedOfflineChapters: finished,
      finishedOfflineBytes: finishedBytes,
      series: series,
    );
  }),
);

/// Size of the staging tree, for this screen only.
///
/// This one **does** walk a directory, which is why it is scoped to the
/// Storage screen rather than bundled with the device reading: the Library
/// header must never wait on a recursive listing to draw a percentage.
/// Device capacity comes from [deviceCapacityProvider] instead, so the pill
/// and this screen quote the same number.
final stagingBytesProvider = FutureProvider<int>(
  (ref) => ref.watch(fileStoreProvider).stagingByteSize(),
);

/// Where offline content actually goes, and how to get it back.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  bool _sortBySize = true;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(storageSummaryProvider);
    final capacity = ref.watch(deviceCapacityProvider).value;
    final staging = ref.watch(stagingBytesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          final free = capacity?.freeBytes;
          final usedPercent = capacity?.usedPercent;
          final temp = staging.value ?? 0;
          final series = [...s.series];
          if (!_sortBySize) {
            series.sort(
              (a, b) => a.group.displayName.toLowerCase().compareTo(
                b.group.displayName.toLowerCase(),
              ),
            );
          }
          final largest = s.series.isEmpty ? 1 : s.series.first.bytes;

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEB READER USES',
                      style: monoStyle(color: const Color(0xFF5F5B54)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatBytes(s.totalBytes),
                      style: serifStyle(size: 34),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.offlineChapters} chapter'
                      '${s.offlineChapters == 1 ? '' : 's'} across '
                      '${s.offlineSeries} series · reading history not '
                      'included',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5F5B54),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _Metric('${s.offlineChapters}', 'chapters offline'),
                    _Metric('${s.offlineSeries}', 'series offline'),
                    _Metric(
                      free == null ? '—' : formatBytes(free),
                      'available on device',
                      warn: free != null && free < 1024 * 1024 * 1024,
                    ),
                    // The number the Library shows, spelled out where there
                    // is room for it.
                    _Metric(
                      usedPercent == null ? '—' : '$usedPercent%',
                      'device storage used',
                    ),
                    _Metric(formatBytes(temp), 'temporary files'),
                  ],
                ),
              ),
              if (free == null)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDFDAD2)),
                  ),
                  child: const Text(
                    "Available device space can't be read right now. Capture "
                    'still works — space is checked as files are written.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Color(0xFF5F5B54),
                    ),
                  ),
                ),
              if (temp > 0) _TempFilesCard(bytes: temp),
              SectionLabel(
                'BY SERIES',
                trailing: _SortToggle(
                  label: _sortBySize ? 'Largest' : 'Name',
                  onTap: () => setState(() => _sortBySize = !_sortBySize),
                ),
              ),
              const Divider(),
              for (final row in series) ...[
                _SeriesRow(row: row, largestBytes: largest),
                const Divider(),
              ],
              const SectionLabel('FREE UP SPACE'),
              const Divider(),
              _CleanupRow(
                icon: Icons.auto_delete,
                label: 'Remove finished offline chapters',
                sub: s.finishedOfflineChapters == 0
                    ? 'Nothing finished is stored offline right now'
                    : '${s.finishedOfflineChapters} chapters read to the end · '
                          'frees ~${formatBytes(s.finishedOfflineBytes)}',
                enabled: s.finishedOfflineChapters > 0,
                onTap: () => _confirmGlobalCleanup(s),
              ),
              _CleanupRow(
                icon: Icons.checklist,
                label: 'Choose chapters to remove',
                sub: 'Open a series and select chapters yourself',
                enabled: series.isNotEmpty,
                onTap: () => context.push(
                  '/series/${series.first.group.item.id}?select=1',
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  'Removing offline files never deletes a series, read marks '
                  'or reading history. Chapters stay listed and can be '
                  'captured again any time.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.55,
                    color: Color(0xFFA39D93),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmGlobalCleanup(StorageSummary s) async {
    final ok = await showRemovalConfirm(
      context: context,
      summary: RemovalSummary(
        title: 'Remove finished offline chapters?',
        body:
            "Chapters you've read to the end will no longer be stored "
            'offline. They stay in your library with read marks and history, '
            'and you can capture any of them again.',
        facts: [
          ('Chapters', '${s.finishedOfflineChapters}'),
          ('Space freed', '~${formatBytes(s.finishedOfflineBytes)}'),
        ],
        lockNote:
            'Anything open in the reader or being captured right now is '
            'kept.',
      ),
    );
    if (!ok || !mounted) return;
    await ref.read(taskQueueProvider).enqueueCleanup();
    if (!mounted) return;
    showCleanupToast(
      context,
      text:
          'Removing ${s.finishedOfflineChapters} chapters — progress in '
          'Activity',
      icon: Icons.delete_sweep,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, {this.warn = false});

  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: warn ? const Color(0xFFF8EEDA) : const Color(0xFFF5F3EF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: warn ? const Color(0xFFE8D5B2) : const Color(0xFFE7E3DC),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: monoStyle(
            size: 15,
            color: warn ? const Color(0xFF4A2F08) : const Color(0xFF1B1A18),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF5F5B54)),
        ),
      ],
    ),
  );
}

class _TempFilesCard extends ConsumerWidget {
  const _TempFilesCard({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8EEDA),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8D5B2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.cleaning_services, size: 20, color: Color(0xFF8A5A1F)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatBytes(bytes)} of temporary files',
                style: TextStyle(
                  fontSize: 13,
                  fontVariations: wght(600),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A2F08),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Left behind by interrupted captures. Cleaning never touches '
                'saved chapters.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF6B4A15),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8A5A1F),
          ),
          onPressed: () async {
            final swept = await ref.read(fileStoreProvider).sweepStaging();
            ref.invalidate(stagingBytesProvider);
            unawaited(
              ref.read(deviceCapacityProvider.notifier).refresh(force: true),
            );
            if (!context.mounted) return;
            showCleanupToast(
              context,
              text: swept == 0
                  ? 'Nothing to clean'
                  : 'Temporary files cleaned · ${formatBytes(bytes)} freed',
              icon: Icons.cleaning_services,
            );
          },
          child: const Text('Clean'),
        ),
      ],
    ),
  );
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF3F1ED),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
      side: const BorderSide(color: Color(0xFFE7E3DC)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 16, color: Color(0xFF3E3A34)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF3E3A34)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.row, required this.largestBytes});

  final SeriesStorage row;
  final int largestBytes;

  @override
  Widget build(BuildContext context) {
    final pct = largestBytes == 0
        ? 0.0
        : (row.bytes / largestBytes).clamp(0.0, 1.0);
    return InkWell(
      key: ValueKey('storageRow-${row.group.item.id}'),
      onTap: () => context.push('/series/${row.group.item.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.group.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontVariations: wght(500),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.offlineChapters} chapters offline',
                    style: monoStyle(),
                  ),
                  if (row.partialChapters > 0) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_circle_down,
                          size: 14,
                          color: Color(0xFF8A5A1F),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${row.partialChapters} partial',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8A5A1F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatBytes(row.bytes), style: monoStyle(size: 13)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFEAE6E0),
                      color: const Color(0xFF35606F),
                    ),
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, size: 19, color: Color(0xFFB3ADA3)),
          ],
        ),
      ),
    );
  }
}

class _CleanupRow extends StatelessWidget {
  const _CleanupRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.5,
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF5F5B54)),
      title: Text(label, style: const TextStyle(fontSize: 14.5)),
      subtitle: Text(
        sub,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xFF8C877E),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 19,
        color: Color(0xFFB3ADA3),
      ),
      onTap: enabled ? onTap : null,
    ),
  );
}

/// The Library header's storage entry: a disk glyph and one number.
///
/// Deliberately tiny. It shows **device** usage — not the library's share of
/// the disk, which would be a different and far less useful fact — and it
/// reads that from [deviceCapacityProvider], which is one throttled platform
/// call and nothing else. The previous version watched a provider that also
/// walked the staging tree, so drawing the Library header waited on a
/// recursive directory listing.
///
/// Fixed width, because a variable-width readout ("1.2 GB free" → "834 MB
/// free") nudged the Archive and Settings buttons every time it refreshed.
class StoragePill extends ConsumerWidget {
  const StoragePill({super.key});

  /// Enough for the glyph plus "100%", and never more. Fixed so the number
  /// changing cannot nudge the buttons beside it.
  static const double width = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(deviceCapacityProvider).value;
    final percent = capacity?.usedPercent;
    // Low-space warning stays on *free* bytes: 8% left of a small disk is
    // urgent in a way 92% used does not convey on a large one.
    final free = capacity?.freeBytes;
    final low = free != null && free < 1024 * 1024 * 1024;
    final critical = free != null && free < 500 * 1024 * 1024;

    final fg = critical
        ? const Color(0xFF8E3B31)
        : low
        ? const Color(0xFF8A5A1F)
        // Healthy: the same ink as the other header glyphs, so it is quiet
        // by belonging rather than by being faint.
        : kHeaderIconColor;

    // Unknown capacity shows the glyph alone. Inventing a percentage from a
    // half-known device is the one thing this must not do.
    final label = percent == null
        ? 'Device storage — usage unavailable'
        : 'Device storage $percent% used';

    return Semantics(
      button: true,
      label: label,
      // The glyph and the bare "72%" say less than the label does, and a
      // screen reader announcing both says it twice.
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: width,
          // Same height as every other action in the header, so the row has
          // one centre line rather than two.
          height: kHeaderActionSize,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => LeaveBrowserGuard.push(context, '/storage'),
              customBorder: const CircleBorder(),
              // Scale-down rather than clip: the box is fixed, so a wider
              // font (or a text-scale setting) must shrink the number rather
              // than overflow the header.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The same glyph size as its neighbours: at 15pt against
                  // their 22pt it read as a different family of thing.
                  Icon(Icons.storage, size: kHeaderIconSize, color: fg),
                  if (percent != null) ...[
                    const SizedBox(width: 3),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$percent%',
                          maxLines: 1,
                          style: monoStyle(
                            size: 12,
                            color: fg,
                            weight: critical || low
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
