import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/live_freeze_guard.dart';

void main() {
  late int frames;
  late int height;
  late int buffered;
  late int? bytes;
  late bool playing;
  late bool buffering;
  late String key;
  late bool watched;
  late List<String> actions;
  late DateTime now;
  late LiveFreezeGuard guard;

  setUp(() {
    frames = 0;
    height = 1080;
    buffered = 15000;
    bytes = null;
    playing = true;
    buffering = false;
    key = 'p1|ch1';
    watched = true;
    actions = [];
    now = DateTime(2026, 11, 24, 18);
    guard = LiveFreezeGuard(
      target: () => watched
          ? (player: Object(), key: key, playing: playing, buffering: buffering)
          : null,
      stats: (_) async => {
        'rendered': frames,
        'height': height,
        'bufferedMs': buffered,
        if (bytes != null) 'bytes': bytes,
      },
      nudge: () async => actions.add('nudge'),
      reload: () async => actions.add('reload'),
      clock: () => now,
    );
  });

  /// One poll; [moving] = 25 new frames since the last.
  Future<void> poll({bool moving = false}) async {
    if (moving) frames += 25;
    await guard.tick();
  }

  Future<void> playFor(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await poll(moving: true);
    }
  }

  test('stuck with the sound on: Pause/Play, then one reload', () async {
    await playFor(3);
    await poll();
    await poll();
    expect(actions, isEmpty);
    await poll();
    expect(actions, ['nudge']);
    await poll();
    await poll();
    await poll();
    expect(actions, ['nudge', 'reload']);
    // Still stuck after the reload: nothing more until it moves.
    for (var i = 0; i < 6; i++) {
      await poll();
    }
    expect(actions, ['nudge', 'reload']);
  });

  test('Pause/Play that helps: no reload, and a later freeze starts over',
      () async {
    await playFor(3);
    for (var i = 0; i < 3; i++) {
      await poll();
    }
    expect(actions, ['nudge']);
    await playFor(5);
    for (var i = 0; i < 3; i++) {
      await poll();
    }
    expect(actions, ['nudge', 'nudge']);
  });

  test('never while paused, waiting for data, with little buffered or no video',
      () async {
    await playFor(3);
    playing = false;
    for (var i = 0; i < 5; i++) {
      await poll();
    }
    playing = true;
    buffering = true;
    for (var i = 0; i < 5; i++) {
      await poll();
    }
    buffering = false;
    buffered = 400;
    for (var i = 0; i < 5; i++) {
      await poll();
    }
    buffered = 15000;
    height = 0;
    for (var i = 0; i < 5; i++) {
      await poll();
    }
    watched = false;
    for (var i = 0; i < 5; i++) {
      await poll();
    }
    expect(actions, isEmpty);
  });

  test('not before the channel showed a picture; a new channel starts over',
      () async {
    for (var i = 0; i < 6; i++) {
      await poll();
    }
    expect(actions, isEmpty, reason: 'no frame yet (starting / radio)');
    await playFor(3);
    key = 'p1|ch2';
    for (var i = 0; i < 6; i++) {
      await poll();
    }
    expect(actions, isEmpty, reason: 'the new channel showed nothing yet');
  });

  test('at most two reloads in five minutes', () async {
    Future<void> freeze() async {
      await playFor(2);
      for (var i = 0; i < 6; i++) {
        await poll();
      }
    }

    await freeze();
    await freeze();
    await freeze();
    expect(actions.where((a) => a == 'reload'), hasLength(2));
    expect(actions.where((a) => a == 'nudge'), hasLength(3));
    now = now.add(const Duration(minutes: 6));
    await freeze();
    expect(actions.where((a) => a == 'reload'), hasLength(3));
  });

  test('stuck waiting while data keeps coming: one reload', () async {
    // ESPN News, 110 s behind live: one track silent, the player buffering
    // for good with 0.2 s buffered while the connection delivered.
    bytes = 0;
    await playFor(3);
    buffered = 200;
    buffering = true;
    for (var i = 0; i < 9; i++) {
      bytes = bytes! + 300 * 1024;
      await poll();
    }
    expect(actions, isEmpty);
    bytes = bytes! + 300 * 1024;
    await poll();
    expect(actions, ['reload']);
    // Still stuck after it: nothing more until the picture moves.
    for (var i = 0; i < 20; i++) {
      bytes = bytes! + 300 * 1024;
      await poll();
    }
    expect(actions, ['reload']);
  });

  test('no picture and no data (network down) is left to the reconnect',
      () async {
    bytes = 5 * 1024 * 1024;
    await playFor(3);
    buffered = 0;
    buffering = true;
    for (var i = 0; i < 25; i++) {
      await poll();
    }
    expect(actions, isEmpty);
  });

  test('a counter that starts over (reused player) is not a freeze', () async {
    await playFor(3);
    frames = 0;
    await poll();
    await playFor(3);
    expect(actions, isEmpty);
  });
}
