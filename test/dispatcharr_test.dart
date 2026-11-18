import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/dispatcharr.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart';

/// Answers recorded from a real Dispatcharr 0.34.1 (2026-11-18).
const _server = 'http://10.0.0.5:9191';
const _uuid = 'ea2c9f8a-2ac2-4aa6-9fbd-9044d2baf38b';

final _streams = [
  {
    'id': 668,
    'name': 'France 24 (1080p)',
    'm3u_account': 3,
    'stream_hash': 'df9538754a7e0000',
    'stream_stats': {
      'resolution': '1920x1080',
      'video_codec': 'h264',
      'source_fps': 29.97,
    },
    'is_stale': false,
  },
  {
    'id': 671,
    'name': 'France 24 English HD (1080p)',
    'm3u_account': 3,
    'stream_hash': '531de70f14c50000',
    'stream_stats': null,
  },
  {
    'id': 25,
    'name': 'CBC News Network (1080p)',
    'm3u_account': 2,
    'stream_hash': '2d462e30f38d0000',
    'stream_stats': {'resolution': '3840x2160', 'video_codec': 'hevc'},
  },
];

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Channel _channel(String url) => Channel(
    id: 'p1::1',
    rawId: '1',
    playlistId: 'p1',
    name: 'France 24',
    group: 'News',
    url: url);

