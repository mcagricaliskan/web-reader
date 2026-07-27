import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/storage/manifest.dart';

void main() {
  ChapterManifest sample() => ChapterManifest(
    schemaVersion: ChapterManifest.currentSchemaVersion,
    chapterId: 'chapter-1',
    libraryItemId: 'item-1',
    sourceUrl: 'https://x.com/chapter/1',
    canonicalUrl: 'https://x.com/chapter/1',
    title: 'Chapter 1',
    capturedAt: DateTime.utc(2026, 7, 25, 12, 30),
    status: CaptureStatus.partial,
    statusReason: 'assetsFailed:1',
    detectedImageCount: 3,
    storedImageCount: 2,
    nextUrl: 'https://x.com/chapter/2',
    sequence: 1,
    assets: const [
      AssetEntry(
        index: 1,
        sourceUrl: 'https://x.com/img/1.png',
        status: AssetStatus.stored,
        relativePath: 'assets/001.png',
        mimeType: 'image/png',
        byteSize: 5661,
        width: 800,
        height: 1200,
      ),
      AssetEntry(
        index: 2,
        sourceUrl: 'https://x.com/img/2.png',
        status: AssetStatus.failed,
        error: 'HTTP 503',
      ),
      AssetEntry(
        index: 3,
        sourceUrl: 'https://x.com/img/3.png',
        status: AssetStatus.stored,
        relativePath: 'assets/003.png',
        mimeType: 'image/png',
        byteSize: 4200,
      ),
    ],
  );

  test('round-trips through JSON without losing anything', () {
    final original = sample();
    final restored = ChapterManifest.decode(original.encode());

    expect(restored.schemaVersion, original.schemaVersion);
    expect(restored.chapterId, original.chapterId);
    expect(restored.libraryItemId, original.libraryItemId);
    expect(restored.sourceUrl, original.sourceUrl);
    expect(restored.canonicalUrl, original.canonicalUrl);
    expect(restored.title, original.title);
    expect(restored.capturedAt.toUtc(), original.capturedAt.toUtc());
    expect(restored.status, CaptureStatus.partial);
    expect(restored.statusReason, 'assetsFailed:1');
    expect(restored.detectedImageCount, 3);
    expect(restored.storedImageCount, 2);
    expect(restored.nextUrl, original.nextUrl);
    expect(restored.sequence, 1);
    expect(restored.assets, hasLength(3));
  });

  test('preserves asset order and per-asset failure detail', () {
    final restored = ChapterManifest.decode(sample().encode());

    expect(restored.assets.map((a) => a.index), [1, 2, 3]);
    expect(restored.assets[1].status, AssetStatus.failed);
    expect(restored.assets[1].error, 'HTTP 503');
    expect(restored.assets[1].relativePath, isNull);
  });

  test('storedAssets exposes only what is actually on disk, in order', () {
    final restored = ChapterManifest.decode(sample().encode());

    expect(restored.storedAssets.map((a) => a.relativePath), [
      'assets/001.png',
      'assets/003.png',
    ]);
  });

  test('asset paths are relative — never absolute container paths', () {
    final restored = ChapterManifest.decode(sample().encode());

    for (final asset in restored.storedAssets) {
      expect(asset.relativePath, isNot(startsWith('/')));
      expect(asset.relativePath, startsWith('assets/'));
    }
  });

  test('an unknown status decodes to failed rather than throwing', () {
    expect(captureStatusFromName('nonsense'), CaptureStatus.failed);
    expect(assetStatusFromName(null), AssetStatus.failed);
  });

  test('copyWith promotes status without disturbing identity', () {
    final updated = sample().copyWith(
      status: CaptureStatus.complete,
      storedImageCount: 3,
    );

    expect(updated.status, CaptureStatus.complete);
    expect(updated.storedImageCount, 3);
    expect(updated.chapterId, 'chapter-1');
    expect(updated.sequence, 1);
  });
}
