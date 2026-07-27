import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/page_data.dart';
import 'package:web_reader/capture/image_candidates.dart';

/// A page image built from the same JSON shape the bridge produces.
PageImage img({
  required int index,
  String? src,
  String? currentSrc,
  String? dataSrc,
  int naturalWidth = 800,
  int naturalHeight = 1200,
  int renderedWidth = 390,
  int renderedHeight = 585,
  int attrWidth = 0,
  int attrHeight = 0,
  bool hidden = false,
  bool chrome = false,
  bool complete = true,
  int top = 0,
}) => PageImage(
  domIndex: index,
  src: src,
  currentSrc: currentSrc,
  dataSrc: dataSrc,
  complete: complete,
  naturalWidth: naturalWidth,
  naturalHeight: naturalHeight,
  renderedWidth: renderedWidth,
  renderedHeight: renderedHeight,
  attrWidth: attrWidth,
  attrHeight: attrHeight,
  documentTop: top,
  hidden: hidden,
  inPageChrome: chrome,
);

void main() {
  group('image candidate filtering', () {
    test('keeps large in-flow panels in DOM order', () {
      final selection = selectImageCandidates([
        img(index: 0, src: 'https://x/p1.png'),
        img(index: 1, src: 'https://x/p2.png'),
        img(index: 2, src: 'https://x/p3.png'),
        img(index: 3, src: 'https://x/p4.png'),
      ]);

      expect(selection.accepted.map((c) => c.url), [
        'https://x/p1.png',
        'https://x/p2.png',
        'https://x/p3.png',
        'https://x/p4.png',
      ]);
      expect(selection.rejected, isEmpty);
    });

    test('rejects icons, avatars and tracking pixels by size', () {
      final selection = selectImageCandidates([
        img(
          index: 0,
          src: 'https://x/icon.png',
          naturalWidth: 32,
          naturalHeight: 32,
        ),
        img(
          index: 1,
          src: 'https://x/avatar.png',
          naturalWidth: 64,
          naturalHeight: 64,
        ),
        img(
          index: 2,
          src: 'https://x/pixel.png',
          naturalWidth: 1,
          naturalHeight: 1,
        ),
        img(index: 3, src: 'https://x/p1.png'),
        img(index: 4, src: 'https://x/p2.png'),
        img(index: 5, src: 'https://x/p3.png'),
      ]);

      expect(selection.accepted.length, 3);
      expect(
        selection.rejected
            .where((r) => r.reason == RejectReason.tooSmall)
            .length,
        3,
      );
    });

    test('rejects wide banner-shaped images by aspect ratio', () {
      final selection = selectImageCandidates([
        // 970x400 passes the size floor but is 2.4:1 — still a panel shape.
        img(
          index: 0,
          src: 'https://x/wide.png',
          naturalWidth: 3000,
          naturalHeight: 400,
        ),
        img(index: 1, src: 'https://x/p1.png'),
        img(index: 2, src: 'https://x/p2.png'),
        img(index: 3, src: 'https://x/p3.png'),
      ]);

      expect(
        selection.accepted.map((c) => c.url),
        isNot(contains('https://x/wide.png')),
      );
      expect(
        selection.rejected.any((r) => r.reason == RejectReason.bannerAspect),
        isTrue,
      );
    });

    test('rejects hidden images and page chrome', () {
      final selection = selectImageCandidates([
        img(index: 0, src: 'https://x/logo.png', chrome: true),
        img(index: 1, src: 'https://x/ghost.png', hidden: true),
        img(index: 2, src: 'https://x/p1.png'),
        img(index: 3, src: 'https://x/p2.png'),
        img(index: 4, src: 'https://x/p3.png'),
      ]);

      expect(selection.accepted.length, 3);
      expect(
        selection.rejected.map((r) => r.reason),
        containsAll([RejectReason.pageChrome, RejectReason.hidden]),
      );
    });

    test('de-duplicates repeated URLs, keeping the first occurrence', () {
      final selection = selectImageCandidates([
        img(index: 0, src: 'https://x/p1.png'),
        img(index: 1, src: 'https://x/p2.png'),
        img(index: 2, src: 'https://x/p3.png'),
        img(index: 3, src: 'https://x/p1.png'), // duplicate further down
      ]);

      expect(selection.accepted.length, 3);
      expect(selection.accepted.first.domIndex, 0);
      expect(selection.rejected.single.reason, RejectReason.duplicateUrl);
    });

    test('prefers currentSrc, then src, then a lazy attribute', () {
      final selection = selectImageCandidates([
        img(
          index: 0,
          src: 'https://x/small.png',
          currentSrc: 'https://x/big.png',
        ),
        img(index: 1, src: 'https://x/p2.png'),
        img(index: 2, dataSrc: 'https://x/lazy.png', src: null),
      ]);

      expect(selection.accepted.map((c) => c.url), [
        'https://x/big.png',
        'https://x/p2.png',
        'https://x/lazy.png',
      ]);
    });

    test('drops images with no usable URL and ignores data: URIs', () {
      final selection = selectImageCandidates([
        img(index: 0, src: null),
        img(index: 1, src: 'data:image/gif;base64,R0lGOD'),
        img(index: 2, src: 'https://x/p1.png'),
        img(index: 3, src: 'https://x/p2.png'),
        img(index: 4, src: 'https://x/p3.png'),
      ]);

      expect(selection.accepted.length, 3);
      expect(
        selection.rejected.where((r) => r.reason == RejectReason.noUrl).length,
        2,
      );
    });

    test('keeps the dominant width cluster and drops an odd-sized stray', () {
      final selection = selectImageCandidates([
        img(index: 0, src: 'https://x/p1.png', naturalWidth: 800),
        img(index: 1, src: 'https://x/p2.png', naturalWidth: 800),
        img(index: 2, src: 'https://x/p3.png', naturalWidth: 805),
        img(index: 3, src: 'https://x/promo.png', naturalWidth: 1600),
      ]);

      expect(selection.accepted.length, 3);
      expect(
        selection.accepted.map((c) => c.url),
        isNot(contains('https://x/promo.png')),
      );
      expect(
        selection.rejected.single.reason,
        RejectReason.outsideContentColumn,
      );
    });

    test('keeps everything when no cluster is convincing', () {
      // Three different widths: no group reaches minClusterSize, so nothing
      // is dropped — a noisy chapter beats a silently truncated one.
      final selection = selectImageCandidates([
        img(index: 0, src: 'https://x/a.png', naturalWidth: 600),
        img(index: 1, src: 'https://x/b.png', naturalWidth: 900),
        img(index: 2, src: 'https://x/c.png', naturalWidth: 1300),
      ]);

      expect(selection.accepted.length, 3);
    });

    test('keeps a BROKEN content image so the chapter fails honestly', () {
      // Regression: a 503 panel has no intrinsic size and a collapsed box.
      // Filtering it out made a 6-page chapter save 5 pages and report
      // "complete" — losing a page while claiming success.
      final selection = selectImageCandidates([
        img(index: 0, src: 'https://x/p1.png'),
        img(index: 1, src: 'https://x/p2.png'),
        img(
          index: 2,
          src: 'https://x/broken.png',
          complete: true,
          naturalWidth: 0,
          naturalHeight: 0,
          renderedWidth: 0,
          renderedHeight: 0,
          attrWidth: 800,
          attrHeight: 1200,
        ),
        img(index: 3, src: 'https://x/p4.png'),
      ]);

      expect(selection.accepted.length, 4);
      expect(
        selection.accepted.map((c) => c.url),
        contains('https://x/broken.png'),
      );
      expect(selection.accepted.map((c) => c.domIndex), [0, 1, 2, 3]);
    });

    test('falls back to rendered size for unloaded lazy images', () {
      final selection = selectImageCandidates([
        img(
          index: 0,
          dataSrc: 'https://x/lazy1.png',
          src: null,
          complete: false,
          naturalWidth: 0,
          naturalHeight: 0,
          renderedWidth: 800,
          renderedHeight: 1200,
        ),
        img(index: 1, src: 'https://x/p2.png', naturalWidth: 800),
        img(index: 2, src: 'https://x/p3.png', naturalWidth: 800),
      ]);

      expect(selection.accepted.length, 3);
      expect(selection.accepted.first.url, 'https://x/lazy1.png');
    });
  });
}