void main() {
  group('dispatcharrChannelRef', () {
    test('Xtream live URLs give the channel id', () {
      expect(dispatcharrChannelRef(_server, '$_server/live/u/p/1.ts')?.id, 1);
      expect(
          dispatcharrChannelRef(_server, '$_server/live/u/p/42.m3u8')?.id, 42);
      expect(dispatcharrChannelRef(_server, '$_server/live/u/p/7')?.id, 7);
    });

    test('M3U proxy URLs give the uuid', () {
      final ref =
          dispatcharrChannelRef(_server, '$_server/proxy/ts/stream/$_uuid');
      expect(ref?.uuid, _uuid);
      expect(ref?.id, isNull);
    });

    test('another server, port or a stream hash is not a channel', () {
      expect(dispatcharrChannelRef(_server, 'http://other:9191/live/u/p/1.ts'),
          isNull);
      expect(
          dispatcharrChannelRef(_server, 'http://10.0.0.5:8080/live/u/p/1.ts'),
          isNull);
      expect(
          dispatcharrChannelRef(
              _server, '$_server/proxy/ts/stream/df9538754a7e0000'),
          isNull);
      expect(
          dispatcharrChannelRef(_server, '$_server/movie/u/p/1.mkv'), isNull);
    });

    test('a server under a path keeps its prefix', () {
      const base = 'https://example.org/dispatcharr';
      expect(dispatcharrChannelRef(base, '$base/live/u/p/3.ts')?.id, 3);
      expect(dispatcharrChannelRef(base, 'https://example.org/live/u/p/3.ts'),
          isNull);
    });

    test('host case and an https proxy in front still match', () {
      expect(
          dispatcharrChannelRef('http://Dispatch.Local:9191',
                  'http://dispatch.local:9191/live/u/p/5.ts')
              ?.id,
          5);
      expect(
          dispatcharrChannelRef('https://tv.example.org',
                  'http://tv.example.org/live/u/p/5.ts')
              ?.id,
          5);
    });
  });

  test('normalizeUrl adds http and drops pasted page paths', () {
    expect(DispatcharrApi.normalizeUrl('10.0.0.5:9191'), _server);
    expect(DispatcharrApi.normalizeUrl('$_server/channels'), _server);
    expect(DispatcharrApi.normalizeUrl('$_server/#/login'), _server);
    expect(DispatcharrApi.normalizeUrl('https://tv.example.org/'),
        'https://tv.example.org');
  });

  test('the phone can send an API key instead of a user name', () {
    final r = PairingResult.fromJson(
        {'mode': 'server', 'server': _server, 'key': 'abc'});
    expect(r?.apiKey, 'abc');
    expect(r?.username, '');
    expect(
        PairingResult.fromJson({'mode': 'server', 'server': _server}), isNull);
  });

  test('quality reads what Dispatcharr measured', () {
    final s = _streams.map(DispatcharrStream.fromJson).toList();
    expect(s[0].quality, '1080p · H.264 · 30 fps');
    expect(s[1].quality, isNull);
    expect(s[2].quality, '4K · HEVC');
  });

  group('signIn', () {
    test('reuses the existing API key, never regenerates it', () async {
      final calls = <String>[];
      final api = DispatcharrApi(client: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        switch (r.url.path) {
          case '/api/core/version/':
            return _json({'version': '0.34.1'});
          case '/api/accounts/token/':
            expect(
                jsonDecode(r.body), {'username': 'amd', 'password': 'secret'});
            return _json({'access': 'jwt', 'refresh': 'r'});
          case '/api/accounts/api-keys/':
            expect(r.headers['Authorization'], 'Bearer jwt');
            return _json({'key': 'existing-key'});
          case '/api/accounts/users/me/':
            expect(r.headers['X-API-Key'], 'existing-key');
            return _json({
              'username': 'amd',
              'user_level': 1,
              'custom_properties': {'xc_password': 'xc1'},
            });
        }
        return _json({}, 404);
      }));
      final account = await api.signIn(_server, 'amd', 'secret');
      expect(account.login.apiKey, 'existing-key');
      expect(account.xcPassword, 'xc1');
      expect(account.admin, isFalse);
      expect(calls, isNot(contains('POST /api/accounts/api-keys/generate/')));
    });

    test('makes a key when the user has none', () async {
      final api = DispatcharrApi(
          client: MockClient((r) async => switch (r.url.path) {
                '/api/core/version/' => _json({'version': '0.34.1'}),
                '/api/accounts/token/' => _json({'access': 'jwt'}),
                '/api/accounts/api-keys/' => _json({'key': null}),
                '/api/accounts/api-keys/generate/' =>
                  _json({'key': 'new-key'}, 201),
                '/api/accounts/users/me/' =>
                  _json({'username': 'admin', 'user_level': 10}),
                _ => _json({}, 404),
              }));
      final account = await api.signIn(_server, 'admin', 'pw');
      expect(account.login.apiKey, 'new-key');
      expect(account.xcPassword, isNull);
      expect(account.admin, isTrue);
    });

    test('a wrong password is a login error', () async {
      final api = DispatcharrApi(
          client: MockClient((r) async => switch (r.url.path) {
                '/api/core/version/' => _json({'version': '0.34.1'}),
                _ => _json({'detail': 'No active account'}, 401),
              }));
      expect(api.signIn(_server, 'a', 'b'),
          throwsA(isA<DispatcharrLoginException>()));
    });

    test('something that is not Dispatcharr is not a login error', () async {
      final api = DispatcharrApi(
          client: MockClient((r) async => http.Response('<html>', 200)));
      expect(
          api.signIn(_server, 'a', 'b'),
          throwsA(isA<DispatcharrException>()
              .having((e) => e is DispatcharrLoginException, 'login', false)));
    });
  });

  group('Dispatcharr.streamsFor', () {
    late List<String> calls;
    late Dispatcharr d;

    setUp(() {
      calls = [];
      d = Dispatcharr.instance;
      d.login.value =
          const DispatcharrLogin(server: _server, apiKey: 'k', username: 'amd');
      d.api = DispatcharrApi(client: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        expect(r.headers['X-API-Key'], 'k');
        return switch (r.url.path) {
          '/api/channels/channels/by-uuids/' => _json([
              {'id': 1, 'uuid': _uuid}
            ]),
          '/api/channels/channels/1/streams/' => _json(_streams),
          '/api/m3u/accounts/' => _json([
              {'id': 2, 'name': 'Public CA'},
              {'id': 3, 'name': 'Public News'},
            ]),
          _ => _json({}, 404),
        };
      }));
    });

    tearDown(() => d.save(null));

    test('an Xtream channel lists its streams and providers', () async {
      final r = await d.streamsFor(_channel('$_server/live/amd/xc1/1.ts'));
      expect(r!.streams.map((s) => s.id), [668, 671, 25]);
      expect(r.accounts[2], 'Public CA');
      expect(calls, isNot(contains('POST /api/channels/channels/by-uuids/')));
    });

    test('an M3U channel is found by its uuid, once', () async {
      final ch = _channel('$_server/proxy/ts/stream/$_uuid');
      await d.streamsFor(ch);
      await d.streamsFor(ch);
      expect(
          calls
              .where((c) => c == 'POST /api/channels/channels/by-uuids/')
              .length,
          1);
      // Streams are cached for 30 s too.
      expect(
          calls
              .where((c) => c == 'GET /api/channels/channels/1/streams/')
              .length,
          1);
    });

    test('a channel of another server asks nothing', () async {
      expect(await d.streamsFor(_channel('http://provider.tv/live/a/b/1.ts')),
          isNull);
      expect(calls, isEmpty);
    });

    test('no server connected = nothing', () async {
      d.login.value = null;
      expect(
          await d.streamsFor(_channel('$_server/live/amd/xc1/1.ts')), isNull);
    });

    test('a server that stops answering opens the drawer without them',
        () async {
      d.api = DispatcharrApi(client: MockClient((r) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return _json([]);
      }));
      final r = await d.streamsFor(_channel('$_server/live/amd/xc1/1.ts'),
          timeout: const Duration(milliseconds: 50));
      expect(r, isNull);
    });

    test('the stream URL goes through the proxy', () {
      expect(DispatcharrApi.streamUrl(_server, 'abc'),
          '$_server/proxy/ts/stream/abc');
    });
  });
}
