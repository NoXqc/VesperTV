import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/screens/settings/dispatcharr_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/dispatcharr.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/live_source_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wide_guide_back_test.dart' show GuidePlaylist, GuideEpg;

const _server = 'http://10.0.0.5:9191';

class _Playlists extends GuidePlaylist {
  _Playlists(super.storage);
  final entries = <PlaylistProfile>[];
  final loads = <String>[];

  /// What the next load fails with (a refused Xtream login), else null.
  String? loadError;
  String? _error;

  @override
  List<PlaylistProfile> get profiles => entries;

  @override
  String? get error => _error;

  @override
  Future<void> addPlaylist(PlaylistProfile profile) async {
    entries.add(profile);
    notifyListeners();
  }

  @override
  Future<void> loadPlaylist(String playlistId) async {
    loads.add(playlistId);
    _error = loadError;
    notifyListeners();
  }

  @override
  Future<void> removePlaylist(String playlistId) async {
    entries.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }

  @override
  Future<void> warmAllCategories(String playlistId) async {}
}

class _Epg extends GuideEpg {
  _Epg(super.storage);
  final refreshed = <String>[];

  @override
  Future<void> refresh(String url,
      {required Set<String> knownChannelIds}) async {
    refreshed.add(url);
  }
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

DispatcharrApi _api({String? xc = 'xc1'}) => DispatcharrApi(
    client: MockClient((r) async => switch (r.url.path) {
          '/api/core/version/' => _json({'version': '0.34.1'}),
          '/api/accounts/token/' => _json({'access': 'jwt'}),
          '/api/accounts/api-keys/' => _json({'key': 'k'}),
          '/api/accounts/users/me/' => _json({
              'username': 'amd',
              'user_level': 1,
              'custom_properties': {if (xc != null) 'xc_password': xc},
            }),
          _ => _json({}, 404),
        }));

Future<_Playlists> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final prefs = AppPreferences(storage);
  await prefs.init();
  final playlist = _Playlists(storage);
  final playback = PlaybackService(storage, playlist);
  final epg = _Epg(storage);
  Dispatcharr.instance.attach(storage);
  await tester.pumpWidget(MultiProvider(providers: [
    Provider.value(value: storage),
    ChangeNotifierProvider.value(value: prefs),
    ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
    ChangeNotifierProvider.value(value: playback),
    ChangeNotifierProvider<EpgService>.value(value: epg),
  ], child: const MaterialApp(home: DispatcharrScreen())));
  await tester.pumpAndSettle();
  return playlist;
}

