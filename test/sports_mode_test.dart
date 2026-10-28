import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_screen.dart';
import 'package:nox_iptv/screens/sports_channels_screen.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/widgets/sports_widgets.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/sports_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/refined_finish.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/utils/tv_theme.dart';
import 'package:nox_iptv/widgets/sports_mode_toggle.dart';

class _Storage extends StorageService {
  @override
  Future<void> writeCacheFile(String name, String content) async {}
}

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [];
}

class _Epg extends EpgService {
  _Epg(super.storage);
  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
          DateTime from, DateTime to, List<String> terms) async =>
      [];
}

class _Playback extends PlaybackService {
  _Playback(super.storage, super.playlist);
  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
    currentChannel = null;
    notifyListeners();
  }
}

const _league = SportsLeague(
    id: 'nhl',
    espnPath: 'hockey/nhl',
    name: 'Hockey',
    shortName: 'NHL',
    logoUrl: '');
SportsGame _game(int index, GameState state) => SportsGame(
      id: 'game$index',
      league: _league,
      start: DateTime.now().add(Duration(minutes: index)),
      state: state,
      statusText: state == GameState.live ? 'Live' : 'Scheduled',
      home: SportsTeam(
          id: 'home$index',
          name: 'Home $index',
          shortName: 'Home $index',
          abbreviation: 'H$index'),
      away: SportsTeam(
          id: 'away$index',
          name: 'Away $index',
          shortName: 'Away $index',
          abbreviation: 'A$index'),
    );

class _Feed extends SportsService {
  _Feed(this.games, {this.gate})
      : super.forTesting(MockClient((_) async => http.Response('{}', 200)));
  final List<SportsGame> games;
  final Completer<void>? gate;
  @override
  Future<List<SportsGame>> gamesForDay(
      List<SportsLeague> leagues, DateTime day) async {
    await gate?.future;
    final now = DateTime.now();
    return day.day == now.day ? games : [];
  }

  @override
  Future<DateTime?> nextGameStart(SportsLeague league, DateTime day) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late AppPreferences prefs;
  late _Playlist playlist;
  late _Playback playback;
  final boundary = GlobalKey();

