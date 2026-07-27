import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'library_screen.dart' show SeriesGroup, formatBytes, formatRelative;

/// Series the user has tucked away. Everything is still on the device; the
/// only thing archiving changed is visibility and update checking — and this
/// screen exists to say that plainly and to undo it in one tap.
class ArchivedScreen extends ConsumerWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(archivedGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived')),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      size: 30,
                      color: Color(0xFF9A948A),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nothing archived',
                      style: TextStyle(
                        fontSize: 16,
                        fontVariations: wght(600),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Archiving hides a finished series from the library '
                      'without deleting anything. Find it in a series’ '
                      'menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: Color(0xFF5F5B54),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Divider(),
              for (final group in list) ...[
                _ArchivedRow(group: group),
                const Divider(),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Archiving never deletes anything. Restored series return '
                  'to the library exactly as they were.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF8C877E),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchivedRow extends ConsumerWidget {
  const _ArchivedRow({required this.group});

  final SeriesGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = group.chapters.fold<int>(0, (sum, c) => sum + c.byteSize);
    final meta = [
      '${group.offlineCount} chapter${group.offlineCount == 1 ? '' : 's'} offline',
      if (bytes > 0) formatBytes(bytes),
      if (group.item.archivedAt != null)
        'archived ${formatRelative(group.item.archivedAt)}',
    ].join(' · ');

    return InkWell(
      key: ValueKey('archivedRow-${group.item.id}'),
      onTap: () => context.push('/series/${group.item.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            MonogramTile(id: group.item.id, title: group.displayName),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontVariations: wght(600),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5F5B54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () =>
                  ref.read(seriesRepositoryProvider).restore(group.item.id),
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }
}
