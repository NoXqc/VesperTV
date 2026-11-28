import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/desktop_timeshift.dart';
import 'package:nox_iptv/services/live_timeshift.dart';

/// Live pause & rewind on mpv (computers / iPhone / Apple TV): what mpv
/// keeps ([MpvKeptRange], from `demuxer-cache-state`), where skips land,
/// Play after a pause, the copy file's limits, and the controller on a
/// fake mpv.
Duration s(num seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

/// mpv 0.36 (the app's Windows libmpv) 6 s into a live MPEG-TS at
/// 3 Mbit/s with the timeshift options (2026-11-28).
const _mpvState =
    '{"cache-end":6.421333,"reader-pts":6.341333,"cache-duration":0.080000,'
    '"eof":false,"underrun":false,"idle":false,"total-bytes":121344,'
    '"fw-bytes":4096,"file-cache-bytes":2622553,"raw-input-rate":402611,'
    '"debug-low-level-seeks":0,"debug-byte-level-seeks":0,'
    '"debug-ts-last":7.821333,"bof-cached":true,"eof-cached":false,'
    '"seekable-ranges":[{"start":0.000000,"end":5.981333}]}';

String _state(
        {required num start,
        required num seekEnd,
        required num end,
        int? file = 1000000,
        List<List<num>>? more}) =>
    '{"cache-end":$end,"total-bytes":500000,"fw-bytes":4000,'
    '${file == null ? '' : '"file-cache-bytes":$file,'}'
    '"seekable-ranges":[${[
      ...?more?.map((r) => '{"start":${r[0]},"end":${r[1]}}'),
      '{"start":$start,"end":$seekEnd}'
    ].join(',')}]}';

MpvKeptRange _range(
        {required num position,
        num start = 0,
        required num seekEnd,
        required num end,
        int minutes = 30,
        int? file = 1000000}) =>
    MpvKeptRange.parse(
        _state(start: start, seekEnd: seekEnd, end: end, file: file),
        position: s(position),
        window: Duration(minutes: minutes))!;

final _live = Channel(
  id: 'p::news',
  rawId: 'news',
  playlistId: 'p',
  name: 'News',
  group: 'News',
  url: 'http://host:80/live/u/pw/1.ts',
);

final _catchup = Channel(
  id: 'p::cu',
  rawId: 'cu',
  playlistId: 'p',
  name: 'Catch-up channel',
  group: 'News',
  url: 'http://host:80/live/u/pw/2.ts',
  catchupDays: 2,
  catchupKind: CatchupKind.xc,
  streamId: '2',
);

class _FakeMpv implements TimeshiftMpv {
  final props = <String, String>{
    'cache': 'yes',
    'demuxer-seekable-cache': 'auto',
    'cache-on-disk': 'yes',
    'demuxer-cache-dir': '',
    'demuxer-donate-buffer': 'yes',
    'demuxer-max-back-bytes': '33554432',
    'demuxer-max-bytes': '33554432',
  };
  final sets = <(String, String)>[];
  final seeks = <Duration>[];
  var plays = 0;
  String cacheState = '';
  @override
  Duration position = Duration.zero;
  @override
  bool playing = true;
  final logLines = StreamController<PlayerLog>.broadcast();

  @override
  Future<String> get(String name) async =>
      name == 'demuxer-cache-state' ? cacheState : props[name] ?? '';

  @override
  Future<void> set(String name, String value) async {
    sets.add((name, value));
    props[name] = value;
  }

  @override
  Future<void> seek(Duration to) async {
    seeks.add(to);
    position = to;
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
  }

  @override
  Stream<PlayerLog> get logs => logLines.stream;
}

