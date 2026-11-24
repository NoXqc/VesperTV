import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/launcher_channels.dart';

Map<String, Object?> _card(String key, String kind,
        {String type = 'movie',
        String title = 'Title',
        String? image = 'https://img.example/a.jpg',
        String aspect = 'wide',
        int? season,
        int? episode,
        int? position,
        int? duration}) =>
    {
      'key': key,
      'kind': kind,
      'type': type,
      'title': title,
      'image': image,
      'aspect': aspect,
      'season': season,
      'episode': episode,
      'position': position,
      'duration': duration,
    };

void main() {
  test('rows in order, empty ones left out', () {
    final shelf = LauncherChannels.topShelf(watchNext: [
      _card('c1', 'continue', position: 600000, duration: 1200000),
      _card('w1', 'watchlist', aspect: 'poster'),
      _card('n1', 'next', type: 'episode', season: 2, episode: 3),
    ], favourites: [
      _card('f1', 'row', type: 'channel', title: 'TSN 1'),
    ]);
    final rows = (shelf['rows'] as List).cast<Map<String, Object?>>();
    expect(rows.map((r) => r['title']),
        ['Continue Watching', 'Watch list', 'Favourite channels']);
    final continuing = (rows[0]['items'] as List).cast<Map<String, Object?>>();
    expect(continuing.map((i) => i['id']), ['c1', 'n1']);
    expect(continuing[0]['progress'], 0.5);
    expect(continuing[1]['title'], 'Title · S2E3');
    expect(continuing[1].containsKey('progress'), isFalse);
    final watchList = (rows[1]['items'] as List).single as Map;
    expect(watchList['shape'], 'poster');
    final channel = (rows[2]['items'] as List).single as Map;
    expect(channel['shape'], 'square');
    expect(channel['title'], 'TSN 1');
  });

  test('each item opens the app on its key, like an Android launcher link', () {
    final shelf = LauncherChannels.topShelf(
        watchNext: [_card('hub:ab12/=+', 'new')], favourites: const []);
    final item =
        ((shelf['rows'] as List).single as Map)['items'] as List<Object?>;
    final link = Uri.parse((item.single as Map)['link'] as String);
    expect(link.scheme, 'vespertv');
    expect(link.host, 'launcher');
    expect(link.queryParameters['k'], 'hub:ab12/=+');
  });

  test('no picture: no image key; nothing at all: no rows', () {
    final shelf = LauncherChannels.topShelf(
        watchNext: [_card('c1', 'continue', image: null)],
        favourites: const []);
    final item = (((shelf['rows'] as List).single as Map)['items'] as List)
        .single as Map;
    expect(item.containsKey('image'), isFalse);
    expect(
        LauncherChannels.topShelf(
            watchNext: const [], favourites: const [])['rows'],
        isEmpty);
  });
}
