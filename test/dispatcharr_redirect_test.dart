import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/dispatcharr.dart';
import 'package:nox_iptv/services/live_sources.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// cillfog (Discord, 2026-11-23): Dispatcharr streams on a Redirect stream
/// profile play as the channel but not when picked in Sources. Checked on
/// a real Dispatcharr 0.34.1 the same day: the channel's address answers a
/// 302 to the provider; one stream's address (`/proxy/ts/stream/<hash>`)
/// answers 200 and 188 bytes, then nothing (only channels are redirected);
/// with `skip_redirect=true` and the user's X-API-Key it plays, proxied. A
/// Standard user is never shown a stream's provider address, an admin is.
const _server = 'http://10.0.0.5:9191';
const _uuid = '6abc2d09-db85-4038-9248-24643491820b';
const _provider = 'https://cdn.example.tv/live/zen/index.m3u8';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

/// The profiles of a 0.34.1 server: 4 is the locked Redirect.
final _profiles = [
  {'id': 3, 'name': 'Proxy', 'command': '', 'locked': true},
  {'id': 4, 'name': 'Redirect', 'command': '', 'locked': true},
  {'id': 1, 'name': 'FFmpeg', 'command': 'ffmpeg', 'locked': true},
  // A user's own profile with the same name is not Dispatcharr's Redirect.
  {'id': 9, 'name': 'Redirect', 'command': 'ffmpeg', 'locked': false},
];

