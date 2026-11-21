import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catchup_back_to_now_test.dart' show CuPlaylist, CuStorage, FakePlayer;

/// AMD (Discord, 2026-11-21, LOG-HZQBLZ): a Dispatcharr stream picked in
/// Sources took 29-42 s to show. The server switch comes down the open
/// connection after the 10-30 s the player buffered ahead, then ExoPlayer
/// stumbled on the splice. The player now reconnects once Dispatcharr
/// starts new viewers on the new stream. The channel is held on the server
/// meanwhile (its shutdown delay is 0 by default: with no viewer for a
/// moment it would restart on its first stream), and the old player goes
/// before the new one starts (one 4K HEVC decoder on the S905X4 boxes).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final channel = Channel(
      id: 'p::sky',
      rawId: 'sky',
      playlistId: 'p',
      name: 'Sky Sports Main Event UHD',
      group: 'Sports',
      url: 'http://dispatcharr:9191/live/u/pw/2.ts');
  final other = Channel(
      id: 'p::bbc',
      rawId: 'bbc',
      playlistId: 'p',
      name: 'BBC News',
      group: 'News',
      url: 'http://dispatcharr:9191/live/u/pw/3.ts');
  const after = Duration(seconds: 7);

  late PlaybackService playback;
  late CuPlaylist playlist;
  late List<String> log;
  late List<FakePlayer> players;
  late DateTime clockNow;
  late bool holdFails;

  Future<Future<void> Function()?> hold(Channel c) async {
    if (holdFails) {
      log.add('hold refused');
      return null;
    }
    log.add('hold ${c.url}');
    return () async => log.add('release');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = CuStorage();
    await storage.init();
    playlist = CuPlaylist(storage);
    log = [];
    players = [];
    clockNow = DateTime.utc(2026, 11, 21, 15, 57, 20);
    holdFails = false;
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
    messenger.setMockMethodCallHandler(
        const MethodChannel('vespertv/stats'), (call) async => null);
  });

  tearDown(() {
    playback.dispose();
    playlist.dispose();
  });

  void switchTest(String name, Future<void> Function(WidgetTester) body) =>
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

  Future<void> playChannel(WidgetTester tester) async {
    await playback.play(channel);
    await settle(tester);
    expect(players, hasLength(1));
    log.clear();
  }

  switchTest('held, the old player closes first, the new one plays, let go',
      (tester) async {
    await playChannel(tester);
    final done = playback.reconnectAfterServerSwitch(after, 'Stream B', hold);
    await tester.pump(const Duration(seconds: 6));
    expect(log, isEmpty, reason: 'not before the delay');

    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await done;
    expect(log, [
      'hold ${channel.url}',
      'dispose ${channel.url}',
      'open ${channel.url}',
      'release',
    ]);
    expect(playback.controller, same(players.last));
    expect(players.last.value.isPlaying, isTrue);
    expect(playback.currentChannel!.id, channel.id);
    expect(playback.error, isNull);
  });

  switchTest('another channel meanwhile: no hold, no reconnect',
      (tester) async {
    await playChannel(tester);
    final done = playback.reconnectAfterServerSwitch(after, 'Stream B', hold);
    await tester.pump(const Duration(seconds: 2));
    await playback.play(other);
    await settle(tester);
    log.clear();
    await tester.pump(const Duration(seconds: 6));
    await done;
    expect(log, isEmpty);
    expect(playback.currentChannel!.id, other.id);
  });

  switchTest('a second pick meanwhile: one reconnect, after the second',
      (tester) async {
    await playChannel(tester);
    final first = playback.reconnectAfterServerSwitch(after, 'Stream B', hold);
    await tester.pump(const Duration(seconds: 4));
    final second = playback.reconnectAfterServerSwitch(after, 'Stream C', hold);
    await tester.pump(const Duration(seconds: 4));
    await first;
    expect(log, isEmpty, reason: 'too early for Stream C');
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    await second;
    expect(log.where((l) => l.startsWith('hold')), hasLength(1));
    expect(log.last, 'release');
  });

  switchTest('paused by the viewer meanwhile: no reconnect', (tester) async {
    await playChannel(tester);
    final done = playback.reconnectAfterServerSwitch(after, 'Stream B', hold);
    await tester.pump(const Duration(seconds: 2));
    clockNow = clockNow.add(const Duration(seconds: 2));
    await playback.togglePlayPause();
    log.clear();
    await tester.pump(const Duration(seconds: 6));
    await done;
    expect(log, isEmpty);
    expect(players, hasLength(1));
  });

  switchTest('the channel cannot be held: the old connection stays',
      (tester) async {
    await playChannel(tester);
    holdFails = true;
    final done = playback.reconnectAfterServerSwitch(after, 'Stream B', hold);
    await tester.pump(const Duration(seconds: 8));
    await done;
    expect(log, ['hold refused']);
    expect(players, hasLength(1));
    expect(players.single.disposed, isFalse);
  });

  switchTest('not playing when picked: nothing', (tester) async {
    await playChannel(tester);
    await players.single.pause();
    final done = playback.reconnectAfterServerSwitch(after, 'Stream B', hold);
    await tester.pump(const Duration(seconds: 8));
    await done;
    expect(log, isEmpty);
  });
}
