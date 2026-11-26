import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/hub_collection.dart';
import 'package:nox_iptv/screens/archive_catalog_screen.dart';
import 'package:nox_iptv/screens/hub_folder_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/card_trailer.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Owner, 2026-11-26: "Can we add it to collections and expand
/// collection": a collection's page plays the trailer in its wide card;
/// Expand collection in the focused 16:9 card with Wide cards on (owner's
/// pick: "Inside the focused card"), a poster grid plays none.
const _source = ArchiveSource(
  manifestUrl: 'https://aio.example/manifest.json',
  name: 'AIOMetadata',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'nf.movies', name: 'Netflix'),
  ],
);

const _folder = HubFolder(id: 'netflix', title: 'Netflix', sources: []);

class _Folder extends ArchiveService {
  _Folder(super.storage);
  final row = ArchiveRow(
      source: _source,
      catalog: const ArchiveCatalog(
          type: ArchiveType.movie, id: 'nf.movies', name: 'Netflix'),
      items: [
        for (var i = 0; i < 8; i++)
          ArchiveMeta(
              id: 'tt20$i',
              type: ArchiveType.movie,
              name: 'Title $i',
              backgroundUrl: 'https://img.test/$i',
              year: '2026')
      ]);
  @override
  List<ArchiveSource> get enabledSources => [_source];
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  Future<void> open() async {}
  @override
  List<ArchiveRow> folderRows(HubFolder folder) => [row];
  @override
  bool folderLoading(HubFolder folder) => false;
  @override
  List<(ArchiveSource, ArchiveCatalog)> folderCatalogs(HubFolder folder) =>
      [(_source, row.catalog)];
  @override
  Future<void> loadFolder(HubFolder folder) async {}
  @override
  bool isFavorite(ArchiveSource source, ArchiveMeta meta) => false;
  @override
  Future<void> loadMore(ArchiveRow row, {bool notify = true}) async {}
}

class _Video extends VideoPlayerPlatform {
  final created = <String>[];
  final calls = <String>[];
  final events = StreamController<VideoEvent>.broadcast(sync: true);
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options.dataSource.uri!);
    return created.length;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume:$volume');
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const SizedBox.expand();
}

Uri _file(String id) =>
    Uri.parse('https://rr1.googlevideo.com/videoplayback?itag=18&id=$id');

Future<_Folder> _open(WidgetTester tester, Widget page,
    {required bool cardTrailers, bool wideCards = false}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  await storage.setCardTrailers(cardTrailers);
  final prefs = AppPreferences(storage);
  await prefs.init();
  prefs.isTelevision = true;
  if (wideCards) prefs.setWideCards(true);
  addTearDown(prefs.dispose);
  final service = _Folder(storage);
  await tester.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<ArchiveService>.value(value: service),
    Provider<StorageService>.value(value: storage),
    ChangeNotifierProvider<AppPreferences>.value(value: prefs),
  ], child: MaterialApp(theme: ThemeData.dark(), home: page)));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return service;
}

/// The focused card (a grid's cards have no focus node of their own).
PosterCard? _focusedCard(WidgetTester tester) =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<PosterCard>();

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

Future<void> _initialize(WidgetTester tester, _Video video) async {
  video.events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 2),
      size: const Size(640, 360)));
  await tester.pump();
  await tester.pump();
}

Future<void> _close(WidgetTester tester, _Video video, _Folder service) async {
  await tester.pumpWidget(const SizedBox());
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  // The backdrops' cache tidies up after 10 s.
  await tester.pump(const Duration(seconds: 11));
  await video.events.close();
  service.dispose();
}

