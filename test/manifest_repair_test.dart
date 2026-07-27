import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/reading/reading_position.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';
import 'package:web_reader/storage/manifest_repair.dart';

import '../tool/fixture/fixture_site.dart';

/// Dimension repair: the stored file's own header corrects a manifest that
/// recorded what the DOM claimed. No re-download, no file moves, progress
/// stays approximately valid because the panel count never changes.
void main() {
  late Directory root;
  late FileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('webread_repair');
    store = FileStore(root);
    Directory(
      p.join(root.path, FileStore.libraryFolderName),
    ).createSync(recursive: true);
    Directory(
      p.join(root.path, FileStore.tmpFolderName),
    ).createSync(recursive: true);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ChapterManifest manifestWith(List<AssetEntry> assets) => ChapterManifest(
    schemaVersion: 1,
    chapterId: 'c1',
    libraryItemId: 'series-1',
    sourceUrl: 'https://x.example/manga/foo/1',
    title: 'Foo 1',
    capturedAt: DateTime(2026, 7, 20),
    status: CaptureStatus.complete,
    detectedImageCount: assets.length,
    storedImageCount: assets.length,
    assets: assets,
  );

  /// Commit a chapter whose real files are 800x1200 PNGs but whose manifest
  /// claims whatever the entries say.
  Future<String> seed(List<AssetEntry> entries) async {
    final staging = await store.beginChapter(
      libraryItemId: 'series-1',
      chapterId: 'c1',
    );
    for (final e in entries) {
      if (e.relativePath == null) continue;
      final name = e.relativePath!.split('/').last;
      await staging
          .assetFile(name)
          .writeAsBytes(panelPng(chapter: 1, index: e.index));
    }
    return store.commit(staging, manifestWith(entries));
  }

  AssetEntry entry(int i, {int? width, int? height, bool verified = false}) =>
      AssetEntry(
        index: i,
        sourceUrl: 'https://cdn.example/$i.png',
        status: AssetStatus.stored,
        relativePath: 'assets/00$i.png',
        width: width,
        height: height,
        dimensionsVerified: verified,
      );

  test('corrects DOM-reported dimensions from the stored file', () async {
    // The DOM claimed 390x585 (a rendered box) — the file is 800x1200.
    final relative = await seed([
      entry(1, width: 390, height: 585),
      entry(2, width: 800, height: 1200),
    ]);
    final manifest = (await store.readManifest(relative))!;

    final result = await repairManifestDimensions(store, relative, manifest);

    expect(result.correctedCount, 1, reason: 'only the wrong entry counts');
    expect(result.manifest.assets[0].width, 800);
    expect(result.manifest.assets[0].height, 1200);
    expect(result.manifest.assets[0].dimensionsVerified, isTrue);
    expect(
      result.manifest.assets[0].domWidth,
      390,
      reason: 'the old claim stays visible as the DOM diagnostic',
    );
    expect(result.manifest.assets[0].domHeight, 585);
    expect(result.manifest.assets[1].dimensionsVerified, isTrue);

    // Persisted: a fresh read sees the corrected manifest.
    final reread = (await store.readManifest(relative))!;
    expect(reread.assets[0].width, 800);
    expect(reread.assets[0].dimensionsVerified, isTrue);
  });

  test('verified entries are never re-read', () async {
    final relative = await seed([entry(1, width: 390, height: 585)]);
    var manifest = (await store.readManifest(relative))!;

    final first = await repairManifestDimensions(store, relative, manifest);
    expect(first.checkedCount, 1);

    manifest = (await store.readManifest(relative))!;
    final second = await repairManifestDimensions(store, relative, manifest);
    expect(second.checkedCount, 0, reason: 'repair runs at most once per file');
    expect(second.didRepair, isFalse);
  });

  test('an unparseable file keeps its recorded dimensions', () async {
    final relative = await seed([entry(1, width: 390, height: 585)]);
    // Overwrite with bytes that are not an image.
    await store
        .assetFile(relative, 'assets/001.png')
        .writeAsString('<html>not an image</html>');
    final manifest = (await store.readManifest(relative))!;

    final result = await repairManifestDimensions(store, relative, manifest);

    expect(result.correctedCount, 0);
    expect(
      result.manifest.assets[0].width,
      390,
      reason: 'keep the guess rather than invent a size',
    );
    expect(result.manifest.assets[0].dimensionsVerified, isFalse);
  });

  test('a missing file is left alone', () async {
    final relative = await seed([entry(1, width: 390, height: 585)]);
    store.assetFile(relative, 'assets/001.png').deleteSync();
    final manifest = (await store.readManifest(relative))!;

    final result = await repairManifestDimensions(store, relative, manifest);
    expect(result.correctedCount, 0);
    expect(result.manifest.assets[0].width, 390);
  });

  test('reading progress stays approximately valid across a repair', () async {
    // Wrong manifest: claims square panels. Real files: 800x1200.
    final relative = await seed([
      for (var i = 1; i <= 3; i++) entry(i, width: 800, height: 800),
    ]);
    final manifest = (await store.readManifest(relative))!;

    // Position saved against the WRONG geometry: panel 1, 50% down it.
    const saved = ReadingPosition(
      fraction: 0.5,
      imageIndex: 1,
      offsetInImage: 0.5,
    );

    final result = await repairManifestDimensions(store, relative, manifest);
    final layout = ChapterLayout(
      viewportWidth: 400,
      panels: [
        for (final a in result.manifest.storedAssets)
          (width: a.width, height: a.height),
      ],
    );

    // The anchor still lands on panel 1, half-way down — panel count is
    // unchanged, so the anchor survives; only the pixel offset rescales.
    final offset = layout.offsetForPosition(saved);
    final restored = layout.positionForOffset(offset);
    expect(restored.imageIndex, 1);
    expect(restored.offsetInImage, closeTo(0.5, 0.01));
  });
}
