import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'browser/browser_controller.dart';
import 'capture/capture_job.dart';
import 'core/device_storage.dart';
import 'providers.dart';
import 'storage/database.dart';
import 'library/series_repository.dart';
import 'storage/file_store.dart';
import 'storage/manifest.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final fileStore = await FileStore.open();
  await _recoverOnStartup(db, fileStore);

  // Chapter assets are re-downloadable; a multi-GB library must not ride
  // along in every iCloud backup. Only the asset tree is excluded — the
  // database (reading state, rules, settings) stays backed up. Idempotent;
  // Android reports unsupported and that is fine.
  try {
    final excluded = await DeviceStorage().excludeFromBackup(
      fileStore.rootDir.path,
    );
    debugPrint(
      '[storage] backup exclusion: ${excluded ? 'set' : 'unsupported'}',
    );
  } catch (e) {
    debugPrint('[storage] backup exclusion failed: $e');
  }

  // Regroup captures made before series grouping existed. Reassigns rows only;
  // no file is moved and no capture state changes, so it is safe to re-run.
  try {
    final report = await SeriesRepository(
      db,
    ).backfillExistingCaptures(log: (m) => debugPrint('[library] $m'));
    if (report.didAnything) debugPrint('[library] backfill: $report');
  } catch (e) {
    debugPrint('[library] backfill failed: $e');
  }

  final browser = BrowserController();
  final captureJob = CaptureJobController(
    browser: browser,
    db: db,
    fileStore: fileStore,
  );

  final services = AppServices(
    db: db,
    fileStore: fileStore,
    browser: browser,
    captureJob: captureJob,
  );
  // Turn any queue rows a kill left behind into a resume OFFER — nothing
  // autonomous starts at launch (Q24).
  try {
    await services.taskQueue.restore();
  } catch (e) {
    debugPrint('[queue] restore failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const WebReaderApp(),
    ),
  );
}

/// Startup recovery, before the UI is interactive.
///
/// The invariant this protects: a chapter is never promoted to `complete` by
/// recovery. Anything left mid-flight is reset and re-capturable; anything
/// whose files vanished is demoted, keeping its row.
Future<void> _recoverOnStartup(AppDatabase db, FileStore fileStore) async {
  try {
    // A kill between "step the old chapter aside" and "move the new one in"
    // leaves a `.previous` directory; put it back before anything reads.
    final restored = await fileStore.restoreInterruptedReplacements();
    if (restored > 0) {
      debugPrint('[recovery] restored $restored interrupted replacement(s)');
    }

    final swept = await fileStore.sweepStaging();
    if (swept > 0) debugPrint('[recovery] swept $swept staging dir(s)');

    final reset = await db.resetInFlightChapters();
    if (reset > 0) debugPrint('[recovery] reset $reset in-flight chapter(s)');

    // Files on disk with no usable database row: finish the record from the
    // manifest, which describes itself.
    for (final relative in fileStore.listCommittedChapterPaths()) {
      final manifest = await fileStore.readManifest(relative);
      if (manifest == null) continue;
      final existing = await db.chapterById(manifest.chapterId);
      if (existing != null && existing.contentPath != null) continue;
      if (manifest.status != CaptureStatus.complete &&
          manifest.status != CaptureStatus.partial) {
        continue;
      }
      debugPrint('[recovery] reconciling ${manifest.chapterId} from manifest');
      final priorReading = await db.chapterById(manifest.chapterId);
      await db.upsertChapter(
        Chapter(
          id: manifest.chapterId,
          libraryItemId: manifest.libraryItemId,
          title: manifest.title,
          sourceUrl: manifest.sourceUrl,
          urlKey: manifest.sourceUrl,
          captureStatus: manifest.status.name,
          contentPath: relative,
          capturedAt: manifest.capturedAt,
          detectedImageCount: manifest.detectedImageCount,
          storedImageCount: manifest.storedImageCount,
          nextSourceUrl: manifest.nextUrl,
          sequence: manifest.sequence ?? 0,
          byteSize: await fileStore.chapterByteSize(relative),
          // Recovery restores the capture, never the reading position.
          readStatus: priorReading?.readStatus ?? 'unread',
          progressFraction: priorReading?.progressFraction ?? 0,
          progressImageIndex: priorReading?.progressImageIndex ?? 0,
          progressOffsetInImage: priorReading?.progressOffsetInImage ?? 0,
          firstOpenedAt: priorReading?.firstOpenedAt,
          lastReadAt: priorReading?.lastReadAt,
          completedAt: priorReading?.completedAt,
          progressUpdatedAt: priorReading?.progressUpdatedAt,
        ),
      );
    }
  } catch (e) {
    debugPrint('[recovery] failed: $e');
  }
}
