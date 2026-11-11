import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/home_rows.dart';

void main() {
  test('a new viewer gets every row in the default order', () {
    final rows = HomeRows.parse(null);
    // Media Hub collections go under Continue Watching and its rows.
    expect(rows.visible, [
      HomeRowKind.games,
      HomeRowKind.continueWatching,
      HomeRowKind.newEpisodes,
      HomeRowKind.watchList,
      HomeRowKind.collections,
      HomeRowKind.recentChannels,
      HomeRowKind.favourites,
      HomeRowKind.newMovies,
      HomeRowKind.newShows,
    ]);
    expect(rows.hidden, isEmpty);
  });

  test('saved order and hidden rows round-trip; unknown ids are dropped', () {
    final rows = HomeRows.parse(['favourites', '-games', 'bogus', 'recent']);
    expect(rows.order.take(3), [
      HomeRowKind.favourites,
      HomeRowKind.games,
      HomeRowKind.recentChannels
    ]);
    expect(rows.hidden, {HomeRowKind.games});
    // Rows added in a later version are appended, shown; New episodes goes
    // under Continue Watching.
    expect(rows.visible, contains(HomeRowKind.newShows));
    final continueAt = rows.order.indexOf(HomeRowKind.continueWatching);
    expect(rows.order[continueAt + 1], HomeRowKind.newEpisodes);
    expect(rows.order[continueAt + 2], HomeRowKind.watchList);
    expect(rows.order[continueAt + 3], HomeRowKind.collections);
    expect(HomeRows.parse(rows.encoded).encoded, rows.encoded);
  });

  test('moving skips hidden rows and stops at the ends', () {
    final rows = HomeRows.parse([
      'games',
      '-continue',
      '-new_episodes',
      '-watchlist',
      '-collections',
      'recent',
      'favourites',
      'new_movies',
      'new_shows'
    ]);
    rows.move(HomeRowKind.recentChannels, -1); // over hidden Continue
    expect(rows.visible.first, HomeRowKind.recentChannels);
    rows.move(HomeRowKind.recentChannels, -1); // already first
    expect(rows.visible.first, HomeRowKind.recentChannels);
    rows.move(HomeRowKind.newShows, 1); // already last
    expect(rows.visible.last, HomeRowKind.newShows);
    expect(rows.hidden, {
      HomeRowKind.continueWatching,
      HomeRowKind.newEpisodes,
      HomeRowKind.watchList,
      HomeRowKind.collections
    });
  });
}
