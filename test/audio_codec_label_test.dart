import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';
import 'package:nox_iptv/widgets/data_pool_card.dart';

void main() {
  test('Atmos comes from the codec, never from 5.1 or bitrate', () {
    // The player reads E-AC-3 JOC from the audio frames (.ts streams).
    expect(DataPoolCard.isAtmos('eac3-joc'), isTrue);
    // HLS/DASH manifests name it ec+3.
    expect(DataPoolCard.isAtmos('ec+3'), isTrue);
    expect(DataPoolCard.isAtmos('audio/eac3'), isFalse);
    expect(DataPoolCard.isAtmos('ec-3'), isFalse);
    expect(DataPoolCard.isAtmos(null), isFalse);
    // MKV TrueHD whose first frame has the 16-channel presentation.
    expect(DataPoolCard.isAtmos('truehd-atmos'), isTrue);
    expect(DataPoolCard.isAtmos('truehd'), isFalse);
  });

  test('TrueHD Atmos keeps its codec name', () {
    expect(DataPoolCard.codecName('truehd-atmos'), 'TrueHD Atmos');
    expect(DataPoolCard.codecName('ec+3'), 'E-AC-3 Atmos');
  });

  test('audio track names say their language', () {
    // Owner, 2026-11-09: English tracks named only "Original".
    expect(audioTrackName('Original', 'en'), 'English (Original)');
    expect(audioTrackName('Original', 'eng'), 'English (Original)');
    expect(audioTrackName('English - TrueHD Atmos', 'en'),
        'English - TrueHD Atmos');
    expect(audioTrackName('ENG', 'eng'), 'ENG');
    expect(audioTrackName('French', 'fr'), 'French');
    expect(audioTrackName(null, 'en'), 'English');
    expect(audioTrackName('Commentary', 'und'), 'Commentary');
    expect(audioTrackName('', 'mul'), '');
    expect(audioTrackName(null, null), '');
  });

  test('.ts streams report MIME types; they get readable names', () {
    expect(DataPoolCard.codecName('eac3-joc'), 'E-AC-3 Atmos');
    expect(DataPoolCard.codecName('audio/eac3'), 'E-AC-3');
    expect(DataPoolCard.codecName('audio/ac3'), 'AC-3');
    expect(DataPoolCard.codecName('audio/mp4a-latm'), 'AAC');
    expect(DataPoolCard.codecName('truehd'), 'TrueHD');
    expect(DataPoolCard.codecName('audio/vnd.dts.hd'), 'DTS-HD');
    expect(DataPoolCard.codecName('audio/vnd.dts'), 'DTS');
    expect(DataPoolCard.codecName('ec-3'), 'E-AC-3');
    expect(DataPoolCard.codecName('avc1.640028'), 'H.264');
  });
}
