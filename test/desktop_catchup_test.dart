import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/desktop_catchup.dart';

/// Windows catch-up's decisions (DesktopCatchup.plan): the same rules as
/// Android's PlaybackService.playCatchup.
void main() {
  final now = DateTime.utc(2026, 11, 6, 20, 0, 30);
  final live = Channel(
    id: 'p::live1',
    rawId: 'live1',
    playlistId: 'p',
    name: 'News',
    group: 'News',
    url: 'http://example.test/live/1.ts',
    catchupDays: 2,
    catchupKind: CatchupKind.shift,
  );
  final programmes = [
    EpgProgram(
        channelId: 'live1',
        title: 'Evening news',
        start: DateTime.utc(2026, 11, 6, 18),
        stop: DateTime.utc(2026, 11, 6, 19)),
  ];

  test('a past time plays as catch-up from the minute before it', () {
    final s = DesktopCatchup.plan(live, DateTime.utc(2026, 11, 6, 18, 10, 45),
        now: now,
        profile: null,
        programmes: programmes,
        stopAtProgrammeEnd: false)!;
    expect(s.requestStart, DateTime.utc(2026, 11, 6, 18, 10));
    expect(s.startOffset, const Duration(seconds: 45));
    expect(s.channel.transientPlayback, isTrue);
    expect(s.channel.isLive, isFalse);
    expect(s.until, isNull);
    expect(s.channel.url, contains('utc='));
  });

  test('stops at the programme end when Keep playing is off', () {
    final s = DesktopCatchup.plan(live, DateTime.utc(2026, 11, 6, 18, 30),
        now: now,
        profile: null,
        programmes: programmes,
        stopAtProgrammeEnd: true)!;
    expect(s.until, DateTime.utc(2026, 11, 6, 19));
  });

  test('older than the archive starts at its oldest time', () {
    final s = DesktopCatchup.plan(live, DateTime.utc(2026, 11, 1),
        now: now,
        profile: null,
        programmes: programmes,
        stopAtProgrammeEnd: false)!;
    expect(s.requestStart, DateTime.utc(2026, 11, 4, 20));
  });

  test('close to now, or no catch-up: live instead', () {
    expect(
        DesktopCatchup.plan(live, now.subtract(const Duration(seconds: 30)),
            now: now,
            profile: null,
            programmes: programmes,
            stopAtProgrammeEnd: false),
        isNull);
    final noArchive = Channel(
        id: 'p::live2',
        rawId: 'live2',
        playlistId: 'p',
        name: 'Movies',
        group: 'Movies',
        url: 'http://example.test/live/2.ts');
    expect(
        DesktopCatchup.plan(noArchive, DateTime.utc(2026, 11, 6, 18),
            now: now,
            profile: null,
            programmes: programmes,
            stopAtProgrammeEnd: false),
        isNull);
  });

  // LOG-WFEVGV (Mac, 1.0.73, NPO catch-up): every `.m3u8` try logged these
  // and stayed black; media_kit's error stream never fired, so the `.ts`
  // switch never ran.
  test('mpv lines that mean the .m3u8 never opened', () {
    bool failed(String prefix, String level, String text) =>
        DesktopCatchup.openFailed(
            PlayerLog(prefix: prefix, level: level, text: text));
    expect(
        failed('ffmpeg/demuxer', 'error',
            "hls: Error when loading first segment 'http://x/1.ts'"),
        isTrue);
    expect(
        failed('ffmpeg/demuxer', 'warn',
            "hls: Error when loading first segment 'http://x/1.ts'"),
        isTrue);
    expect(failed('lavf', 'error', 'avformat_open_input() failed  '), isTrue);
    expect(
        failed('cplayer', 'error', 'Failed to recognize file format.'), isTrue);
    // Not an open failure.
    expect(
        failed('sub', 'error',
            "Could not find subtitle decoder for format 'eia_608'."),
        isFalse);
    expect(failed('ffmpeg', 'error', 'http: Stream ends prematurely at 1'),
        isFalse);
    expect(failed('lavf', 'warn', 'avformat_open_input() failed'), isFalse);
  });
}
