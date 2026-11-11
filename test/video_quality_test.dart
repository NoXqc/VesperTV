import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/video_quality.dart';

/// The player's quality badge, from the decoded picture's real size:
/// 720p HD, 1080p FHD, 2160p 4K. A film wider than 16:9 must not lose its
/// badge (user report, 2026-10-21: a 4K Media Hub movie, 3840x1600,
/// showed HD).
void main() {
  test('16:9 broadcast sizes', () {
    expect(qualityLabelForTrack(height: 2160, width: 3840), '4K');
    expect(qualityLabelForTrack(height: 1080, width: 1920), 'FHD');
    expect(qualityLabelForTrack(height: 720, width: 1280), 'HD');
    expect(qualityLabelForTrack(height: 576, width: 720), isNull);
    expect(qualityLabelForTrack(height: 480, width: 854), isNull);
  });

  test('cinema-wide films keep their badge', () {
    expect(qualityLabelForTrack(height: 1600, width: 3840), '4K');
    expect(qualityLabelForTrack(height: 1608, width: 3836), '4K');
    expect(qualityLabelForTrack(height: 800, width: 1920), 'FHD');
    expect(qualityLabelForTrack(height: 536, width: 1280), 'HD');
    expect(qualityLabelForTrack(height: 360, width: 864), isNull);
  });

  test('crops a few lines short of the nominal size keep their badge', () {
    // 4K IMAX-ratio (1.50:1) Dolby Vision film, owner's photo 2026-11-11.
    expect(qualityLabelForTrack(height: 2156, width: 3236), '4K');
    expect(qualityLabelForTrack(height: 2076, width: 3840), '4K');
    expect(qualityLabelForTrack(height: 1076, width: 1616), 'FHD');
    expect(qualityLabelForTrack(height: 716, width: 1076), 'HD');
    // QHD stays FHD; 1080p never reaches 4K.
    expect(qualityLabelForTrack(height: 1440, width: 2560), 'FHD');
    expect(qualityLabelForTrack(height: 1080, width: 1920), 'FHD');
  });

  test('no width reported: height alone, as before', () {
    expect(qualityLabelForTrack(height: 2160), '4K');
    expect(qualityLabelForTrack(height: 1600), 'FHD');
    expect(qualityLabelForTrack(height: 720), 'HD');
    expect(qualityLabelForTrack(height: 576), isNull);
  });
}
