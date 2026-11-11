import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/screens/hub_folder_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuidePlaylist;

/// Media Hub collections on Home (owner, 2026-11-11: "if a user chose
/// so"): Show on Home puts a collection's tiles in a Home row; OK opens the
/// tile's page; Remove from Home takes the row away.
class _Cache extends ArchiveCache {
  @override
  Future<List<ArchiveMeta>> read(
          String sourceKey, ArchiveCatalog catalog) async =>
      const [];

  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;

  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

final _file = [
  {
    'id': 'streaming',
    'title': '🎬 Streaming',
    'folders': [
      {
        'id': 'netflix',
        'title': 'Netflix',
        'catalogSources': [
          {'addonId': 'aio', 'catalogId': 'nf.movies', 'type': 'movie'},
        ]
      },
      {
        'id': 'disney',
        'title': 'Disney Plus',
        'catalogSources': [
          {'addonId': 'aio', 'catalogId': 'dp.movies', 'type': 'movie'},
        ]
      },
    ]
  },
  {
    'id': 'discover',
    'title': 'Discover',
    'folders': [
      {
        'id': 'popular',
        'title': 'Popular',
        'catalogSources': [
          {'addonId': 'aio', 'catalogId': 'nf.movies', 'type': 'movie'},
        ]
      },
    ]
  },
];

const _aio = ArchiveSource(
  manifestUrl: 'https://aio.example/x/manifest.json',
  name: 'AIOMetadata',
  addonId: 'aio',
  listOnly: true,
  catalogs: [
    ArchiveCatalog(
        type: ArchiveType.movie,
        id: 'nf.movies',
        name: 'Netflix Movies',
        homeHidden: true),
    ArchiveCatalog(
        type: ArchiveType.movie,
        id: 'dp.movies',
        name: 'Disney Movies',
        homeHidden: true),
  ],
);

void main() {
  testWidgets('Show on Home: a tile row on Home, OK opens its page',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    await storage.setArchiveSourcesJson(jsonEncode([_aio.toJson()]));
    // Home with only the Collections row.
    // The Streaming row, then a one-card row under it (New episodes on the
    // box): Left/Right died there after Back (owner, 2026-11-11).
    await storage.setHomeRows([
      HomeRowKind.collections.id,
      HomeRowKind.recentChannels.id,
      for (final kind in HomeRowKind.values)
        if (kind != HomeRowKind.collections &&
            kind != HomeRowKind.recentChannels)
          '-${kind.id}',
    ]);
    final playlist = GuidePlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    final viewers = ViewerProfileService(storage, playlist, playback);
    final epg = EpgService(storage);
    await playback.recordWatched(playlist.live);
    final archive = ArchiveService(storage, cache: _Cache(),
        api: ArchiveApiService(client: MockClient((r) async {
      if (r.url.pathSegments.contains('catalog')) {
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'metas': [
                {'id': 'tt1', 'type': 'movie', 'name': 'A Netflix film'}
              ]
            })),
            200);
      }
      return http.Response.bytes(utf8.encode(jsonEncode(_file)), 200);
    })));
    await archive.importCollections('https://x.example/c.json');
    await archive.setCollectionOnHome('streaming', true);

    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
          ChangeNotifierProvider<EpgService>.value(value: epg),
          ChangeNotifierProvider<ArchiveService>.value(value: archive),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const HomeScreen())),
                        child: const Text('Open Home')))))));
    // Home over the TV page, like the box.
    await tester.tap(find.text('Open Home'));
    await tester.pumpAndSettle();

    expect(find.text('Streaming'), findsWidgets,
        reason: "the row is named after the collection");
    expect(find.text('Netflix'), findsWidgets);

    // The first card has the remote: OK opens the tile's page.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(HubFolderScreen), findsOneWidget);
    expect(find.text('Netflix Movies'), findsOneWidget);
    expect(find.text('A Netflix film'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    // No settling: the box's remote is pressed while Home still reloads.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HubFolderScreen), findsNothing);
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()),
        reason: 'a card has the remote right after Back');
    // Right at once moves along the Streaming row (it did nothing for
    // seconds: the selector's row pointed at the row under it).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Disney Plus'), findsWidgets);
    final hero = tester.widgetList<Text>(find.text('Disney Plus'));
    expect(hero.length, greaterThanOrEqualTo(2),
        reason: 'the card and the hero: Disney Plus has the selector');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    // Back on Home the remote still has a card (owner, 2026-11-11: focus
    // was lost and nothing moved).
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final back = FocusManager.instance.primaryFocus;
    expect(back?.context, isNotNull);
    expect(
        back!.context!.findAncestorWidgetOfExactType<HomeScreen>(), isNotNull,
        reason: 'focus is on Home, not on the closed page');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(HubFolderScreen), findsOneWidget,
        reason: 'OK works again: the remote is on the tile');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Focus left on the page itself (what the box showed): the next key
    // puts it back on the card instead of doing nothing.
    FocusManager.instance.primaryFocus!
        .unfocus(disposition: UnfocusDisposition.scope);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final restored = FocusManager.instance.primaryFocus;
    expect(restored, isNot(isA<FocusScopeNode>()));
    expect(restored!.context!.findAncestorWidgetOfExactType<HomeScreen>(),
        isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(HubFolderScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Remove from Home (Settings or the hold menu): the row goes.
    await archive.setCollectionOnHome('streaming', false);
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    playback.dispose();
    viewers.dispose();
    playlist.dispose();
    prefs.dispose();
    epg.dispose();
    archive.dispose();
  });

  testWidgets(
      'a row gone above while a tile page is open: Left / Right stay in the '
      "tile's row", (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    await storage.setArchiveSourcesJson(jsonEncode([_aio.toJson()]));
    // Recent channels above the collections (Streaming, then Discover).
    await storage.setHomeRows([
      HomeRowKind.recentChannels.id,
      HomeRowKind.collections.id,
      for (final kind in HomeRowKind.values)
        if (kind != HomeRowKind.collections &&
            kind != HomeRowKind.recentChannels)
          '-${kind.id}',
    ]);
    final playlist = GuidePlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    final viewers = ViewerProfileService(storage, playlist, playback);
    final epg = EpgService(storage);
    await playback.recordWatched(playlist.live);
    final archive = ArchiveService(storage, cache: _Cache(),
        api: ArchiveApiService(client: MockClient((r) async {
      final segs = r.url.pathSegments;
      final at = segs.indexOf('catalog');
      if (at >= 0) {
        final id = segs[at + 2].split('.json').first;
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'metas': [
                {'id': 'tt$id', 'type': 'movie', 'name': 'A $id film'}
              ]
            })),
            200);
      }
      return http.Response.bytes(utf8.encode(jsonEncode(_file)), 200);
    })));
    await archive.importCollections('https://x.example/c.json');
    await archive.setCollectionOnHome('streaming', true);
    await archive.setCollectionOnHome('discover', true);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
          ChangeNotifierProvider<EpgService>.value(value: epg),
          ChangeNotifierProvider<ArchiveService>.value(value: archive),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const HomeScreen())),
                        child: const Text('Open Home')))))));
    await tester.tap(find.text('Open Home'));
    await tester.pumpAndSettle();

    // Recent channels, Down = Streaming (Netflix), Right = Disney Plus.
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowRight);
    await press(LogicalKeyboardKey.enter);
    expect(find.text('Disney Movies'), findsOneWidget);
    // While the page is open, the row above goes (Home reloads on Back).
    await playback.removeFromHistory(playlist.live);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HubFolderScreen), findsNothing);

    // Left = Netflix, in the same row (it stayed: Home took the selector
    // for the row under it, the box's photo +726).
    await press(LogicalKeyboardKey.arrowLeft);
    await press(LogicalKeyboardKey.enter);
    expect(find.text('Netflix Movies'), findsOneWidget,
        reason: 'Left moved along the Streaming row');

    await tester.pumpWidget(const SizedBox());
    playback.dispose();
    viewers.dispose();
    playlist.dispose();
    prefs.dispose();
    epg.dispose();
    archive.dispose();
  });
}
