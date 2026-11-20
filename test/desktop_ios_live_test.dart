import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/desktop_live_recovery.dart';
import 'package:nox_iptv/services/desktop_stream_setup.dart';

/// iPhone live HLS that cut out every 20-30 s (LOG-SKRVK2 / LOG-B2ES7H,
/// 2026-11-20): one connection at a time, an immediate first reopen, the
/// HLS warnings in Send log. Windows / macOS / Linux unchanged.
void main() {
  test('iPhone streams use one HLS connection at a time', () {
    expect(desktopLavfOptions(apple: true), contains('http_multiple=0'));
    expect(desktopLavfOptions(apple: true),
        startsWith('reconnect=1,reconnect_at_eof=1,reconnect_streamed=1'));
  });

  test('computers keep the same ffmpeg options as before', () {
    expect(
      desktopLavfOptions(apple: false),
      'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,'
      'reconnect_delay_max=5,rw_timeout=30000000',
    );
  });

  test('the first reopen after an end goes at once on the iPhone only', () {
    expect(DesktopLiveRecovery.waitFor('ended', 1, quick: true), 0);
    expect(DesktopLiveRecovery.waitFor('ended', 2, quick: true), 4);
    expect(DesktopLiveRecovery.waitFor('error', 1, quick: true), 2);
    expect(DesktopLiveRecovery.waitFor('stalled', 1, quick: true), 2);
    expect(DesktopLiveRecovery.waitFor('ended', 1, quick: false), 2);
    expect(DesktopLiveRecovery.waitFor('no video', 9, quick: true), 30);
  });

  test('HLS reader warnings reach Send log, decoder warnings do not', () {
    expect(
        isHlsTroubleLog('ffmpeg/demuxer', 'hls: Failed to reload playlist 0'),
        isTrue);
    expect(
        isHlsTroubleLog(
            'ffmpeg/demuxer', 'hls: Failed to open segment 1234 of playlist 0'),
        isTrue);
    expect(isHlsTroubleLog('lavf', 'EOF reached'), isTrue);
    expect(isHlsTroubleLog('ffmpeg/video', 'h264: no frame!'), isFalse);
    expect(
        isHlsTroubleLog('ffmpeg/demuxer', 'mpegts: Packet corrupt'), isFalse);
  });
}