class _DirStorage extends StorageService {
  _DirStorage(this.dir);
  final Directory dir;
  @override
  Future<String> rawCachePath(String name, String ext) async =>
      '${dir.path}/$name.$ext';
  @override
  Future<String?> cacheFilePath(String name) async {
    final f = File('${dir.path}/$name.json');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> writeCacheFile(String name, String content) =>
      File('${dir.path}/$name.json').writeAsString(content);

  @override
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a Redirect stream asks Dispatcharr to proxy it', () {
    expect(
        DispatcharrApi.streamUrl(_server, 'abc',
            format: 'mpegts', skipRedirect: true),
        '$_server/proxy/ts/stream/abc?output_format=mpegts&skip_redirect=true');
    expect(DispatcharrApi.streamUrl(_server, 'abc', skipRedirect: true),
        '$_server/proxy/ts/stream/abc?skip_redirect=true');
    expect(DispatcharrApi.streamUrl(_server, 'abc', format: 'hls'),
        '$_server/proxy/ts/stream/abc?output_format=hls');
  });

  group('which streams are on Redirect', () {
    late int defaultProfile;
    late bool profilesReadable;
    late bool admin;
    late Dispatcharr d;

    List<Map<String, Object?>> streams() => [
          {
            'id': 262,
            'name': 'XITE Nuevo Latino (1080p)',
            'stream_hash': 'h262',
            'stream_profile_id': null,
            if (admin) 'url': _provider,
          },
          {
            'id': 263,
            'name': 'XITE Siempre Latino (1080p)',
            'stream_hash': 'h263',
            // Its own profile, whatever the default.
            'stream_profile_id': 1,
            if (admin) 'url': 'https://cdn.example.tv/other.m3u8',
          },
          {
            'id': 264,
            'name': 'Yo! MTV (1080p)',
            'stream_hash': 'h264',
            'stream_profile_id': 9,
            if (admin) 'url': 'https://cdn.example.tv/mtv.m3u8',
          },
        ];

    setUp(() {
      defaultProfile = 4;
      profilesReadable = true;
      admin = false;
      d = Dispatcharr.instance;
      d.login.value =
          const DispatcharrLogin(server: _server, apiKey: 'k', username: 'vt');
      d.api = DispatcharrApi(client: MockClient((r) async {
        return switch (r.url.path) {
          '/api/channels/channels/by-uuids/' => _json([
              {'id': 2, 'uuid': _uuid}
            ]),
          '/api/channels/channels/2/streams/' => _json(streams()),
          '/api/core/streamprofiles/' =>
            profilesReadable ? _json(_profiles) : _json({}, 403),
          '/api/core/settings/' => _json([
              {
                'id': 13,
                'key': 'stream_settings',
                'value': {
                  'm3u_hash_key': 'url',
                  'default_stream_profile': defaultProfile,
                },
              },
            ]),
          _ => _json({}, 404),
        };
      }));
    });

    tearDown(() => d.save(null));

    Channel channel() => Channel(
        id: 'p1::2',
        rawId: '2',
        playlistId: 'p1',
        name: 'VesperTV test',
        group: 'News',
        url: '$_server/proxy/ts/stream/$_uuid');

    test('Redirect as the default: every stream without its own profile',
        () async {
      final r = await d.streamsFor(channel());
      expect(r!.redirects, {262},
          reason: '263 has FFmpeg; 264 is a look-alike, not the locked one');
      expect(r.streams.first.url, isNull, reason: 'a Standard user');
    });

    test('a proxy default: none', () async {
      defaultProfile = 3;
      expect((await d.streamsFor(channel()))!.redirects, isEmpty);
    });

    test('profiles not readable: listed as before', () async {
      profilesReadable = false;
      final r = await d.streamsFor(channel());
      expect(r!.streams, hasLength(3));
      expect(r.redirects, isEmpty);
    });

    test('an admin is shown the provider address', () async {
      admin = true;
      final r = await d.streamsFor(channel());
      expect(r!.streams.first.url, _provider);
    });
  });

  group('the Sources rows', () {
    late PlaylistManager manager;
    late Dispatcharr d;
    late bool admin;
    late Channel playing;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      );
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('vesper_dredirect_');
      addTearDown(() => temp.delete(recursive: true));
      final storage = _DirStorage(temp);
      await storage.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
      addTearDown(catalog.close);
      manager = PlaylistManager(storage, catalog);
      addTearDown(manager.dispose);
      final file = File('${temp.path}/d.m3u');
      await file.writeAsString([
        '#EXTM3U',
        '#EXTINF:-1 tvg-id="zen" group-title="Music",VesperTV test',
        '$_server/proxy/ts/stream/$_uuid',
        '',
      ].join('\n'));
      await manager.addPlaylist(PlaylistProfile(
        id: 'd',
        name: 'Dispatcharr',
        mode: 'm3u',
        m3uUrl: Uri.file(file.path).toString(),
        sortOrder: 0,
        createdAt: DateTime(2026),
      ));
      await manager.loadPlaylist('d');
      playing = manager
          .visibleChannels(category: 'tv')
          .firstWhere((c) => c.name == 'VesperTV test');

      admin = false;
      d = Dispatcharr.instance;
      d.login.value =
          const DispatcharrLogin(server: _server, apiKey: 'k', username: 'vt');
      d.api = DispatcharrApi(client: MockClient((r) async {
        return switch (r.url.path) {
          '/api/channels/channels/by-uuids/' => _json([
              {'id': 2, 'uuid': _uuid}
            ]),
          '/api/channels/channels/2/streams/' => _json([
              {
                'id': 262,
                'name': 'XITE Nuevo Latino (1080p)',
                'stream_hash': 'h262',
                'stream_profile_id': null,
                if (admin) 'url': _provider,
              },
              {
                'id': 263,
                'name': 'XITE Siempre Latino (1080p)',
                'stream_hash': 'h263',
                'stream_profile_id': 1,
              },
            ]),
          '/api/core/streamprofiles/' => _json(_profiles),
          '/api/core/settings/' => _json([
              {
                'id': 13,
                'key': 'stream_settings',
                'value': {'default_stream_profile': 4},
              },
            ]),
          '/api/accounts/users/me/' =>
            _json({'username': 'vt', 'user_level': admin ? 10 : 1}),
          _ => _json({}, 404),
        };
      }));
    });

    tearDown(() => d.save(null));

    Channel row(List<LiveSourceRow> rows, String name) =>
        rows.firstWhere((r) => r.$1.name == name).$1;

    test('a Standard user: the Redirect stream is proxied, with the key',
        () async {
      final (:rows, canAdd: _) = await liveSourceRows(manager, playing);
      final redirect = row(rows, 'XITE Nuevo Latino (1080p)');
      expect(redirect.url, '$_server/proxy/ts/stream/h262?skip_redirect=true');
      expect(redirect.httpHeaders['X-API-Key'], 'k');
      // A stream on its own (FFmpeg) profile is as before.
      expect(row(rows, 'XITE Siempre Latino (1080p)').url,
          '$_server/proxy/ts/stream/h263');
    });

    test("an admin: the provider's address, like Dispatcharr's redirect",
        () async {
      admin = true;
      final (:rows, canAdd: _) = await liveSourceRows(manager, playing);
      final redirect = row(rows, 'XITE Nuevo Latino (1080p)');
      expect(redirect.url, _provider);
      expect(redirect.httpHeaders.containsKey('X-API-Key'), isFalse,
          reason: "the Dispatcharr key never goes to the provider");
      // Picking it: the channel isn't proxied on the server (Redirect), so
      // the switch is refused and the stream plays itself.
      final played = <Channel>[];
      await playPickedLiveSource(playing, redirect, (c) async => played.add(c));
      expect(played.single.url, _provider);
    });
  });
}
