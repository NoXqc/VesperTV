import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/glass_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuideEpg, GuidePlaylist;

class _EntryPlaylist extends GuidePlaylist {
  _EntryPlaylist(super.storage);

  bool emptyFavorites = false;
  final extraFavorites = <Channel>[];
  final favorite = Channel(
      id: 'p::favorite',
      rawId: 'favorite',
      playlistId: 'p',
      name: 'Favourite channel',
      group: 'Favourite origin',
      isFavorite: true,
      url: 'https://example.com/favorite');

  @override
  List<Channel> get channels => [live, favorite, ...extraFavorites];

  @override
  List<M3uGroup> get tvGroups => [
        ...super.tvGroups,
        for (var i = 0; i < 30; i++)
          M3uGroup(
              title: 'Provider group $i', playlistId: 'p', channels: [live]),
      ];

  @override
  List<Channel> get favoriteLiveChannelsWithGroups =>
      emptyFavorites ? [] : [favorite, ...extraFavorites];

  @override
  List<Channel> get favoriteLiveChannels => favoriteLiveChannelsWithGroups;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late AppPreferences prefs;
  late _EntryPlaylist playlist;
  late PlaybackService playback;
  late GuideEpg epg;
  late ViewerProfileService viewers;
  late ArchiveService archive;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    storage = ZapStorage();
    await storage.init();
    await storage
        .setHomeRows([for (final kind in HomeRowKind.values) '-${kind.id}']);
    await storage.setHideProfiles(true);
    prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    playlist = _EntryPlaylist(storage);
    playback = PlaybackService(storage, playlist);
    epg = GuideEpg(storage);
    viewers = ViewerProfileService(storage, playlist, playback);
    archive = ArchiveService(storage);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });

  tearDown(() {
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    prefs.dispose();
    epg.dispose();
    archive.dispose();
  });

  Future<void> open(WidgetTester tester,
      {bool startupHome = false, String initialTab = 'TV'}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<EpgService>.value(value: epg),
          ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
          ChangeNotifierProvider<ArchiveService>.value(value: archive),
        ],
        child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          onGenerateInitialRoutes: startupHome
              ? (_) => [
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            const TvHomeScreen(startupBrowseCovered: true)),
                    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                  ]
              : null,
          routes: {'/': (_) => TvHomeScreen(initialTab: initialTab)},
        )));
    await tester.pumpAndSettle();
  }

  void expectFavorites(WidgetTester tester) {
    final selected = find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_SelectableRow' &&
        (widget as dynamic).label == 'Favourites' &&
        (widget as dynamic).selected == true);
    expect(selected, findsOneWidget);
    if (!playlist.emptyFavorites) {
      expect(find.text('Favourite channel'), findsWidgets);
      if (playback.currentChannel == null) {
        expect(find.text('Test channel'), findsNothing);
      }
    }
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  for (final view in ['live', 'timeline']) {
    for (final state in ['stopped', 'playing', 'pending', 'empty']) {
      testWidgets('fresh TV launch selects Favourites: $view, $state',
          (tester) async {
        prefs.guideViewMode = view;
        if (state == 'playing') playback.currentChannel = playlist.live;
        if (state == 'pending') playback.pendingResumeChannel = playlist.live;
        playlist.emptyFavorites = state == 'empty';
        await open(tester);
        expectFavorites(tester);
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(
            FocusManager.instance.primaryFocus?.debugLabel, 'first-group-row');
        expect(find.text('Favourites').hitTestable(), findsOneWidget);
        await close(tester);
      });
    }

    testWidgets('Home return resets a scrolled group and selector: $view',
        (tester) async {
      prefs.guideViewMode = view;
      await open(tester);
      final farGroup = find.text('Provider group 25');
      final groupScroll = tester.state<ScrollableState>(find.ancestor(
          of: find.text('Favourites'), matching: find.byType(Scrollable)));
      await tester.scrollUntilVisible(farGroup, 350,
          scrollable: find
              .byElementPredicate((element) => element == groupScroll.context));
      Focus.of(tester.element(farGroup)).requestFocus();
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.select);
      if (farGroup.evaluate().isEmpty) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
      }
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectFavorites(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-tab-TV');
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'first-group-row');
      expect(find.text('Favourites').hitTestable(), findsOneWidget);
      await close(tester);
    });
  }

  testWidgets('startup Home returns to Favourites with a pending other channel',
      (tester) async {
    playback.pendingResumeChannel = playlist.live;
    await open(tester, startupHome: true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectFavorites(tester);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'first-group-row');
    await close(tester);
  });

  testWidgets('Home from Movies returns to TV Favourites', (tester) async {
    await open(tester, initialTab: 'Movies');
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectFavorites(tester);
    await close(tester);
  });

  testWidgets('Home return respects hidden Live TV after merging Favourites',
      (tester) async {
    prefs.setHideLiveTv(true);
    await open(tester, initialTab: 'Movies');
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-tab-Movies');
    expect(find.text('TV').hitTestable(), findsNothing);
    final selected = find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_SelectableRow' &&
        (widget as dynamic).label == 'Movies' &&
        (widget as dynamic).selected == true);
    expect(selected, findsOneWidget);
    await close(tester);
  });

  testWidgets('group hold menu is half width and dismissal keeps the group',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Test group'));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('Test group'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassMenuSurface)).width, 280);
    expect(find.text('Add to Favourites').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Test channel'), findsWidgets);
    expect(find.text('Favourite channel'), findsNothing);
    await close(tester);
  });
  Future<void> holdChannel(WidgetTester tester, String name) async {
    final label = find.text(name).first;
    await tester.ensureVisible(label);
    if (prefs.guideViewMode == 'timeline') {
      final row = find.byWidgetPredicate((w) =>
          w.runtimeType.toString() == '_TimelineRow' &&
          (w as dynamic).channel.name == name);
      final focus = find
          .descendant(
              of: row,
              matching: find.byWidgetPredicate((w) =>
                  w is Focus && w.focusNode != null && w.canRequestFocus))
          .first;
      tester.widget<Focus>(focus).focusNode!.requestFocus();
    } else {
      Focus.of(tester.element(label)).requestFocus();
    }
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
  }

  for (final view in ['live', 'timeline']) {
    testWidgets(
        'mixed favourites sort A-Z, Z-A and revert without losing manual order: $view',
        (tester) async {
      prefs.guideViewMode = view;
      prefs.mixFavoritePlaylists = true;
      playlist.extraFavorites.addAll([
        Channel(
            id: 'other::z',
            rawId: 'z',
            playlistId: 'other',
            name: 'Zulu channel',
            group: 'Other',
            url: 'https://example.com/z',
            isFavorite: true),
        Channel(
            id: 'other::a',
            rawId: 'a',
            playlistId: 'other',
            name: 'Alpha channel',
            group: 'Other',
            url: 'https://example.com/a',
            isFavorite: true),
      ]);
      final original = ['other::z', 'other::a', playlist.favorite.id];
      await storage.setFavoriteLiveOrder(original);
      await open(tester);
      for (final (label, expected) in [
        ('Name A–Z', ['other::a', playlist.favorite.id, 'other::z']),
        ('Name Z–A', ['other::z', playlist.favorite.id, 'other::a']),
        ('Revert to original order', original),
      ]) {
        await holdChannel(tester, 'Favourite channel');
        final sort = find.text('Sort favourites');
        await tester.ensureVisible(sort);
        await tester.tap(sort);
        await tester.pumpAndSettle();
        expect(find.text('Revert to original order'), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
            playlist
                .orderedFavoriteLiveChannels(mixPlaylists: true)
                .map((c) => c.id),
            expected);
        expect(storage.getFavoriteLiveOrder(), original);
        final positions = {
          for (final name in [
            'Zulu channel',
            'Alpha channel',
            'Favourite channel'
          ])
            name: tester.getTopLeft(find.text(name).first).dy
        };
        final names = {
          playlist.favorite.id: 'Favourite channel',
          'other::z': 'Zulu channel',
          'other::a': 'Alpha channel'
        };
        expect(positions[names[expected[0]]]!,
            lessThan(positions[names[expected[1]]]!));
        expect(positions[names[expected[1]]]!,
            lessThan(positions[names[expected[2]]]!));
        expect(FocusManager.instance.primaryFocus, isNotNull);
      }
      await close(tester);
    });

    testWidgets('favourites sort is absent with mixing off: $view',
        (tester) async {
      prefs.guideViewMode = view;
      prefs.mixFavoritePlaylists = false;
      await open(tester);
      await holdChannel(tester, 'Favourite channel');
      expect(find.text('Remove from Favourites'), findsOneWidget);
      expect(find.text('Sort favourites'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await close(tester);
    });
  }

  testWidgets('sort is absent in provider groups even when mixing is on',
      (tester) async {
    prefs.guideViewMode = 'live';
    prefs.mixFavoritePlaylists = true;
    await open(tester);
    await tester.tap(find.text('Test group'));
    await tester.pumpAndSettle();
    await holdChannel(tester, 'Test channel');
    expect(find.text('Sort favourites'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await close(tester);
  });

  testWidgets(
      'viewer switch or cancelling sort never overwrites another viewer',
      (tester) async {
    prefs.guideViewMode = 'live';
    prefs.mixFavoritePlaylists = true;
    await open(tester);
    await holdChannel(tester, 'Favourite channel');
    await tester.tap(find.text('Sort favourites'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(storage.getFavoriteLiveSort(), isNull);
    await holdChannel(tester, 'Favourite channel');
    await tester.tap(find.text('Sort favourites'));
    await tester.pumpAndSettle();
    await storage.setActiveViewerId('other');
    await tester.tap(find.text('Name Z–A'));
    await tester.pumpAndSettle();
    expect(storage.getFavoriteLiveSort(), isNull);
    await storage.setActiveViewerId('main');
    expect(storage.getFavoriteLiveSort(), isNull);
    await close(tester);
  });
}
