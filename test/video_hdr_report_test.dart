import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/video_hdr_report.dart';

void main() {
  test('missing or unsupported HDR is unknown rather than SDR', () {
    for (final value in [null, 'unknown', '', 'unsupported']) {
      expect(VideoHdrReport.label({'hdr': value}), 'Unknown / not reported');
    }
    expect(VideoHdrReport.label({'hdr': 'sdr', 'hdrSource': 'stream'}),
        'No (SDR) (stream)');
  });
  test('decoder fallback and stream evidence identify their source', () {
    expect(VideoHdrReport.label({'hdr': 'hdr10', 'hdrSource': 'decoder'}),
        'HDR10 (decoder)');
    expect(VideoHdrReport.label({'hdr': 'hlg', 'hdrSource': 'stream'}),
        'HLG (stream)');
  });
  test('Dolby Vision profile and fallback details are retained', () {
    expect(
        VideoHdrReport.label(
            {'hdr': 'dolby_vision', 'hdrSource': 'stream', 'dvProfile': 7}),
        'Dolby Vision (profile 7, HDR10 compatible) (stream)');
    expect(
        VideoHdrReport.label(
            {'hdr': 'dolby_vision', 'hdrSource': 'stream', 'dvProfile': 5}),
        'Dolby Vision (profile 5, no HDR10 fallback) (stream)');
    expect(
        VideoHdrReport.label({
          'hdr': 'dolby_vision',
          'hdrSource': 'stream',
          'dvProfile': 8,
          'dvBase': 'hlg'
        }),
        'Dolby Vision (profile 8, HLG compatible) (stream)');
  });
  test('conflicting decoder information is shown separately', () {
    expect(
        VideoHdrReport.decoderDifference(
            {'streamHdr': 'hdr10', 'decoderHdr': 'sdr'}),
        'No (SDR)');
    for (final decoded in ['hdr10', 'unknown', null]) {
      expect(
          VideoHdrReport.decoderDifference(
              {'streamHdr': 'hdr10', 'decoderHdr': decoded}),
          isNull);
    }
    expect(
        VideoHdrReport.decoderDifference(
            {'streamHdr': 'unknown', 'decoderHdr': 'hdr10'}),
        isNull);
  });
}
