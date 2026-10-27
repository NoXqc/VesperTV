import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/xtream_api_service.dart';

XtreamApiService _api() => XtreamApiService(
    server: 'http://host:80', username: 'u', password: 'p', playlistId: 'pl');

Future<T> _withReplies<T>(
        Map<String, Object> byAction, Future<T> Function() body) =>
    http.runWithClient(
        body,
        () => MockClient((req) async {
              final action = req.url.queryParameters['action'] ?? '';
              return http.Response(jsonEncode(byAction[action]), 200);
            }));

Map<String, Object> _auth(Object? serverInfo) => {
      'user_info': {'auth': 1, 'status': 'Active', 'max_connections': '1'},
      if (serverInfo != null) 'server_info': serverInfo,
    };

void main() {
  group('Xtream', () {
    test('tv_archive int, string and missing', () async {
      final channels = await _withReplies({
        'get_live_streams': [
          {
            'stream_id': 11,
            'name': 'A',
            'epg_channel_id': 'a.us',
            'tv_archive': 1,
            'tv_archive_duration': 2,
          },
          {
            'stream_id': '12',
            'name': 'B',
            'epg_channel_id': '',
            'tv_archive': '1',
            'tv_archive_duration': '7',
          },
          {'stream_id': 13, 'name': 'C', 'epg_channel_id': 'c.us'},
          {
            'stream_id': 14,
            'name': 'D',
            'tv_archive': 0,
            'tv_archive_duration': 3,
          },
          {
            'stream_id': 15,
            'name': 'E',
            'tv_archive': 1,
            'tv_archive_duration': 'abc',
          },
          {
            'stream_id': 16,
            'name': 'F',
            'tv_archive': 1,
            'tv_archive_duration': 90,
          },
        ],
      }, () => _api().getLiveStreams(categoryNames: const {}));
      final byName = {for (final c in channels) c.name: c};
      expect(byName['A']!.catchupDays, 2);
      expect(byName['A']!.catchupKind, CatchupKind.xc);
      expect(byName['A']!.streamId, '11');
      expect(byName['A']!.hasCatchup, isTrue);
      expect(byName['B']!.catchupDays, 7);
      expect(byName['B']!.streamId, '12');
      expect(byName['C']!.catchupDays, 0);
      expect(byName['C']!.catchupKind, isNull);
      expect(byName['C']!.streamId, '13');
      expect(byName['C']!.hasCatchup, isFalse);
      expect(byName['D']!.catchupDays, 0);
      expect(byName['E']!.catchupDays, 0);
      expect(byName['F']!.catchupDays, 30);
    });

    test('server_info clock offset', () async {
      Future<XtreamApiService> login(Object? info) async {
        final api = _api();
        await _withReplies({'': _auth(info)}, api.authenticate);
        return api;
      }

      // 1793097343 = 2026-10-27 10:35:43 UTC.
      final utc = await login({
        'timezone': 'UTC',
        'time_now': '2026-10-27 10:35:43',
        'timestamp_now': 1793097343,
      });
      expect(utc.serverTimeOffset, Duration.zero);
      expect(utc.serverTimeZone, 'UTC');

      final plus2 = await login({
        'timezone': 'Europe/Paris',
        'time_now': '2026-10-27 12:35:44',
        'timestamp_now': '1793097343',
      });
      expect(plus2.serverTimeOffset, const Duration(hours: 2));
      expect(XtreamApiService.formatServerOffset(plus2.serverTimeOffset!),
          '+02:00');

      final minus5 = await login({
        'timezone': 'America/New_York',
        'time_now': '2026-10-27 05:35:41',
        'timestamp_now': 1793097343,
      });
      expect(minus5.serverTimeOffset, const Duration(hours: -5));
      expect(XtreamApiService.formatServerOffset(minus5.serverTimeOffset!),
          '-05:00');

      final none = await login(null);
      expect(none.serverTimeOffset, isNull);
      final junk = await login({'time_now': 'soon', 'timestamp_now': 'x'});
      expect(junk.serverTimeOffset, isNull);
    });

    test('profile keeps the offset; old profiles load without it', () {
      final p = PlaylistProfile.fromJson({
        'id': 'pl',
        'name': 'X',
        'mode': 'xtream',
        'serverTimeOffsetMinutes': -300,
      });
      expect(p.serverTimeOffsetMinutes, -300);
      expect(
          PlaylistProfile.fromJson(p.toJson()).serverTimeOffsetMinutes, -300);
      expect(p.copyWith(name: 'Y').serverTimeOffsetMinutes, -300);
      final old =
          PlaylistProfile.fromJson({'id': 'pl', 'name': 'X', 'mode': 'xtream'});
      expect(old.serverTimeOffsetMinutes, isNull);
      expect(old.toJson().containsKey('serverTimeOffsetMinutes'), isFalse);
    });
  });

  group('M3U', () {
    test('header defaults, entry override, aliases, VOD excluded', () {
      final list = M3uParser.parse('''
#EXTM3U url-tvg="http://e/x.xml" catchup="flussonic" catchup-days="3"
#EXTINF:-1 tvg-id="a" group-title="News",A
http://h/a/index.m3u8?token=1
#EXTINF:-1 tvg-id="b" group-title="News" catchup="shift" catchup-days="5",B
http://h/b/index.m3u8
#EXTINF:-1 tvg-id="m" group-title="Movies",M
http://h/m.mp4
''', playlistId: 'pl');
      final by = {for (final c in list) c.name: c};
      expect(by['A']!.catchupKind, CatchupKind.flussonic);
      expect(by['A']!.catchupDays, 3);
      expect(by['B']!.catchupKind, CatchupKind.shift);
      expect(by['B']!.catchupDays, 5);
      expect(by['M']!.catchupDays, 0);
      expect(by['M']!.catchupKind, isNull);
      expect(by['M']!.hasCatchup, isFalse);
    });

    test('days without a type pick the kind from the URL/source', () {
      final list = M3uParser.parse('''
#EXTM3U
#EXTINF:-1 tvg-id="x" tvg-rec="5",X
http://host:8080/user/pass/1234.ts
#EXTINF:-1 tvg-id="l" timeshift="2",L
http://host:8080/live/user/pass/99.m3u8
#EXTINF:-1 tvg-id="s" catchup-days="4" catchup-source="?utc={utc}&lutc={lutc}",S
http://h/s.m3u8
#EXTINF:-1 tvg-id="t" catchup-days="4",T
http://h/t.m3u8
#EXTINF:-1 tvg-id="k" catchup="default" catchup-source="http://h/k-{utc}.ts",K
http://h/k.m3u8
#EXTINF:-1 tvg-id="u" catchup="mystery" catchup-days="3",U
http://h/u.m3u8
#EXTINF:-1 tvg-id="z" catchup-days="0",Z
http://h/z.m3u8
#EXTINF:-1 tvg-id="f" catchup="fs-ts" catchup-days="99",F
http://h/f/mpegts
''', playlistId: 'pl');
      final by = {for (final c in list) c.name: c};
      expect(by['X']!.catchupKind, CatchupKind.xc);
      expect(by['X']!.catchupDays, 5);
      expect(by['L']!.catchupKind, CatchupKind.xc);
      expect(by['S']!.catchupKind, CatchupKind.defaultKind);
      expect(by['S']!.catchupSource, '?utc={utc}&lutc={lutc}');
      expect(by['T']!.catchupKind, CatchupKind.shift);
      expect(by['K']!.catchupKind, CatchupKind.defaultKind);
      expect(by['K']!.catchupDays, 7);
      expect(by['U']!.catchupKind, isNull);
      expect(by['U']!.catchupDays, 0);
      expect(by['Z']!.catchupDays, 0);
      expect(by['F']!.catchupKind, CatchupKind.flussonicTs);
      expect(by['F']!.catchupDays, 30);
    });

    test('no header leaves later entries without catch-up', () {
      final list = M3uParser.parse('''
#EXTINF:-1 tvg-id="a",A
http://h/a.m3u8
''', playlistId: 'pl');
      expect(list.single.catchupDays, 0);
    });
  });

  group('Channel', () {
    Channel live() => Channel(
          id: 'pl::a.us',
          rawId: 'a.us',
          playlistId: 'pl',
          name: 'A',
          group: 'News',
          url: 'http://h/live/u/p/11.ts',
          catchupDays: 2,
          catchupKind: CatchupKind.xc,
          catchupSource: 'src',
          streamId: '11',
        );

    void expectCatchup(Channel c) {
      expect(c.catchupDays, 2);
      expect(c.catchupKind, CatchupKind.xc);
      expect(c.catchupSource, 'src');
      expect(c.streamId, '11');
    }

    test('fields survive JSON, copyWith, withUniqueIds, withCatalogType', () {
      expectCatchup(Channel.fromJson(live().toJson()));
      expectCatchup(live().copyWith(isFavorite: true));
      expectCatchup(M3uParser.withCatalogType(live()));
      final twin = Channel(
          id: 'pl::a.us',
          rawId: 'a.us',
          playlistId: 'pl',
          name: 'A HD',
          group: 'News',
          url: 'http://h/live/u/p/12.ts');
      final unique = Channel.withUniqueIds([live(), twin]);
      expect(unique.first.id, isNot(unique.last.id));
      expectCatchup(unique.first);
      expect(unique.last.catchupDays, 0);
    });

    test('old cache entries load without catch-up keys', () {
      final json = live().toJson()
        ..remove('catchupDays')
        ..remove('catchupKind')
        ..remove('catchupSource')
        ..remove('streamId');
      final c = Channel.fromJson(json);
      expect(c.catchupDays, 0);
      expect(c.catchupKind, isNull);
      expect(c.streamId, isNull);
      expect(c.hasCatchup, isFalse);
      expect(Channel.fromJson({...json, 'catchupKind': 'bogus'}).catchupKind,
          isNull);
    });

    test('cu_ ids are catch-up, never live', () {
      expect(Channel.isCatchupId('cu_a.us_1793097300'), isTrue);
      expect(Channel.isLiveId('cu_a.us_1793097300'), isFalse);
      expect(Channel.isCatchupId('a.us'), isFalse);
      expect(Channel.isLiveId('a.us'), isTrue);
    });
  });
}
