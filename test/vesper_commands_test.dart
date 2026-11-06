import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_commands.dart';

void main() {
  VesperCommand? p(String s) => parseVesperCommand(s);

  group('player commands', () {
    test('pause / resume / stop in several languages', () {
      for (final s in [
        'Pause',
        'pause it',
        'Hey Vesper, pause',
        'mets pause',
        'pausa',
        'Pausieren'
      ]) {
        expect(p(s)?.tool, 'player', reason: s);
        expect(p(s)?.args['action'], 'pause', reason: s);
      }
      for (final s in ['resume', 'Play', 'reprends', 'continua', 'weiter']) {
        expect(p(s)?.args['action'], 'resume', reason: s);
      }
      for (final s in ['stop', 'arrête', 'Stopp']) {
        expect(p(s)?.args['action'], 'stop', reason: s);
      }
    });

    test('channel up / down and back to live', () {
      expect(p('next channel')?.args['action'], 'channel_up');
      expect(p('chaîne suivante')?.args['action'], 'channel_up');
      expect(p('previous channel')?.args['action'], 'channel_down');
      expect(p('back to live')?.args['action'], 'back_to_live');
      expect(p('retour au direct')?.args['action'], 'back_to_live');
    });

    test('seek with numbers, words and minutes', () {
      expect(p('go back 30 seconds')?.args, {'action': 'seek', 'seconds': -30});
      expect(p('rewind ten seconds')?.args['seconds'], -10);
      expect(p('skip 2 minutes')?.args['seconds'], 120);
      expect(p('recule de 5 minutes')?.args['seconds'], -300);
      expect(p('go back')?.args['seconds'], -30);
    });
  });

  group('play', () {
    test('a channel name after a play verb', () {
      expect(p('play TSN 1')?.args, {'name': 'tsn 1'});
      expect(p('Put on RDS')?.args, {'name': 'rds'});
      expect(p('mets la chaîne TVA')?.args, {'name': 'tva'});
      expect(p('switch to channel 5')?.args, {'name': '5'});
      expect(p('please watch CNN')?.tool, 'play');
    });

    test('movie / show words set the kind', () {
      expect(p('play the movie Dune')?.args, {'name': 'dune', 'kind': 'movie'});
      expect(p('watch the show Severance')?.args,
          {'name': 'severance', 'kind': 'series'});
    });

    test('a team game', () {
      expect(p('put on the Habs game')?.args, {'team': 'habs'});
      expect(p('le match du Canadien')?.args, {'team': 'canadien'});
      expect(p('pon el partido del Madrid')?.args, {'team': 'madrid'});
      expect(p('the game'), isNull);
    });
  });

  group('open / search / guide', () {
    test('sections', () {
      expect(p('open the movies')?.args, {'section': 'movies'});
      expect(p('show me the guide')?.args, {'section': 'guide'});
      expect(p('ouvre les films')?.args, {'section': 'movies'});
      expect(p('go to sports')?.args, {'section': 'sports'});
      expect(p('Settings')?.args, {'section': 'settings'});
      expect(p('media hub')?.args, {'section': 'hub'});
    });

    test('search carries the words', () {
      expect(p('search for the office')?.args,
          {'section': 'search', 'query': 'the office'});
      expect(p('cherche Dune')?.args, {'section': 'search', 'query': 'dune'});
    });

    test("what's on, a channel's guide, when is it on", () {
      expect(p("What's on?")?.tool, 'now_playing');
      expect(p("what's on TSN 1")?.args, {'name': 'tsn 1'});
      expect(p('when is the Simpsons on')?.args, {'title': 'simpsons'});
      expect(p('quand joue le Canadien')?.args, {'title': 'canadien'});
    });

    test('favourites and sports', () {
      expect(p('add this to favorites')?.args,
          {'action': 'add', 'ref': 'current'});
      expect(p('my favourites')?.args, {'action': 'list'});
      expect(p("today's games")?.tool, 'sports_today');
    });
  });

  test('anything else is for the AI', () {
    expect(p('make me a movie night list for Friday'), isNull);
    expect(p(''), isNull);
    expect(p('vesper'), isNull);
  });
}
