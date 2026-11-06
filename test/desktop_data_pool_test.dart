import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/desktop_data_pool_card.dart';

/// Windows Data pool: mpv's property values turned into the card's words.
void main() {
  DesktopStreamStats stats(Map<String, String> values) =>
      DesktopStreamStats(values);

  test('container from mpv file-format', () {
    expect(stats({'file-format': 'hls,applehttp'}).container, 'HLS');
    expect(stats({'file-format': 'mpegts'}).container, 'MPEG-TS');
    expect(stats({'file-format': 'matroska,webm'}).container, 'MKV');
    expect(stats({'file-format': 'mov,mp4,m4a,3gp,3g2,mj2'}).container, 'MP4');
    expect(stats({}).container, 'Direct stream');
  });

  test('HDR from the transfer function, nothing without video', () {
    expect(stats({'video-params/gamma': 'pq'}).hdr, 'HDR10');
    expect(stats({'video-params/gamma': 'hlg'}).hdr, 'HLG');
    expect(stats({'video-params/gamma': 'bt.1886'}).hdr, 'SDR');
    expect(stats({}).hdr, isNull);
  });

  test('decoder: hardware API or software', () {
    expect(stats({'video-format': 'hevc', 'hwdec-current': 'd3d11va'}).decoder,
        'Hardware (d3d11va)');
    expect(stats({'video-format': 'h264', 'hwdec-current': 'no'}).decoder,
        'Software');
    expect(stats({'hwdec-current': 'no'}).decoder, isNull);
  });

  test('numbers parse, missing ones stay null', () {
    final s = stats({'video-params/w': '1920', 'container-fps': '59.940'});
    expect(s.integer('video-params/w'), 1920);
    expect(s.decimal('container-fps'), closeTo(59.94, 0.001));
    expect(s.integer('video-params/h'), isNull);
  });
}
