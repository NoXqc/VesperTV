import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/media_server_errors.dart';
import 'package:nox_iptv/services/silo_api.dart';

/// A fake Silo server: answers by method + path, records every request.
class _Server {
  final requests = <http.Request>[];
  final Map<String, http.Response Function(http.Request)> routes = {};
  var accessToken = 'access-1';

  /// Older tokens the server still takes (not expired yet).
  final stillValid = <String>{};

  late final client = MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path}';
    final route = routes[key];
    if (route == null) return http.Response('{"status":404}', 404);
    final auth = request.headers['Authorization'];
    final open = key.startsWith('POST /api/v2/auth/') ||
        key == 'GET /api/v2/system/info';
    if (!open &&
        auth != 'Bearer $accessToken' &&
        !stillValid.any((t) => auth == 'Bearer $t')) {
      return http.Response('{"status":401}', 401);
    }
    return route(request);
  });

  static http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
}

/// A JWT-shaped access token that runs out at [exp].
String _jwt(DateTime exp) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.'
      '${part({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

ArchiveSource _source({String token = 'access-1'}) => ArchiveSource(
      manifestUrl: 'http://silo.test:8090#7:p1',
      name: 'Silo · silo.test',
      server: MediaServerLogin(
        kind: MediaServerKind.silo,
        userId: '7',
        token: token,
        deviceId: 'dev',
        userName: 'owner',
        refreshToken: 'refresh-1',
        profileId: 'p1',
        profileName: 'Owner',
      ),
    );

