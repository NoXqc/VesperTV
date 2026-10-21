import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';

/// An add-on with IMDb catalogs and no streams ("Streaming Catalogs":
/// Netflix, Disney+… lists; user request, 2026-10-21) is added as a
/// list-only source instead of refused; one without IMDb ids still is.
void main() {
  Map<String, Object?> manifest(List<String> prefixes) => {
        'name': 'Streaming Catalogs',
        'resources': ['catalog'],
        'types': ['movie', 'series'],
        'idPrefixes': prefixes,
        'catalogs': [
          {'type': 'movie', 'id': 'nfx', 'name': 'Netflix'},
          {'type': 'series', 'id': 'nfx', 'name': 'Netflix'},
        ],
      };

  final client = MockClient((req) async {
    final body = switch (req.url.path) {
      '/imdb/manifest.json' => manifest(['tt']),
      '/own/manifest.json' => manifest(['own']),
      _ => null,
    };
    if (body == null) return http.Response('not found', 404);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });

  test('IMDb catalogs without streams = a list-only source', () async {
    final source = await ArchiveApiService(client: client)
        .fetchManifest('https://x.org/imdb/manifest.json');
    expect(source.listOnly, isTrue);
    expect(source.streamOnly, isFalse);
    expect(source.underOther, isFalse);
    expect(source.catalogs.map((c) => c.type).toList(),
        [ArchiveType.movie, ArchiveType.series]);
    expect(source.catalogBaseUrl, 'https://x.org/imdb');
    // Kept across a restart.
    final again = ArchiveSource.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>);
    expect(again.listOnly, isTrue);
  });

  test('catalogs on its own ids without streams are still refused', () {
    expect(
        ArchiveApiService(client: client)
            .fetchManifest('https://x.org/own/manifest.json'),
        throwsA(isA<ArchiveApiException>()));
  });
}
