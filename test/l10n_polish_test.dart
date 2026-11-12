import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/fr.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/l10n/pl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Polish covers every French key', () {
    expect(kFr.keys.where((k) => !kPl.containsKey(k)), isEmpty);
  });

  test('Polish keeps every {placeholder} of its English key', () {
    final re = RegExp(r'\{[a-zA-Z0-9_]+\}');
    // `{s}` after a letter is English's plural "s" ("day{s}"); Polish
    // rephrases those strings without it.
    final pluralS = RegExp(r'(?<=[a-z])\{s\}');
    for (final e in kPl.entries) {
      final key = e.key.replaceAll(RegExp(r'#few$'), '');
      final want = re
          .allMatches(key.replaceAll(pluralS, ''))
          .map((m) => m[0])
          .toList()
        ..sort();
      final got = re.allMatches(e.value).map((m) => m[0]).toList()..sort();
      expect(got, want, reason: e.key);
    }
  });

  test('picking Polish translates the UI and score statuses', () async {
    await L10n.apply('pl');
    expect(L10n.code, 'pl');
    expect(tr('Settings'), 'Ustawienia');
    expect(tr('Season {season}', {'season': 2}), 'Sezon 2');
    expect(trSports('Final'), 'Koniec');
    expect(trSports('2OT'), '2. dogr.');
    await L10n.apply('en');
  });

  test('Polish plurals use the one / few / many forms', () async {
    await L10n.apply('pl');
    String playlists(int n) => trPlural(n, '{n} playlist', '{n} playlists');
    expect(playlists(1), '1 playlista');
    expect(playlists(2), '2 playlisty');
    expect(playlists(4), '4 playlisty');
    expect(playlists(5), '5 playlist');
    expect(playlists(12), '12 playlist');
    expect(playlists(14), '14 playlist');
    expect(playlists(22), '22 playlisty');
    expect(playlists(112), '112 playlist');
    expect(trPlural(1, '{n} day', '{n} days'), '1 dzień');
    expect(trPlural(3, '{n} day', '{n} days'), '3 dni');
    await L10n.apply('en');
    expect(trPlural(2, '{n} playlist', '{n} playlists'), '2 playlists');
  });
}
