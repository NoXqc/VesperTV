import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/widgets/provider_expiry_overlay.dart';

/// "Subscription ends in N days" (Kal-el23, Discord 2026-11-18).
void main() {
  final now = DateTime(2026, 11, 18, 14, 30);
  PlaylistProfile p(String name, DateTime? expires, {bool enabled = true}) =>
      PlaylistProfile(
        id: name,
        name: name,
        mode: 'xtream',
        sortOrder: 0,
        createdAt: DateTime(2026),
        expiresAt: expires,
        enabled: enabled,
      );

  test('within a week or ended lately, soonest first, whole days', () {
    final list = expiringPlaylists([
      p('Later', DateTime(2026, 12, 20)),
      p('Five', DateTime(2026, 11, 23, 2)),
      p('Today', DateTime(2026, 11, 18, 23)),
      p('Ended', DateTime(2026, 11, 10)),
      p('Long gone', DateTime(2026, 9, 1)),
      p('No date', null),
      p('Off', DateTime(2026, 11, 19), enabled: false),
    ], now);
    expect([for (final (pl, d) in list) '${pl.name}:$d'],
        ['Ended:-8', 'Today:0', 'Five:5']);
  });

  test('exactly a week away still warns, eight days does not', () {
    final list = expiringPlaylists([
      p('Seven', DateTime(2026, 11, 25, 12)),
      p('Eight', DateTime(2026, 11, 26, 12)),
    ], now);
    expect([for (final (pl, _) in list) pl.name], ['Seven']);
  });
}