void main() {
  test('normalizeUrl adds http, drops pages pasted from the browser', () {
    expect(
        SiloApi.normalizeUrl('192.168.1.20:8090/'), 'http://192.168.1.20:8090');
    expect(SiloApi.normalizeUrl('https://silo.example.com/activate?code=1'),
        'https://silo.example.com');
    expect(SiloApi.normalizeUrl(' https://h/silo/login '), 'https://h/silo');
  });

  test('discover accepts a v2 server, falls back to the origin', () async {
    final server = _Server()
      ..routes['GET /api/v2/system/info'] =
          ((_) => _Server.json({'api_major': 2, 'server_version': 'x'}));
    final api = SiloApi(server.client);
    expect(
        await api.discover('silo.test:8090/web/home'), 'http://silo.test:8090');
  });

  test('login keeps profile and tokens through JSON', () {
    final login = _source().server!;
    final back =
        MediaServerLogin.fromJson(jsonDecode(jsonEncode(login.toJson())))!;
    expect(back.kind, MediaServerKind.silo);
    expect(back.refreshToken, 'refresh-1');
    expect(back.profileId, 'p1');
    expect(back.withTokens('a2', 'r2').profileId, 'p1');
  });

  test('libraries: movies and series only, with the profile header', () async {
    final server = _Server()
      ..routes['GET /api/v2/user/libraries'] = ((_) => _Server.json({
            'items': [
              {'id': '1', 'name': 'Movies', 'type': 'movies'},
              {'id': '2', 'name': 'Shows', 'type': 'series'},
              {'id': '3', 'name': 'Music', 'type': 'music'},
            ]
          }));
    final api = SiloApi(server.client);
    final libs = await api.libraries(_source());
    expect(libs.map((c) => (c.id, c.type)),
        [('1', ArchiveType.movie), ('2', ArchiveType.series)]);
    expect(server.requests.single.headers['X-Profile-Id'], 'p1');
  });

  test('catalog pages by seek and maps cards', () async {
    final server = _Server()
      ..routes['GET /api/v2/catalog'] = ((_) => _Server.json({
            'items': [
              {
                'content_id': 'movie-tmdb-10378',
                'type': 'movie',
                'title': 'Big Buck Bunny',
                'year': 2008,
                'imdb_id': 'tt1254207',
                'poster_url': '/api/v2/images/p.jpg',
                'backdrop_url': 'https://image.tmdb.org/b.jpg',
                'logo_url': 'https://image.tmdb.org/l.svg',
                'duration_seconds': 600,
                'rating_tmdb': 6.47,
                'genres': ['Animation'],
              }
            ]
          }));
    final api = SiloApi(server.client);
    const catalog =
        ArchiveCatalog(type: ArchiveType.movie, id: '1', name: 'Movies');
    final items = await api.fetchCatalog(_source(), catalog, skip: 100);
    final q = server.requests.single.url.queryParameters;
    expect(q['library_id'], '1');
    expect(q['seek'], '100');
    expect(q['type'], 'movie');
    final m = items.single;
    expect(m.id, 'movie-tmdb-10378');
    expect(m.imdbId, 'tt1254207');
    expect(m.posterUrl, 'http://silo.test:8090/api/v2/images/p.jpg');
    expect(m.logoUrl, isNull, reason: 'SVG logos cannot be drawn');
    expect(m.runtime, '10 min');
    expect(m.rating, '6.5');
  });

  test('a series gets its episodes; episodes without a file are left out',
      () async {
    final server = _Server()
      ..routes['GET /api/v2/catalog/items/s1'] = ((_) => _Server.json(
          {'content_id': 's1', 'type': 'series', 'title': 'Test Show'}))
      ..routes['GET /api/v2/catalog/series/s1/seasons'] = ((_) => _Server.json({
            'items': [
              {'season_number': 2},
              {'season_number': 1},
            ]
          }))
      ..routes['GET /api/v2/catalog/series/s1/seasons/1/episodes'] =
          ((_) => _Server.json({
                'items': [
                  {
                    'content_id': 'e2',
                    'season_number': 1,
                    'episode_number': 2,
                    'title': 'Two',
                    'files': [
                      {'file_id': '3'}
                    ],
                  },
                  {
                    'content_id': 'e1',
                    'season_number': 1,
                    'episode_number': 1,
                    'title': 'One',
                    'files': [
                      {'file_id': '2'}
                    ],
                  },
                ]
              }))
      ..routes['GET /api/v2/catalog/series/s1/seasons/2/episodes'] =
          ((_) => _Server.json({
                'items': [
                  {
                    'content_id': 'e9',
                    'season_number': 2,
                    'episode_number': 1,
                    'title': 'Not on disk',
                    'files': [],
                  },
                ]
              }));
    final api = SiloApi(server.client);
    final meta = await api.fetchMeta(_source(),
        const ArchiveMeta(id: 's1', type: ArchiveType.series, name: 'x'));
    expect(meta!.videos.map((v) => v.id), ['e1', 'e2']);
  });

  test('streams are placeholder links, one per file', () async {
    final server = _Server()
      ..routes['GET /api/v2/catalog/items/m1'] = ((_) => _Server.json({
            'content_id': 'm1',
            'versions': [
              {
                'file_id': '1',
                'file_name': 'Movie.mkv',
                'file_size': 1234,
                'resolution': '2160p',
                'hdr': true,
                'codec_video': 'hevc',
                'container': 'mkv',
              }
            ]
          }));
    final api = SiloApi(server.client);
    final streams = await api.streams(_source(), 'm1');
    final s = streams.single;
    expect(SiloApi.isPlayLink(s.url), isTrue);
    expect(s.sizeBytes, 1234);
    expect(s.fileName, 'Movie.mkv');
    expect(s.title, 'Silo · 2160p · HDR · HEVC · MKV');
  });

  group('play', () {
    late _Server server;
    late SiloApi api;
    final link = SiloApi.playLink(_source(), 'm1', '42');

    setUp(() {
      server = _Server()
        ..routes['GET /api/v2/playback/capabilities'] =
            ((_) => _Server.json({'installation_id': 'inst-1'}))
        ..routes['POST /api/v2/playback/start'] = (r) {
          final body = jsonDecode(r.body) as Map;
          expect(body['file_id'], '42');
          expect(body['profile_id'], 'p1');
          expect(body['installation_id'], 'inst-1');
          expect(body['protocol_version'], 3);
          return _Server.json({
            'outcome': 'playable',
            'session_id': 'sess-1',
            'playback_plan': {
              'delivery': 'original_http',
              'stream': {
                'url': '/api/v2/stream/sess-1?st=abc',
                'headers': <String, String>{},
              },
            },
          }, 201);
        }
        ..routes['POST /api/v2/playback/sess-1/progress'] =
            ((_) => _Server.json({'outcome': 'applied'}))
        ..routes['DELETE /api/v2/playback/sess-1'] =
            ((_) => _Server.json({'outcome': 'stopped'}));
      api = SiloApi(server.client);
    });

    test('start returns the signed link; stop reports the position', () async {
      final play = await api.startPlayback(_source(), link);
      expect(play.url, 'http://silo.test:8090/api/v2/stream/sess-1?st=abc');
      // Issue #21: servers before 2026-11-14 (and plays no login session
      // started) refuse the link without the account: 401 on every try.
      expect(play.headers['Authorization'], 'Bearer access-1');
      expect(play.headers['X-Profile-Id'], 'p1');
      expect(play.headers['X-Silo-Device-Id'], 'dev');
      expect(play.headers.containsKey('Accept'), isFalse);
      expect(SiloSessions.instance.isSilo(play.url), isTrue);

      SiloSessions.instance.stopped(play.url, const Duration(seconds: 61));
      await pumpEventQueue();
      final stop = server.requests.last;
      expect(stop.method, 'DELETE');
      expect((jsonDecode(stop.body) as Map)['position'], 61);
      expect(SiloSessions.instance.isSilo(play.url), isFalse);
      // The server's installation id is asked once per server.
      await api.startPlayback(_source(), link);
      expect(
          server.requests
              .where((r) => r.url.path.endsWith('/playback/capabilities'))
              .length,
          1);
    });

    test('a link on another host (node, media origin) gets no sign-in',
        () async {
      server.routes['POST /api/v2/playback/start'] = (_) => _Server.json({
            'outcome': 'playable',
            'session_id': 'sess-2',
            'playback_plan': {
              'delivery': 'original_http',
              'stream': {
                'url': 'https://node.example/stream/grant-xyz',
                'headers': {'X-Grant': 'g1'},
              },
            },
          }, 201);
      final play = await api.startPlayback(_source(), link);
      expect(play.headers, {'X-Grant': 'g1'});
      SiloSessions.instance.stopped(play.url, Duration.zero);
    });

    test('a sign-in close to running out is renewed before the play', () async {
      final old = _jwt(DateTime.now().add(const Duration(hours: 1)));
      server
        ..stillValid.add(old)
        ..accessToken = 'access-2'
        ..routes['POST /api/v2/auth/refresh'] = ((_) => _Server.json(
            {'access_token': 'access-2', 'refresh_token': 'refresh-2'}));
      final play = await api.startPlayback(_source(token: old), link);
      expect(play.headers['Authorization'], 'Bearer access-2');
      final start = server.requests
          .firstWhere((r) => r.url.path.endsWith('/playback/start'));
      expect(start.headers['Authorization'], 'Bearer access-2');
      SiloSessions.instance.stopped(play.url, Duration.zero);

      // Hours left: no renewal.
      final fresh = SiloApi(server.client);
      final long = _jwt(DateTime.now().add(const Duration(hours: 7)));
      server.stillValid.add(long);
      final before = server.requests.length;
      final second = await fresh.startPlayback(_source(token: long), link);
      expect(second.headers['Authorization'], 'Bearer $long');
      expect(
          server.requests
              .skip(before)
              .where((r) => r.url.path.endsWith('/auth/refresh')),
          isEmpty);
      SiloSessions.instance.stopped(second.url, Duration.zero);
    });

    test('a refused plan is said, nothing plays', () async {
      server.routes['POST /api/v2/playback/start'] = (_) => _Server.json({
            'outcome': 'adaptation_unavailable',
            'terminal': {
              'reason': 'bitrate_policy_unavailable',
              'message': 'Too big for this connection',
              'retryable': false,
            },
          }, 201);
      await expectLater(
          () => api.startPlayback(_source(), link),
          throwsA(isA<SiloPlaybackRefusedException>().having(
              (e) => e.message, 'message', 'Too big for this connection')));
    });
  });

  test('tokenLife reads a JWT expiry; anything else is unknown', () {
    final now = DateTime(2026, 11, 25, 12);
    expect(SiloApi.tokenLife(_jwt(now.add(const Duration(hours: 2))), now: now),
        const Duration(hours: 2));
    expect(SiloApi.tokenLife('access-1', now: now), isNull);
    expect(SiloApi.tokenLife('a.%%%.c', now: now), isNull);
  });

  test('an expired access token is renewed once and saved', () async {
    final server = _Server()..accessToken = 'access-2';
    server.routes['POST /api/v2/auth/refresh'] = (r) {
      expect((jsonDecode(r.body) as Map)['refresh_token'], 'refresh-1');
      return _Server.json(
          {'access_token': 'access-2', 'refresh_token': 'refresh-2'});
    };
    server.routes['GET /api/v2/user/libraries'] = (_) => _Server.json({
          'items': [
            {'id': '1', 'name': 'Movies', 'type': 'movies'}
          ]
        });
    final api = SiloApi(server.client);
    MediaServerLogin? saved;
    api.onLoginChanged = (_, login) => saved = login;
    final source = _source();
    expect(await api.libraries(source), hasLength(1));
    expect(saved?.token, 'access-2');
    expect(saved?.refreshToken, 'refresh-2');
    expect(saved?.profileId, 'p1');
    // Later calls use the renewed token without another refresh.
    await api.libraries(source);
    expect(server.requests.where((r) => r.url.path.endsWith('/refresh')),
        hasLength(1));
  });

  test('a refused refresh means signing in again', () async {
    final server = _Server()..accessToken = 'other';
    server.routes['POST /api/v2/auth/refresh'] =
        (_) => _Server.json({'status': 401}, 401);
    server.routes['GET /api/v2/user/libraries'] =
        (_) => _Server.json({'items': []});
    final api = SiloApi(server.client);
    await expectLater(() => api.libraries(_source()),
        throwsA(isA<MediaServerLoginException>()));
  });

  test('code sign-in: pending, then approved with the profile picked there',
      () async {
    var polls = 0;
    final server = _Server()
      ..routes['POST /api/v2/auth/device/start'] = ((_) => _Server.json({
            'device_code': 'dc',
            'user_code': '4821-7730',
            'verification_uri': 'http://silo.test:8090/activate',
            'verification_uri_complete':
                'http://silo.test:8090/activate?code=48217730',
            'expires_in': 900,
            'interval': 5,
          }, 201))
      ..routes['POST /api/v2/auth/device/poll'] = ((_) => ++polls == 1
          ? _Server.json({'status': 'pending', 'poll_after': 5})
          : _Server.json({
              'status': 'approved',
              'profile_id': 'p2',
              'profile_token': 'pt',
              'tokens': {
                'access_token': 'a',
                'refresh_token': 'r',
                'user': {'id': '7', 'username': 'owner'},
              },
            }));
    final api = SiloApi(server.client);
    final code = await api.startDeviceLogin('http://silo.test:8090', 'dev');
    expect(code.userCode, '4821-7730');
    expect(await api.pollDeviceLogin('http://silo.test:8090', 'dev', code),
        isNull);
    final signIn =
        await api.pollDeviceLogin('http://silo.test:8090', 'dev', code);
    expect(signIn!.profileId, 'p2');
    expect(signIn.profileToken, 'pt');
    expect(signIn.userName, 'owner');
  });

  test('code sign-in refused on the server ends it', () async {
    final server = _Server()
      ..routes['POST /api/v2/auth/device/poll'] =
          ((_) => _Server.json({'status': 'denied'}));
    final api = SiloApi(server.client);
    final code = SiloDeviceCode(
        deviceCode: 'dc',
        userCode: '1',
        verificationUrl: '',
        verificationUrlComplete: '',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        interval: const Duration(seconds: 5));
    await expectLater(
        () => api.pollDeviceLogin('http://silo.test:8090', 'dev', code),
        throwsA(isA<SiloSignInEndedException>()));
  });
}
