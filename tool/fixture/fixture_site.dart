// The controlled webtoon fixture: page markup and image bytes.
//
// Shared by the standalone CLI server (`serve.dart`, for manual browsing) and
// by the integration test, which serves it *in-process on the simulator* so
// the test can shut the source down mid-run and prove offline reading.
import 'dart:io';
import 'dart:typed_data';

const int kChapterCount = 3;
const int kContentImagesPerChapter = 6;

/// Chapter with a deliberately broken (503) panel, so partial capture is
/// exercised on every run.
const int kBrokenChapter = 2;
const int kBrokenPanel = 5;

/// Panel that responds slowly, so "loaded" never means "finished".
const int kSlowPanel = 4;

/// Handle one fixture request. Returns false if the path is unknown.
Future<bool> handleFixtureRequest(
  HttpRequest req, {
  bool applyDelays = true,

  /// How many chapters the "site" currently has. Tests raise this mid-run to
  /// simulate the source publishing new chapters after a capture.
  int chapterCount = kChapterCount,
}) async {
  final path = req.uri.path;
  final res = req.response;
  res.headers.set('Access-Control-Allow-Origin', '*');

  if (path == '/' || path == '/index.html') {
    await _html(res, indexPage(chapterCount));
    return true;
  }

  // Localised and awkward variants, for exercising detection without relying
  // on a language dictionary:
  //   /tr/<n>       Turkish label, no rel=next
  //   /de/<n>       German label, no rel=next
  //   /amb/<n>      two equally plausible controls -> must ask the user
  //   /nolabel/<n>  icon-only control, no rel/text/aria -> must ask the user
  final localeMatch = RegExp(r'^/(tr|de|amb|nolabel)/(\d+)$').firstMatch(path);
  if (localeMatch != null) {
    final variant = localeMatch.group(1)!;
    final n = int.parse(localeMatch.group(2)!);
    if (n < 1 || n > chapterCount) {
      res.statusCode = 404;
      await _html(res, '<h1>No such chapter</h1>');
      return true;
    }
    await _html(
      res,
      localisedChapterPage(variant, n, chapterCount: chapterCount),
    );
    return true;
  }

  final chapterMatch = RegExp(r'^/chapter/(\d+)$').firstMatch(path);
  if (chapterMatch != null) {
    final n = int.parse(chapterMatch.group(1)!);
    if (n < 1 || n > chapterCount) {
      res.statusCode = 404;
      await _html(res, '<h1>No such chapter</h1>');
      return true;
    }
    await _html(res, chapterPage(n, chapterCount: chapterCount));
    return true;
  }

  final imgMatch = RegExp(r'^/img/(\d+)/(\d+)\.png$').firstMatch(path);
  if (imgMatch != null) {
    final chapter = int.parse(imgMatch.group(1)!);
    final index = int.parse(imgMatch.group(2)!);
    if (applyDelays && index == kSlowPanel) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (chapter == kBrokenChapter && index == kBrokenPanel) {
      res.statusCode = 503;
      await res.close();
      return true;
    }
    await _png(res, panelPng(chapter: chapter, index: index));
    return true;
  }

  const chrome = <String, List<int>>{
    '/chrome/icon.png': [32, 32, 0x33, 0x33, 0x33],
    '/chrome/logo.png': [240, 48, 0x88, 0x44, 0xcc],
    '/chrome/pixel.png': [1, 1, 0xff, 0xff, 0xff],
    '/chrome/avatar.png': [64, 64, 0x22, 0x99, 0x66],
    '/chrome/banner.png': [970, 90, 0xdd, 0x22, 0x22],
  };
  final spec = chrome[path];
  if (spec != null) {
    await _png(res, solidPng(spec[0], spec[1], spec[2], spec[3], spec[4]));
    return true;
  }

  res.statusCode = 404;
  await res.close();
  return false;
}

Future<void> _html(HttpResponse res, String body) {
  res.headers.contentType = ContentType.html;
  res.headers.set('Cache-Control', 'no-store');
  res.write(body);
  return res.close();
}

