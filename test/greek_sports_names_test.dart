import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/greek_sports_names.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';

void main() {
  test('Greek guide titles normalize to the feeds\' Latin names', () {
    expect(sportsNormalize('Ολυμπιακός - ΠΑΟΚ'), ' olympiakos paok ');
    expect(sportsNormalize('ΠΑΝΑΘΗΝΑΪΚΟΣ - ΑΕΚ'), ' panathinaikos aek ');
    expect(sportsNormalize('Λεβαδειακός - Άρης'), ' levadiakos aris ');
    expect(sportsNormalize('Κολοσσός Ρόδου'), ' kolossos rodou ');
    // Latin text is unchanged.
    expect(
        sportsNormalize('GR: Cosmote Sport 1 HD'), ' gr cosmote sport 1 hd ');
  });

  test('a feed team name finds its Greek spellings', () {
    final olympiacos = greekTeamFor(sportsNormalize('Olympiacos BC'))!;
    // The transliterated title's spelling is one of its phrases...
    expect(olympiacos.phrases, contains(' olympiakos '));
    // ...and a Greek stem the guide query can find.
    expect('Ολυμπιακός - ΠΑΟΚ'.contains(olympiacos.stems.first), isTrue);
    expect(greekTeamFor(sportsNormalize('Hajduk Split')), isNull);
  });

  test('the new leagues route to TheSportsDB with Greek channels first', () {
    for (final id in ['gre.2', 'basketball.euroleague', 'basketball.gre.1']) {
      expect(sportsLeagueById(id)?.sportsDbId, isNotNull, reason: id);
    }
    expect(sportsLeagueById('gre.1')!.homeTags, ['gr']);
    expect(sportsLeagueById('basketball.gre.1')!.homeTags, ['gr']);
  });

  test('Balkan and Turkish letters fold like other accents', () {
    expect(sportsNormalize('Košarka: Beşiktaş - Žalgiris'),
        ' kosarka besiktas zalgiris ');
    expect(sportsNormalize('Crvena zvezda - Partizan Đorđević'),
        ' crvena zvezda partizan dordevic ');
  });

  test('EuroLeague clubs in a Greek-only Nova title (Strong8K)', () {
    final title =
        sportsNormalize('Live: Μπάσκετ: Χάποελ Τελ Αβίβ - Βίρτους Μπολόνια');
    for (final feed in ['Hapoel Tel Aviv BC', 'Virtus Pallacanestro Bologna']) {
      final club = greekTeamFor(sportsNormalize(feed));
      expect(club, isNotNull, reason: feed);
      expect(club!.phrases.any(title.contains), isTrue, reason: feed);
      expect(
          club.stems.any('Χάποελ Τελ Αβίβ - Βίρτους Μπολόνια'.contains), isTrue,
          reason: feed);
    }
    // Every phrase is what sportsNormalize makes of the Greek spelling.
    for (final club in greekForeignTeamNames) {
      for (final p in club.phrases) {
        expect(p, startsWith(' '));
        expect(p, endsWith(' '));
      }
    }
  });
}