void main() {
  group('MpvKeptRange', () {
    test('reads mpv 0.36 demuxer-cache-state', () {
      final r = MpvKeptRange.parse(_mpvState,
          position: s(5.661333), window: const Duration(minutes: 30))!;
      expect(r.start, Duration.zero);
      expect(r.seekEnd, s(5.981333));
      expect(r.newest, s(6.421333));
      expect(r.fileBytes, 2622553);
      expect(r.indexBytes, 121344);
      expect(r.forwardBytes, 4096);
      expect(r.behind, s(6.421333 - 5.661333));
      expect(r.atLive, isTrue);
      // LIVE: just before the newest keyframe (mpv refuses past it).
      expect(r.liveSeek, s(5.981333) - MpvKeptRange.endMargin);
      expect(r.state.on, isTrue);
      expect(r.state.memoryOnly, isFalse);
    });

    test('nothing to seek in yet / not JSON = null', () {
      expect(
          MpvKeptRange.parse('{"cache-end":1.0,"seekable-ranges":[]}',
              position: Duration.zero, window: const Duration(minutes: 30)),
          isNull);
      expect(
          MpvKeptRange.parse('',
              position: Duration.zero, window: const Duration(minutes: 30)),
          isNull);
      expect(
          MpvKeptRange.parse('not json',
              position: Duration.zero, window: const Duration(minutes: 30)),
          isNull);
    });

    test('no copy file = memory only', () {
      final r = _range(position: 10, seekEnd: 11, end: 12, file: null);
      expect(r.fileBytes, isNull);
      expect(r.state.memoryOnly, isTrue);
    });

    test('the setting\'s minutes cap what is offered', () {
      // An hour kept by mpv, 30 min setting.
      final r = _range(position: 3590, seekEnd: 3598, end: 3600);
      expect(r.oldest, s(1800));
      expect(r.available, const Duration(minutes: 30));
      // Less kept than the setting: mpv's oldest keyframe (+ margin).
      final young = _range(position: 100, start: 2, seekEnd: 118, end: 120);
      expect(young.oldest, s(2) + MpvKeptRange.startMargin);
      expect(young.available, s(118) - MpvKeptRange.startMargin);
    });

    test('HLS: LIVE stays inside the seekable range, not cache-end', () {
      // Measured: cache-end 57.99, newest seek point 55.96; a seek to
      // cache-end - 1 was refused ("Cannot seek in this stream").
      final r = _range(position: 23, seekEnd: 55.96, end: 57.99);
      final live = r.landing(Duration.zero, hasCatchup: false);
      expect(live.kind, TimeshiftLandingKind.live);
      expect(live.seekTo, lessThanOrEqualTo(s(55.96)));
      expect(r.behind, s(57.99 - 23));
    });

    test('where a skip lands', () {
      final r = _range(position: 3590, seekEnd: 3598, end: 3600);
      // Back 30 s from 10 s behind.
      final back = r.landing(s(40), hasCatchup: false);
      expect(back.kind, TimeshiftLandingKind.inRange);
      expect(back.seekTo, s(3560));
      // Near live = LIVE.
      expect(
          r.landing(s(3), hasCatchup: false).kind, TimeshiftLandingKind.live);
      // Past what is kept, no catch-up: the oldest kept moment.
      final far = r.landing(const Duration(minutes: 45), hasCatchup: false);
      expect(far.kind, TimeshiftLandingKind.oldest);
      expect(far.seekTo, s(1800));
      // Past it on a catch-up channel: catch-up (more than 5 s past).
      expect(r.landing(const Duration(minutes: 45), hasCatchup: true).kind,
          TimeshiftLandingKind.catchup);
      // Within 5 s of the oldest moment on a catch-up channel: still kept.
      expect(
          r.landing(const Duration(minutes: 30) + s(3), hasCatchup: true).kind,
          TimeshiftLandingKind.oldest);
    });

    test('a seek is never negative and never outside what is kept', () {
      // mpv counts a negative absolute seek from the end (measured: -20
      // landed 20 s before the end).
      final r = _range(position: 1, seekEnd: 0.05, end: 0.4);
      expect(r.clampSeek(s(-20)), greaterThanOrEqualTo(Duration.zero));
      expect(r.landing(const Duration(hours: 1), hasCatchup: false).seekTo,
          greaterThanOrEqualTo(Duration.zero));
      final big = _range(position: 3590, seekEnd: 3598, end: 3600);
      expect(big.clampSeek(s(10)), big.oldest);
      expect(big.clampSeek(s(4000)), big.liveSeek);
    });

    test('picks the range the picture is in', () {
      final r = MpvKeptRange.parse(
          _state(start: 500, seekEnd: 598, end: 600, more: [
            [0, 100]
          ]),
          position: s(50),
          window: const Duration(minutes: 30))!;
      expect(r.start, Duration.zero);
      expect(r.seekEnd, s(100));
      final newest = MpvKeptRange.parse(
          _state(start: 500, seekEnd: 598, end: 600, more: [
            [0, 100]
          ]),
          position: s(590),
          window: const Duration(minutes: 30))!;
      expect(newest.start, s(500));
    });

    test('a picture outside what is kept (a jump in times) offers nothing', () {
      final r = _range(position: 9000, seekEnd: 598, end: 600);
      expect(r.inSync, isFalse);
      expect(r.behind, Duration.zero);
      expect(r.available, Duration.zero);
    });

    test('Play after a pause', () {
      // Paused 5 min on a 30 min setting: still kept.
      final short = _range(position: 3300, seekEnd: 3598, end: 3600);
      expect(short.resumeAfterPause(hasCatchup: true), TimeshiftResume.play);
      // Paused 40 min: past the setting's minutes.
      final long = _range(position: 1200, seekEnd: 3598, end: 3600);
      expect(long.resumeAfterPause(hasCatchup: true), TimeshiftResume.catchup);
      expect(
          long.resumeAfterPause(hasCatchup: false), TimeshiftResume.fromOldest);
    });
  });

  group('options and limits', () {
    test('mpv options for the setting', () {
      final o = optionsFor(minutes: 30, dir: '/tmp/vesper_timeshift');
      expect(o, {
        'cache': 'yes',
        'demuxer-seekable-cache': 'yes',
        'cache-on-disk': 'yes',
        'demuxer-cache-dir': '/tmp/vesper_timeshift',
        'demuxer-donate-buffer': 'no',
        'demuxer-max-back-bytes': '${60 * 1024 * 1024}',
      });
      // An iPhone's 32 MiB forward limit would stop reading a paused
      // channel: raised while armed; a computer's 256 MiB stays.
      expect(
          optionsFor(
              minutes: 30,
              dir: 'd',
              forwardNow: 32 * 1024 * 1024)['demuxer-max-bytes'],
          '${60 * 1024 * 1024}');
      expect(
          optionsFor(minutes: 30, dir: 'd', forwardNow: 256 * 1024 * 1024)
              .containsKey('demuxer-max-bytes'),
          isFalse);
      expect(indexBytesFor(10), 20 * 1024 * 1024);
      expect(indexBytesFor(60), 120 * 1024 * 1024);
      expect(indexBytesFor(5), 16 * 1024 * 1024);
    });

    test('copy file limits', () {
      const gib = 1024 * 1024 * 1024;
      expect(
          budgetBytes(
              free: -1, kind: DesktopDeviceKind.appleTv, windows: false),
          6 * gib);
      expect(
          budgetBytes(free: -1, kind: DesktopDeviceKind.phone, windows: false),
          3 * gib);
      expect(
          budgetBytes(
              free: 100 * gib, kind: DesktopDeviceKind.computer, windows: true),
          16 * gib);
      expect(
          budgetBytes(
              free: 10 * gib, kind: DesktopDeviceKind.computer, windows: true),
          6 * gib);
      // Windows with too little free space: off.
      expect(
          budgetBytes(
              free: 4 * gib, kind: DesktopDeviceKind.computer, windows: true),
          isNull);
      // Elsewhere a low reading only shrinks it.
      expect(
          budgetBytes(
              free: 2 * gib, kind: DesktopDeviceKind.appleTv, windows: false),
          gib);
      expect(
          budgetBytes(
              free: 5 * gib, kind: DesktopDeviceKind.appleTv, windows: false),
          3 * gib);
      expect(leaveLimitBytes(DesktopDeviceKind.appleTv), gib);
      expect(leaveLimitBytes(DesktopDeviceKind.computer), 4 * gib);
    });

    test('past the limit: reopen at live, or at once past a quarter more', () {
      expect(
          limitAction(fileBytes: 90, budget: 100, atLive: true, playing: true),
          TimeshiftLimit.keep);
      expect(
          limitAction(fileBytes: 110, budget: 100, atLive: true, playing: true),
          TimeshiftLimit.restartAtLive);
      expect(
          limitAction(
              fileBytes: 110, budget: 100, atLive: false, playing: true),
          TimeshiftLimit.keep);
      expect(
          limitAction(
              fileBytes: 110, budget: 100, atLive: true, playing: false),
          TimeshiftLimit.keep);
      expect(
          limitAction(
              fileBytes: 130, budget: 100, atLive: false, playing: false),
          TimeshiftLimit.restartNow);
    });

    test('mpv words for a copy file it cannot write or create', () {
      expect(cacheTrouble('cache', 'Failed to write to cache file.'),
          CacheTrouble.write);
      expect(cacheTrouble('demux', 'Failed to create file cache.'),
          CacheTrouble.create);
      expect(
          cacheTrouble('ffmpeg', 'http: cache write error'), isNull); // ffmpeg
      expect(cacheTrouble('cplayer', 'Cannot seek in this stream.'), isNull);
    });

    test('Send log never shows the home folder', () {
      expect(shortDir(r'C:\Users\someone\AppData\Local\Temp\vesper_timeshift'),
          '…/Temp/vesper_timeshift');
      expect(
          shortDir(
              '/private/var/mobile/Containers/Data/Application/X/tmp/vesper_timeshift'),
          '…/tmp/vesper_timeshift');
    });

    test('mpv read-backs compare as values', () {
      expect(sameValue('62914560', '62914560'), isTrue);
      expect(sameValue('yes', 'yes'), isTrue);
      expect(sameValue('yes', 'auto'), isFalse);
      expect(sameValue('62914560', ''), isFalse);
    });
  });

  group('DesktopTimeshift on a fake mpv', () {
    late _FakeMpv mpv;
    late DesktopTimeshift ts;
    late DateTime now;
    final catchups = <DateTime>[];
    final restarts = <String>[];
    final printed = <String>[];
    DebugPrintCallback? oldPrint;

    setUp(() {
      LiveTimeshift.minutes = 30;
      DesktopTimeshift.resetStorageFailure();
      mpv = _FakeMpv();
      now = DateTime(2026, 11, 28, 20, 0);
      catchups.clear();
      restarts.clear();
      printed.clear();
      oldPrint = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
      ts = DesktopTimeshift(mpv,
          clock: () => now,
          dirFor: () async => Directory.systemTemp,
          freeBytesOf: (_) => -1);
    });

    tearDown(() {
      debugPrint = oldPrint!;
      LiveTimeshift.minutes = LiveTimeshift.defaultMinutes;
    });

    Future<bool> arm(Channel c) => ts.arm(c,
        why: 'test',
        catchup: (at) async => catchups.add(at),
        restart: restarts.add);

    /// Stops the 1 s poll and the seek checks (no timer left pending).
    Future<void> done(WidgetTester tester) async {
      await ts.disarm('end of test');
      await tester.pump(const Duration(seconds: 2));
      // testWidgets checks debugPrint before tearDown runs.
      debugPrint = oldPrint!;
    }

    testWidgets('arming sets the options; disarming puts them back',
        (tester) async {
      expect(await arm(_live), isTrue);
      expect(ts.armed, isTrue);
      expect(mpv.props['cache-on-disk'], 'yes');
      expect(mpv.props['demuxer-donate-buffer'], 'no');
      expect(mpv.props['demuxer-max-back-bytes'], '${60 * 1024 * 1024}');
      expect(mpv.props['demuxer-cache-dir'], Directory.systemTemp.path);
      expect(mpv.props['demuxer-max-bytes'], '${60 * 1024 * 1024}');
      expect(printed.where((l) => l.startsWith('Timeshift: on for News')),
          hasLength(1));
      expect(printed.last, contains('(all set)'));
      await ts.disarm('test');
      expect(ts.armed, isFalse);
      // Before: 32 MiB back, donate on, no folder; the open stream stops
      // writing (cache-on-disk=no).
      expect(mpv.props['demuxer-max-back-bytes'], '33554432');
      expect(mpv.props['demuxer-donate-buffer'], 'yes');
      expect(mpv.props['demuxer-cache-dir'], '');
      expect(mpv.props['cache-on-disk'], 'no');
      expect(mpv.props['demuxer-max-bytes'], '33554432');
      expect(ts.state.value, isNull);
      // Armed again (a zap back from the preview): the same values return
      // when it stops, not the ones it set.
      expect(await arm(_live), isTrue);
      expect(await arm(_catchup), isTrue);
      await ts.disarm('test');
      expect(mpv.props['demuxer-max-back-bytes'], '33554432');
      expect(mpv.props['demuxer-donate-buffer'], 'yes');
      await done(tester);
    });

    testWidgets('off: the setting, a channel that is not live', (tester) async {
      LiveTimeshift.minutes = 0;
      expect(await arm(_live), isFalse);
      expect(mpv.sets, isEmpty);
      LiveTimeshift.minutes = 30;
      expect(
          await arm(Channel(
              id: 'p::t',
              rawId: 't',
              playlistId: 'p',
              name: 'Trailer',
              group: '',
              url: 'http://host/t.ts',
              transientPlayback: true)),
          isFalse);
      expect(mpv.sets, isEmpty);
      await done(tester);
    });

    testWidgets('an option this libmpv does not take is named in Send log',
        (tester) async {
      mpv.props.remove('demuxer-donate-buffer');
      final wrapped = _ForgetfulMpv(mpv, 'demuxer-donate-buffer');
      ts = DesktopTimeshift(wrapped,
          clock: () => now,
          dirFor: () async => Directory.systemTemp,
          freeBytesOf: (_) => -1);
      expect(await arm(_live), isTrue);
      expect(printed.last, contains('NOT TAKEN: demuxer-donate-buffer'));
      await done(tester);
    });

    testWidgets('skips gather 700 ms, then one seek', (tester) async {
      await arm(_live);
      mpv.cacheState = _state(start: 0, seekEnd: 1198, end: 1200);
      mpv.position = s(1199);
      await ts.readNow();
      expect(ts.state.value!.atLive, isTrue);
      ts.nudge(const Duration(seconds: -30), live: _live);
      ts.nudge(const Duration(seconds: -30), live: _live);
      expect(ts.target.value, s(61));
      expect(mpv.seeks, isEmpty);
      await tester.pump(const Duration(milliseconds: 750));
      expect(mpv.seeks, [s(1200 - 61)]);
      expect(ts.target.value, isNull);
      expect(
          printed.any((l) =>
              l.startsWith('Timeshift: skip:') &&
              l.contains('-> 0:01:01 behind live')),
          isTrue);
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });

    testWidgets('a skip past what is kept on a catch-up channel = catch-up',
        (tester) async {
      await arm(_catchup);
      mpv.cacheState = _state(start: 0, seekEnd: 598, end: 600);
      mpv.position = s(599);
      await ts.readNow();
      ts.nudge(const Duration(minutes: -15), live: _catchup);
      await tester.pump(const Duration(milliseconds: 750));
      expect(mpv.seeks, isEmpty);
      expect(catchups, hasLength(1));
      expect(now.difference(catchups.single), s(901));
      await done(tester);
    });

    testWidgets('the same past what is kept without catch-up = the oldest',
        (tester) async {
      await arm(_live);
      mpv.cacheState = _state(start: 0, seekEnd: 598, end: 600);
      mpv.position = s(599);
      await ts.readNow();
      ts.nudge(const Duration(minutes: -15), live: _live);
      // Without catch-up the target stops at what is kept.
      expect(ts.target.value, s(600) - MpvKeptRange.startMargin);
      await tester.pump(const Duration(milliseconds: 750));
      expect(catchups, isEmpty);
      expect(mpv.seeks.single, MpvKeptRange.startMargin);
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });

    testWidgets('Play after a pause carries on; past the window it does not',
        (tester) async {
      await arm(_live);
      mpv.cacheState = _state(start: 0, seekEnd: 1198, end: 1200);
      mpv.position = s(1199);
      await ts.readNow();
      mpv.playing = false;
      ts.notePause();
      now = now.add(const Duration(minutes: 5));
      mpv.cacheState = _state(start: 0, seekEnd: 1498, end: 1500);
      await ts.readNow();
      expect(ts.state.value!.behind, s(301));
      expect(ts.resume(live: _live), isTrue);
      expect(mpv.plays, 1);
      expect(mpv.seeks, isEmpty);
      // Paused 40 min (30 min setting): from the oldest kept moment.
      mpv.playing = false;
      ts.notePause();
      now = now.add(const Duration(minutes: 40));
      mpv.cacheState = _state(start: 0, seekEnd: 3898, end: 3900);
      await ts.readNow();
      expect(ts.resume(live: _live), isTrue);
      await tester.pump();
      expect(mpv.seeks.single, s(3900 - 1800));
      expect(mpv.plays, 2);
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });

    testWidgets(
        'past the window on a catch-up channel = catch-up from the '
        'pause', (tester) async {
      await arm(_catchup);
      mpv.cacheState = _state(start: 0, seekEnd: 1198, end: 1200);
      mpv.position = s(1199);
      await ts.readNow();
      final pausedAt = now;
      ts.notePause();
      now = now.add(const Duration(minutes: 40));
      mpv.cacheState = _state(start: 0, seekEnd: 3598, end: 3600);
      await ts.readNow();
      expect(ts.resume(live: _catchup, pausedAt: pausedAt), isTrue);
      await tester.pump();
      expect(catchups, [pausedAt]);
      await done(tester);
    });

    testWidgets('nothing read yet: Play is the caller\'s', (tester) async {
      await arm(_live);
      expect(ts.resume(live: _live), isFalse);
      await done(tester);
    });

    testWidgets('LIVE seeks to the newest seek point and plays',
        (tester) async {
      await arm(_live);
      mpv.cacheState = _state(start: 0, seekEnd: 1196, end: 1200);
      mpv.position = s(900);
      mpv.playing = false;
      await ts.readNow();
      await ts.toLive(why: 'test');
      expect(mpv.seeks.single, s(1196) - MpvKeptRange.endMargin);
      expect(mpv.plays, 1);
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });

    testWidgets('a seek that lands elsewhere is logged (asked vs got)',
        (tester) async {
      await arm(_live);
      mpv.cacheState = _state(start: 0, seekEnd: 1198, end: 1200);
      mpv.position = s(1199);
      mpv.playing = false;
      await ts.readNow();
      await ts.goTo(s(100), live: _live, why: 'test');
      mpv.position = s(1180); // mpv went somewhere else
      await tester.pump(const Duration(seconds: 1));
      expect(
          printed.any((l) =>
              l.startsWith('Timeshift: seek landed elsewhere: asked 1100.0 s')),
          isTrue);
      await done(tester);
    });

    testWidgets('the copy file past its limit opens the channel again',
        (tester) async {
      ts = DesktopTimeshift(mpv,
          clock: () => now,
          dirFor: () async => Directory.systemTemp,
          freeBytesOf: (_) => 6 * 1024 * 1024 * 1024);
      await arm(_live);
      // 6 GiB free - 4 GiB reserve = a 2 GiB limit.
      mpv.cacheState = _state(
          start: 0, seekEnd: 1198, end: 1200, file: 3 * 1024 * 1024 * 1024);
      mpv.position = s(1199);
      await ts.readNow();
      expect(restarts, ['copy limit']);
      // Not again right away.
      await ts.readNow();
      expect(restarts, hasLength(1));
      await done(tester);
    });

    testWidgets(
        'mpv failing to write its copy: off, reopened, no arming for '
        'a while', (tester) async {
      await arm(_live);
      mpv.logLines.add(const PlayerLog(
          prefix: 'cache', level: 'error', text: 'Failed to write to cache.'));
      await tester.pump();
      await tester.pump();
      expect(ts.armed, isFalse);
      expect(restarts, ['storage']);
      expect(await arm(_live), isFalse);
      expect(printed.any((l) => l.contains('storage failed')), isTrue);
      await done(tester);
    });

    testWidgets('leaving full screen behind live goes back to live first',
        (tester) async {
      await arm(_live);
      mpv.cacheState = _state(start: 0, seekEnd: 1198, end: 1200);
      mpv.position = s(900);
      await ts.readNow();
      var reopened = 0;
      await ts.leave(reopen: () async => reopened++);
      expect(mpv.seeks.single, s(1198) - MpvKeptRange.endMargin);
      expect(ts.armed, isFalse);
      expect(reopened, 0);
      await done(tester);
    });

    testWidgets('leaving with a big copy file reopens to free it',
        (tester) async {
      await arm(_live);
      mpv.cacheState = _state(
          start: 0, seekEnd: 1198, end: 1200, file: 5 * 1024 * 1024 * 1024);
      mpv.position = s(1199);
      await ts.readNow();
      var reopened = 0;
      await ts.leave(reopen: () async => reopened++);
      expect(reopened, 1);
      expect(ts.armed, isFalse);
      await done(tester);
    });

    testWidgets('the 10 s line names what is kept', (tester) async {
      await arm(_live);
      mpv.cacheState = _mpvState;
      mpv.position = s(5.66);
      await ts.readNow();
      expect(
          printed.any((l) =>
              l.startsWith('Timeshift: kept 0:00:05 of 30 min (0.0-6.4 s') &&
              l.contains('copy 2.5 MB')),
          isTrue);
      await done(tester);
    });
  });
}

/// An mpv that ignores [missing] (an older libmpv without that option).
class _ForgetfulMpv implements TimeshiftMpv {
  _ForgetfulMpv(this.inner, this.missing);
  final _FakeMpv inner;
  final String missing;

  @override
  Future<String> get(String name) async =>
      name == missing ? '' : await inner.get(name);

  @override
  Future<void> set(String name, String value) async {
    if (name != missing) await inner.set(name, value);
  }

  @override
  Future<void> seek(Duration to) => inner.seek(to);

  @override
  Future<void> play() => inner.play();

  @override
  Duration get position => inner.position;

  @override
  bool get playing => inner.playing;

  @override
  Stream<PlayerLog> get logs => inner.logs;
}
