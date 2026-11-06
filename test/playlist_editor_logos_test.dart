import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_channel_info.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_editor_server.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RealHttp extends HttpOverrides {}

class EditorPlaylists extends PlaylistManager {
  EditorPlaylists(StorageService storage, this.session)
      : super(storage, CatalogDatabase());
  final PlaylistSession session;
  @override
  List<PlaylistProfile> get profiles => [session.profile];
  @override
  PlaylistSession? editorSession(String id) =>
      id == session.profile.id ? session : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late PlaylistSession session;
  late EditorPlaylists manager;
  late PlaybackService playback;
  late PlaylistEditorServer server;
  late HttpClient client;
  late Uri base;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    final profile = PlaylistProfile(
        id: 'p',
        name: 'Test',
        mode: 'm3u',
        m3uUrl: 'https://example.com/m3u',
        epgUrl: 'https://main.example/guide',
        extraEpgUrls: ['https://custom.example/guide'],
        sortOrder: 0,
        createdAt: DateTime(2026));
    session = PlaylistSession(
        profile: profile,
        storage: storage,
        catalogDb: CatalogDatabase(),
        favoriteIds: () => {},
        favoriteSeriesIds: () => {},
        isRestrictedViewer: () => false,
        onNotify: () {})
      ..channels = [
        Channel(
            id: 'p::a',
            rawId: 'a',
            playlistId: 'p',
            name: 'Sky',
            group: 'Sports',
            url: 'https://example.com/live',
            logoUrl: 'https://main.example/provider.png')
      ];
    manager = EditorPlaylists(storage, session);
    playback = PlaybackService(storage, manager);
    server = PlaylistEditorServer(manager, playback, storage)
      ..guideChannels = (url) => [
            EpgChannelInfo(
                'same',
                'Sky',
                url.contains('custom')
                    ? 'https://custom.example/logo.png'
                    : null)
          ];
    await server.start();
    base = Uri.parse(server.address!);
    client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), RealHttp());
  });
  tearDown(() async {
    client.close(force: true);
    await server.stop();
    server.dispose();
    playback.dispose();
    manager.dispose();
  });
  Future<({int status, Map data})> request(String path,
      {Object? body, String viewer = 'main'}) async {
    final req =
        await client.openUrl(body == null ? 'GET' : 'POST', base.resolve(path));
    req.headers.set('x-editor-code', server.code);
    req.headers.set('x-editor-viewer', viewer);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final data = await utf8.decoder.bind(res).join();
    return (
      status: res.statusCode,
      data: data.isEmpty ? {} : jsonDecode(data) as Map
    );
  }

  test(
      'source-aware authenticated API and URL save preserve programme matching',
      () async {
    var response = await request('/api/epg/search?pl=p&q=sky&source=1');
    expect(response.status, 200);
    final result = (response.data['results'] as List).single;
    expect(result['l'], 'https://custom.example/logo.png');
    expect(result['sourceName'], 'Extra guide 1');
    response = await request('/api/edits?pl=p', body: {
      'edits': {
        'names': {'a': 'Renamed'},
        'logos': {'a': result['l']}
      }
    });
    expect(response.data['error'], isNull);
    expect(session.channels.single.logoUrl, result['l']);
    expect(session.epgIdOverrides, isEmpty);
    await request('/api/epg/link?pl=p', body: {'r': 'a', 'id': 'same'});
    expect(session.channels.single.logoUrl, result['l']);
    await request('/api/edits?pl=p', body: {
      'edits': {
        'names': {'a': 'Renamed'},
        'logos': {}
      }
    });
    expect(session.channels.single.name, 'Renamed');
    expect(
        session.channels.single.logoUrl, 'https://main.example/provider.png');
    expect(session.epgIdOverrides, {'a': 'same'});
  });
  test(
      'invalid and overlong image URLs are rejected server-side before truncation',
      () async {
    for (final logo in [
      'javascript:alert(1)',
      "https://example.com/${'a' * 1000}"
    ]) {
      final res = await request('/api/edits?pl=p', body: {
        'edits': {
          'logos': {'a': logo}
        }
      });
      expect(res.data['error'], contains('HTTP(S)'));
      expect(session.edits.logos, isEmpty);
    }
  });
  test('refresh action uses the shared guide callback, without editing logos',
      () async {
    var refreshes = 0;
    server.refreshGuide = () async {
      refreshes++;
    };
    final res = await request('/api/epg/refresh?pl=p', body: {});
    expect(res.status, 200);
    expect(refreshes, 1);
    expect(session.edits.logos, isEmpty);
  });

  test('viewer changed while editor open cannot save into another profile',
      () async {
    await storage.setActiveViewerId('other');
    final res = await request('/api/edits?pl=p', body: {
      'edits': {
        'logos': {'a': 'https://custom.example/logo.png'}
      }
    });
    expect(res.status, 409);
    expect(storage.getPlaylistEditsJson('p'), isNull);
    expect(session.edits.logos, isEmpty);
  });
}
