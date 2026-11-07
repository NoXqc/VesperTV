import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_ai.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_commands.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';

/// Vesper voice search tuning (user report, 2026-11-06): "TSN 1" heard as
/// "TSN one" found nothing and played Sportsnet One; asking for all TSN /
/// CBS east and west, a PPV category or the English feed of a game.
void main() {
  List<String> rank(List<String> names, String q, {int limit = 20}) =>
      rankByName(names, q, (n) => n, limit: limit);

  const channels = [
    'CA: Sportsnet One',
    'CA: Sportsnet 360',
    'CA: TSN 10',
    'CA: TSN 1 HD',
    'CA: TSN 1',
    'CA: TSN 2',
    'CA: TSN 3',
    'CA: TSN 4',
    'CA: TSN 5',
    'TSN1 4K',
    'US: CBS East',
    'US: CBS West',
    'US: CBS Sports Network',
  ];

  group('spoken channel names', () {
    test('a spoken number finds the digit, never Sportsnet', () {
      for (final q in ['TSN one', 'tsn 1', 'T S N 1', 't.s.n. one', 'TSN1']) {
        final found = rank(channels, q);
        expect(found.first, 'CA: TSN 1', reason: q);
        expect(found, isNot(contains('CA: Sportsnet One')), reason: q);
        expect(found.indexOf('CA: TSN 10'),
            greaterThan(found.indexOf('CA: TSN 1 HD')),
            reason: q);
      }
    });

    test('a digit finds a channel that spells its number', () {
      expect(rank(channels, 'sportsnet 1').first, 'CA: Sportsnet One');
      expect(rank(['BBC One', 'BBC Two'], 'bbc 2').single, 'BBC Two');
      expect(rank(['TSN 2'], 'TSN deux').single, 'TSN 2');
    });

    test('"TSN" lists every TSN, not Sportsnet', () {
      final found = rank(channels, 'tsn');
      expect(found, hasLength(8));
      expect(found.any((n) => n.contains('Sportsnet')), isFalse);
    });

    test('a piece of a word still matches when nothing better does', () {
      expect(rank(['CA: Sportsnet One'], 'tsn'), ['CA: Sportsnet One']);
    });

    test('number words in names fold the same way', () {
      expect(spokenTokens('CA: TSN1 HD'), ['ca', 'tsn', '1', 'hd']);
      expect(spokenTokens('T.S.N. One'), ['tsn', '1']);
    });
  });

  group('phrases', () {
    VesperCommand? p(String s) => parseVesperCommand(s);

    test('all of a name opens the search page to pick', () {
      for (final s in [
        'show me all TSN',
        'all TSN channels',
        'list every TSN channel',
        'show me the TSN channels',
        'which TSN channels are there',
        'montre-moi toutes les chaînes TSN',
        'todos los canales TSN',
      ]) {
        expect(p(s)?.args, {'section': 'search', 'query': 'tsn'}, reason: s);
      }
      expect(p('show me CBS west and east channels')?.args,
          {'section': 'search', 'query': 'cbs'});
      expect(p('show me all the movies')?.args, {'section': 'movies'});
      expect(p('play the all star game')?.tool, 'play_game');
    });

    test('which channels have a game: list them, never a team name', () {
      for (final s in [
        'which channel has the Habs game',
        'which channels have the habs game',
        'what channel is the habs game on',
        'what are the habs feeds for tonight\'s game',
        'where can I watch the Habs game tonight',
        'quelle chaîne passe le match du Canadien',
        'sur quelle chaîne est le match du canadien',
        'qué canal tiene el partido del habs',
        'welcher Sender zeigt das Spiel von habs',
      ]) {
        expect(p(s)?.tool, 'play_game', reason: s);
        expect(p(s)?.args['list'], isTrue, reason: s);
      }
      expect(p('which channel has the Habs game')?.args['team'], 'habs');
      expect(p('what are the montreal canadiens feeds for tonights game')?.args,
          {'team': 'montreal canadiens', 'list': true});
      expect(p('quelle chaîne passe le match du Canadien')?.args['team'],
          'canadien');
      // A team playing, no "game" word.
      for (final (s, team) in [
        (
          'What channel are the Montreal Canadiens playing tonight',
          'montreal canadiens'
        ),
        ('what channel are the habs playing on', 'habs'),
        ('what channel do the Leafs play on tonight', 'leafs'),
        ('on which channel are the habs playing today', 'habs'),
        ('sur quelle chaîne jouent les Canadiens ce soir', 'canadiens'),
        ('à quel poste joue le Canadien', 'canadien'),
      ]) {
        expect(p(s)?.args, {'team': team, 'list': true}, reason: s);
      }
      expect(p('what channel is jeopardy on')?.args['list'], isNot(isTrue));
      // An odd question is no game to play.
      expect(p('is there a habs game'), isNull);
      expect(p('put on the habs game')?.args, {'team': 'habs'});
    });

    test('play it on a channel of that game', () {
      for (final s in [
        'play it on RDS',
        'put it on RDS',
        'watch that on RDS',
        'mets-le sur RDS',
        'mets le match sur RDS',
      ]) {
        expect(p(s)?.tool, 'play_feed', reason: s);
        expect(p(s)?.args, {'name': 'rds'}, reason: s);
      }
      // Plain channel commands unchanged.
      expect(p('put on RDS')?.tool, 'play');
      expect(p('switch to the guide')?.args, {'section': 'guide'});
    });

    test('the bubble lists each channel once, other languages marked', () {
      final reply = VesperAi.describeResult(
          const VesperCommand('play_game', {'team': 'habs', 'list': true}), {
        'games': [
          {
            'game': 'Canadiens at Maple Leafs',
            'channels': [
              {'ref': 'l1', 'title': 'CA: Sportsnet One', 'language': 'en'},
              {'ref': 'l2', 'title': 'CA: RDS', 'language': 'fr'},
              {'ref': 'l3', 'title': 'CA: RDS', 'language': 'fr'},
              {'ref': 'l4', 'title': 'NHL Center Ice 4'},
            ],
          }
        ],
      });
      expect(
          reply.text,
          'Canadiens at Maple Leafs: CA: Sportsnet One · CA: RDS (FR) · '
          'NHL Center Ice 4');
      final none = VesperAi.describeResult(
          const VesperCommand('play_game', {'team': 'habs', 'list': true}), {
        'games': [
          {'game': 'Canadiens at Maple Leafs', 'channels': []}
        ],
      });
      expect(none.text, contains('No channel'));
    });

    test('a title in a place: the Media Hub searches it itself', () {
      for (final s in [
        'open Carrie in Media Hub',
        'find carrie in the hub',
        'search for Carrie in the Media Hub',
        'cherche Carrie dans le Media Hub',
      ]) {
        expect(p(s)?.args, {'section': 'hub', 'query': 'carrie'}, reason: s);
      }
      expect(p('find dune in movies')?.args,
          {'section': 'search', 'query': 'dune'});
      expect(p('media hub')?.args, {'section': 'hub'});
      expect(p('open the media hub')?.args, {'section': 'hub'});
    });

    test('a category opens that group', () {
      expect(p('open PPV')?.args, {'section': 'group', 'query': 'ppv'});
      expect(p('open pay per view')?.args,
          {'section': 'group', 'query': 'pay per view'});
      expect(p('go to the live events category')?.args,
          {'section': 'group', 'query': 'live events'});
      expect(p('ouvre la catégorie PPV')?.args,
          {'section': 'group', 'query': 'ppv'});
      // Still sections / channels.
      expect(p('open the guide')?.args, {'section': 'guide'});
      expect(p('switch to TSN 1')?.tool, 'play');
      expect(p('open channel 5')?.tool, isNot('open'));
    });

    test('a game in a language', () {
      for (final s in [
        'find the English feed of the Habs game',
        'play the habs game in english',
        'the english broadcast of the habs game',
      ]) {
        expect(p(s)?.tool, 'play_game', reason: s);
        expect(p(s)?.args, {'team': 'habs', 'language': 'en'}, reason: s);
      }
      expect(p('le match du canadien en français')?.args,
          {'team': 'canadien', 'language': 'fr'});
      expect(p('put on the habs game')?.args, {'team': 'habs'});
      expect(
          p('play the English Premier League game')?.args['language'], isNull);
    });
  });

  group('feed language', () {
    Channel ch(String name, [String group = '']) => Channel(
        id: 'p::$name',
        rawId: name,
        playlistId: 'p',
        name: name,
        group: group,
        url: 'http://x/1.ts');

    test('names, groups and networks say the language', () {
      expect(vesperChannelLanguage(ch('CA: TSN 2')), 'en');
      expect(vesperChannelLanguage(ch('CA: RDS')), 'fr');
      expect(vesperChannelLanguage(ch('TVA Sports', 'CA| SPORTS')), 'fr');
      expect(vesperChannelLanguage(ch('Sportsnet One', 'CANADA FR')), 'fr');
      expect(vesperChannelLanguage(ch('US: ESPN')), 'en');
      expect(vesperChannelLanguage(ch('ESPN Deportes')), 'es');
      expect(vesperChannelLanguage(ch('FR: Canal+ Sport')), 'fr');
      expect(vesperChannelLanguage(ch('beIN Sports 1')), isNull);
    });
  });
}
