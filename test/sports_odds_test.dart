import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/sports_service.dart';

void main() {
  test('current lines from moneyline / pointSpread / total', () {
    final odds = sportsOddsOf([
      {
        'provider': {'name': 'DraftKings', 'displayName': 'DraftKings'},
        'details': 'VGK -115',
        'overUnder': 6.5,
        'moneyline': {
          'home': {
            'close': {
              'odds': '-115',
              'link': {'href': 'https://bet'}
            },
            'open': {'odds': '-125'}
          },
          'away': {
            'close': {'odds': '-105'}
          },
        },
        'pointSpread': {
          'home': {
            'close': {'line': '-1.5', 'odds': '+215'}
          },
          'away': {
            'close': {'line': '+1.5', 'odds': '-270'}
          },
        },
        'total': {
          'over': {
            'close': {'line': 'o6.5', 'odds': '+110'}
          },
          'under': {
            'close': {'line': 'u6.5', 'odds': '-130'}
          },
        },
      }
    ])!;
    expect(odds.provider, 'DraftKings');
    expect(odds.line, 'VGK -115 · O/U 6.5');
    expect(odds.homeMoneyline, '-115');
    expect(odds.awayMoneyline, '-105');
    expect(odds.homeSpread, '-1.5');
    expect(odds.awaySpreadOdds, '-270');
    expect(odds.overOdds, '+110');
    expect(odds.underOdds, '-130');
  });

  test('older flat shape and soccer draw', () {
    final odds = sportsOddsOf([
      {
        'details': 'CHE -115',
        'overUnder': 2.5,
        'homeTeamOdds': {'moneyLine': -115},
        'awayTeamOdds': {'moneyLine': 290},
        'drawOdds': {'moneyLine': 285},
      }
    ])!;
    expect(odds.homeMoneyline, '-115');
    expect(odds.awayMoneyline, '+290');
    expect(odds.drawMoneyline, '+285');
    expect(odds.total, '2.5');
  });

  test('nothing usable = no odds', () {
    expect(sportsOddsOf(null), isNull);
    expect(sportsOddsOf(const []), isNull);
    expect(
        sportsOddsOf([
          {
            'provider': {'name': 'X'}
          }
        ]),
        isNull);
  });
}
