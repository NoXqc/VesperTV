import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/media_server_api.dart';
import 'package:nox_iptv/services/plex_api.dart';

http.Response response(Object body) => http.Response(jsonEncode(body), 200);
http.Response container(Map<String, Object?> body) =>
    response({'MediaContainer': body});

final server = PlexServer('machine-1', 'My library', 'server-test-token',
    [Uri.parse('http://library.test:32400')]);

void main() {
  test('Plex sign-in uses a stable client id and server-specific credentials',
      () async {
    final api = PlexApi(MockClient((request) async {
      expect(request.url.host, 'plex.tv');
      expect(request.headers['x-plex-client-identifier'], 'device-1');
      expect(request.headers['accept'], 'application/json');
      if (request.url.path == '/api/v2/pins') {
        expect(request.method, 'POST');
        expect(request.headers.containsKey('x-plex-token'), false);
        return response({'id': 42, 'code': 'ABCD', 'expiresIn': 100});
      }
      if (request.url.path == '/api/v2/pins/42') {
        return response({'authToken': 'account-test-token'});
      }
      expect(request.url.path, '/api/v2/resources');
      expect(request.headers['x-plex-token'], 'account-test-token');
      return response([
        {'provides': 'player', 'clientIdentifier': 'player'},
        {
          'provides': 'server',
          'clientIdentifier': 'machine-1',
          'name': 'My library',
          'accessToken': 'server-test-token',
          'connections': [
            {'uri': 'https://relay.test', 'relay': true},
            {'uri': 'https://remote.test', 'local': false},
            {'uri': 'http://library.test:32400', 'local': true},
            {'uri': 'file:///invalid', 'local': true},
          ]
        },
      ]);
    }));
    final pin = await api.createPin('device-1');
    expect(pin.verificationUrl.queryParameters['pin'], 'ABCD');
    expect(await api.pollPin('device-1', pin), 'account-test-token');
    final servers = await api.servers('device-1', 'account-test-token');
    expect(servers, hasLength(1));
    expect(servers.single.token, 'server-test-token');
    expect(servers.single.connections.map((u) => u.host),
        ['library.test', 'remote.test', 'relay.test']);
  });

  test(
      'Plex routes catalogs, search, details, episodes and complete direct versions',
      () async {
    final queries = <Map<String, String>>[];
    final api = MediaServerApi(client: MockClient((request) async {
      expect(request.url.host, 'library.test');
      expect(request.headers['x-plex-token'], 'server-test-token');
      expect(request.url.queryParameters.containsKey('X-Plex-Token'), false);
      final path = request.url.path;
      if (path == '/library/sections') {
        return container({
          'Directory': [
            {'key': '1', 'title': 'Movies', 'type': 'movie'},
            {'key': '2', 'title': 'Shows', 'type': 'show'},
            {'key': '3', 'title': 'Music', 'type': 'artist'},
          ]
        });
      }
      if (path == '/library/sections/1/all') {
        queries.add(request.url.queryParameters);
        return container({
          'Metadata': [
            {
              'ratingKey': '10',
              'type': 'movie',
              'title': 'A movie',
              'thumb': '/library/metadata/10/thumb/1',
              'year': 2024,
              'duration': 5400000,
              'rating': 8.2,
              'Guid': [
                {'id': 'imdb://tt1234567'}
              ],
              'Genre': [
                {'tag': 'Drama'}
              ],
              'Role': [
                {'tag': 'Actor'}
              ]
            },
          ]
        });
      }
      if (path == '/library/metadata/20') {
        return container({
          'Metadata': [
            {
              'ratingKey': '20',
              'type': 'show',
              'title': 'A show',
              'Guid': [
                {'id': 'imdb://tt7654321'}
              ],
              'Role': [
                {'tag': 'Actor'}
              ]
            },
          ]
        });
      }
      if (path == '/library/metadata/20/allLeaves') {
        return container({
          'totalSize': 2,
          'Metadata': [
            {
              'ratingKey': '22',
              'type': 'episode',
              'title': 'Two',
              'parentIndex': 1,
              'index': 2,
              'originallyAvailableAt': '2024-02-02'
            },
            {
              'ratingKey': '21',
              'type': 'episode',
              'title': 'One',
              'parentIndex': 1,
              'index': 1
            },
          ]
        });
      }
      if (path == '/library/metadata/21') {
        return container({
          'Metadata': [
            {
              'ratingKey': '21',
              'type': 'episode',
              'Media': [
                {
                  'videoResolution': '1080',
                  'videoCodec': 'h264',
                  'Part': [
                    {
                      'key': '/library/parts/1/2/file.mkv',
                      'size': 123456789,
                      'file': '/private/directory/Episode.mkv',
                      'Stream': [
                        {
                          'streamType': 3,
                          'languageCode': 'fra',
                          'key': '/library/streams/5'
                        },
                        {
                          'streamType': 3,
                          'languageCode': 'eng',
                          'key': 'https://outside.test/steal'
                        },
                      ]
                    },
                  ]
                },
                {
                  'Part': [
                    {'key': '//outside.test/steal'}
                  ]
                },
                {
                  'Part': [
                    {'key': '/part-1'},
                    {'key': '/part-2'}
                  ]
                },
              ]
            },
          ]
        });
      }
      fail('Unexpected Plex endpoint: $path');
    }));
    final source = await api.connectPlex(server, 'device-1');
    expect(source.server!.kind, MediaServerKind.plex);
    expect(source.baseUrl, 'http://library.test:32400');
    expect(source.catalogs.map((c) => c.name), ['Movies', 'Shows']);
    final stored = ArchiveSource.fromJson(source.toJson());
    expect(stored.server!.token, 'server-test-token');
    expect(stored.key, source.key);
    final movie =
        (await api.fetchCatalog(source, source.catalogs.first, skip: 100))
            .single;
    expect(movie.imdb, 'tt1234567');
    expect(movie.runtime, '90 min');
    expect(movie.cast, ['Actor']);
    expect(Uri.parse(movie.posterUrl!).queryParameters['X-Plex-Token'],
        'server-test-token');
    await api.fetchCatalog(source, source.catalogs.first, search: 'A movie');
    expect(queries.first['X-Plex-Container-Start'], '100');
    expect(queries.last['title'], 'A movie');
    final show = await api.fetchMeta(source,
        const ArchiveMeta(id: '20', type: ArchiveType.series, name: 'A show'));
    expect(show!.imdb, 'tt7654321');
    expect(show.cast, ['Actor']);
    expect(show.videos.map((v) => v.id), ['21', '22']);
    final streams = await api.streams(source, '21');
    expect(streams, hasLength(1));
    expect(Uri.parse(streams.single.url).path, '/library/parts/1/2/file.mkv');
    expect(streams.single.fileName, 'Episode.mkv');
    expect(streams.single.sizeBytes, 123456789);
    expect(streams.single.subtitles, hasLength(1));
    expect(streams.single.subtitles.single.language, 'fra');
  });

  test(
      'local connection failure falls back; identities survive address changes',
      () async {
    final api = PlexApi(MockClient((request) async {
      if (request.url.host == 'offline.test') {
        throw http.ClientException('offline');
      }
      return container({
        'Directory': [
          {'key': '1', 'title': 'Films', 'type': 'movie'}
        ]
      });
    }));
    final first = await api.connect(
        PlexServer(server.id, server.name, server.token,
            [Uri.parse('http://offline.test'), ...server.connections]),
        'device');
    final second = await api.connect(
        PlexServer(server.id, server.name, server.token,
            [Uri.parse('https://remote.test')]),
        'device');
    expect(first.baseUrl, 'http://library.test:32400');
    expect(first.key, second.key);
  });

  test('invalid credentials and empty libraries have distinct errors',
      () async {
    final denied =
        PlexApi(MockClient((_) async => http.Response('secret reply', 401)));
    expect(() => denied.connect(server, 'device'),
        throwsA(isA<MediaServerLoginException>()));
    final empty =
        PlexApi(MockClient((_) async => container({'Directory': []})));
    expect(() => empty.connect(server, 'device'),
        throwsA(isA<MediaServerNoLibraryException>()));
    final failure =
        PlexApi(MockClient((_) async => http.Response('secret reply', 500)));
    expect(
        () => failure.connect(server, 'device'),
        throwsA(predicate((error) =>
            error is ArchiveApiException &&
            !error.toString().contains('secret'))));
  });
}
