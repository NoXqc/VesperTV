import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/youtube_embed.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/trailer_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/detail_trailer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:nox_iptv/widgets/detail_header.dart';

const _request = TrailerRequest(title: 'Film', series: false);
final _url = Uri.parse('https://www.youtube.com/watch?v=AbCdEfGhI12');

class _Harness {
  final key = GlobalKey<DetailTrailerState>();
  final navigator = GlobalKey<NavigatorState>();
  final scripts = <String>[];
  final documents = <YouTubeEmbedDocument>[];
  final pending = <Completer<Uri?>>[];
  void Function(Object?)? event;
  int lookups = 0;
  Widget child = const Center(key: ValueKey('details'), child: Text('Details'));
  bool deferred = false;
  Uri? result = _url;
  Future<void> Function(String)? execute;

  Widget page({bool enabled = true, TrailerRequest request = _request}) =>
      MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [appRouteObserver],
          home: Scaffold(
              body: DetailTrailer(
            key: key,
            enabled: enabled,
            request: request,
            resolve: (request, sources) {
              lookups++;
              if (!deferred) return Future.value(this.result);
              final result = Completer<Uri?>();
              pending.add(result);
              return result.future;
            },
            youtubeBuilder: (document, controller, callback) {
              if (!documents.contains(document)) documents.add(document);
              event = callback;
              controller((script) async {
                scripts.add(script);
                await execute?.call(script);
              });
              return const ColoredBox(
                  key: ValueKey('preview'), color: Colors.blue);
            },
            child: child,
          )));
}

class _FakeVideo extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast(sync: true);
  final calls = <String>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {
    calls.add('volume:$volume');
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const SizedBox.expand();
}

