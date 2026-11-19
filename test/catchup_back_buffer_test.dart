import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/catchup_format.dart';
import 'package:nox_iptv/services/playback_service.dart';

/// Catch-up keeps the last 30 s it played (LOG-EVPPYN, Fire TV,
/// 2026-11-19): −10 froze 12-17 s while the slow `.ts` panel was asked
/// again; +10 (already downloaded) came back in 0.2 s.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catch-up links get a back buffer, live and VOD links don\'t', () {
    const archive = 'http://host/timeshift/u/pw/91/2026-10-27:18-30/11.ts';
    final catchup = streamController(archive);
    expect(catchup.videoPlayerOptions?.backBufferDurationMs, 30000);

    final live = streamController('http://host/live/u/pw/11.ts');
    expect(live.videoPlayerOptions?.backBufferDurationMs, isNull);
    final movie = streamController('http://host/movie/u/pw/5.mkv');
    expect(movie.videoPlayerOptions?.backBufferDurationMs, isNull);
  });

  test('archive links: Xtream path and php forms, Flussonic', () {
    expect(
        CatchupFormat.isArchiveLink(
            'http://h/streaming/timeshift.php?username=a&stream=1'),
        isTrue);
    expect(
        CatchupFormat.isArchiveLink('http://h/ch/timeshift_abs-1795116600.ts'),
        isTrue);
    expect(CatchupFormat.isArchiveLink('http://h/live/u/p/1.m3u8'), isFalse);
  });
}
