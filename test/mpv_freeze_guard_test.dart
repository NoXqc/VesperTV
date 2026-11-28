import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/mpv_freeze_guard.dart';

/// mpv as the freeze guard reads it ('' = not reported).
class FakeMpv {
  double? pos = 100;
  double? audio = 100;
  int height = 1080;
  double cache = 15;
  bool pausedForCache = false;
  bool coreIdle = false;
  int fwBytes = 4 << 20;
  double fps = 25;
  bool fails = false;
  final Set<String> empty = {};
  final List<String> reads = [];

  Future<String> read(String name) async {
    reads.add(name);
    if (fails) throw StateError('player gone');
    if (empty.contains(name)) return '';
    return switch (name) {
      'time-pos' => pos?.toString() ?? '',
      'audio-pts' => audio?.toString() ?? '',
      'video-params/h' => height > 0 ? '$height' : '',
      'demuxer-cache-duration' => '$cache',
      'paused-for-cache' => pausedForCache ? 'yes' : 'no',
      'core-idle' => coreIdle ? 'yes' : 'no',
      'demuxer-cache-state' => jsonEncode({
          'fw-bytes': fwBytes,
          'underrun': pausedForCache,
          'raw-input-rate': 200000,
        }),
      'estimated-vf-fps' => '$fps',
      'estimated-frame-number' => '${((pos ?? 0) * fps).round()}',
      'frame-drop-count' || 'decoder-frame-drop-count' => '0',
      _ => '',
    };
  }
}

