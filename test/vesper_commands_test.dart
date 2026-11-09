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
      expect(p('fast forward 2 minutes')?.args['seconds'], 120);
      expect(p('rewind 30 seconds')?.args['seconds'], -30);
      // Typed without a space.
      expect(p('fast forward 2min')?.args['seconds'], 120);
      expect(p('rewind 30sec')?.args['seconds'], -30);
    });

    test('next / previous episode', () {
      for (final s in [
        'next episode',
        'Play the next episode',
        'épisode suivant',
        "l'épisode suivant",
        'siguiente episodio',
        'prossimo episodio',
        'nächste Folge',
        'epomeno epeisodio',
      ]) {
        expect(p(s)?.args, {'action': 'next_episode'}, reason: s);
      }
      for (final s in [
        'previous episode',
        'épisode précédent',
        'episodio anterior',
        'vorherige Folge',
      ]) {
        expect(p(s)?.args, {'action': 'previous_episode'}, reason: s);
      }
      // A bare "next" stays channel up (the tool plays the next episode
      // when a show is playing).
      expect(p('next')?.args['action'], 'channel_up');
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

  test('continue watching / play a title in Media Hub', () {
    Map<String, Object?>? hub(String s) {
      final c = p(s);
      return c?.tool == 'media_hub' ? c!.args : null;
    }

    const spider = {'action': 'continue', 'query': 'spider man'};
    expect(hub('continue watching Spider-Man in mediahub'), spider);
    expect(hub('Continue watching Spider-Man in Media Hub'), spider);
    expect(hub('keep watching spider-man'), spider);
    expect(hub('resume Spider-Man'), spider);
    expect(hub('continue de regarder Spider-Man'), spider);
    expect(hub('reprends Spider-Man dans le Media Hub'), spider);
    expect(hub('sigue viendo Spider-Man'), spider);
    expect(
        hub('play Carrie in Media Hub'), {'action': 'play', 'query': 'carrie'});
    // The player and sections keep their meaning.
    expect(p('continue')?.args, {'action': 'resume'});
    expect(hub('resume playback'), isNull);
    expect(hub('continue watching'), isNull);
    expect(p('open media hub')?.args, {'section': 'hub'});
    expect(p('open Carrie in Media Hub')?.args,
        {'section': 'hub', 'query': 'carrie'});
    expect(p('play TSN 1')?.tool, 'play');
  });

  test('help and the watch list', () {
    expect(p('what can you do?')?.tool, 'help');
    expect(p('aide')?.tool, 'help');
    expect(p('my watch list')?.args, {'action': 'list'});
    expect(p('add this to my watch list')?.args,
        {'action': 'add', 'ref': 'current'});
    expect(
        p('add Dune to my watchlist')?.args, {'action': 'add', 'name': 'dune'});
    expect(
        p('ajoute Dune à ma liste')?.args, {'action': 'add', 'name': 'dune'});
  });

  test('anything else is for the AI', () {
    expect(p('make me a movie night list for Friday'), isNull);
    expect(p(''), isNull);
    expect(p('vesper'), isNull);
  });
}
