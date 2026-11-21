import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/dispatcharr.dart';
import 'package:nox_iptv/services/live_sources.dart';
import 'package:nox_iptv/services/live_stream_format.dart';

/// clayts450 (Discord, 2026-11-18): a stream picked in Sources played in
/// Dispatcharr's default format, not the channel's, and on its own, so
/// Dispatcharr's failover was off. Answers shaped like a real Dispatcharr
/// 0.34.1 (checked against the PC's test server the same day).
const _server = 'http://10.0.0.5:9191';
const _uuid = '6abc2d09-db85-4038-9248-24643491820b';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Channel _channel(String url, {String name = 'Test channel'}) => Channel(
    id: 'p1::2',
    rawId: '2',
    playlistId: 'p1',
    name: name,
    group: 'News',
    url: url);

void main() {
  group('dispatcharrOutputFormat', () {
    tearDown(() => LiveStreamFormat.hlsAccounts = () => const []);

    test('the Xtream extension decides, like Dispatcharr', () {
      expect(dispatcharrOutputFormat('$_server/live/u/p/2.ts'), 'mpegts');
      expect(dispatcharrOutputFormat('$_server/live/u/p/2.m3u8'), 'hls');
      expect(dispatcharrOutputFormat('$_server/live/u/p/2.mp4'), 'fmp4');
    });

    test("VesperTV's Stream format HLS plays .ts links as .m3u8", () {
      LiveStreamFormat.hlsAccounts = () => ['/live/u/p/'];
      expect(dispatcharrOutputFormat('$_server/live/u/p/2.ts'), 'hls');
    });

    test('an M3U channel link names no format, unless it asks for one', () {
      expect(
          dispatcharrOutputFormat('$_server/proxy/ts/stream/$_uuid'), isNull);
      expect(
          dispatcharrOutputFormat('$_server/proxy/ts/stream/$_uuid?output=hls'),
          'hls');
      expect(
          dispatcharrOutputFormat(
              '$_server/proxy/ts/stream/$_uuid?output_format=mpegts'),
          'mpegts');
    });

    test('a picked stream asks for that format', () {
      expect(DispatcharrApi.streamUrl(_server, 'abc', format: 'hls'),
          '$_server/proxy/ts/stream/abc?output_format=hls');
      expect(DispatcharrApi.streamUrl(_server, 'abc'),
          '$_server/proxy/ts/stream/abc');
    });
  });

  group('switching the channel on the server', () {
    late List<String> calls;
    late Dispatcharr d;
    late int level;
    late int switchStatus;
    late Object? behind;
    final channel = _channel('$_server/live/u/p/2.ts');
    final stream = _channel(
        DispatcharrApi.streamUrl(_server, 'h263', format: 'mpegts'),
        name: 'XITE Siempre Latino');

    setUp(() {
      calls = [];
      level = 10;
      switchStatus = 200;
      behind = 5;
      d = Dispatcharr.instance;
      d.login.value =
          const DispatcharrLogin(server: _server, apiKey: 'k', username: 'vt');
      d.api = DispatcharrApi(client: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        expect(r.headers['X-API-Key'], 'k');
        return switch (r.url.path) {
          '/api/accounts/users/me/' =>
            _json({'username': 'vt', 'user_level': level}),
          '/api/channels/channels/2/' => _json({'id': 2, 'uuid': _uuid}),
          '/proxy/ts/change_stream/$_uuid' => () {
              expect(jsonDecode(r.body), {'stream_id': 263});
              return _json(
                  {'message': 'Stream changed successfully'}, switchStatus);
            }(),
          '/proxy/ts/status/$_uuid' =>
            _json({'state': 'active', 'stream_id': 263}),
          '/api/core/settings/' => behind == null
              ? _json({'detail': 'forbidden'}, 403)
              : _json([
                  {'id': 1, 'key': 'stream_settings', 'value': {}},
                  {
                    'id': 2,
                    'key': 'proxy_settings',
                    'name': 'Proxy Settings',
                    'value': behind is String
                        ? behind
                        : {
                            'channel_shutdown_delay': 0,
                            'new_client_behind_seconds': behind,
                          },
                  },
                ]),
          _ => _json({}, 404),
        };
      }));
      d.notePick(stream.url, channel, 263);
    });

    tearDown(() => d.save(null));

    test('an admin switches the channel itself and stays on it', () async {
      final back = await d.switchChannelTo(stream);
      expect(back?.url, channel.url);
      expect(calls, contains('POST /proxy/ts/change_stream/$_uuid'));
      // The uuid is looked up once.
      await d.switchChannelTo(stream);
      expect(
          calls.where((c) => c == 'GET /api/channels/channels/2/').length, 1);
    });

    test('not an admin: nothing is switched, the stream plays on its own',
        () async {
      level = 1;
      expect(await d.switchChannelTo(stream), isNull);
      expect(calls, isNot(contains('POST /proxy/ts/change_stream/$_uuid')));
    });

    test('a refused switch falls back to playing the stream', () async {
      switchStatus = 502;
      expect(await d.switchChannelTo(stream), isNull);
    });

    test('a source that is not a Dispatcharr stream asks nothing', () async {
      expect(await d.switchChannelTo(_channel('http://other.tv/1.ts')), isNull);
      expect(calls, isEmpty);
    });

    test('the stream the channel plays now is known to an admin', () async {
      expect(await d.activeStreamOf(channel), 263);
      level = 1;
      await d.save(d.login.value); // forget the admin answer
      d.login.value =
          const DispatcharrLogin(server: _server, apiKey: 'k', username: 'vt');
      expect(await d.activeStreamOf(channel), isNull);
    });

    test('picking: switched = the player stays, with a message', () async {
      final played = <String>[];
      final note = await playPickedLiveSource(channel, stream, (c) async {
        played.add(c.url);
      });
      expect(played, isEmpty, reason: 'already on the channel');
      expect(note, contains('XITE Siempre Latino'));
    });

    // AMD, 2026-11-21 (LOG-HZQBLZ): 29-42 s per pick through the open
    // connection; a fresh one after the delay starts on the new stream.
    test('switched on the channel: a fresh connection after the delay',
        () async {
      final played = <String>[];
      final reconnects = <String>[];
      await playPickedLiveSource(channel, stream, (c) async {
        played.add(c.url);
      }, reconnect: (after, name, hold) async {
        reconnects.add('$name after ${after.inSeconds} s');
      });
      await pumpEventQueue();
      expect(played, isEmpty);
      expect(reconnects, ['XITE Siempre Latino after 7 s']);
    });

    test("the delay follows the server's new_client_behind_seconds", () async {
      behind = 8;
      expect(await d.reconnectDelay(), const Duration(seconds: 10));
      // Asked once per sign-in.
      behind = 2;
      expect(await d.reconnectDelay(), const Duration(seconds: 10));
      expect(calls.where((c) => c == 'GET /api/core/settings/').length, 1);
    });

    test('settings as a JSON string, start at live, or unreadable', () async {
      behind = '{"new_client_behind_seconds": 3}';
      expect(await d.reconnectDelay(), const Duration(seconds: 5));
      await d.save(d.login.value);
      behind = 0;
      expect(await d.reconnectDelay(), const Duration(seconds: 2));
      await d.save(d.login.value);
      behind = null;
      expect(await d.reconnectDelay(), const Duration(seconds: 7),
          reason: "Dispatcharr's default 5 s");
    });

    test('picking from a stream played on its own goes back to the channel',
        () async {
      final played = <String>[];
      final other =
          _channel(DispatcharrApi.streamUrl(_server, 'h264', format: 'mpegts'));
      var reconnected = false;
      await playPickedLiveSource(other, stream, (c) async {
        played.add(c.url);
      }, reconnect: (_, __, ___) async => reconnected = true);
      await pumpEventQueue();
      expect(played, [channel.url]);
      expect(reconnected, isFalse, reason: 'that play is a new connection');
    });

    test('picking without admin plays the stream itself', () async {
      level = 1;
      final played = <String>[];
      var reconnected = false;
      final note = await playPickedLiveSource(channel, stream, (c) async {
        played.add(c.url);
      }, reconnect: (_, __, ___) async => reconnected = true);
      await pumpEventQueue();
      expect(played, [stream.url]);
      expect(note, isNull);
      expect(reconnected, isFalse);
    });
  });

  group('holding the channel while the player reconnects', () {
    late List<String> events;
    late StreamController<List<int>> body;
    late int status;
    late Dispatcharr d;

    setUp(() {
      events = [];
      status = 200;
      body = StreamController<List<int>>(
          onCancel: () => events.add('connection closed'));
      d = Dispatcharr.instance;
      d.login.value =
          const DispatcharrLogin(server: _server, apiKey: 'k', username: 'vt');
      d.api = DispatcharrApi(client: MockClient.streaming((r, _) async {
        events.add('GET ${r.url}');
        if (status != 200) {
          return http.StreamedResponse(Stream.value(const <int>[]), status);
        }
        return http.StreamedResponse(body.stream, 200);
      }));
    });

    tearDown(() => d.save(null));

    test('one more viewer of the channel until released', () async {
      final holding = d.holdChannel(_channel('$_server/live/u/p/2.m3u8'));
      await pumpEventQueue();
      body.add(List.filled(188, 0x47));
      final release = await holding;
      expect(release, isNotNull);
      // As one TS download, not an HLS playlist that ends at once.
      expect(events, ['GET $_server/live/u/p/2.ts']);
      body.add(List.filled(188, 0x47));
      await release!();
      expect(events.last, 'connection closed');
    });

    test('no bytes or a refusal: not held', () async {
      status = 403;
      expect(await d.holdChannel(_channel('$_server/live/u/p/2.ts')), isNull);
      status = 200;
      expect(
          await d.holdChannel(_channel('$_server/live/u/p/2.ts'),
              wait: const Duration(milliseconds: 50)),
          isNull);
      expect(events.last, 'connection closed');
    });

    test('lets go by itself', () async {
      final holding = d.holdChannel(_channel('$_server/live/u/p/2.ts'),
          longest: const Duration(milliseconds: 50));
      await pumpEventQueue();
      body.add(const [0x47]);
      expect(await holding, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(events.last, 'connection closed');
    });

    test('dispatcharrTsUrl', () {
      expect(
          dispatcharrTsUrl('$_server/live/u/p/2.ts'), '$_server/live/u/p/2.ts');
      expect(dispatcharrTsUrl('$_server/live/u/p/2.m3u8'),
          '$_server/live/u/p/2.ts');
      expect(dispatcharrTsUrl('$_server/proxy/ts/stream/$_uuid?output=hls'),
          '$_server/proxy/ts/stream/$_uuid?output=mpegts');
      expect(dispatcharrTsUrl('$_server/proxy/ts/stream/$_uuid'),
          '$_server/proxy/ts/stream/$_uuid');
    });
  });
}
