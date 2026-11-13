import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';

/// Continue watching from the launcher, seconds after playing: the add-on's
/// server had closed the pooled connection and the stream list failed at
/// once (Homatics, 2026-11-13). One connection error is asked again.
void main() {
  final streams = jsonEncode({
    'streams': [
      {'name': 'NoXStreams', 'title': '1080p', 'url': 'https://cdn.test/a.mkv'}
    ]
  });

  test('a connection error is retried once', () async {
    var calls = 0;
    final logs = <String>[];
    final api = ArchiveApiService(
      diagnostics: logs.add,
      client: MockClient((request) async {
        if (++calls == 1) {
          throw http.ClientException(
              'Connection closed before full header was received',
              request.url);
        }
        return http.Response(streams, 200);
      }),
    );
    final found =
        await api.fetchStreams('https://addon.test', ArchiveType.movie, 'tt1');
    expect(calls, 2);
    expect(found, hasLength(1));
    expect(
        logs,
        contains('ArchiveApi: retry after ClientException(Connection closed '
            'before full header was received)'));
  });

  test('a second connection error still fails', () async {
    var calls = 0;
    final api = ArchiveApiService(
      client: MockClient((request) async {
        calls++;
        throw http.ClientException('Connection refused', request.url);
      }),
    );
    await expectLater(
        api.fetchStreams('https://addon.test', ArchiveType.movie, 'tt1'),
        throwsA(isA<http.ClientException>()));
    expect(calls, 2);
  });

  test('an HTTP error is not retried', () async {
    var calls = 0;
    final api = ArchiveApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response('nope', 500);
      }),
    );
    await expectLater(
        api.fetchStreams('https://addon.test', ArchiveType.movie, 'tt1'),
        throwsA(isA<ArchiveApiException>()));
    expect(calls, 1);
  });

  test('the logged error keeps hosts and links out', () {
    expect(
        ArchiveApiService.errorText(http.ClientException(
            "Failed host lookup: 'streams.example.com'",
            Uri.parse('https://streams.example.com/x'))),
        "ClientException(Failed host lookup: '<host>')");
    expect(
        ArchiveApiService.errorText(http.ClientException(
            'Connection reset by peer, uri=https://a.test/secret/manifest.json')),
        'ClientException(Connection reset by peer, uri=<url>)');
    expect(ArchiveApiService.errorText(const FormatException('x')),
        'FormatException');
  });
}
