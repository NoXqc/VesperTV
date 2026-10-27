import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catchup_session.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import 'wide_guide_back_test.dart' show GuidePlaylist;

/// Catch-up playback and Back to now (dev-notes/catchup-plan.md §1).
class CuStorage extends StorageService {
  @override
  Future<void> writeCacheFile(String name, String content) async {}
}

class CuPlaylist extends GuidePlaylist {
  CuPlaylist(super.storage);
  @override
  bool isPlaylistEnabled(String playlistId) => true;
}

/// A player that opens instantly; the test drives its end / errors.
class FakePlayer extends VideoPlayerHdrController {
  FakePlayer(this.url, this.log) : super.networkUrl(Uri.parse(url));
  final String url;
  final List<String> log;
  bool disposed = false;
  Duration? seekedTo;

  @override
  Future<void> initialize(
      {VideoViewType viewType = VideoViewType.textureView}) async {
    value = value.copyWith(
        isInitialized: true,
        duration: const Duration(minutes: 30),
        size: const Size(1920, 1080));
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> seekTo(Duration position) async {
    seekedTo = position;
    value = value.copyWith(position: position);
  }

  @override
  int get textureId => 7;

  @override
  bool isVideoTrackSupportAvailable() => false;

  @override
  bool isAudioTrackSupportAvailable() => false;

  @override
  Future<void> dispose() async {
    log.add('dispose $url');
    disposed = true;
    await super.dispose();
  }

  void finishAt(Duration position) => value =
      value.copyWith(position: position, isPlaying: false, isCompleted: true);

  void failWith(String description) =>
      value = value.copyWith(errorDescription: description, isPlaying: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 27, 20, 0, 30);
  final live = Channel(
    id: 'p::cbc.ca',
    rawId: 'cbc.ca',
    playlistId: 'p',
    name: 'CBC',
    group: 'News',
    url: 'http://host:80/live/u/pw/11.ts',
    catchupDays: 2,
    catchupKind: CatchupKind.xc,
    streamId: '11',
  );
  final plain = Channel(
      id: 'p::plain',
      rawId: 'plain',
      playlistId: 'p',
      name: 'Plain',
      group: 'News',
      url: 'http://host:80/live/u/pw/12.ts');

  late PlaybackService playback;
  late StorageService storageRef;
  late CuPlaylist playlist;
  late List<String> log;
  late List<FakePlayer> players;
  late DateTime clockNow;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = CuStorage();
    await storage.init();
    storageRef = storage;
    playlist = CuPlaylist(storage);
    log = [];
    players = [];
    clockNow = now;
    playback = PlaybackService(storage, playlist)
      ..clock = (() => clockNow)
      ..createController = (url, {closedCaptionFile}) {
        log.add('open $url');
        final p = FakePlayer(url, log);
        players.add(p);
        return p;
      };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]));
    messenger.setMockMethodCallHandler(const MethodChannel('vespertv/stats'),
        (call) async {
      log.add('${call.method} ${call.arguments}');
      return null;
    });
  });

  tearDown(() {
    playback.dispose();
    playlist.dispose();
  });

  /// testWidgets that stops playback and lets the live 4K-tag timers run
  /// out at the end.
  void cuTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await playback.stop();
        await tester.pump(const Duration(seconds: 20));
      });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  cuTest('a past programme plays as finite catch-up from its minute',
      (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    final s = playback.catchup!;
    expect(s.live.id, live.id);
    expect(s.requestStart, DateTime.utc(2026, 10, 27, 18, 30));
    expect(playback.currentChannel!.rawId, startsWith('cu_cbc.ca_'));
    expect(playback.currentChannel!.isLive, isFalse);
    expect(playback.liveChannel!.id, live.id);
    // Up to now: 18:30 -> 20:00:30 = 91 minutes, as HLS.
    expect(players.single.url,
        'http://host/timeshift/u/pw/91/2026-10-27:18-30/11.m3u8');
    expect(log, contains('setFiniteMode {playerId: 7, on: true}'));
    expect(players.single.value.isPlaying, isTrue);
  });

  cuTest('Back to now releases catch-up first, then plays live',
      (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    log.clear();
    await playback.backToLive();
    await settle(tester);
    expect(log.first, startsWith('dispose http://host/timeshift/'));
    expect(log[1], 'open ${live.url}');
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, live.id);
    expect(playback.currentChannel!.isLive, isTrue);
    expect(players.last.value.isPlaying, isTrue);
  });

  cuTest('a time within 90 s of now just plays live', (tester) async {
    await playback.playCatchup(live, now.subtract(const Duration(seconds: 60)));
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, live.id);
    expect(players.single.url, live.url);
  });

  cuTest('a channel without catch-up plays live', (tester) async {
    await playback.playCatchup(plain, DateTime.utc(2026, 10, 27, 18));
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, plain.id);
  });

  cuTest('older than the archive is clamped to its oldest minute',
      (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 20));
    await settle(tester);
    expect(playback.catchup!.requestStart, DateTime.utc(2026, 10, 25, 20, 0));
    expect(players.single.url, contains('/360/2026-10-25:20-00/11.m3u8'));
  });

  cuTest('end of a request carries on from the playhead', (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    // Watched 40 min 20 s of it; the clock moved on too.
    clockNow = now.add(const Duration(minutes: 41));
    players.single.finishAt(const Duration(minutes: 40, seconds: 20));
    await settle(tester);
    final s = playback.catchup!;
    expect(s.requestStart, DateTime.utc(2026, 10, 27, 19, 10));
    expect(s.startOffset, const Duration(seconds: 20));
    expect(players.last.seekedTo, const Duration(seconds: 20));
    expect(players.first.disposed, isTrue);
  });

  cuTest('end of a request at the live edge goes back to now', (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 19, 50));
    await settle(tester);
    // Played 10 min 10 s; now is 20:10:40 -> playhead 20:00:10 is 10 min
    // behind, so it carries on...
    clockNow = now.add(const Duration(minutes: 10, seconds: 10));
    players.last.finishAt(const Duration(minutes: 10, seconds: 10));
    await settle(tester);
    expect(playback.catchup, isNotNull);
    // ...and a request that ends within 90 s of now is caught up.
    clockNow = clockNow.add(const Duration(minutes: 10));
    final s = playback.catchup!;
    final caughtUp = clockNow.subtract(const Duration(seconds: 30));
    players.last.finishAt(caughtUp.difference(s.requestStart));
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, live.id);
  });

  cuTest('an empty request is treated as caught up (no loop)', (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    final opened = players.length;
    players.last.finishAt(const Duration(seconds: 1));
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, live.id);
    expect(players.length, opened + 1);
  });

  cuTest('a 404 shows a message; other errors retry 3 times a minute',
      (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    players.last.failWith('Source error [HTTP 404 Not Found]');
    await settle(tester);
    expect(playback.error, 'This programme is not available in catch-up.');

    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    // Fails 5 min in; each retry asks again from 18:35 (a new request
    // starts at its own position 0).
    players.last.seekTo(const Duration(minutes: 5));
    for (var i = 0; i < 3; i++) {
      players.last
          .failWith('Source error [ERROR_CODE_IO_NETWORK_CONNECTION_FAILED]');
      await settle(tester);
      expect(playback.catchup, isNotNull, reason: 'retry $i');
      expect(
          playback.catchup!.requestStart, DateTime.utc(2026, 10, 27, 18, 35));
    }
    players.last
        .failWith('Source error [ERROR_CODE_IO_NETWORK_CONNECTION_FAILED]');
    await settle(tester);
    expect(playback.error, contains('NETWORK_CONNECTION_FAILED'));
  });

  cuTest('Back to now while a request is still opening wins', (tester) async {
    unawaited(playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30)));
    await playback.backToLive();
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, live.id);
    expect(players.last.url, live.url);
    // Never two players (two provider connections) at once.
    expect(players.where((p) => !p.disposed), [players.last]);
  });

  cuTest('stop clears catch-up; a late request end does nothing',
      (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    final p = players.last;
    await playback.stop();
    await settle(tester);
    expect(p.disposed, isTrue);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel, isNull);
    expect(players.length, 1);
  });

  cuTest('pause on a catch-up channel resumes from the pause', (tester) async {
    await playback.play(live);
    await settle(tester);
    final livePlayer = players.last;
    await playback.togglePlayPause();
    expect(livePlayer.value.isPlaying, isFalse);
    expect(playback.livePausedAt, now);
    // A short pause: the live player's own buffer carries on.
    clockNow = now.add(const Duration(seconds: 40));
    await playback.togglePlayPause();
    await settle(tester);
    expect(players.last, same(livePlayer));
    expect(livePlayer.value.isPlaying, isTrue);
    expect(playback.catchup, isNull);
    // A long one: catch-up from the moment it was paused.
    await playback.togglePlayPause();
    final pausedAt = clockNow;
    clockNow = clockNow.add(const Duration(minutes: 7));
    await playback.togglePlayPause();
    await settle(tester);
    final s = playback.catchup!;
    expect(s.live.id, live.id);
    expect(s.playhead(s.startOffset), pausedAt);
    expect(livePlayer.disposed, isTrue);
    // ...and Back to now from there.
    await playback.backToLive();
    await settle(tester);
    expect(playback.currentChannel!.id, live.id);
    expect(playback.livePausedAt, isNull);
  });

  cuTest('pausing a channel without catch-up stays a plain pause',
      (tester) async {
    await playback.play(plain);
    await settle(tester);
    await playback.togglePlayPause();
    clockNow = now.add(const Duration(minutes: 7));
    await playback.togglePlayPause();
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(players.length, 1);
    expect(players.single.value.isPlaying, isTrue);
  });

  cuTest('the player bar: CATCH-UP tag, behind-live clock, LIVE goes live',
      (tester) async {
    await playback.playCatchup(live, DateTime.utc(2026, 10, 27, 18, 30));
    await settle(tester);
    final prefs = AppPreferences(storageRef);
    final epg = EpgService(storageRef);
    Widget bar() => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prefs),
            ChangeNotifierProvider.value(value: playback),
            ChangeNotifierProvider.value(value: epg),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<PlaybackService>(
                builder: (context, p, _) => PlayerControls(
                  controller: p.controller!,
                  title: p.currentChannel!.name,
                  channelId: p.currentChannel!.epgId,
                  isLive: p.currentChannel!.isLive,
                  channel: p.currentChannel,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(bar());
    await tester.pump();
    expect(find.text('CATCH-UP'), findsOneWidget);
    expect(find.textContaining('behind live'), findsOneWidget);
    expect(find.byTooltip('Previous programme'), findsOneWidget);
    expect(find.byTooltip('Next programme'), findsOneWidget);
    await tester.tap(find.text('LIVE'));
    await settle(tester);
    expect(playback.catchup, isNull);
    expect(playback.currentChannel!.id, live.id);
    await tester.pump();
    expect(find.text('CATCH-UP'), findsNothing);
    expect(find.text('LIVE'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    epg.dispose();
  });

  test('the cu_ channel keeps the live EPG id and stays out of history', () {
    final ch = CatchupSession.channelFor(
        live, DateTime.utc(2026, 10, 27, 18, 30), 'http://x');
    expect(ch.epgId, live.epgId);
    expect(ch.transientPlayback, isTrue);
    expect(ch.isLive, isFalse);
    expect(ch.id,
        'p::cu_cbc.ca_${DateTime.utc(2026, 10, 27, 18, 30).millisecondsSinceEpoch ~/ 1000}');
  });
}
