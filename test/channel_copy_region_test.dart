import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/channel_copy_fallback.dart';
import 'package:nox_iptv/utils/channel_name_matching.dart';

/// Owner, 2026-11-18: playing `QC: TVA MONTREAL` (Blcktv), the player's
/// Sources didn't offer `CA| TVA MONTREAL HD` from his Trex playlist; he had
/// to add it by hand.
void main() {
  Channel ch(String playlist, String raw, String name) => Channel(
      id: '$playlist::$raw',
      rawId: raw,
      playlistId: playlist,
      name: name,
      group: 'QC',
      url: 'http://$playlist/$raw.ts');

  test('QC and CA tags are one country', () {
    expect(channelCopyKey('QC: TVA MONTREAL'),
        channelCopyKey('CA| TVA MONTREAL HD'));
    expect(channelCopyKey('QUEBEC - TVA MONTREAL'),
        channelCopyKey('CA: TVA MONTREAL'));
    expect(channelCopyKey('USA: ESPN'), channelCopyKey('US| ESPN HD'));
    expect(channelCopyKey('GB: SKY SPORTS MAIN EVENT'),
        channelCopyKey('UK| SKY SPORTS MAIN EVENT FHD'));
  });

  test('different countries stay apart', () {
    expect(channelCopyKey('US: ESPN'), isNot(channelCopyKey('CA: ESPN')));
    expect(channelCopyKey('FR: TV5'), isNot(channelCopyKey('CA: TV5')));
    expect(channelCopyKey('QC: TVA MONTREAL'),
        isNot(channelCopyKey('QC: TVA QUEBEC')));
  });

  test('accents do not count', () {
    expect(channelCopyKey('QC: TVA MONTRÉAL'),
        channelCopyKey('CA| TVA MONTREAL HD'));
    expect(
        channelCopyKey('QC: TÉLÉ-QUÉBEC'), channelCopyKey('CA: TELE QUEBEC'));
    expect(
        channelCopyKey('CA: CANAL VIE'), isNot(channelCopyKey('CA: CANAL D')));
  });

  test('ESPN+ and quality tags keep their old meaning', () {
    expect(channelCopyKey('US: ESPN+'), isNot(channelCopyKey('US: ESPN')));
    expect(channelCopyKey('CA| TSN2 FHD'), channelCopyKey('CA| TSN 2 HD'));
  });

  test('the Sources list finds the other playlist copy, accented or not', () {
    final playing = ch('blcktv', '1', 'QC: TVA MONTREAL');
    final trex = [
      ch('trex', '9', 'CA| TVA MONTREAL HD'),
      ch('trex', '10', 'CA| TVA MONTRÉAL 4K'),
      ch('trex', '11', 'CA| TVA SPORTS'),
      ch('trex', '12', 'CA| NOOVO MONTREAL'),
    ];
    expect(
        ChannelCopyFallback.copiesOf(playing, trex).map((c) => c.name).toSet(),
        {'CA| TVA MONTREAL HD', 'CA| TVA MONTRÉAL 4K'});
  });
}