void main() {
  late FakeMpv mpv;
  late bool playing;
  late bool buffering;
  late String key;
  late bool watched;
  late List<String> actions;
  late List<String> lines;
  late DateTime now;
  late MpvFreezeGuard guard;

  setUp(() {
    mpv = FakeMpv();
    playing = true;
    buffering = false;
    key = '1';
    watched = true;
    actions = [];
    lines = [];
    now = DateTime(2026, 11, 28, 20);
    guard = MpvFreezeGuard(
      target: () => watched
          ? (key: key, label: 'ESPN 4K', playing: playing, buffering: buffering)
          : null,
      read: mpv.read,
      nudge: () async => actions.add('nudge'),
      reload: () async => actions.add('reload'),
      clock: () => now,
      log: lines.add,
    );
  });

  /// One poll, a second after the last; [moving] = a second of new frames.
  Future<void> poll({bool moving = false}) async {
    now = now.add(const Duration(seconds: 1));
    if (moving) {
      mpv.pos = (mpv.pos ?? 0) + 1;
      mpv.audio = (mpv.audio ?? 0) + 1;
    }
    await guard.tick();
  }

  Future<void> playFor(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await poll(moving: true);
    }
  }

  Future<void> stuckFor(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await poll();
    }
  }

  test('stuck with data cached: Pause/Play, then one reload', () async {
    await playFor(3);
    await stuckFor(2);
    expect(actions, isEmpty);
    await poll();
    expect(actions, ['nudge']);
    await stuckFor(2);
    expect(actions, ['nudge']);
    await poll();
    expect(actions, ['nudge', 'reload']);
    // Still stuck after the reload: nothing more until it moves.
    await stuckFor(8);
    expect(actions, ['nudge', 'reload']);
  });

  test('the lab freeze: sound track silent, mpv neither paused nor waiting',
      () async {
    // libmpv 0.36 (the app's Windows build), audio packets stopped while
    // video kept arriving: time-pos and audio-pts still, paused-for-cache
    // no, core-idle no, the cache growing.
    await playFor(5);
    for (var i = 0; i < 6; i++) {
      mpv.cache += 1;
      mpv.fwBytes += 200 * 1024;
      await poll();
    }
    expect(actions, ['nudge', 'reload']);
    final nudge = lines.firstWhere((l) => l.contains('Pause/Play ('));
    expect(nudge, contains('LiveFreeze: picture stuck 3.0s on "ESPN 4K"'));
    expect(nudge, contains('sound stopped too'));
    expect(nudge, contains('pausedForCache=no coreIdle=no'));
    expect(lines.where((l) => l.contains('reloading (reload 1 of 2')),
        hasLength(1));
  });

  test('Pause/Play that helps: no reload, a later freeze starts over',
      () async {
    await playFor(3);
    await stuckFor(3);
    expect(actions, ['nudge']);
    await playFor(5);
    expect(
        lines.any((l) =>
            l.contains('moving again') && l.contains('(Pause/Play helped)')),
        isTrue);
    await stuckFor(3);
    expect(actions, ['nudge', 'nudge']);
  });

  test(
      'never while paused, waiting for data, restarting, short of data or '
      'without video', () async {
    await playFor(3);
    playing = false;
    await stuckFor(5);
    playing = true;
    buffering = true;
    await stuckFor(5);
    buffering = false;
    mpv.pausedForCache = true;
    await stuckFor(5);
    mpv.pausedForCache = false;
    mpv.coreIdle = true;
    await stuckFor(5);
    mpv.coreIdle = false;
    mpv.cache = 0.4;
    mpv.fwBytes = 0; // nothing arriving either
    await stuckFor(5);
    mpv.cache = 15;
    mpv.height = 0;
    await stuckFor(5);
    mpv.height = 1080;
    watched = false;
    await stuckFor(5);
    expect(actions, isEmpty);
    expect(lines.any((l) => l.contains('while mpv waits for data')), isTrue);
    expect(
        lines.any((l) => l.contains('not acting: under 1 s cached')), isTrue);
  });

  test('not before the first picture; a new open starts over', () async {
    await stuckFor(6);
    expect(actions, isEmpty, reason: 'no frame yet (starting)');
    mpv.height = 0;
    await playFor(3);
    mpv.height = 1080;
    await stuckFor(6);
    expect(actions, isEmpty, reason: 'audio only so far (radio)');
    await playFor(3);
    key = '2';
    await stuckFor(6);
    expect(actions, isEmpty, reason: 'the new open showed nothing yet');
    expect(lines.any((l) => l.contains('first picture on "ESPN 4K"')), isTrue);
  });

  test('a picture slower than 1 fps (a still image) is no freeze', () async {
    await playFor(3);
    mpv.fps = 0.2;
    await stuckFor(8);
    expect(actions, isEmpty);
  });

  test('a timestamp jump back counts as a new picture', () async {
    await playFor(3);
    await stuckFor(2);
    mpv.pos = 1.4; // a server switch restarted the timestamps
    await poll();
    await stuckFor(2);
    expect(actions, isEmpty);
  });

  test('at most two reloads in five minutes', () async {
    Future<void> freeze() async {
      await playFor(2);
      await stuckFor(6);
    }

    await freeze();
    await freeze();
    await freeze();
    expect(actions.where((a) => a == 'reload'), hasLength(2));
    expect(actions.where((a) => a == 'nudge'), hasLength(3));
    expect(lines.any((l) => l.contains('2 reloads in 5 min already')), isTrue);
    now = now.add(const Duration(minutes: 6));
    await freeze();
    expect(actions.where((a) => a == 'reload'), hasLength(3));
  });

  test('stuck waiting while data keeps coming: one reload', () async {
    await playFor(3);
    mpv.cache = 0.2;
    mpv.pausedForCache = true;
    mpv.coreIdle = true;
    buffering = true;
    for (var i = 0; i < 9; i++) {
      mpv.fwBytes += 300 * 1024;
      await poll();
    }
    expect(actions, isEmpty);
    mpv.fwBytes += 300 * 1024;
    await poll();
    expect(actions, ['reload']);
    expect(lines.last, contains('KB arrived (player stuck waiting)'));
    // Still stuck after it: nothing more until the picture moves.
    for (var i = 0; i < 20; i++) {
      mpv.fwBytes += 300 * 1024;
      await poll();
    }
    expect(actions, ['reload']);
  });

  test('no picture and no data (network down) is left to the reconnect',
      () async {
    await playFor(3);
    mpv.cache = 0;
    mpv.pausedForCache = true;
    buffering = true;
    await stuckFor(25);
    expect(actions, isEmpty);
    expect(lines.any((l) => l.contains('left to the reconnect')), isTrue);
  });

  test('while it plays, one property a second', () async {
    await playFor(3);
    mpv.reads.clear();
    await playFor(5);
    expect(mpv.reads, List.filled(5, 'time-pos'));
  });

  test('empty or failing properties: one line per stream, no action', () async {
    mpv.empty.add('estimated-vf-fps');
    await playFor(3);
    await stuckFor(6);
    expect(lines.where((l) => l.contains('mpv estimated-vf-fps empty')),
        hasLength(1));
    mpv.fails = true;
    await stuckFor(10);
    expect(lines.where((l) => l.contains('mpv time-pos read failed')),
        hasLength(1));
    expect(actions, ['nudge', 'reload']);
  });

  test(
      'Send log: a watch line every 10 s, one line a second at most, no '
      'address', () async {
    await playFor(30);
    final watchLines =
        lines.where((l) => l.startsWith('LiveFreeze: watch "')).toList();
    expect(watchLines, hasLength(3));
    expect(
        watchLines.last,
        'LiveFreeze: watch "ESPN 4K" pos=+10.0s frames=+250 drops=+0/+0 '
        'sound=+10.0s cache=15.0s pausedForCache=no coreIdle=no '
        'playing=yes buffering=no h=1080 fps=25.0 picture=yes');
    // Freeze + recovery: every line on its own second unless it's an action.
    await stuckFor(12);
    expect(lines.every((l) => l.startsWith('LiveFreeze: ')), isTrue);
    expect(lines.any((l) => l.contains('://')), isFalse);
    guard.stop();
    expect(lines.last, startsWith('LiveFreeze: stopped watching "ESPN 4K"'));
    expect(lines.last, contains('1 Pause/Play, 1 reload(s)'));
  });
}