  setUpAll(() async {
    for (final entry in {
      'Roboto': Platform.environment['SPORTS_MODE_PREVIEW_FONT'],
      'MaterialIcons': Platform.environment['SPORTS_MODE_PREVIEW_ICONS'],
    }.entries) {
      if (entry.value == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(
            ByteData.sublistView(await File(entry.value!).readAsBytes())));
      await loader.load();
    }
  });

  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({
      AppConstants.keySportsMode: true,
      AppConstants.keySportsLeagues: [
        'nhl',
        'nfl',
        'nba',
        'mlb',
        'eng.1',
        'uefa.champions',
        'esp.1'
      ],
    });
    storage = _Storage();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    playlist = _Playlist(storage);
    playback = _Playback(storage, playlist);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    // Sports logos are decorative. Give the cache a real temporary location
    // while Flutter's test HTTP client supplies its normal failed-image reply.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
  });

  tearDown(() {
    playback.dispose();
    playlist.dispose();
    prefs.dispose();
    L10n.code = 'en';
  });

  Future<void> open(WidgetTester tester,
      {List<SportsGame>? games,
      Size size = const Size(960, 540),
      double scale = 1,
      _Feed? feed}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<EpgService>(create: (_) => _Epg(storage)),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<ViewerProfileService>(
              create: (_) => ViewerProfileService(storage, playlist, playback)),
        ],
        child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          theme: RefinedFinish.apply(
              ThemeData(
                  colorScheme:
                      buildPaletteColorScheme(prefs.palette, Brightness.dark)),
              prefs.refinedFinish),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: boundary,
              child: SportsScreen(
                  home: true,
                  service: feed ??
                      _Feed(games ??
                          [
                            _game(100, GameState.live),
                            for (var i = 0; i < 18; i++)
                              _game(i, GameState.pre),
                            _game(200, GameState.post),
                          ]))),
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String? getFocus() => FocusManager.instance.primaryFocus?.debugLabel;
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 31));
  }

  test('Sports Mode is opt-in per viewer and survives reopening', () async {
    expect(prefs.sportsMode, isTrue);
    await storage.setActiveViewerId('other');
    expect(prefs.sportsMode, isFalse);
    await prefs.setSportsMode(true);
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getSportsMode(), isTrue);
    await reopened.setActiveViewerId('main');
    expect(reopened.getSportsMode(), isTrue);
    await storage.setActiveViewerId('main');
    await prefs.setSportsMode(false);
    await storage.setActiveViewerId('other');
    expect(prefs.sportsMode, isTrue);
  });

  for (final backup in [true, false]) {
    test(
        '${backup ? 'backup' : 'transfer'} retains Sports Mode for each viewer',
        () async {
      await storage.setActiveViewerId('other');
      await storage.setSportsMode(false);
      final payload =
          backup ? storage.exportForBackup() : storage.exportForTransfer();
      SharedPreferences.setMockInitialValues({});
      final restored = StorageService();
      await restored.init();
      if (backup) {
        await restored.importForBackup(payload);
      } else {
        await restored.importForTransfer(payload);
      }
      await restored.setActiveViewerId('main');
      expect(restored.getSportsMode(), isTrue);
      await restored.setActiveViewerId('other');
      expect(restored.getSportsMode(), isFalse);
    });
  }

  testWidgets(
      'league move crosses between rail and floating bar without losing focus',
      (tester) async {
    await open(tester, games: []);
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(getFocus(), 'sports-chip-league:eng.1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(storage.getSportsLeagues()![5], 'eng.1');
    expect(getFocus(), 'sports-chip-league:eng.1');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(storage.getSportsLeagues()![4], 'eng.1');
    expect(getFocus(), 'sports-chip-league:eng.1');
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(getFocus(), 'sports-chip-league:mlb');
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets('Networks Back returns to its action in the sports home',
      (tester) async {
    await open(tester, games: []);
    tester
        .widgetList<SportsChip>(find.byType(SportsChip))
        .firstWhere((chip) => chip.label == 'Networks')
        .focusNode
        .requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(SportsChannelsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SportsChannelsScreen), findsNothing);
    expect(getFocus(), 'sports-chip-networks');
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets('Live TV Back returns to sports instead of asking to exit',
      (tester) async {
    await open(tester, games: []);
    for (var i = 0; i < 5; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(getFocus(), 'sports-chip-mode:tv');
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(TvHomeScreen).hitTestable(), findsOneWidget);
    for (var i = 0;
        i < 3 && find.byType(TvHomeScreen).hitTestable().evaluate().isNotEmpty;
        i++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(find.byType(TvHomeScreen), findsNothing);
    expect(find.text('Stay'), findsNothing);
    expect(getFocus(), 'sports-chip-mode:tv');
    if (!Platform.isWindows) expect(playback.stops, greaterThan(0));
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets('five leagues on rail; explicit bar/day/tool arrows and Back',
      (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('sports-mode-rail')), findsOneWidget);
    expect(getFocus(), 'sports-chip-league:nhl');
    final rail = tester.getRect(find.byKey(const ValueKey('sports-mode-rail')));
    expect(rail.width, lessThan(200));
    expect(
        find.byKey(const ValueKey('sports-mode-league:eng.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sports-mode-league:uefa.champions')),
        findsNothing);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-card-nhl:game100');
    // The rail hides while the content has focus; a tab marks the edge.
    expect(find.byKey(const ValueKey('sports-mode-rail')), findsNothing);
    expect(find.byKey(const ValueKey('sports-mode-rail-tab')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowUp); // tools, day menu first
    expect(getFocus(), 'sports-chip-day:menu');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-chip-standings');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-chip-myteams');
    await press(tester, LogicalKeyboardKey.arrowUp); // no day strip
    expect(getFocus(), 'sports-chip-league:all');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-chip-league:uefa.champions');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(getFocus(), 'sports-chip-myteams');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(getFocus(), 'sports-chip-league:nhl');
    expect(find.byKey(const ValueKey('sports-mode-rail')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Stay'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(prefs.sportsMode, isTrue);
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets(
      'long game rows scroll horizontally and vertically and remember selection',
      (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowDown); // first card in next row
    expect(getFocus(), 'sports-card-nhl:game0');
    for (var i = 0; i < 17; i++) {
      await press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(getFocus(), 'sports-card-nhl:game17');
    final selected =
        tester.getRect(find.byKey(const ValueKey('card-nhl:game17')));
    expect(selected.right, lessThanOrEqualTo(970));
    expect(selected.left, greaterThan(170));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(getFocus(), 'sports-card-nhl:game200');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(getFocus(), 'sports-card-nhl:game17');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-card-nhl:game17');
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets('loading and empty days retain working rail and header controls',
      (tester) async {
    final gate = Completer<void>();
    await open(tester, feed: _Feed([], gate: gate));
    expect(getFocus(), 'sports-chip-league:nhl');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(getFocus(), 'sports-chip-league:nfl');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-chip-league:all');
    gate.complete();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(getFocus(), 'sports-chip-day:menu');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(getFocus(), 'sports-chip-day:menu');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-chip-standings');
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets(
      'sidebar scroll reaches Sports Mode; switching off returns to root',
      (tester) async {
    await open(tester, games: []);
    for (var i = 0; i < 20; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(getFocus(), 'sports-chip-mode:toggle');
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(SportsModeToggle), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(prefs.sportsMode, isFalse);
    expect(playback.stops, greaterThan(0));
    expect(Navigator.of(tester.element(find.byType(SportsScreen))).canPop(),
        isFalse);
    await disposePage(tester);
  });

  testWidgets('normal Sports Trak exposes the same Sports Mode switch',
      (tester) async {
    await prefs.setSportsMode(false);
    await open(tester, games: []);
    expect(find.byKey(const ValueKey('sports-mode-rail')), findsNothing);
    tester
        .widgetList<SportsChip>(find.byType(SportsChip))
        .firstWhere((chip) => chip.label == 'Sports Mode')
        .focusNode
        .requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(SportsModeToggle), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(prefs.sportsMode, isTrue);
    expect(find.byKey(const ValueKey('sports-mode-rail'), skipOffstage: false),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets('day menu replaces the day strip and changes the day',
      (tester) async {
    await open(tester, games: []);
    await press(tester, LogicalKeyboardKey.arrowRight); // league:all
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(getFocus(), 'sports-chip-day:menu');
    expect(find.text('Yesterday'), findsNothing);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown); // Today -> Tomorrow
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsNothing);
    expect(
        tester
            .widget<SportsChip>(find.byWidgetPredicate((w) =>
                w is SportsChip &&
                w.focusNode.debugLabel == 'sports-chip-day:menu'))
            .label,
        'Tomorrow');
    expect(getFocus(), 'sports-chip-day:menu');
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  for (final size in [const Size(390, 844), const Size(960, 540)]) {
    testWidgets('game content fits $size with large text', (tester) async {
      L10n.code = 'el';
      await open(tester, size: size, scale: 1.5);
      expect(tester.takeException(), isNull);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(tester.takeException(), isNull);
      await disposePage(tester);
    });
  }

  for (final locale in ['en', 'fr', 'el']) {
    testWidgets('narrow $locale large text keeps all controls reachable',
        (tester) async {
      L10n.code = locale;
      await open(tester, games: [], size: const Size(390, 844), scale: 1.4);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowDown); // day menu
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(getFocus(), 'sports-chip-myteams');
      expect(tester.takeException(), isNull);
      await disposePage(tester);
    });
  }

  testWidgets('dedicated My Teams row has no duplicate card focus nodes',
      (tester) async {
    await storage.setSportsFollowedTeams(['nhl|home0']);
    prefs.setRefinedFinish(true);
    await open(tester, size: const Size(1280, 720));
    if (Platform.environment['SPORTS_MODE_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final view =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
        final image = await view.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('Logs/sports-mode-wide.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    expect(find.byKey(const ValueKey('card-nhl:game0')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(getFocus(), 'sports-card-nhl:game0');
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });
}
