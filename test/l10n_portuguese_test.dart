import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/fr.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/l10n/pt.dart';

/// European Portuguese (pt-PT): Ricardo Simões' translation (PR #19), the
/// strings added after it started filled in the same style.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Portuguese covers every French key', () {
    expect(kFr.keys.where((k) => !kPt.containsKey(k)), isEmpty);
  });

  test('Portuguese keeps every {placeholder} of its English key', () {
    final re = RegExp(r'\{[a-zA-Z0-9_]+\}');
    // `{s}` after a letter is English's plural "s" ("day{s}"); Portuguese
    // rephrases those strings without it.
    final pluralS = RegExp(r'(?<=[a-z])\{s\}');
    for (final e in kPt.entries) {
      final want = re
          .allMatches(e.key.replaceAll(pluralS, ''))
          .map((m) => m[0])
          .toList()
        ..sort();
      final got = re.allMatches(e.value).map((m) => m[0]).toList()..sort();
      expect(got, want, reason: e.key);
    }
  });

  test('picking Portuguese translates the UI and score statuses', () async {
    await L10n.apply('pt');
    expect(L10n.code, 'pt');
    expect(tr('Settings'), 'Definições');
    expect(tr('Season {season}', {'season': 2}), 'Temporada 2');
    expect(trSports('Final'), 'Final');
    expect(trSports('Halftime'), 'Intervalo');
    expect(trSports('2OT'), '2.º prol.');
    await L10n.apply('en');
    expect(tr('Settings'), 'Settings');
  });
}