Future<void> _png(HttpResponse res, Uint8List bytes) {
  res.headers.contentType = ContentType('image', 'png');
  res.headers.set('Cache-Control', 'no-store');
  res.add(bytes);
  return res.close();
}

String indexPage([int chapterCount = kChapterCount]) =>
    '''
<!doctype html><html><head><meta name="viewport"
  content="width=device-width, initial-scale=1"><title>Fixture Webtoon</title></head>
<body style="font-family:-apple-system,sans-serif;padding:24px">
<h1>Fixture Webtoon</h1>
<ul>${List.generate(chapterCount, (i) => '<li><a href="/chapter/${i + 1}">Chapter ${i + 1}</a></li>').join()}</ul>
</body></html>''';

/// Panels 1-2 load eagerly; 3-6 are lazy-loaded on intersection with a delay,
/// so a capture that trusted `onLoadStop` would miss two thirds of the chapter.
String chapterPage(int n, {int chapterCount = kChapterCount}) {
  final buf = StringBuffer();
  for (var i = 1; i <= kContentImagesPerChapter; i++) {
    final url = '/img/$n/$i.png';
    if (i <= 2) {
      buf.writeln(
        '<img class="panel" src="$url" width="800" height="1200" '
        'alt="panel $i">',
      );
    } else {
      buf.writeln(
        '<img class="panel lazy" data-src="$url" width="800" '
        'height="1200" alt="panel $i">',
      );
    }
  }
  // Duplicate of panel 1: the filter must de-duplicate by URL.
  buf.writeln(
    '<img class="panel" src="/img/$n/1.png" width="800" '
    'height="1200" alt="duplicate of panel 1">',
  );
  // Hidden large image: must be rejected despite passing the size test.
  buf.writeln(
    '<img src="/img/$n/2.png" width="800" height="1200" '
    'style="display:none" alt="hidden">',
  );

  final nextLink = n < chapterCount
      ? '<a id="next" rel="next" href="/chapter/${n + 1}">Next Chapter →</a>'
      : '<span id="next-disabled">No next chapter</span>';
  final prevLink = n > 1
      ? '<a rel="prev" href="/chapter/${n - 1}">← Previous</a>'
      : '';

  return '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fixture Webtoon — Chapter $n</title>
<link rel="canonical" href="/chapter/$n">
<style>
  body { margin:0; background:#111; color:#eee; font-family:-apple-system,sans-serif; }
  header, footer { padding:12px 16px; background:#1c1c1c; }
  nav a { color:#8cf; margin-right:16px; }
  img.panel { display:block; width:100%; height:auto; margin:0 auto; max-width:800px; }
  img.lazy { min-height:1200px; background:#222; }
</style></head>
<body>
<header>
  <img src="/chrome/logo.png" width="240" height="48" alt="logo">
  <img src="/chrome/icon.png" width="32" height="32" alt="icon">
  <img src="/chrome/avatar.png" width="64" height="64" alt="avatar">
  <h2>Fixture Webtoon — Chapter $n</h2>
</header>
<img src="/chrome/banner.png" width="970" height="90" alt="ad banner">
<div class="reader">
$buf
</div>
<img src="/chrome/pixel.png" width="1" height="1" alt="">
<footer><nav>$prevLink $nextLink</nav></footer>
<script>
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      const img = e.target;
      io.unobserve(img);
      setTimeout(() => { img.src = img.dataset.src; img.classList.remove('lazy'); }, 400);
    }
  }, { rootMargin: '200px' });
  document.querySelectorAll('img.lazy').forEach((i) => io.observe(i));
</script>
</body></html>''';
}

// ---------------------------------------------------------------------------
// Minimal PNG encoder — keeps the fixture dependency-free.
// ---------------------------------------------------------------------------

/// A content panel: distinct colour per chapter, plus `index` white bars so
/// panel order is verifiable by eye in the reader.
Uint8List panelPng({required int chapter, required int index}) {
  const w = 800, h = 1200;
  const palette = [
    [0x1e, 0x3a, 0x8a],
    [0x7c, 0x2d, 0x12],
    [0x14, 0x53, 0x2d],
  ];
  final base = palette[(chapter - 1) % palette.length];
  final rgb = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    final shade = (y * 40 ~/ h);
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 3;
      rgb[o] = (base[0] + shade).clamp(0, 255);
      rgb[o + 1] = (base[1] + shade).clamp(0, 255);
      rgb[o + 2] = (base[2] + shade).clamp(0, 255);
    }
  }
  for (var b = 0; b < index; b++) {
    final x0 = 40 + b * 60;
    for (var y = 60; y < 220; y++) {
      for (var x = x0; x < x0 + 40 && x < w; x++) {
        final o = (y * w + x) * 3;
        rgb[o] = 0xff;
        rgb[o + 1] = 0xff;
        rgb[o + 2] = 0xff;
      }
    }
  }
  return _encodePng(w, h, rgb);
}

Uint8List solidPng(int w, int h, int r, int g, int b) {
  final rgb = Uint8List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    rgb[i * 3] = r;
    rgb[i * 3 + 1] = g;
    rgb[i * 3 + 2] = b;
  }
  return _encodePng(w, h, rgb);
}

Uint8List _encodePng(int width, int height, Uint8List rgb) {
  final raw = Uint8List(height * (1 + width * 3));
  var o = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 0; // filter: none
    raw.setRange(o, o + width * 3, rgb, y * width * 3);
    o += width * 3;
  }
  final idat = Uint8List.fromList(ZLibEncoder().convert(raw));

  final ihdr = BytesBuilder()
    ..add(_u32(width))
    ..add(_u32(height))
    ..add([8, 2, 0, 0, 0]); // 8-bit truecolour RGB

  return Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    ..._chunk('IHDR', ihdr.toBytes()),
    ..._chunk('IDAT', idat),
    ..._chunk('IEND', Uint8List(0)),
  ]);
}

List<int> _u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];

List<int> _chunk(String type, Uint8List data) {
  final typeBytes = type.codeUnits;
  final crc = _crc32(Uint8List.fromList([...typeBytes, ...data]));
  return [..._u32(data.length), ...typeBytes, ...data, ..._u32(crc)];
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}

/// Chapter pages whose next-control is expressed differently, so detection is
/// exercised beyond `rel="next"` and beyond English.
///
/// Deliberately not a language-coverage exercise. `nolabel` and `amb` exist to
/// prove the app *asks the user* rather than guessing when the page gives it
/// nothing trustworthy — which is the point of the fallback model.
String localisedChapterPage(
  String variant,
  int n, {
  int chapterCount = kChapterCount,
}) {
  final buf = StringBuffer();
  for (var i = 1; i <= kContentImagesPerChapter; i++) {
    buf.writeln(
      '<img class="panel" src="/img/$n/$i.png" width="800" height="1200" '
      'alt="panel $i">',
    );
  }

  final next = n < chapterCount ? '/$variant/${n + 1}' : null;
  final String nav;
  switch (variant) {
    case 'tr':
      nav = next == null
          ? '<span>Son bolum</span>'
          : '<a class="nav-next" href="$next">Sonraki Bolum</a>';
    case 'de':
      nav = next == null
          ? '<span>Letztes Kapitel</span>'
          : '<a class="weiter" href="$next">Naechstes Kapitel</a>';
    case 'amb':
      // Two equally plausible controls pointing at different pages: the app
      // must refuse to pick and ask instead.
      nav = next == null
          ? '<span>Ende</span>'
          : '<a href="$next">Next</a> '
                '<a href="/$variant/$chapterCount">Continue</a>';
    case 'nolabel':
    default:
      // Icon-only control: no rel, no text, no aria-label, no href pattern the
      // heuristics can trust on their own.
      nav = next == null
          ? '<span>[end]</span>'
          : '<a class="x1" href="$next">'
                '<img src="/chrome/icon.png" width="32" height="32"></a>';
  }

  return '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fixture $variant - chapter $n</title>
<style>
  body { margin:0; background:#111; color:#eee; }
  img.panel { display:block; width:100%; height:auto; max-width:800px; margin:0 auto; }
</style></head>
<body>
<div class="reading-content">
$buf
</div>
<footer><nav>$nav</nav></footer>
</body></html>''';
}
