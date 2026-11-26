import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/card_trailer.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Owner, 2026-11-26 (ARVIO's rows): resting on a Media Hub title widens
/// its card and plays the trailer in it, with sound.
const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Card trailers',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'popular', name: 'Popular')
  ],
);

class _Rows extends ArchiveService {
  _Rows(super.storage);
  final entries = [
    ArchiveRow(
        source: _source,
        catalog: const ArchiveCatalog(
            type: ArchiveType.movie, id: 'popular', name: 'Popular'),
        items: [
          for (var i = 0; i < 6; i++)
            ArchiveMeta(
                id: 'tt10$i',
                type: ArchiveType.movie,
                name: 'Title $i',
                backgroundUrl: 'https://img.test/$i',
                year: '2026')
        ]),
  ];
  @override
  List<ArchiveSource> get enabledSources => [_source];
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  Future<void> open() async {}
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) =>
      entries;
  @override
  bool canSearch(ArchiveType type) => false;
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

Future<_Rows> _open(WidgetTester tester, {required bool cardTrailers}) async {
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
  addTearDown(prefs.dispose);
  final service = _Rows(storage);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          theme: ThemeData.dark(),
          home: const ArchiveScreen())));
  await tester.pump();
  await tester.pump();
  return service;
}

PosterCard _focused(WidgetTester tester) =>
    tester.widget<PosterCard>(find.byWidgetPredicate(
        (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false)));

Future<void> _right(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pump();
  await tester.pump();
}

void main() {
  late _Video video;
  final asked = <String>[];
  setUp(() {
    asked.clear();
    // The wide card's backdrop goes through the image cache.
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

  testWidgets('a rested card widens after 0.5 s and plays its trailer',
      (tester) async {
    final service = await _open(tester, cardTrailers: true);
    await _right(tester);
    final title = _focused(tester).title;
    final id =
        service.entries.single.items.firstWhere((m) => m.name == title).id;
    await tester.pump(const Duration(milliseconds: 350));
    expect(asked, [id]);
    expect(_focused(tester).wideWidth, isNull);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(_focused(tester).wideWidth, isNotNull);
    expect(_focused(tester).wideVideo, isNotNull);
    // The player waits for 1 s on the card.
    expect(find.byType(CardTrailer), findsNothing);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    final trailer = tester.widget<CardTrailer>(find.byType(CardTrailer));
    expect(trailer.uri, _file(id));
    await tester.pump();
    expect(video.created, [_file(id).toString()]);
    video.events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 2),
        size: const Size(640, 360)));
    await tester.pump();
    await tester.pump();
    // With sound (owner: "not muted").
    expect(video.calls, containsAllInOrder(['volume:1.0', 'play']));

    // Moving on stops it and shrinks the card.
    await _right(tester);
    await tester.pump();
    expect(find.byType(CardTrailer), findsNothing);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    expect(video.calls, contains('dispose'));
    await tester.pumpWidget(const SizedBox());
    await video.events.close();
    service.dispose();
  });

  testWidgets('switch off: the usual 2 s widening, no lookup, no video',
      (tester) async {
    final service = await _open(tester, cardTrailers: false);
    await _right(tester);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_focused(tester).wideWidth, isNull);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(_focused(tester).wideWidth, isNotNull);
    expect(_focused(tester).wideVideo, isNull);
    expect(asked, isEmpty);
    expect(video.created, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await video.events.close();
    service.dispose();
  });

  testWidgets('stepping at a browsing pace never opens a player',
      (tester) async {
    final service = await _open(tester, cardTrailers: true);
    for (var i = 0; i < 4; i++) {
      await _right(tester);
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(asked, hasLength(4));
    expect(video.created, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(video.created, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await video.events.close();
    service.dispose();
  });

  testWidgets('quick steps across a row look nothing up', (tester) async {
    final service = await _open(tester, cardTrailers: true);
    for (var i = 0; i < 4; i++) {
      await _right(tester);
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(asked, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await video.events.close();
    service.dispose();
  });
}
