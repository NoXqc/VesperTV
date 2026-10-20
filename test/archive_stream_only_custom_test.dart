import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';

/// An IMDb stream add-on that also lists one custom-type catalog ("tv"):
/// it stays stream-only (Cinemeta grids), like up to 1.0.23 — 1.0.24 read
/// it as "own catalogs" and only its "tv" row showed, under Other (user
/// report, 2026-10-20).
void main() {
  final client = MockClient((req) async {
    if (req.url.path != '/imdb/manifest.json') {
      return http.Response('not found', 404);
    }
    return http.Response.bytes(
        utf8.encode(jsonEncode({
          'name': 'IMDb streams',
          'resources': ['catalog', 'stream'],
          'types': ['movie', 'series', 'tv'],
          'idPrefixes': ['tt'],
          'catalogs': [
            {'type': 'tv', 'id': 'channels', 'name': 'Channels'},
          ],
        })),
        200);
  });

  test('a custom catalog alone keeps an IMDb add-on stream-only', () async {
    final source = await ArchiveApiService(client: client)
        .fetchManifest('https://x.org/imdb/manifest.json');
    expect(source.streamOnly, isTrue);
    expect(source.catalogs.where((c) => c.wireType != null), isEmpty);
    expect(source.catalogs.map((c) => c.type).toSet(),
        {ArchiveType.movie, ArchiveType.series});
  });
}
