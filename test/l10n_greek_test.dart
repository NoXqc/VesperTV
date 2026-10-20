import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/el.dart';
import 'package:nox_iptv/l10n/fr.dart';
import 'package:nox_iptv/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Greek covers every French key', () {
    expect(kFr.keys.where((k) => !kEl.containsKey(k)), isEmpty);
  });

  test('picking Greek translates the UI and score statuses', () async {
    await L10n.apply('el');
    expect(L10n.code, 'el');
    expect(tr('Settings'), 'Ρυθμίσεις');
    expect(tr('Season {season}', {'season': 2}), 'Σεζόν 2');
    expect(trSports('Final'), 'Τελικό');
    expect(trSports('1st Half'), '1ο ημίχρονο');
    await L10n.apply('en');
  });
}
