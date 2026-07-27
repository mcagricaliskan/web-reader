// Capture ONE real chapter, end to end, and read it back off disk.
//
//   flutter test integration_test/live_capture_test.dart -d <simulator-id>
//
// Deliberately limited to a single chapter: enough to prove asset acquisition
// works against a real, Referer-gated CDN serving AVIF, without pulling a
// meaningful portion of anyone's series.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/asset_downloader.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/core/image_dimensions.dart';
import 'package:web_reader/library/series_repository.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

// Chapter 885: the one reported as rendering with distorted panel
// proportions. Its real panels range from 718x513 to 800x16000 in one
// chapter, which is exactly what makes wrong dimensions visible.
const liveChapter =
    'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku';

/// Unique per process: a run that is killed mid-way never uninstalls the
/// app, so a fixed name would leak rows into the next invocation.
final String kRunStamp = DateTime.now().millisecondsSinceEpoch.toRadixString(
  36,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FileStore fileStore;
  late BrowserController browser;
  late CaptureJobController job;

  Future<void> settle(WidgetTester tester, Duration d) async {
    await Future<void>.delayed(d);
    await tester.pump();
  }

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await settle(tester, const Duration(milliseconds: 250));
    }
  }

  tearDown(() async {
    job.stop();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (job.isRunning && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await db.close();
  });

  testWidgets(
    'capture one live chapter and read it from disk',
    (tester) async {
      db = AppDatabase(name: 'it_live_capture_$kRunStamp');
      fileStore = await FileStore.open(
        folderName: 'webread_it_live_capture_$kRunStamp',
      );
      browser = BrowserController();
      job = CaptureJobController(
        browser: browser,
        db: db,
        fileStore: fileStore,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              AppServices(
                db: db,
                fileStore: fileStore,
                browser: browser,
                captureJob: job,
              ),
            ),
          ],
          child: const WebReaderApp(),
        ),
      );
      await settle(tester, const Duration(seconds: 3));

      // The shell boots on the Library tab; captures need the rendered
      // Browser surface (hidden-WebView guard would otherwise hold).
      await tester.tap(
        find.byKey(const ValueKey('navTab-Browser')),
        warnIfMissed: false,
      );
      await settle(tester, const Duration(milliseconds: 800));

      await browser.loadAndWait(
        liveChapter,
        timeout: const Duration(seconds: 60),
      );
      await settle(tester, const Duration(seconds: 3));

      unawaited(job.start(chapterLimit: 1));
      await waitFor(
        tester,
        () => job.progress.state.isTerminal && !job.isRunning,
      );

      for (final line in job.log.reversed) {
        debugPrint('[job] $line');
      }

      final chapters = await db.watchAllChapters().first;
      if (chapters.isEmpty) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: UNREACHABLE/BLOCKED url=$liveChapter — '
          'no chapter recorded; NOT a verification',
        );
        markTestSkipped('uzaymanga unreachable — NOT a verification');
        return;
      }

      // Series grouping: the chapter must land under a real series group, named
      // after the series and not after the chapter.
      final items = await db.watchLibraryItems().first;
      expect(items, hasLength(1));
      final group = items.single;
      debugPrint(
        '[live] series group: "${displayNameFor(group)}" '
        'host=${group.host} key=${group.seriesKey} '
        'basis=${group.identityBasis} confidence=${group.identityConfidence}',
      );
      expect(group.seriesKey, isNotNull);
      expect(
        displayNameFor(group),
        isNot(contains('Bölüm')),
        reason: 'the group is the series, not one of its chapters',
      );

      final chapter = chapters.first;
      debugPrint(
        '[live] chapter label="${chapter.chapterLabel}" '
        'number=${chapter.chapterNumber}',
      );
      expect(chapter.libraryItemId, group.id);
      debugPrint(
        '[live] "${chapter.title}" status=${chapter.captureStatus} '
        'stored=${chapter.storedImageCount}/${chapter.detectedImageCount} '
        'bytes=${chapter.byteSize}',
      );

      expect(
        chapter.storedImageCount,
        greaterThan(0),
        reason: 'the whole point: real bytes must reach the disk',
      );

      final manifest = await fileStore.readManifest(chapter.contentPath!);
      expect(manifest, isNotNull);

      // --- dimension truth table: DOM vs manifest vs decoded file ---------
      // The manifest's width/height must equal the stored file's own header,
      // and the reader lays panels out from the manifest — so this is the
      // whole distortion pipeline checked in one place.
      final mimes = <String, int>{};
      var mismatchedDom = 0;
      for (final asset in manifest!.storedAssets) {
        final file = fileStore.assetFile(
          chapter.contentPath!,
          asset.relativePath!,
        );
        expect(file.existsSync(), isTrue, reason: asset.relativePath);
        final bytes = await file.readAsBytes();
        final sniffed = detectImageMime(bytes);
        expect(
          sniffed,
          isNotNull,
          reason: 'stored bytes must be a format we can identify',
        );
        mimes.update(sniffed!, (v) => v + 1, ifAbsent: () => 1);

        final decoded = readImageDimensions(bytes);
        expect(
          decoded,
          isNotNull,
          reason: 'panel ${asset.index}: dimensions must be readable',
        );
        expect(
          asset.dimensionsVerified,
          isTrue,
          reason: 'panel ${asset.index}: capture must verify from bytes',
        );
        expect(
          (asset.width, asset.height),
          (decoded!.width, decoded.height),
          reason:
              'panel ${asset.index}: manifest must carry the file\'s own '
              'dimensions — this is what the reader lays out with',
        );
        final domDiffers =
            asset.domWidth != decoded.width ||
            asset.domHeight != decoded.height;
        if (domDiffers) mismatchedDom++;
        debugPrint(
          '[dims] panel ${asset.index}: '
          'dom=${asset.domWidth}x${asset.domHeight} '
          'manifest=${asset.width}x${asset.height} '
          'file=${decoded.width}x${decoded.height}'
          '${domDiffers ? '  << DOM disagreed with the file' : ''}',
        );
      }
      debugPrint('[live] stored formats: $mimes');
      debugPrint(
        '[dims] ${manifest.storedAssets.length} panels checked · '
        '$mismatchedDom DOM report(s) disagreed with the stored file',
      );

      for (final asset in manifest.assets.where(
        (a) => a.status == AssetStatus.failed,
      )) {
        debugPrint('[live] failed asset ${asset.index}: ${asset.error}');
      }

      // Readable offline: the reader decodes straight from these files.
      final firstFile = File(
        fileStore
            .assetFile(
              chapter.contentPath!,
              manifest.storedAssets.first.relativePath!,
            )
            .path,
      );
      expect(await firstFile.length(), greaterThan(1000));
      debugPrint(
        '[live] first panel on disk: ${firstFile.path.split('/').last} '
        '${await firstFile.length()} bytes',
      );
      // Stored extension must match the sniffed MIME (audit finding: URL
      // extensions lie on real CDNs).
      for (final asset in manifest.storedAssets) {
        final ext = asset.relativePath!.split('.').last;
        final expected = switch (asset.mimeType) {
          'image/jpeg' => 'jpg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          'image/avif' => 'avif',
          'image/gif' => 'gif',
          _ => ext, // exotic: fileNameFor fell back, nothing to assert
        };
        expect(
          ext,
          expected,
          reason: '${asset.relativePath} vs ${asset.mimeType}',
        );
      }
      debugPrint(
        '[LIVE][uzaymanga] RESULT: PASSED url=$liveChapter '
        '(single-chapter capture, original bytes on disk, dims verified, '
        'extensions match MIME)',
      );
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
