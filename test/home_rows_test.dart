import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/home_rows.dart';

void main() {
  test('a new viewer gets every row in the default order', () {
    final rows = HomeRows.parse(null);
    expect(rows.visible, HomeRowKind.values);
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
    // Rows added in a later version are appended, shown.
    expect(rows.visible, contains(HomeRowKind.newShows));
    expect(HomeRows.parse(rows.encoded).encoded, rows.encoded);
  });

  test('moving skips hidden rows and stops at the ends', () {
    final rows = HomeRows.parse([
      'games',
      '-continue',
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
    expect(rows.hidden, {HomeRowKind.continueWatching});
  });
}
