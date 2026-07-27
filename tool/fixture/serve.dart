// Standalone fixture server, for driving the app by hand in the Simulator.
//
//   dart tool/fixture/serve.dart [port]
//   then browse to http://localhost:8099/chapter/1 inside Web Reader
//
// The automated integration test does NOT need this: it serves the same
// fixture in-process so it can shut the source down mid-test.
import 'dart:io';

import 'fixture_site.dart';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8099;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  stdout.writeln('Fixture server on http://localhost:$port/chapter/1');
  stdout.writeln(
    'Chapters: 1..$kChapterCount · '
    '$kContentImagesPerChapter panels each · '
    'chapter $kBrokenChapter panel $kBrokenPanel returns 503 on purpose',
  );

  await for (final req in server) {
    try {
      await handleFixtureRequest(req);
    } catch (e) {
      stderr.writeln('fixture error: $e');
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }
}
