import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/video_quality.dart';

/// The player's quality badge, from the decoded picture's real size. A film
/// wider than 16:9 must not lose its badge (user report, 2026-10-21: a 4K
/// Media Hub movie, 3840x1600, showed HD).
void main() {
  test('16:9 broadcast sizes', () {
    expect(qualityLabelForTrack(height: 2160, width: 3840), '4K');
    expect(qualityLabelForTrack(height: 1080, width: 1920), 'HD');
    expect(qualityLabelForTrack(height: 1080, width: 1920, frameRate: 59.94),
        'FHD');
    expect(qualityLabelForTrack(height: 720, width: 1280), isNull);
  });

  test('cinema-wide films keep their badge', () {
    expect(qualityLabelForTrack(height: 1600, width: 3840), '4K');
    expect(qualityLabelForTrack(height: 1608, width: 3836), '4K');
    expect(qualityLabelForTrack(height: 800, width: 1920), 'HD');
    expect(qualityLabelForTrack(height: 536, width: 1280), isNull);
  });

  test('no width reported: height alone, as before', () {
    expect(qualityLabelForTrack(height: 2160), '4K');
    expect(qualityLabelForTrack(height: 1600), 'HD');
  });
}
