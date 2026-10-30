import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/skip_segments.dart';
import 'package:nox_iptv/services/tracker_api.dart';
import 'package:nox_iptv/services/watch_tracker.dart';
import 'package:nox_iptv/widgets/skip_segment_button.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

/// IntroDB's real reply shape (Breaking Bad S1E2, 2026-10-30).
const _reply = {
  'imdb_id': 'tt0903747',
  'is_movie': false,
  'season': 1,
  'episode': 2,
  'intro': {'start_sec': 314.5, 'end_sec': 331, 'confidence': 1},
  'recap': null,
  'outro': {'start_ms': 2843000, 'end_ms': 2901000},
  'post_credits': null,
};

class _FakePlayer extends VideoPlayerHdrController {
  _FakePlayer() : super.networkUrl(Uri.parse('http://x.test/e.mkv'));
  final seeks = <Duration>[];

  void at(Duration position) => value = value.copyWith(
      isInitialized: true,
      duration: const Duration(minutes: 49),
      position: position);

  @override
  Future<void> seekTo(Duration position) async => seeks.add(position);
}

void main() {
  test('parses intro and outro, drops nonsense ranges', () {
    final s = SkipSegments.parse(_reply);
    expect(s.map((x) => x.kind), [SkipKind.intro, SkipKind.outro]);
    expect(s.first.start, const Duration(milliseconds: 314500));
    expect(s.first.end, const Duration(seconds: 331));
    expect(s.last.start, const Duration(seconds: 2843));
    expect(
        SkipSegments.parse({
          'intro': {'start_sec': 10, 'end_sec': 11}, // 1 s: too short
          'recap': {'start_sec': 50, 'end_sec': 20}, // backwards
          'outro': {'start_sec': 0, 'end_sec': 900}, // 15 min: too long
        }),
        isEmpty);
  });

  test('asks IntroDB once per episode, by IMDb id', () async {
    final asked = <Uri>[];
    final source = SkipSegments(client: MockClient((r) async {
      asked.add(r.url);
      return http.Response(jsonEncode(_reply), 200);
    }));
    final a = await source.forEpisode(imdb: 'tt0903747', season: 1, episode: 2);
    await source.forEpisode(imdb: 'tt0903747', season: 1, episode: 2);
    expect(a, hasLength(2));
    expect(asked, hasLength(1));
    expect(asked.single.host, 'api.introdb.app');
    expect(asked.single.queryParameters,
        {'imdb_id': 'tt0903747', 'season': '1', 'episode': '2'});
  });

  test('a TMDB-only show goes through the viewer key; no key = no request',
      () async {
    final asked = <Uri>[];
    final source = SkipSegments(client: MockClient((r) async {
      asked.add(r.url);
      if (r.url.host == 'api.themoviedb.org') {
        return http.Response(jsonEncode({'imdb_id': 'tt0903747'}), 200);
      }
      return http.Response(jsonEncode(_reply), 200);
    }));
    expect(
        await source.forEpisode(tmdb: '1396', season: 1, episode: 2), isEmpty);
    expect(asked, isEmpty);
    final s = await source.forEpisode(
        tmdb: '1396', season: 1, episode: 2, tmdbKey: 'k');
    expect(s, hasLength(2));
    expect(asked.first.path, '/3/tv/1396/external_ids');
  });

  test('an unknown episode or a failure is no button', () async {
    final source = SkipSegments(
        client: MockClient((r) async => http.Response('nope', 500)));
    expect(
        await source.forEpisode(imdb: 'tt1', season: 1, episode: 1), isEmpty);
  });

  group('watcher', () {
    late _FakePlayer player;
    late SkipSegmentWatcher watcher;

    setUp(() {
      player = _FakePlayer();
      watcher = SkipSegmentWatcher(
          source: SkipSegments(
              client: MockClient(
                  (r) async => http.Response(jsonEncode(_reply), 200))));
      WatchTracker.instance.register(
          'ep1', const TrackedItem.episode('tt0903747', season: 1, episode: 2));
    });

    tearDown(() => watcher.dispose());

    Future<void> start() async {
      watcher.attach(player, 'ep1',
          enabled: true, episodeCandidate: true, tmdbKey: null);
      await Future<void>.delayed(Duration.zero);
    }

    test('shows inside the intro only, then skips to its end', () async {
      await start();
      player.at(const Duration(minutes: 1));
      expect(watcher.visibleWith(false), isNull);
      player.at(const Duration(seconds: 320));
      final intro = watcher.visibleWith(false)!;
      expect(intro.kind, SkipKind.intro);
      await watcher.skip(intro);
      expect(player.seeks, [const Duration(seconds: 331)]);
      // Skipped: not offered again while the seek lands.
      player.at(const Duration(seconds: 321));
      expect(watcher.visibleWith(true), isNull);
    });

    test('credits with a next episode play it instead of seeking', () async {
      await start();
      player.at(const Duration(seconds: 2850));
      final outro = watcher.visibleWith(false)!;
      var next = 0;
      await watcher.skip(outro, playNext: () => next++);
      expect(next, 1);
      expect(player.seeks, isEmpty);
    });

    test('off, live or not an episode: nothing is asked', () async {
      watcher.attach(player, 'ep1',
          enabled: false, episodeCandidate: true, tmdbKey: null);
      await Future<void>.delayed(Duration.zero);
      player.at(const Duration(seconds: 320));
      expect(watcher.visibleWith(true), isNull);
    });
  });

  testWidgets('auto-hides after 10 s, returns while the bar shows',
      (tester) async {
    final player = _FakePlayer();
    final watcher = SkipSegmentWatcher(
        source: SkipSegments(
            client: MockClient(
                (r) async => http.Response(jsonEncode(_reply), 200))));
    WatchTracker.instance.register(
        'ep2', const TrackedItem.episode('tt0903747', season: 1, episode: 2));
    await tester.runAsync(() async {
      watcher.attach(player, 'ep2',
          enabled: true, episodeCandidate: true, tmdbKey: null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    player.at(const Duration(seconds: 316));
    Widget app(bool bar) => MaterialApp(
          home: Stack(children: [
            SkipSegmentButton(
                watcher: watcher,
                controlsVisible: bar,
                hasNext: false,
                hint: SkipHint.ok,
                onSkip: (_) {}),
          ]),
        );
    await tester.pumpWidget(app(false));
    expect(find.text('Skip intro'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    await tester.pump(SkipSegmentWatcher.autoHide);
    expect(find.text('Skip intro'), findsNothing);
    await tester.pumpWidget(app(true));
    expect(find.text('Skip intro'), findsOneWidget);
    watcher.dispose();
  });

  testWidgets('focused pill: OK skips, Down goes back to the bar',
      (tester) async {
    final player = _FakePlayer();
    final watcher = SkipSegmentWatcher(
        source: SkipSegments(
            client: MockClient(
                (r) async => http.Response(jsonEncode(_reply), 200))));
    WatchTracker.instance.register(
        'ep3', const TrackedItem.episode('tt0903747', season: 1, episode: 2));
    await tester.runAsync(() async {
      watcher.attach(player, 'ep3',
          enabled: true, episodeCandidate: true, tmdbKey: null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    player.at(const Duration(seconds: 316));
    final node = FocusNode();
    final skipped = <SkipSegment>[];
    var downs = 0;
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        SkipSegmentButton(
            watcher: watcher,
            controlsVisible: true,
            hasNext: false,
            hint: SkipHint.up,
            focusNode: node,
            onDown: () => downs++,
            onSkip: skipped.add),
      ]),
    ));
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    node.requestFocus();
    await tester.pump();
    expect(find.text('OK'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(downs, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(skipped.single.kind, SkipKind.intro);
    node.dispose();
    watcher.dispose();
  });
}