Future<void> _signIn(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '10.0.0.5:9191/channels');
  await tester.enterText(fields.at(1), 'amd');
  await tester.enterText(fields.at(2), 'secret');
  await tester.tap(find.text('Connect'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => Dispatcharr.instance.save(null));

  testWidgets('connect adds and loads the server as a playlist at once',
      (tester) async {
    // roman (LOG-G67D3G, 2026-11-19): connected, "but no
    // playlist/content/groups": Add as a playlist was a second step.
    Dispatcharr.instance.api = _api();
    final playlists = await _open(tester);
    await _signIn(tester);
    // Saved: the API key, never the password.
    final login = Dispatcharr.instance.login.value!;
    expect(login.server, _server);
    expect(login.apiKey, 'k');
    expect(jsonEncode(login.toJson()), isNot(contains('secret')));

    // Saved without a second press: Xtream with the XC password, loaded.
    expect(playlists.entries, hasLength(1));
    final added = playlists.entries.single;
    expect(added.name, 'Dispatcharr');
    expect(added.mode, 'xtream');
    expect(added.xtreamServer, _server);
    expect(added.xtreamUsername, 'amd');
    expect(added.xtreamPassword, 'xc1');
    expect(playlists.loads, [added.id]);
    // A new Xtream playlist asks what to download, like a manual add.
    expect(find.text('Download content'), findsOneWidget);
    await tester.tap(find.text('Download All'));
    await tester.pumpAndSettle();
    // Back at the first page (here Dispatcharr), naming the new playlist.
    expect(find.text('Playlists on this server: Dispatcharr'), findsOneWidget);
    expect(find.text('Add another playlist from it'), findsOneWidget);
  });

  testWidgets('a refused playlist login stays on Add Playlist, adds nothing',
      (tester) async {
    Dispatcharr.instance.api = _api();
    final playlists = await _open(tester);
    playlists.loadError = 'Authentication failed';
    await _signIn(tester);
    expect(playlists.loads, hasLength(1));
    expect(playlists.entries, isEmpty);
    expect(find.textContaining('Authentication failed'), findsWidgets);
    // Back: still connected, and Add as a playlist fills the form in
    // without saving it by itself.
    playlists.loadError = null;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Connected to $_server as amd'), findsOneWidget);
    expect(
        find.text('No playlist loads from this server yet.'), findsOneWidget);
    await tester.tap(find.text('Add as a playlist'));
    await tester.pumpAndSettle();
    expect(find.text('Add Playlist'), findsWidgets);
    final values = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller?.text)
        .toList();
    expect(values, containsAll(['Dispatcharr', _server, 'amd', 'xc1']));
    expect(playlists.loads, hasLength(1));
  });

  testWidgets('a playlist on the same server is named', (tester) async {
    Dispatcharr.instance.api = _api();
    final playlists = await _open(tester);
    playlists.entries.add(PlaylistProfile(
        id: 'd',
        name: 'Home Dispatcharr',
        mode: 'xtream',
        xtreamServer: _server,
        xtreamUsername: 'amd',
        xtreamPassword: 'xc1',
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await _signIn(tester);
    expect(find.text('Playlists on this server: Home Dispatcharr'),
        findsOneWidget);
    expect(find.text('Add another playlist from it'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(Dispatcharr.instance.login.value, isNull);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('no Xtream password: connect adds the M3U and guide links',
      (tester) async {
    Dispatcharr.instance.api = _api(xc: null);
    final playlists = await _open(tester);
    await _signIn(tester);
    final added = playlists.entries.single;
    expect(added.mode, 'm3u');
    expect(added.m3uUrl, '$_server/output/m3u');
    expect(added.epgUrl, '$_server/output/epg');
    expect(playlists.loads, [added.id]);
    expect(find.text('Playlists on this server: Dispatcharr'), findsOneWidget);
    expect(find.textContaining('has no XC password'), findsOneWidget);
  });

  testWidgets('a pasted API key signs in without a password', (tester) async {
    final paths = <String>[];
    Dispatcharr.instance.api = DispatcharrApi(client: MockClient((r) async {
      paths.add(r.url.path);
      return switch (r.url.path) {
        '/api/core/version/' => _json({'version': '0.34.1'}),
        '/api/accounts/users/me/' => r.headers['X-API-Key'] == 'pasted'
            ? _json({'username': 'amd', 'user_level': 1})
            : _json({'detail': 'bad'}, 401),
        _ => _json({}, 404),
      };
    }));
    await _open(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10.0.0.5:9191');
    await tester.enterText(fields.at(3), 'pasted');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to $_server as amd'), findsOneWidget);
    expect(Dispatcharr.instance.login.value?.apiKey, 'pasted');
    expect(paths, isNot(contains('/api/accounts/token/')));
  });

  testWidgets('a refused API key says so', (tester) async {
    Dispatcharr.instance.api = DispatcharrApi(
        client: MockClient((r) async => r.url.path == '/api/core/version/'
            ? _json({'version': '0.34.1'})
            : _json({'detail': 'bad'}, 401)));
    await _open(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10.0.0.5:9191');
    await tester.enterText(fields.at(3), 'nope');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Dispatcharr refused this API key.'), findsOneWidget);
    expect(Dispatcharr.instance.login.value, isNull);
  });

  testWidgets('a web login limited to some networks points to the API key',
      (tester) async {
    // AMD's server (2026-11-18): the key connected, the password got 403.
    Dispatcharr.instance.api = DispatcharrApi(
        client: MockClient((r) async => r.url.path == '/api/core/version/'
            ? _json({'version': '0.34.0'})
            : _json({'error': 'Forbidden'}, 403)));
    await _open(tester);
    await _signIn(tester);
    expect(find.textContaining('Use your API key instead'), findsOneWidget);
    expect(find.textContaining("Couldn't find"), findsNothing);
  });

  testWidgets('password accepted but the key lookup refused: paste the key',
      (tester) async {
    // AMD's LOG-DJ39QW (+835): his Dispatcharr logged "Login success", the
    // next call (/api/accounts/api-keys/) got 403.
    final paths = <String>[];
    Dispatcharr.instance.api = DispatcharrApi(client: MockClient((r) async {
      paths.add(r.url.path);
      return switch (r.url.path) {
        '/api/core/version/' => _json({'version': '0.34.0'}),
        '/api/accounts/token/' => _json({'access': 'jwt', 'refresh': 'r'}),
        _ => _json({'detail': 'Forbidden'}, 403),
      };
    }));
    await _open(tester);
    await _signIn(tester);
    expect(find.textContaining('Your password works'), findsOneWidget);
    expect(find.textContaining('HTTP 403'), findsOneWidget);
    expect(paths, isNot(contains('/api/accounts/api-keys/generate/')));
    expect(Dispatcharr.instance.login.value, isNull);
  });

  testWidgets('an address that is not Dispatcharr says so', (tester) async {
    Dispatcharr.instance.api = DispatcharrApi(
        client: MockClient((r) async => http.Response('Not found', 404)));
    await _open(tester);
    await _signIn(tester);
    expect(find.text("Couldn't find a Dispatcharr server at that address."),
        findsOneWidget);
  });

  testWidgets('a wrong password says so and saves nothing', (tester) async {
    Dispatcharr.instance.api = DispatcharrApi(
        client: MockClient((r) async => r.url.path == '/api/core/version/'
            ? _json({'version': '0.34.1'})
            : _json({'detail': 'No active account'}, 401)));
    await _open(tester);
    await _signIn(tester);
    expect(find.text('Wrong user name or password.'), findsOneWidget);
    expect(Dispatcharr.instance.login.value, isNull);
  });

  testWidgets("Sources in the player: Only Dispatcharr's is saved",
      (tester) async {
    // AMD (2026-11-18): only the streams he assigned in Dispatcharr.
    Dispatcharr.instance.api = _api();
    final playlists = await _open(tester);
    // Already has its playlist, so Connect stays on this page.
    playlists.entries.add(PlaylistProfile(
        id: 'd',
        name: 'Home Dispatcharr',
        mode: 'xtream',
        xtreamServer: _server,
        xtreamUsername: 'amd',
        xtreamPassword: 'xc1',
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await _signIn(tester);
    expect(Dispatcharr.instance.sources, DispatcharrSources.first);
    expect(find.text("Dispatcharr's first"), findsOneWidget);
    await tester.tap(find.text('Sources in the player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Only Dispatcharr's"));
    await tester.pumpAndSettle();
    expect(Dispatcharr.instance.sources, DispatcharrSources.only);
    expect(find.text("Only Dispatcharr's"), findsOneWidget);
    await Dispatcharr.instance.setSources(DispatcharrSources.first);
  });

  test("Sources rows: first, only and VesperTV's order", () {
    // (name, playing now)
    const app = [('channel', false), ('HD copy', false), ('other list', true)];
    const streams = [('Primary', false), ('Secondary', false)];
    List<String> names(DispatcharrSources m) => [
          for (final r
              in arrangeDispatcharrSources(m, app, streams, (r) => r.$2))
            r.$1
        ];
    expect(names(DispatcharrSources.first),
        ['channel', 'Primary', 'Secondary', 'HD copy', 'other list']);
    // The app's rows go, except the one playing now.
    expect(names(DispatcharrSources.only),
        ['channel', 'Primary', 'Secondary', 'other list']);
    expect(
        names(DispatcharrSources.vesper), ['channel', 'HD copy', 'other list']);
    expect(DispatcharrSources.parse(''), DispatcharrSources.first);
    expect(DispatcharrSources.parse('only'), DispatcharrSources.only);
  });

  testWidgets('the drawer shows a Dispatcharr stream with what it measured',
      (tester) async {
    Channel ch(String url, String name) => Channel(
        id: 'p::1',
        rawId: '1',
        playlistId: 'p',
        name: name,
        group: 'News',
        url: url);
    int? picked = -2;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async =>
                    picked = await showLiveSourceDrawer(context, entries: [
                      LiveSourceEntry(
                          channel: ch('$_server/live/a/b/1.ts', 'France 24'),
                          playlist: 'Dispatcharr',
                          current: true),
                      LiveSourceEntry(
                          channel: ch('$_server/proxy/ts/stream/abc',
                              'CBC News Network (1080p)'),
                          playlist: 'Dispatcharr · Public CA',
                          current: false,
                          quality: '1080p · H.264 · 30 fps'),
                    ]),
                child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('CBC News Network (1080p)'), findsOneWidget);
    expect(find.text('Dispatcharr · Public CA · 1080p · H.264 · 30 fps'),
        findsOneWidget);
    await tester.tap(find.text('CBC News Network (1080p)'));
    await tester.pumpAndSettle();
    expect(picked, 1);
  });
}
