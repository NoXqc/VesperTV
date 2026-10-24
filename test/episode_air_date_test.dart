import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/episode_airing.dart';
import 'package:nox_iptv/models/series_details.dart';
import 'package:nox_iptv/services/episode_air_date_service.dart';
import 'package:nox_iptv/widgets/next_episode_air_date.dart';

final now = DateTime(2026, 10, 23, 12);
SeriesDetails details(Map<String, String?> dates) => SeriesDetails(episodes: {
      for (final entry in dates.entries)
        entry.key: EpisodeDetails(
            season: 2,
            episodeNumber: int.parse(entry.key),
            airDate: entry.value),
    });
http.Response meta(String id, List<Map<String, Object?>> videos) =>
    http.Response(
        jsonEncode({
          'meta': {'id': id, 'type': 'series', 'videos': videos}
        }),
        200);

void main() {
  test('Coming soon excludes date-only today but respects future instants', () {
    expect(EpisodeAiring.parse('2026-10-24')!.unreleased(now), isTrue);
    expect(EpisodeAiring.parse('2026-10-23')!.unreleased(now), isFalse);
    expect(EpisodeAiring.parse('2026-10-22')!.unreleased(now), isFalse);
    final instant = DateTime.utc(2026, 10, 23, 12);
    expect(
        EpisodeAiring.parse('2026-10-23T14:01:00+02:00')!.unreleased(instant),
        isTrue);
    expect(
        EpisodeAiring.parse('2026-10-23T14:00:00+02:00')!.unreleased(instant),
        isFalse);
    expect(
        EpisodeAiring.parse('2026-10-23T13:59:00+02:00')!.unreleased(instant),
        isFalse);
  });

  test(
      'dates reject missing, placeholders, invalid calendars and incomplete years',
      () {
    for (final raw in [
      null,
      '',
      '0',
      '0000-00-00',
      '2027',
      '2027-02-29',
      '2026-13-01',
      '2026-10-32',
      'unknown',
      '2026-10-24T99:00:00Z',
      '2026-10-24T12:99:00Z',
      '2026-10-24T12:30:99Z'
    ]) {
      expect(EpisodeAiring.parse(raw), isNull, reason: '$raw');
    }
    expect(EpisodeAiring.parse('2028-02-29'), isNotNull);
  });

  test('date-only today remains possible; timestamps use their actual instant',
      () {
    expect(EpisodeAiring.parse('2026-10-23')!.upcoming(now), isTrue);
    expect(EpisodeAiring.parse('2026-10-22')!.upcoming(now), isFalse);
    expect(
        EpisodeAiring.parse('2026-10-23T01:00:00+03:00')!
            .upcoming(DateTime.utc(2026, 10, 22, 23)),
        isFalse);
    expect(
        EpisodeAiring.parse('2026-10-23T23:00:00-03:00')!
            .upcoming(DateTime.utc(2026, 10, 24, 1)),
        isTrue);
  });

  test('earliest future supplied date wins without any metadata request',
      () async {
    final service = EpisodeAirDateService(
        now: () => now,
        client: MockClient((_) async => throw StateError('Must stay offline')));
    final result = await service.resolve(
        details:
            details({'5': '2026-10-30', '3': '2026-10-22', '4': '2026-10-24'}),
        imdbId: 'tt123');
    expect(result!.code, 'S02E04');
    expect(result.date, DateTime(2026, 10, 24));
  });

  test('no identity or missing user TMDB key causes no title guessing',
      () async {
    var calls = 0;
    final service = EpisodeAirDateService(
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }));
    expect(await service.resolve(tmdbId: '123'), isNull);
    expect(
        await service.resolve(
            imdbId: 'not-imdb', tmdbId: '../../123', tmdbKey: 'test-key'),
        isNull);
    expect(calls, 0);
  });

  test('Cinemeta exact identity selects upcoming episode across seasons',
      () async {
    final service = EpisodeAirDateService(
        now: () => now,
        client: MockClient((request) async {
          expect(request.url.host, 'v3-cinemeta.strem.io');
          expect(request.url.path, '/meta/series/tt123.json');
          expect(request.url.queryParameters, isEmpty);
          return meta('tt123', [
            {'season': 2, 'episode': 1, 'released': '2026-11-05'},
            {'season': 1, 'episode': 9, 'released': '2026-10-24'},
            {'season': 1, 'episode': 8, 'released': '2026-10-20'},
          ]);
        }));
    expect((await service.resolve(imdbId: 'tt123'))!.code, 'S01E09');
  });

  test('wrong identity, movie metadata and absent schedules remain hidden',
      () async {
    for (final body in [
      jsonEncode({
        'meta': {
          'id': 'tt999',
          'videos': [
            {'released': '2027-01-01'}
          ]
        }
      }),
      jsonEncode({
        'meta': {
          'id': 'tt123',
          'type': 'movie',
          'videos': [
            {'released': '2027-01-01'}
          ]
        }
      }),
      '{}'
    ]) {
      final service = EpisodeAirDateService(
          now: () => now,
          client: MockClient((_) async => http.Response(body, 200)));
      expect(await service.resolve(imdbId: 'tt123'), isNull);
    }
  });

  test('known TMDB id uses only the user key and next_episode_to_air',
      () async {
    final service = EpisodeAirDateService(
        now: () => now,
        client: MockClient((request) async {
          expect(request.url.host, 'api.themoviedb.org');
          expect(request.url.path, '/3/tv/123');
          expect(request.url.queryParameters, {'api_key': 'test-key'});
          return http.Response(
              jsonEncode({
                'id': 123,
                'next_episode_to_air': {
                  'season_number': 3,
                  'episode_number': 2,
                  'air_date': '2026-10-25'
                }
              }),
              200);
        }));
    expect((await service.resolve(tmdbId: '123', tmdbKey: 'test-key'))!.code,
        'S03E02');
  });

  test('failed TMDB lookup falls back to known IMDb without sending its key',
      () async {
    final hosts = <String>[];
    final service = EpisodeAirDateService(
        now: () => now,
        client: MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host == 'api.themoviedb.org') {
            return http.Response('{}', 401);
          }
          expect(request.url.queryParameters, isEmpty);
          return meta('tt123', [
            {'released': '2026-10-25', 'season': 1, 'episode': 3}
          ]);
        }));
    expect(
        (await service.resolve(
                tmdbId: '123', tmdbKey: 'test-key', imdbId: 'tt123'))!
            .code,
        'S01E03');
    expect(hosts, ['api.themoviedb.org', 'v3-cinemeta.strem.io']);
  });

  test(
      'concurrent reads share one request and cached schedules advance with time',
      () async {
    var time = now;
    var calls = 0;
    final response = Completer<http.Response>();
    final service = EpisodeAirDateService(
        now: () => time,
        client: MockClient((_) {
          calls++;
          return response.future;
        }));
    final one = service.resolve(imdbId: 'tt123');
    final two = service.resolve(imdbId: 'tt123');
    response.complete(meta('tt123', [
      {'released': '2026-10-23T13:00:00', 'season': 1, 'episode': 1},
      {'released': '2026-10-24', 'season': 1, 'episode': 2},
    ]));
    expect((await one)!.code, 'S01E01');
    expect((await two)!.code, 'S01E01');
    time = DateTime(2026, 10, 23, 14);
    expect((await service.resolve(imdbId: 'tt123'))!.code, 'S01E02');
    expect(calls, 1);
  });

  test('metadata failures are hidden and negative cache expires', () async {
    var time = now;
    var calls = 0;
    final service = EpisodeAirDateService(
        now: () => time,
        client: MockClient((_) async {
          calls++;
          return http.Response('broken', 200);
        }));
    expect(await service.resolve(imdbId: 'tt123'), isNull);
    expect(await service.resolve(imdbId: 'tt123'), isNull);
    expect(calls, 1);
    time = time.add(const Duration(minutes: 11));
    expect(await service.resolve(imdbId: 'tt123'), isNull);
    expect(calls, 2);
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('schedule fits width $width without a focusable action',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await L10n.apply('en');
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: NextEpisodeAirDate(
        details: details({'4': '2026-10-24'}),
        scale: width > 1000 ? 2 : 1,
        service: EpisodeAirDateService(now: () => now),
      ))));
      await tester.pump();
      expect(find.text('Next episode: S02E04 · Oct 24, 2026'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing date hides text; translations use the UI language',
      (tester) async {
    final service = EpisodeAirDateService(now: () => now);
    await tester
        .pumpWidget(MaterialApp(home: NextEpisodeAirDate(service: service)));
    await tester.pump();
    expect(find.byType(Text), findsNothing);
    await L10n.apply('fr');
    addTearDown(() => L10n.apply('en'));
    await tester.pumpWidget(MaterialApp(
        home: NextEpisodeAirDate(
            service: service, details: details({'4': '2026-10-24'}))));
    await tester.pump();
    expect(find.textContaining('Prochain épisode : S02E04'), findsOneWidget);
    expect(find.textContaining('oct.'), findsOneWidget);
  });

  testWidgets(
      'late response for an earlier show never replaces the new schedule',
      (tester) async {
    final response = Completer<http.Response>();
    final service = EpisodeAirDateService(
        now: () => now, client: MockClient((_) => response.future));
    await L10n.apply('en');
    await tester.pumpWidget(MaterialApp(
        home: NextEpisodeAirDate(service: service, imdbId: 'tt123')));
    await tester.pumpWidget(MaterialApp(
        home: NextEpisodeAirDate(
            service: service, details: details({'4': '2026-10-24'}))));
    await tester.pump();
    response.complete(meta('tt123', [
      {'released': '2026-10-25', 'season': 9, 'episode': 9}
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('S02E04'), findsOneWidget);
    expect(find.textContaining('S09E09'), findsNothing);
  });
}
