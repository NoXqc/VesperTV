import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/playback_service.dart';

/// A link the player couldn't read (ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED)
/// is sniffed: an HLS playlist gets retried as HLS, a source's error reply
/// is shown in plain words (Media Hub TV show, user photo 2026-10-21).
void main() {
  final client = MockClient((req) async {
    expect(req.headers['Range'], 'bytes=0-1023');
    return switch (req.url.path) {
      '/hls' => http.Response('#EXTM3U\n#EXT-X-VERSION:3\n', 200),
      '/json' => http.Response(
          jsonEncode({
            'success': false,
            'error': 'ACTIVE_LIMIT',
            'detail': 'You have too many active downloads.',
          }),
          403,
          headers: {'content-type': 'application/json'}),
      '/html' => http.Response(
          '<!doctype html><html><head><title>Account expired</title>', 200,
          headers: {'content-type': 'text/html'}),
      '/text' => http.Response('Max connections reached for this line', 200),
      '/strm' => http.Response('https://cdn.example/file.mkv?token=abc\n', 200),
      _ => http.Response.bytes(
          [0x1A, 0x45, 0xDF, 0xA3, 0xA3, 0x42, 0x86, 0x81, 0x01, 0x00, 0xFF],
          206),
    };
  });

  Future<StreamSniff?> sniff(String path) =>
      sniffStream('https://x.org$path', client: client);

  test('an HLS playlist', () async {
    expect((await sniff('/hls'))!.kind, 'hls');
  });

  test('a JSON error reply names the error', () async {
    final s = (await sniff('/json'))!;
    expect(s.kind, 'json');
    expect(s.status, 403);
    expect(s.text, 'ACTIVE_LIMIT');
    expect(s.tag, '[SOURCE_REPLY:json HTTP 403] ACTIVE_LIMIT');
  });

  test('a web page gives its title', () async {
    final s = (await sniff('/html'))!;
    expect(s.kind, 'html');
    expect(s.text, 'Account expired');
  });

  test('plain text is quoted', () async {
    final s = (await sniff('/text'))!;
    expect(s.kind, 'text');
    expect(s.text, 'Max connections reached for this line');
  });

  test('a .strm-style reply is a link, never shown', () async {
    final s = (await sniff('/strm'))!;
    expect(s.kind, 'link');
    expect(s.text, 'https://cdn.example/file.mkv?token=abc');
    expect(s.tag, '[SOURCE_REPLY:link]');
  });

  test('real media bytes are binary', () async {
    expect((await sniff('/file.mkv'))!.kind, 'binary');
  });
}
