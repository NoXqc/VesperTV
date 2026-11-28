import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_log.dart';
import 'package:nox_iptv/services/apple_tv_display.dart';

/// mpv properties that change as the "stream" plays.
class _FakeMpv {
  _FakeMpv(this.timeline);

  /// After each entry's delay, its values hold.
  final List<(Duration, Map<String, String>)> timeline;
  final _started = DateTime.now();

  Future<String> read(String name) async {
    final elapsed = DateTime.now().difference(_started);
    var values = const <String, String>{};
    for (final (at, v) in timeline) {
      if (elapsed >= at) values = v;
    }
    return values[name] ?? '';
  }
}

void main() {
  group('snap', () {
    test('standard rates and near misses', () {
      expect(AppleTvDisplayMatch.snap(25), 25.0);
      expect(AppleTvDisplayMatch.snap(49.87), 50.0);
      expect(AppleTvDisplayMatch.snap(23.98), 23.976);
      expect(AppleTvDisplayMatch.snap(59.94), 59.94);
      expect(AppleTvDisplayMatch.snap(60.02), 60.0);
    });

    test('nothing for odd or missing rates', () {
      expect(AppleTvDisplayMatch.snap(0), isNull);
      expect(AppleTvDisplayMatch.snap(-1), isNull);
      expect(AppleTvDisplayMatch.snap(double.nan), isNull);
      expect(AppleTvDisplayMatch.snap(40), isNull);
      expect(AppleTvDisplayMatch.snap(120), isNull);
    });
  });

  group('refreshFor (Android DisplayModes.kt rule)', () {
    test('broadcast rates go to 50 / 60 Hz', () {
      for (final only5060 in [false, true]) {
        expect(AppleTvDisplayMatch.refreshFor(25, only5060: only5060), 50.0);
        expect(AppleTvDisplayMatch.refreshFor(50, only5060: only5060), 50.0);
        expect(
            AppleTvDisplayMatch.refreshFor(29.97, only5060: only5060), 59.94);
        expect(
            AppleTvDisplayMatch.refreshFor(59.94, only5060: only5060), 59.94);
        expect(AppleTvDisplayMatch.refreshFor(30, only5060: only5060), 60.0);
        expect(AppleTvDisplayMatch.refreshFor(60, only5060: only5060), 60.0);
      }
    });

    test('films keep 24p unless only 50 / 60 Hz switches', () {
      expect(AppleTvDisplayMatch.refreshFor(23.976, only5060: false), 23.976);
      expect(AppleTvDisplayMatch.refreshFor(24, only5060: false), 24.0);
      expect(AppleTvDisplayMatch.refreshFor(24, only5060: true), isNull);
      expect(AppleTvDisplayMatch.refreshFor(23.976, only5060: true), isNull);
    });

    test('an unknown rate keeps the mode', () {
      expect(AppleTvDisplayMatch.refreshFor(0, only5060: false), isNull);
      expect(AppleTvDisplayMatch.refreshFor(42, only5060: false), isNull);
    });
  });

  group('detect', () {
    const fast = Duration(milliseconds: 5);

    test('a declared standard rate wins as soon as the picture is there',
        () async {
      final mpv = _FakeMpv([
        (Duration.zero, {}),
        (
          const Duration(milliseconds: 30),
          {
            'video-params/w': '1920',
            'video-params/h': '1080',
            'container-fps': '25.000000',
            'estimated-vf-fps': '50.0',
          }
        ),
      ]);
      final video = await AppleTvDisplayMatch.detect(mpv.read, () => true,
          poll: fast, openWait: const Duration(seconds: 2));
      expect(video, isNotNull);
      expect(video!.fps, 25.0);
      expect(video.width, 1920);
      expect(video.height, 1080);
    });

    test('live .ts without a declared rate: mpv\'s measured rate', () async {
      final mpv = _FakeMpv([
        (
          Duration.zero,
          {
            'video-params/w': '1280',
            'video-params/h': '720',
            'container-fps': '',
            'estimated-vf-fps': '49.9',
          }
        ),
      ]);
      final video = await AppleTvDisplayMatch.detect(mpv.read, () => true,
          poll: const Duration(milliseconds: 100),
          openWait: const Duration(seconds: 2),
          measureWait: const Duration(seconds: 3));
      expect(video!.fps, 49.9);
    });

    test('a nonsense declared rate falls back to the measured one', () async {
      final mpv = _FakeMpv([
        (
          Duration.zero,
          {
            'video-params/w': '1920',
            'video-params/h': '1080',
            'container-fps': '90000',
            'estimated-vf-fps': '59.94',
          }
        ),
      ]);
      final video = await AppleTvDisplayMatch.detect(mpv.read, () => true,
          poll: const Duration(milliseconds: 100),
          openWait: const Duration(seconds: 2),
          measureWait: const Duration(seconds: 3));
      expect(video!.fps, 59.94);
    });

    test('a channel change stops it', () async {
      var current = true;
      final mpv = _FakeMpv([(Duration.zero, {})]);
      final pending = AppleTvDisplayMatch.detect(mpv.read, () => current,
          poll: fast, openWait: const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      current = false;
      expect(await pending, isNull);
    });

    test('no picture within the wait: nothing', () async {
      final mpv = _FakeMpv([(Duration.zero, {})]);
      expect(
          await AppleTvDisplayMatch.detect(mpv.read, () => true,
              poll: fast, openWait: const Duration(milliseconds: 60)),
          isNull);
    });

    test('a picture whose rate never settles: nothing', () async {
      final mpv = _FakeMpv([
        (Duration.zero, {'video-params/w': '1920', 'video-params/h': '1080'}),
      ]);
      expect(
          await AppleTvDisplayMatch.detect(mpv.read, () => true,
              poll: fast,
              openWait: const Duration(seconds: 1),
              measureWait: const Duration(milliseconds: 80)),
          isNull);
    });
  });

  group('the TV\'s mode switch (GitHub #20)', () {
    late Directory dir;
    late File stepFile;
    final printed = <String>[];
    final realPrint = debugPrint;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('vesper_step');
      stepFile = File('${dir.path}/vespertv_step.txt');
      AppLog.stepFileForTest = stepFile;
      printed.clear();
      debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
    });
    tearDown(() {
      debugPrint = realPrint;
      AppLog.stepFileForTest = null;
      dir.deleteSync(recursive: true);
    });

    test('a switch is a step until it ends, with a log line each way', () {
      AppleTvDisplayMatch.onModeSwitch(true);
      expect(stepFile.readAsStringSync(), contains('the TV is switching to'));
      AppleTvDisplayMatch.onModeSwitch(false);
      expect(stepFile.existsSync(), isFalse);
      expect(
          printed.first, startsWith('DisplayMatch: the TV started switching'));
      expect(printed.last,
          startsWith('DisplayMatch: the TV finished switching after'));
    });

    test('a crash during the switch leaves it for the next session', () async {
      AppleTvDisplayMatch.onModeSwitch(true);
      expect(await AppLog.takeLastStep(stepFile), contains('switching'));
    });
  });
}
