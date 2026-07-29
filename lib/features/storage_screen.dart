import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../core/device_capacity_provider.dart';
import '../core/device_storage.dart';
import '../providers.dart';
import '../ui/palette.dart';
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
    final palette = AppPalette.of(context);
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
              // The device first: it is the number that decides whether a
              // capture will finish, and the one the Library pill quotes.
              _DeviceMeter(capacity: capacity),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEB READER USES',
                      style: monoStyle(color: palette.inkMuted),
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
                      style: TextStyle(fontSize: 12.5, color: palette.inkMuted),
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
                    // Free space stays as a figure; the *percentage* and its
                    // colour live in the meter above, so this tile does not
                    // carry a second, differently-derived warning.
                    _Metric(
                      free == null ? '—' : formatBytes(free),
                      'available on device',
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
                    color: palette.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    "Available device space can't be read right now. Capture "
                    'still works — space is checked as files are written.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: palette.inkMuted,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  'Removing offline files never deletes a series, read marks '
                  'or reading history. Chapters stay listed and can be '
                  'captured again any time.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.55,
                    color: palette.inkFaint,
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

/// A plain figure. Deliberately never coloured: exactly one thing on this
/// screen carries the warning state, and it is the meter (D51).
class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: monoStyle(size: 15, color: palette.ink)),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// How full the device is: the percentage, a bar, and one line of plain
/// language that changes with the level.
///
/// The percentage is the headline because it is the thing that predicts
/// whether the next capture finishes — "12 GB free" means nothing without
/// knowing the size of the disk it is free on.
class _DeviceMeter extends StatelessWidget {
  const _DeviceMeter({required this.capacity});

  final DeviceCapacity? capacity;

  @override
  Widget build(BuildContext context) {
    final level = capacity?.level ?? StorageLevel.unknown;
    final look = storageLook(level, AppPalette.of(context));
    final percent = capacity?.usedPercent;
    final free = capacity?.freeBytes;
    final total = capacity?.totalBytes;

    return Container(
      key: const ValueKey('deviceStorageMeter'),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 2),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: look.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: look.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.storage, size: 18, color: look.ink),
              const SizedBox(width: 8),
              Text(
                'DEVICE STORAGE',
                style: monoStyle(size: 11, color: look.ink),
              ),
              const Spacer(),
              Text(
                percent == null ? '—' : '$percent%',
                style: serifStyle(size: 30, color: look.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // No bar at all when the platform will not report capacity: an
          // empty track would read as "0% used", which is a claim.
          if (percent != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: look.track,
                valueColor: AlwaysStoppedAnimation<Color>(look.fill),
              ),
            ),
            const SizedBox(height: 9),
          ],
          Text(
            _line(look, level, percent, free, total),
            style: TextStyle(fontSize: 12.5, height: 1.45, color: look.ink),
          ),
        ],
      ),
    );
  }

  /// Says what the colour means, and what to do about it — never just a
  /// restatement of the number above.
  String _line(
    StorageLook look,
    StorageLevel level,
    int? percent,
    int? free,
    int? total,
  ) {
    if (percent == null) {
      return "This device won't report its capacity, so the figure above is "
          'unknown. Captures still check for space as they write.';
    }
    final space = free == null
        ? ''
        : total == null
        ? '${formatBytes(free)} free. '
        : '${formatBytes(free)} free of ${formatBytes(total)}. ';
    return switch (level) {
      StorageLevel.critical =>
        '$space${look.label} — a large chapter may not finish. Remove '
            'offline files below, or free space elsewhere on the device.',
      StorageLevel.warning =>
        '$space${look.label} — worth removing chapters you have finished '
            'before starting a long capture.',
      _ => '${space}Plenty of room for more chapters.',
    };
  }
}

class _TempFilesCard extends ConsumerWidget {
  const _TempFilesCard({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: palette.warnContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.cleaning_services, size: 20, color: palette.warn),
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
                    color: palette.onWarnContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Left behind by interrupted captures. Cleaning never touches '
                  'saved chapters.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: palette.onWarnContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.warn,
              foregroundColor: palette.isDark
                  ? palette.warnContainer
                  : palette.onPrimary,
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
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, size: 16, color: palette.inkStrong),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: palette.inkStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.row, required this.largestBytes});

  final SeriesStorage row;
  final int largestBytes;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
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
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.offlineChapters} chapters offline',
                    style: monoStyle(color: palette.inkFaint),
                  ),
                  if (row.partialChapters > 0) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_circle_down,
                          size: 14,
                          color: palette.warn,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${row.partialChapters} partial',
                          style: TextStyle(fontSize: 11.5, color: palette.warn),
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
                Text(
                  formatBytes(row.bytes),
                  style: monoStyle(size: 13, color: palette.inkMuted),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: palette.border,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right, size: 19, color: palette.inkFaint),
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
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Disabled reads as disabled through the palette's own disabled inks
    // rather than a blanket opacity, which used to take the row's borders and
    // glyphs below the point where they were visible at all on dark.
    final ink = enabled ? palette.ink : palette.inkDisabled;
    final sub2 = enabled ? palette.inkFaint : palette.inkDisabled;
    return ListTile(
      leading: Icon(icon, color: enabled ? palette.inkMuted : sub2),
      title: Text(label, style: TextStyle(fontSize: 14.5, color: ink)),
      subtitle: Text(
        sub,
        style: TextStyle(fontSize: 12, height: 1.4, color: sub2),
      ),
      trailing: Icon(Icons.chevron_right, size: 19, color: sub2),
      onTap: enabled ? onTap : null,
    );
  }
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
    // The colour is the percentage's job now (D51): one rule, shared with
    // the Storage screen, rather than a second free-bytes threshold here.
    final level = capacity?.level ?? StorageLevel.unknown;
    final look = storageLook(level, AppPalette.of(context));
    final fg = look.ink;

    // Unknown capacity shows the glyph alone. Inventing a percentage from a
    // half-known device is the one thing this must not do.
    final label = percent == null
        ? 'Device storage — usage unavailable'
        : 'Device storage $percent% used · ${look.label}';

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
                            weight: level.isConcerning
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
