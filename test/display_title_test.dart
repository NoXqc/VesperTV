import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/display_title.dart';

void main() {
  test('quality prefix with a colon is dropped', () {
    expect(cleanDisplayTitle('4KDV: 9 Hours (2022)'), '9 Hours');
    expect(cleanDisplayTitle('4K: 4 Blocks Zero (2026)'), '4 Blocks Zero');
    expect(cleanDisplayTitle('4K: 13th: Some Lessons'), '13th: Some Lessons');
    expect(cleanDisplayTitle('UHD HDR: Dune'), 'Dune');
    expect(cleanDisplayTitle('4K-DV: Dune'), 'Dune');
  });

  test('a real title colon stays', () {
    expect(cleanDisplayTitle('CSI: Miami'), 'CSI: Miami');
    expect(cleanDisplayTitle('Star Wars: Andor'), 'Star Wars: Andor');
    expect(cleanDisplayTitle('EN - 4K: Dune'), 'Dune');
  });
}
