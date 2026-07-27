import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/features/storage_screen.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/cleanup.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

/// The Storage screen's numbers: derived from real stored data, reactive to
/// removals, and never counting things that are not on the device.
void main() {
  late AppDatabase db;
  late Directory root;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_storage');
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(FileStore(root)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> seedSeries(String id, String title) => db.upsertLibraryItem(
    LibraryItem(
      lifecycle: 'active',
      id: id,
      title: title,
      sourceUrl: 'https://x.example/manga/$id',
      host: 'x.example',
      seriesKey: '/manga/$id',
      createdAt: DateTime(2026, 7, 1),
    ),
  );

  Future<void> seedChapter(
    String series,
    int n, {
    required int bytes,
    String readStatus = 'unread',
    bool offline = true,
    String captureStatus = 'complete',
  }) => db.upsertChapter(
    Chapter(
      id: '$series-c$n',
      libraryItemId: series,
      title: 'Chapter $n',
      sourceUrl: 'https://x.example/manga/$series/$n',
      urlKey: 'https://x.example/manga/$series/$n',
      captureStatus: captureStatus,
      contentPath: offline ? 'library/$series/chapters/$series-c$n' : null,
      capturedAt: DateTime(2026, 7, 20),
      detectedImageCount: 3,
      storedImageCount: 3,
      sequence: n,
      byteSize: offline ? bytes : 0,
      chapterNumber: n.toDouble(),
      chapterLabel: 'Chapter $n',
      readStatus: readStatus,
      progressFraction: readStatus == 'completed' ? 1 : 0,
      progressImageIndex: 0,
      progressOffsetInImage: 0,
    ),
  );

  /// Read the summary once it has data.
  Future<StorageSummary> summary() async {
    for (var i = 0; i < 60; i++) {
      final value = container.read(storageSummaryProvider);
      if (value.hasValue) return value.value!;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('storage summary never resolved');
  }

  test('totals come from real stored sizes, largest series first', () async {
    container.listen(storageSummaryProvider, (_, _) {});
    await seedSeries('s1', 'Small');
    await seedSeries('s2', 'Big');
    await seedChapter('s1', 1, bytes: 1000);
    await seedChapter('s2', 1, bytes: 5000);
    await seedChapter('s2', 2, bytes: 4000);

    final s = await summary();
    expect(s.totalBytes, 10000);
    expect(s.offlineChapters, 3);
    expect(s.offlineSeries, 2);
    expect(s.series.map((r) => r.group.displayName), [
      'Big',
      'Small',
    ], reason: 'largest first by default');
    expect(s.series.first.bytes, 9000);
    expect(s.series.first.offlineChapters, 2);
  });

  test('chapters with no local files are not counted', () async {
    container.listen(storageSummaryProvider, (_, _) {});
    await seedSeries('s1', 'Foo');
    await seedChapter('s1', 1, bytes: 1000);
    await seedChapter('s1', 2, bytes: 0, offline: false);
    await seedChapter(
      's1',
      3,
      bytes: 0,
      offline: false,
      captureStatus: 'knownRemote',
    );

    final s = await summary();
    expect(s.offlineChapters, 1);
    expect(s.totalBytes, 1000);
  });

  test(
    'the finished-chapter estimate counts only completed offline ones',
    () async {
      container.listen(storageSummaryProvider, (_, _) {});
      await seedSeries('s1', 'Foo');
      await seedChapter('s1', 1, bytes: 1000, readStatus: 'completed');
      await seedChapter('s1', 2, bytes: 2000, readStatus: 'completed');
      await seedChapter('s1', 3, bytes: 4000, readStatus: 'inProgress');
      await seedChapter('s1', 4, bytes: 8000);

      final s = await summary();
      expect(s.finishedOfflineChapters, 2);
      expect(s.finishedOfflineBytes, 3000);
      expect(s.totalBytes, 15000, reason: 'unaffected by read state');
    },
  );

  test(
    'totals fall when files are removed, without losing the chapters',
    () async {
      container.listen(storageSummaryProvider, (_, _) {});
      await seedSeries('s1', 'Foo');
      await seedChapter('s1', 1, bytes: 1000, readStatus: 'completed');
      await seedChapter('s1', 2, bytes: 2000);
      expect((await summary()).totalBytes, 3000);

      final cleanup = CleanupService(db: db, fileStore: FileStore(root));
      await cleanup.removeOffline(['s1-c1']);

      // Reactive: the same stream the library uses drives this.
      for (var i = 0; i < 60; i++) {
        final s = container.read(storageSummaryProvider).value;
        if (s != null && s.totalBytes == 2000) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final after = await summary();
      expect(after.totalBytes, 2000);
      expect(after.offlineChapters, 1);
      expect(
        (await db.chaptersForItem('s1')),
        hasLength(2),
        reason: 'metadata is never deleted by a cleanup',
      );
      expect((await db.chapterById('s1-c1'))!.readStatus, 'completed');
    },
  );

  test('a series with nothing offline drops out of the list', () async {
    container.listen(storageSummaryProvider, (_, _) {});
    await seedSeries('s1', 'Foo');
    await seedChapter('s1', 1, bytes: 1000);
    expect((await summary()).offlineSeries, 1);

    await CleanupService(
      db: db,
      fileStore: FileStore(root),
    ).removeOffline(['s1-c1']);
    for (var i = 0; i < 60; i++) {
      final s = container.read(storageSummaryProvider).value;
      if (s != null && s.offlineSeries == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final after = await summary();
    expect(after.offlineSeries, 0);
    expect(after.totalBytes, 0);
    expect(
      await db.libraryItemById('s1'),
      isNotNull,
      reason: 'the series itself is untouched',
    );
  });

  test('archived series still count towards storage', () async {
    // They hold real bytes on the device; hiding them from the shelf does
    // not hide them from the disk.
    container.listen(storageSummaryProvider, (_, _) {});
    await seedSeries('s1', 'Foo');
    await seedChapter('s1', 1, bytes: 1000);
    await db.setSeriesLifecycle('s1', 'archived');

    for (var i = 0; i < 60; i++) {
      final s = container.read(storageSummaryProvider).value;
      if (s != null && s.offlineSeries == 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect((await summary()).totalBytes, 1000);
  });
}
