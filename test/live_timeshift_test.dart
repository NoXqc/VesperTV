import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/live_timeshift.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/utils/scrub_steps.dart';
import 'package:nox_iptv/utils/skip_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catchup_back_to_now_test.dart' show CuStorage, CuPlaylist, FakePlayer;

/// Live pause & rewind (owner + cillfog, Discord 2026-11-25): the native
/// player keeps a rolling copy of a live channel on its one connection;
/// Pause keeps it, the skip buttons jump in it. And the Skip buttons
/// setting (-15/+15, -30/+30) for every skip.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 11, 25, 20, 0, 0);
  final plain = Channel(
      id: 'p::plain',
      rawId: 'plain',
      playlistId: 'p',
      name: 'Plain',
      group: 'News',
      url: 'http://host:80/live/u/pw/12.ts');
  final withCatchup = Channel(
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

  late PlaybackService playback;
  late CuPlaylist playlist;
  late List<String> log;
  late List<FakePlayer> players;
  late DateTime clockNow;
  late Map<String, Object?> nativeState;
  late bool nativeOn;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = CuStorage();
    await storage.init();
    playlist = CuPlaylist(storage);
    log = [];
    players = [];
    clockNow = now;
    nativeOn = true;
    nativeState = {
      'on': true,
      'behindMs': 1500,
      'availableMs': 600000,
      'windowMs': 1800000,
    };
    LiveTimeshift.minutes = 30;
    SkipStep.seconds = 10;
    playback = PlaybackService(storage, playlist)
      ..clock = (() => clockNow)
      ..createController = (url, {closedCaptionFile, httpHeaders = const {}}) {
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
      switch (call.method) {
        case 'setTimeshift':
          return {
            'on': nativeOn,
            if (!nativeOn) 'reason': 'not a single stream (HLS)'
          };
        case 'timeshiftState':
          return nativeState;
        case 'timeshiftJump':
          final delta = (call.arguments as Map)['deltaMs'] as int;
          final behind = (nativeState['behindMs'] as int) - delta;
          return {
            ...nativeState,
            'behindMs': behind < 0 ? 0 : behind,
          };
      }
      return null;
    });
  });

  tearDown(() {
    playback.dispose();
    playlist.dispose();
    SkipStep.seconds = 10;
  });

  void tsTest(String name, Future<void> Function(WidgetTester) body) =>
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

  List<String> calls(String method) =>
      log.where((l) => l.startsWith('$method ')).toList();

  tsTest('a live channel arms the copy with the setting\'s minutes',
      (tester) async {
    await playback.play(plain);
    await settle(tester);
    expect(calls('setTimeshift'),
        ['setTimeshift {playerId: 7, on: true, minutes: 30}']);
    await tester.pump(const Duration(seconds: 1));
    expect(playback.timeshift.value?.on, isTrue);
    expect(playback.timeshift.value?.available, const Duration(minutes: 10));
  });

  tsTest('off in Settings: never asked, nothing shown', (tester) async {
    LiveTimeshift.minutes = 0;
    await playback.play(plain);
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(calls('setTimeshift'), isEmpty);
    expect(playback.timeshift.value, isNull);
  });

  tsTest('an HLS channel (native says no): nothing shown', (tester) async {
    nativeOn = false;
    await playback.play(plain);
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(calls('timeshiftState'), isEmpty);
    expect(playback.timeshift.value, isNull);
  });

  tsTest('catch-up never arms it', (tester) async {
    await playback.playCatchup(
        withCatchup, now.subtract(const Duration(hours: 1)));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(calls('setTimeshift'), isEmpty);
    expect(playback.timeshift.value, isNull);
  });

  tsTest('a long pause on a catch-up channel resumes from the copy',
      (tester) async {
    await playback.play(withCatchup);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    final player = players.last;
    await playback.togglePlayPause();
    expect(player.value.isPlaying, isFalse);
    // 7 minutes: catch-up before; the copy keeps 30.
    clockNow = now.add(const Duration(minutes: 7));
    await playback.togglePlayPause();
    await settle(tester);
    expect(players.last, same(player));
    expect(player.value.isPlaying, isTrue);
    expect(playback.catchup, isNull);
  });

  tsTest('a pause longer than the copy goes to catch-up as before',
      (tester) async {
    await playback.play(withCatchup);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await playback.togglePlayPause();
    clockNow = now.add(const Duration(minutes: 45));
    await playback.togglePlayPause();
    await settle(tester);
    expect(playback.catchup, isNotNull);
  });

  tsTest('skip presses gather into one jump', (tester) async {
    await playback.play(plain);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    playback.timeshiftNudge(const Duration(seconds: -15));
    await tester.pump(const Duration(milliseconds: 200));
    playback.timeshiftNudge(const Duration(seconds: -15));
    await tester.pump(const Duration(milliseconds: 200));
    // Where it will land: 1.5 s behind now + 30 s.
    expect(playback.timeshiftTarget.value, const Duration(milliseconds: 31500));
    expect(calls('timeshiftJump'), isEmpty);
    await tester.pump(const Duration(milliseconds: 800));
    expect(calls('timeshiftJump'),
        ['timeshiftJump {playerId: 7, deltaMs: -30000}']);
    expect(playback.timeshiftTarget.value, isNull);
    expect(
        playback.timeshift.value?.behind, const Duration(milliseconds: 31500));
  });

  tsTest('never further back than the copy on a channel without catch-up',
      (tester) async {
    await playback.play(plain);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    playback.timeshiftNudge(const Duration(minutes: -20));
    expect(playback.timeshiftTarget.value, const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(calls('timeshiftJump').single, contains('deltaMs: -598500'));
  });

  tsTest('past the copy on a catch-up channel: catch-up from then',
      (tester) async {
    await playback.play(withCatchup);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    playback.timeshiftNudge(const Duration(minutes: -20));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(calls('timeshiftJump'), isEmpty);
    final s = playback.catchup!;
    expect(s.live.id, withCatchup.id);
    expect(s.playhead(s.startOffset),
        now.subtract(const Duration(minutes: 20, milliseconds: 1500)));
  });

  tsTest('ahead to now = live, and LIVE jumps there', (tester) async {
    await playback.play(plain);
    await settle(tester);
    nativeState = {...nativeState, 'behindMs': 40000};
    await tester.pump(const Duration(seconds: 1));
    playback.timeshiftNudge(const Duration(seconds: 60));
    expect(playback.timeshiftTarget.value, Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    expect(calls('timeshiftJump').single, contains('deltaMs: 86400000'));
    log.clear();
    nativeState = {...nativeState, 'behindMs': 40000};
    await tester.pump(const Duration(seconds: 1));
    await playback.timeshiftToLive();
    expect(calls('timeshiftJump').single, contains('deltaMs: 86400000'));
  });

  test('state from the native map, labels', () {
    final s = TimeshiftState.fromMap(const {
      'on': true,
      'behindMs': 83000,
      'availableMs': 1200000,
      'memory': true
    });
    expect(s.behind, const Duration(seconds: 83));
    expect(s.atLive, isFalse);
    expect(s.memoryOnly, isTrue);
    expect(TimeshiftState.fromMap(const {'on': true, 'behindMs': 2500}).atLive,
        isTrue);
    expect(LiveTimeshift.behindLabel(const Duration(seconds: 83)), '−1:23');
    expect(LiveTimeshift.behindLabel(const Duration(minutes: 61, seconds: 5)),
        '−1:01:05');
  });

  group('Skip buttons setting', () {
    test('a tap is the setting; holding never moves less', () {
      var t = DateTime(2026, 11, 25);
      SkipStep.seconds = 30;
      final steps = ScrubSteps(clock: () => t);
      expect(steps.next(repeat: false), const Duration(seconds: 30));
      t = t.add(const Duration(milliseconds: 300));
      expect(steps.next(repeat: true), const Duration(seconds: 30));
      t = t.add(const Duration(milliseconds: 1500));
      expect(steps.next(repeat: true), const Duration(seconds: 30));
      t = t.add(const Duration(milliseconds: 1500));
      expect(steps.next(repeat: true), const Duration(seconds: 60));
      SkipStep.seconds = 15;
      steps.reset();
      t = t.add(const Duration(seconds: 5));
      expect(steps.next(repeat: false), const Duration(seconds: 15));
    });

    test('only the offered values; Material icons where they exist', () {
      SkipStep.seconds = 7;
      expect(SkipStep.seconds, 10);
      expect(SkipStep.builtinIcon(forward: false), Icons.replay_10);
      SkipStep.seconds = 30;
      expect(SkipStep.builtinIcon(forward: true), Icons.forward_30);
      SkipStep.seconds = 15;
      expect(SkipStep.builtinIcon(forward: true), isNull);
    });

    testWidgets('15 s draws its number in the round arrow', (tester) async {
      SkipStep.seconds = 15;
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: SkipIcon(forward: false, size: 28))));
      expect(find.text('15'), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsOneWidget);
    });
  });
}
