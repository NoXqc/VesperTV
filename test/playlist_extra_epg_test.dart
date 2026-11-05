import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';

void main() {
  test('extra guides (playlist editor) survive JSON and copyWith', () {
    final p = PlaylistProfile(
        id: 'p1',
        name: 'Main',
        mode: 'm3u',
        m3uUrl: 'http://x/list.m3u',
        epgUrl: 'http://x/guide.xml',
        sortOrder: 0,
        createdAt: DateTime(2026, 11, 5),
        extraEpgUrls: ['https://epg.example/uk.xml.gz']);
    final back = PlaylistProfile.fromJson(p.toJson());
    expect(back.extraEpgUrls, ['https://epg.example/uk.xml.gz']);
    expect(back.copyWith(name: 'Renamed').extraEpgUrls, back.extraEpgUrls);
    // Older saved profiles have none.
    final old = p.toJson()..remove('extraEpgUrls');
    expect(PlaylistProfile.fromJson(old).extraEpgUrls, isEmpty);
  });
}
