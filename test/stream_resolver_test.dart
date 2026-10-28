import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/stream_resolver.dart';

/// Media Hub links are resolved once before playing (debrid redirect
/// chains made a 4K episode take 6.5 s to start on a Shield, 2026-10-21).
void main() {
  late HttpServer server;
  late String base;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) {
      final res = req.response;
      switch (req.uri.path) {
        case '/resolve':
          res.statusCode = 302;
          res.headers.set('location', '/api/requestdl');
        case '/api/requestdl':
          res.statusCode = 307;
          res.headers.set('location', '$base/cdn/file.mkv');
        case '/cdn/file.mkv':
          expect(req.headers.value('range'), 'bytes=0-0');
          res.statusCode = 206;
          res.headers.set('content-range', 'bytes 0-0/1000000');
          res.add([0x1A]);
        case '/loop':
          res.statusCode = 302;
          res.headers.set('location', '/loop');
        default:
          res.statusCode = 404;
      }
      res.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  test('follows the whole chain to the file', () async {
    expect(await resolveRedirects('$base/resolve'), '$base/cdn/file.mkv');
  });

  test('a direct link stays as it is', () async {
    expect(await resolveRedirects('$base/cdn/file.mkv'), '$base/cdn/file.mkv');
  });

  test('an error or an endless loop gives the original back', () async {
    expect(await resolveRedirects('$base/missing'), '$base/missing');
    expect(await resolveRedirects('$base/loop'), '$base/loop');
  });

  test('non-web links are left alone', () async {
    expect(await resolveRedirects('/storage/rec.ts'), '/storage/rec.ts');
  });

  test('reports the size the final server serves', () async {
    final link = await resolveLink('$base/resolve');
    expect(link.url, '$base/cdn/file.mkv');
    expect(link.totalBytes, 1000000);
    expect((await resolveLink('$base/missing')).totalBytes, isNull);
  });
}