void main() {
  late _Video video;
  final asked = <String>[];
  setUp(() {
    asked.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
    final previous = VideoPlayerPlatform.instance;
    video = _Video();
    VideoPlayerPlatform.instance = video;
    CardTrailer.debugFind = (meta) async {
      asked.add(meta.id);
      return _file(meta.id);
    };
    addTearDown(() {
      VideoPlayerPlatform.instance = previous;
      CardTrailer.debugFind = null;
    });
  });

  group("a collection's page", () {
    testWidgets('the card widens at 0.5 s and plays its trailer at 1 s',
        (tester) async {
      final service = await _open(
          tester, const HubFolderScreen(folder: _folder, collection: 'TV'),
          cardTrailers: true);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedCard(tester)?.title, 'Title 1');
      await tester.pump(const Duration(milliseconds: 350));
      expect(asked, ['tt201']);
      expect(_focusedCard(tester)?.wideWidth, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(_focusedCard(tester)?.wideWidth, isNotNull);
      expect(find.byType(CardTrailer), findsNothing,
          reason: 'the player waits for 1 s on the card');
      await tester.pump(const Duration(milliseconds: 460));
      await tester.pump();
      expect(tester.widget<CardTrailer>(find.byType(CardTrailer)).uri,
          _file('tt201'));
      await tester.pump();
      expect(video.created, [_file('tt201').toString()]);
      await _initialize(tester, video);
      expect(video.calls, containsAllInOrder(['volume:1.0', 'play']));

      // Moving on stops it and shrinks the card.
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(find.byType(CardTrailer), findsNothing);
      expect(
          tester
              .widgetList<PosterCard>(find.byType(PosterCard))
              .where((c) => c.wideWidth != null),
          isEmpty);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      expect(video.calls, contains('dispose'));
      await _close(tester, video, service);
    });

    testWidgets('switch off: the usual 2 s widening, no trailer',
        (tester) async {
      final service = await _open(
          tester, const HubFolderScreen(folder: _folder, collection: 'TV'),
          cardTrailers: false);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(_focusedCard(tester)?.wideWidth, isNull);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(_focusedCard(tester)?.wideWidth, isNotNull);
      expect(_focusedCard(tester)?.wideVideo, isNull);
      expect(asked, isEmpty);
      expect(video.created, isEmpty);
      await _close(tester, video, service);
    });

    testWidgets('a title page over it stops the trailer', (tester) async {
      final service = await _open(
          tester, const HubFolderScreen(folder: _folder, collection: 'TV'),
          cardTrailers: true);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(find.byType(CardTrailer), findsOneWidget);
      Navigator.of(tester.element(find.byType(HubFolderScreen))).push(
          MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                  body: Focus(autofocus: true, child: SizedBox()))));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CardTrailer, skipOffstage: false), findsNothing,
          reason: 'the page under it stays built: its player must close');
      await _close(tester, video, service);
    });
  });

  group('Expand collection', () {
    testWidgets('Wide cards: the focused card plays its trailer',
        (tester) async {
      final service = await _open(
          tester, ArchiveCatalogScreen.folder(folder: _folder),
          cardTrailers: true, wideCards: true);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      final card = _focusedCard(tester);
      expect(card?.title, 'Title 1');
      expect(card?.wideStyle, isTrue);
      await tester.pump(const Duration(milliseconds: 350));
      expect(asked, ['tt201']);
      expect(find.byType(CardTrailer), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(tester.widget<CardTrailer>(find.byType(CardTrailer)).uri,
          _file('tt201'));
      await tester.pump();
      expect(video.created, [_file('tt201').toString()]);
      await _initialize(tester, video);
      expect(video.calls, containsAllInOrder(['volume:1.0', 'play']));

      // The next card: this one stops, that one starts after its 1 s.
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(find.byType(CardTrailer), findsNothing);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(tester.widget<CardTrailer>(find.byType(CardTrailer)).uri,
          _file('tt202'));

      // Up to the buttons: it stops.
      for (var i = 0; i < 2; i++) {
        await _key(tester, LogicalKeyboardKey.arrowUp);
      }
      expect(find.byType(CardTrailer), findsNothing);
      await _close(tester, video, service);
    });

    testWidgets('a poster grid plays none', (tester) async {
      final service = await _open(
          tester, ArchiveCatalogScreen.folder(folder: _folder),
          cardTrailers: true);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedCard(tester)?.wideStyle, isFalse);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(asked, isEmpty);
      expect(find.byType(CardTrailer), findsNothing);
      expect(video.created, isEmpty);
      await _close(tester, video, service);
    });
  });
}
