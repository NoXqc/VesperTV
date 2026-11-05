import 'package:flutter_test/flutter_test.dart';
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