void main() {
  testWidgets(
      'backdrop fade keeps Play focus and returns to artwork at trailer end',
      (tester) async {
    final node = FocusNode();
    var pressed = 0;
    final h = _Harness()
      ..child = Center(
          child: TextButton(
              autofocus: true,
              focusNode: node,
              onPressed: () => pressed++,
              child: const Text('Play')));
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    h.event!({'type': 'playing'});
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    expect(
        tester
            .widget<DetailTrailerBackdrop>(find.byType(DetailTrailerBackdrop))
            .progress,
        1);
    await tester.tap(find.text('Play'));
    expect(pressed, 1);
    h.event!({'type': 'ended'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final fading = tester
        .widget<DetailTrailerBackdrop>(find.byType(DetailTrailerBackdrop))
        .progress;
    expect(fading, greaterThan(0));
    expect(fading, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview')), findsNothing);
    expect(
        tester
            .widget<DetailTrailerBackdrop>(find.byType(DetailTrailerBackdrop))
            .progress,
        0);
    expect(node.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    node.dispose();
  });

  testWidgets('dialogs pause and dismissing restores the preview',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    unawaited(showDialog<void>(
        context: h.key.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Choose'))));
    await tester.pumpAndSettle();
    expect(h.scripts, contains('window.vesperPause();'));
    expect(find.byKey(const ValueKey('preview'), skipOffstage: false),
        findsNothing);
    h.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(h.lookups, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('automatic trailers default off and the opt-in survives reload',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    expect(prefs.autoTrailers, isFalse);
    prefs.setAutoTrailers(true);
    final restored = StorageService();
    await restored.init();
    expect(restored.getAutoTrailers(), isTrue);
    prefs.setAutoTrailers(false);
    expect(storage.getAutoTrailers(), isFalse);
    prefs.dispose();
  });

  test('automatic embed mutes before starting; manual embed stays unchanged',
      () {
    final doc = YouTubeEmbedDocument('AbCdEfGhI12', muted: true);
    expect(doc.html.indexOf('player.mute();'),
        lessThan(doc.html.indexOf('player.playVideo();')));
    expect(doc.html, contains("type:'ended'"));
    expect(YouTubeEmbedDocument('AbCdEfGhI12').html,
        isNot(contains('player.mute();')));
  });

  testWidgets('disabled adds no lookup or player', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page(enabled: false));
    await tester.pumpAndSettle();
    expect(h.lookups, 0);
    expect(find.byKey(const ValueKey('preview')), findsNothing);
    expect(find.text('Details'), findsOneWidget);
  });

  for (final size in [const Size(1000, 600), const Size(400, 800)]) {
    testWidgets('trailer fills the backdrop without moving details at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _Harness();
      await tester.pumpWidget(h.page());
      await tester.pumpAndSettle();
      final preview = tester.getRect(find.byKey(const ValueKey('preview')));
      final details = tester.getRect(find.byKey(const ValueKey('details')));
      expect(preview.size, size);
      expect(preview.overlaps(details), isTrue);
      expect(details.size, size);
      // The video platform view stays fully painted, including while loading.
      expect(
          find.ancestor(
              of: find.byKey(const ValueKey('preview')),
              matching: find.byType(Opacity)),
          findsNothing);
      double coverAlpha() => tester
          .widget<ColoredBox>(
              find.byKey(const ValueKey('detail-trailer-cover')))
          .color
          .a;
      expect(coverAlpha(), 1);
      expect(h.documents.single.muted, isFalse);
      expect(h.documents.single.html,
          contains('player.unMute();player.setVolume(100);'));
      h.event!({'type': 'playing'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(coverAlpha(), greaterThan(0));
      expect(coverAlpha(), lessThan(1));
      await tester.pumpAndSettle();
      expect(coverAlpha(), 0);
      expect(tester.getRect(find.byKey(const ValueKey('details'))), details);
      expect(h.documents.single.controls, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(h.scripts, contains('window.vesperPause();'));
    });
  }

  testWidgets('Play cancels a late lookup without opening a player',
      (tester) async {
    final h = _Harness()..deferred = true;
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    await h.key.currentState!.stop();
    h.pending.single.complete(_url);
    await tester.pumpAndSettle();
    expect(h.documents, isEmpty);
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    expect(h.lookups,
        1); // metadata/progress rebuild does not restart a stopped preview
  });

  testWidgets('stop awaits the embedded pause before main playback can start',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    final paused = Completer<void>();
    h.execute = (_) => paused.future;
    var stopped = false;
    final stopping = h.key.currentState!.stop().then((_) => stopped = true);
    await tester.pump();
    expect(h.scripts, ['window.vesperPause();']);
    expect(stopped, isFalse);
    paused.complete();
    await stopping;
    await tester.pumpAndSettle();
    expect(stopped, isTrue);
    expect(find.byKey(const ValueKey('preview')), findsNothing);
  });

  for (final type in ['ended', 'error']) {
    testWidgets('$type returns to artwork without replay or external launch',
        (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.page());
      await tester.pumpAndSettle();
      h.event!({'type': type, 'code': 150});
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview')), findsNothing);
      expect(find.text('Details'), findsOneWidget);
      await tester.pumpWidget(h.page());
      await tester.pumpAndSettle();
      expect(h.lookups, 1);
    });
  }

  testWidgets('covering the route stops playback; returning can preview again',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other page')))));
    await tester.pumpAndSettle();
    expect(h.scripts, contains('window.vesperPause();'));
    expect(find.byKey(const ValueKey('preview'), skipOffstage: false),
        findsNothing);
    h.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(h.lookups, 2);
    expect(find.byKey(const ValueKey('preview')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'backgrounding destroys the preview, resumed rechecks the setting',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(h.scripts, contains('window.vesperPause();'));
    expect(find.byKey(const ValueKey('preview')), findsNothing);
    await tester.pumpWidget(h.page(enabled: false));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.lookups, 1);
  });

  testWidgets('new metadata invalidates the old in-flight trailer',
      (tester) async {
    final h = _Harness()..deferred = true;
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
        h.page(request: const TrailerRequest(title: 'Show', series: true)));
    await tester.pumpAndSettle();
    h.pending[0].complete(_url);
    await tester.pumpAndSettle();
    expect(h.documents, isEmpty);
    h.pending[1].complete(_url);
    await tester.pumpAndSettle();
    expect(h.documents, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('autoplay that never starts times out back to the static details',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview')), findsNothing);
    expect(h.lookups, 1);
  });
  testWidgets('no trailer leaves details unchanged', (tester) async {
    final h = _Harness()..result = null;
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    expect(h.documents, isEmpty);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets(
      'metadata refresh replaces an active session even for the same URL',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    await tester.pumpWidget(h.page(
        request:
            const TrailerRequest(title: 'Film', series: false, year: 2026)));
    await tester.pumpAndSettle();
    expect(h.documents, hasLength(2));
    expect(h.scripts, contains('window.vesperPause();'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'direct trailer has sound and releases its independent player on stop',
      (tester) async {
    final previous = VideoPlayerPlatform.instance;
    final video = _FakeVideo();
    VideoPlayerPlatform.instance = video;
    addTearDown(() {
      VideoPlayerPlatform.instance = previous;
    });
    final h = _Harness()..result = Uri.parse('https://example.com/trailer.mp4');
    await tester.pumpWidget(h.page());
    await tester.pumpAndSettle();
    video.events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 2),
        size: const Size(1280, 720)));
    await tester.pumpAndSettle();
    expect(video.calls, contains('play'));
    expect(video.calls, isNot(contains('volume:0.0')));
    expect(video.calls.lastIndexOf('volume:1.0'),
        lessThan(video.calls.indexOf('play')));
    expect(
        tester
            .widget<DetailTrailerBackdrop>(find.byType(DetailTrailerBackdrop))
            .playing,
        isTrue);
    var stopped = false;
    unawaited(h.key.currentState!.stop().then((_) => stopped = true));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    // Stream cancellation completes in the root zone; let it drain before
    // checking the fake controller disposal from the widget-test zone.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(stopped, isTrue);
    expect(video.calls.last, 'dispose');
    expect(
        tester
            .widget<DetailTrailerBackdrop>(find.byType(DetailTrailerBackdrop))
            .playing,
        isFalse);
    expect(
        tester
            .widget<DetailTrailerBackdrop>(find.byType(DetailTrailerBackdrop))
            .progress,
        0);
    await video.events.close();
  });
}
