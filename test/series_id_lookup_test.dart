import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_discovery_service.dart';

void main() {
  // Skip intro on a provider show without ids: the series page asks for the
  // single exact title/year match.
  test('decorated provider show name finds its one TMDB id', () async {
    final queries = <String>[];
    final api = ArchiveDiscoveryService(client: MockClient((r) async {
      queries.add(r.url.queryParameters['query'] ?? '');
      return http.Response(
          jsonEncode({
            'results': [
              {'id': 42, 'name': 'Carrie', 'first_air_date': '2024-03-01'},
              {'id': 7, 'name': 'Carrie', 'first_air_date': '1990-01-01'},
            ]
          }),
          200);
    }));
    const meta = ArchiveMeta(
        id: 'iptv:5', type: ArchiveType.series, name: '4KDV: Carrie (2024)');
    expect(await api.tmdbIdFor(meta, 'k', 'en'), '42');
    expect(queries.single, 'Carrie');
    expect(await api.tmdbIdFor(meta, '', 'en'), isNull);
  });

  test('two exact matches without a year = no id', () async {
    final api = ArchiveDiscoveryService(
        client: MockClient((r) async => http.Response(
            jsonEncode({
              'results': [
                {'id': 1, 'name': 'Carrie', 'first_air_date': '2024-03-01'},
                {'id': 2, 'name': 'Carrie', 'first_air_date': '1990-01-01'},
              ]
            }),
            200)));
    expect(
        await api.tmdbIdFor(
            const ArchiveMeta(
                id: 'iptv:5', type: ArchiveType.series, name: 'Carrie'),
            'k',
            'en'),
        isNull);
  });
}
