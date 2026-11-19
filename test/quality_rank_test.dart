import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/channel_copy_fallback.dart';

/// The version before the one-scan rewrite (2026-11-19): the rewrite must
/// rank every name the same.
int _oldRank(String name) {
  final words = name
      .toUpperCase()
      .replaceAll(RegExp(r'[^\w+]'), ' ')
      .split(RegExp(r'\s+'))
      .toSet();
  if (words.contains('8K')) return 6;
  if (words.contains('4K') || words.contains('UHD')) return 5;
  if (words.contains('FHD') || words.contains('1080P')) return 4;
  if (words.contains('HD') || words.contains('720P')) return 3;
  if (words.contains('SD')) return 1;
  return 2;
}

void main() {
  test('qualityRank ranks names as before', () {
    final names = [
      '',
      'CNN',
      'UK| SKY SPORTS MAIN EVENT FHD',
      'UK: BBC One HD',
      'UK: BBC One hd',
      'BBC One SD',
      'BBC One HD SD',
      'SD HD FHD 4K 8K',
      'TSN 1 4K',
      'TSN 1 (4K)',
      'TSN1-4K',
      'TSN 1 4K+',
      'HD+',
      'CANAL+ HD',
      'ESPN UHD',
      'ESPN 1080p',
      'ESPN 720P',
      'HDTV',
      'SDTV',
      'FHD_',
      '_HD',
      'HD_1',
      'NHD',
      '4KHD',
      'US: FOX ᴴᴰ',
      'UK| TNT SPORT ᴴᴰ ᵛᶦᵖ',
      'Ⓗⓓ',
      'DE: Das Erste HD|FHD',
      '|HD|',
      'HD:',
      '8k',
      'uhd',
      'Fhd',
      'Sky Sports F1 UHD 3840P (LIVE DURING EVENTS ONLY)',
      'CA: TSN 4 (East) HEVC',
      'UK: BBC 2 RAW 50FPS',
      'Ελληνικά HD',
      'ÉTÉ SD',
    ];
    for (final n in names) {
      expect(ChannelCopyFallback.qualityRank(n), _oldRank(n), reason: n);
    }
    // Generated names: every tag in many spots.
    const tags = ['HD', 'SD', 'FHD', '4K', 'UHD', '8K', '720P', '1080P', 'RAW'];
    const glue = [' ', '|', ':', '-', '_', '+', '(', ')', '.', ''];
    for (final t in tags) {
      for (final a in glue) {
        for (final b in glue) {
          for (final n in ['X$a$t${b}Y', '$t${b}Y', 'X$a$t', t.toLowerCase()]) {
            expect(ChannelCopyFallback.qualityRank(n), _oldRank(n), reason: n);
          }
        }
      }
    }
  });
}
