import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/fr.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/l10n/pl.dart';
import 'package:nox_iptv/l10n/uk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Ukrainian covers every French and Polish key', () {
    expect(kFr.keys.where((k) => !kUk.containsKey(k)), isEmpty);
    expect(kPl.keys.where((k) => !kUk.containsKey(k)), isEmpty);
  });

  test('Ukrainian keeps every {placeholder} of its English key', () {
    final re = RegExp(r'\{[a-zA-Z0-9_]+\}');
    // `{s}` after a letter is English's plural "s" ("day{s}"); Ukrainian
    // rephrases those strings without it.
    final pluralS = RegExp(r'(?<=[a-z])\{s\}');
    for (final e in kUk.entries) {
      final key = e.key.replaceAll(RegExp(r'#(few|one)$'), '');
      final want = re
          .allMatches(key.replaceAll(pluralS, ''))
          .map((m) => m[0])
          .toList()
        ..sort();
      final got = re.allMatches(e.value).map((m) => m[0]).toList()..sort();
      expect(got, want, reason: e.key);
    }
  });

  test('picking Ukrainian translates the UI and score statuses', () async {
    await L10n.apply('uk');
    expect(L10n.code, 'uk');
    expect(tr('Settings'), 'Налаштування');
    expect(tr('Season {season}', {'season': 2}), 'Сезон 2');
    expect(trSports('Final'), 'Завершено');
    expect(trSports('2OT'), '2-й ОТ');
    await L10n.apply('en');
  });

  test('Ukrainian plurals use the one / few / many forms', () async {
    await L10n.apply('uk');
    String playlists(int n) => trPlural(n, '{n} playlist', '{n} playlists');
    expect(playlists(1), '1 плейлист');
    expect(playlists(2), '2 плейлисти');
    expect(playlists(4), '4 плейлисти');
    expect(playlists(5), '5 плейлистів');
    expect(playlists(11), '11 плейлистів');
    expect(playlists(12), '12 плейлистів');
    expect(playlists(21), '21 плейлист');
    expect(playlists(22), '22 плейлисти');
    expect(playlists(111), '111 плейлистів');
    await L10n.apply('en');
    expect(trPlural(21, '{n} playlist', '{n} playlists'), '21 playlists');
  });
}
