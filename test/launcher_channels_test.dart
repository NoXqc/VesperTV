import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/launcher_channels.dart';
import 'package:nox_iptv/services/multiview_sports.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';

LauncherCard _card(String key, {int? position, int? engaged}) => LauncherCard(
    key: key,
    kind: 'continue',
    type: 'movie',
    title: key,
    positionMs: position,
    engagedMs: engaged);

void main() {
  group('stampEngaged', () {
    test('new cards keep the app order, newest first', () {
      final cards = [_card('a', position: 10), _card('b', position: 20)];
      final state = LauncherChannels.stampEngaged(cards, {}, 1000);
      expect(cards[0].engagedMs, 1000);
      expect(cards[1].engagedMs, 999);
      expect(state, {
        'a': [10, 1000],
        'b': [20, 999],
      });
    });

    test('an unchanged position keeps its time, a moved one is now', () {
      final cards = [_card('a', position: 10), _card('b', position: 25)];
      LauncherChannels.stampEngaged(
          cards,
          {
            'a': [10, 500],
            'b': [20, 400],
          },
          2000);
      expect(cards[0].engagedMs, 500);
      expect(cards[1].engagedMs, 1999);
    });

    test('a card with its own time (Watch list) keeps it', () {
      final cards = [_card('wl:x', engaged: 123)];
      final state = LauncherChannels.stampEngaged(cards, {}, 5000);
      expect(cards.single.engagedMs, 123);
      expect(state['wl:x'], [-1, 123]);
    });

    test('cards no longer sent drop out of the state', () {
      final state = LauncherChannels.stampEngaged([
        _card('a', position: 1)
      ], {
        'gone': [5, 5],
      }, 10);
      expect(state.keys, ['a']);
    });
  });

  group('safeImage', () {
    test('plain public images pass', () {
      const tmdb = 'https://image.tmdb.org/t/p/w780/abc.jpg';
      expect(LauncherChannels.safeImage(tmdb), tmdb);
      expect(LauncherChannels.safeImage('http://logo.example/x.png?w=300'),
          'http://logo.example/x.png?w=300');
    });

    test('images carrying an access key or login are left out', () {
      for (final url in [
        'http://10.0.0.5:8096/Items/1/Images/Primary?api_key=secret',
        'https://plex.example:32400/photo/:/transcode?X-Plex-Token=secret',
        'http://panel.example/img.php?username=a&password=b',
        'http://user:pass@panel.example/logo.png',
      ]) {
        expect(LauncherChannels.safeImage(url), isNull, reason: url);
      }
    });

    test('empty, relative and local files are left out', () {
      expect(LauncherChannels.safeImage(null), isNull);
      expect(LauncherChannels.safeImage(''), isNull);
      expect(LauncherChannels.safeImage('/data/user/0/x.png'), isNull);
      expect(LauncherChannels.safeImage('file:///sdcard/x.png'), isNull);
    });
  });

  group('hubArt', () {
    test('public images first: backdrop, then poster', () {
      expect(
          LauncherChannels.hubArt(
              background: 'https://img.example/b.jpg',
              poster: 'https://img.example/p.jpg',
              imdb: 'tt1234567'),
          (image: 'https://img.example/b.jpg', poster: false));
      expect(
          LauncherChannels.hubArt(
              poster: 'https://img.example/p.jpg', imdb: 'tt1234567'),
          (image: 'https://img.example/p.jpg', poster: true));
    });

    test('a media server title falls back to Cinemeta by IMDb id', () {
      expect(
          LauncherChannels.hubArt(
              background:
                  'http://10.0.0.5:8096/Items/1/Images/Backdrop?api_key=k',
              poster: 'http://10.0.0.5:8096/Items/1/Images/Primary?api_key=k',
              imdb: 'tt1234567'),
          (
            image:
                'https://images.metahub.space/background/medium/tt1234567/img',
            poster: false
          ));
    });

    test('no public image and no IMDb id: no image', () {
      expect(
          LauncherChannels.hubArt(
              background: 'http://srv/x?X-Plex-Token=k', imdb: 'tmdb:55'),
          (image: null, poster: false));
    });
  });

  test('card keys are stable hashes that never hold the address', () {
    const identity =
        'h:https://addon.example/realdebrid=SECRET/manifest.json|tt1|movie';
    final key = LauncherChannels.cardKey('wl', identity);
    expect(key, LauncherChannels.cardKey('wl', identity));
    expect(key, startsWith('wl:'));
    expect(key.length, 'wl:'.length + 16);
    expect(key, isNot(contains('SECRET')));
    expect(LauncherChannels.cardKey('nx', 'a::xt_ep_2'),
        isNot(LauncherChannels.cardKey('nx', 'a::xt_ep_3')));
  });

  test('a card keeps a wide image unless it is a poster', () {
    final wide = _card('a').toMap();
    expect(wide['aspect'], 'wide');
    final poster = LauncherCard(
            key: 'b',
            kind: 'watchlist',
            type: 'series',
            title: 'B',
            poster: true)
        .toMap();
    expect(poster['aspect'], 'poster');
    expect(poster['kind'], 'watchlist');
  });

  group('liveCard (Live now in Sports)', () {
    final channel = Channel(
        id: 'p::tsn1',
        rawId: 'tsn1',
        playlistId: 'p',
        name: 'TSN 1 HD',
        group: 'Sports',
        url: 'http://provider.example/live/user/pass/1.ts',
        logoUrl: 'https://logo.example/tsn.png');
    SportsTeam team(String abbr, String? score) => SportsTeam(
        id: abbr,
        name: abbr,
        shortName: abbr,
        abbreviation: abbr,
        logoUrl: 'https://a.espncdn.com/i/teamlogos/nhl/500/$abbr.png',
        color: 'af1e2d',
        score: score);
    LiveGameChannel game({String? home = '2', String? away = '1'}) => (
          game: SportsGame(
            id: '401',
            league: sportsLeagueById('nhl')!,
            start: DateTime.utc(2026, 11, 21, 0),
            state: GameState.live,
            statusText: '2nd 12:10',
            home: team('MTL', home),
            away: team('TOR', away),
          ),
          matches: [ChannelMatch(channel, MatchReason.name, 90)],
        );

    test('score, clock, league and channel; a picture to draw', () {
      final card = LauncherChannels.liveCard(game(), hideScores: false);
      expect(card.type, 'event');
      expect(card.kind, 'row');
      expect(card.live, isTrue);
      expect(card.key, startsWith('live:'));
      expect(card.title, game().game.title);
      expect(card.description, contains('2nd 12:10'));
      expect(card.description, contains('TSN 1 HD'));
      final teams = card.art!['teams'] as List;
      expect([for (final t in teams) (t as Map)['score']], ['1', '2']);
      expect(card.toMap()['live'], isTrue);
      expect(card.toMap()['v'], card.version);
      // The channel's logo if the picture can't be drawn.
      expect(card.image, 'https://logo.example/tsn.png');
    });

    test('hidden scores never reach the launcher', () {
      final card = LauncherChannels.liveCard(game(), hideScores: true);
      final teams = card.art!['teams'] as List;
      expect([for (final t in teams) (t as Map)['score']], [null, null]);
      expect(card.description, isNot(contains('2 – 1')));
      expect(card.description, isNot(contains('1 – 2')));
    });

    test('the same game keeps its key; a new score changes the picture', () {
      final before = LauncherChannels.liveCard(game(), hideScores: false);
      final after =
          LauncherChannels.liveCard(game(home: '3'), hideScores: false);
      expect(after.key, before.key);
      expect(after.version, isNot(before.version));
      expect(LauncherChannels.liveCard(game(), hideScores: false).version,
          before.version);
    });

    test('nothing of the playlist login goes into the card', () {
      final sent = LauncherChannels.liveCard(game(), hideScores: false)
          .toMap()
          .toString();
      expect(sent, isNot(contains('provider.example')));
      expect(sent, isNot(contains('pass')));
    });

    test('golf: the event and the league logo, no teams', () {
      final golf = (
        game: SportsGame(
          id: 'g1',
          league: sportsLeagueById('golf.pga')!,
          start: DateTime.utc(2026, 11, 20, 12),
          state: GameState.live,
          statusText: 'Round 2',
          home: const SportsTeam(
              id: 'e',
              name: 'RSM Classic',
              shortName: 'RSM Classic',
              abbreviation: ''),
          away: const SportsTeam(
              id: 'e',
              name: 'RSM Classic',
              shortName: 'RSM Classic',
              abbreviation: ''),
        ),
        matches: [ChannelMatch(channel, MatchReason.guide, 80)],
      );
      final card = LauncherChannels.liveCard(golf, hideScores: false);
      expect(card.art!.containsKey('teams'), isFalse);
      expect(card.art!['event'], 'RSM Classic');
    });
  });
}
