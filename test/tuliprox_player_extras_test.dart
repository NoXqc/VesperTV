import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/live_sources.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/tuliprox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tuliprox's Player API extensions (3.3.206/207, merged into develop
/// 2026-11-24; docs/src/player-api.md): split, member health, the DVR,
/// watch progress, the event stream, channels / EPG / bouquet. Owner:
/// "Add them all for future proofing". Fixtures follow the doc.
const _base = 'https://tv.example.com/admin';
const _url = 'https://tv.example.com/live/labuser/labpass/949.ts';

Channel _channel(String url, {String id = '949'}) => Channel(
    id: 'p1::$id',
    rawId: id,
    playlistId: 'p1',
    name: 'UK: Sky Sport News',
    group: 'UK| News',
    url: url);

void main() {
  late List<String> calls;
  late Map<String, Object?> bodies;
  late Map<String, Map<String, String>> headersOf;
  late Map<String, Object?> caps;
  late List<Map<String, Object?>> ownStreams;
  late http.Response Function(http.Request) splitAnswer;
  late http.Response Function(http.Request) recordAnswer;
  late List<Map<String, Object?>> rules;
  late bool mcp;
  late List<Map<String, Object?>> progress;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    calls = [];
    bodies = {};
    headersOf = {};
    rules = [];
    mcp = true;
    progress = [];
    caps = {
      'source_switch': true,
      'joinable_streams': true,
      'stream_split': true,
      'watch_progress': true,
      'event_stream': false, // the socket has its own test
      'recording': 'private',
      'recording_enabled': true,
      'effective_permissions': [
        'recording.read',
        'recording.create',
        'recording.manage',
        'recording.delete'
      ],
      'max_connections': 2,
      'active_connections': 1,
    };
    ownStreams = [
      {
        'uid': 2,
        'virtual_id': 593860,
        'group_virtual_id': 949,
        'member_vid': 593860,
        'protocol': 'ts',
        'shared': true,
        'started_at': now,
      },
    ];
    splitAnswer = (_) => http.Response(
        jsonEncode({
          'reconnect_required': true,
          'url': '/live/labuser/labpass/949.ts?dedicated=1',
        }),
        200);
    recordAnswer = (_) => http.Response('', 204);
    Tuliprox.instance.ownLookupDelay = Duration.zero;
    Tuliprox.instance.api = TuliproxApi(client: MockClient((req) async {
      final p = req.url.path;
      final key = '${req.method} $p';
      calls.add(key);
      headersOf[key] = req.headers;
      if (req.body.isNotEmpty) {
        try {
          bodies[key] = jsonDecode(req.body);
        } catch (_) {}
      }
      if (p == '/admin/auth/token') {
        return http.Response(jsonEncode({'token': 'player-jwt'}), 200);
      }
      switch ((req.method, p)) {
        case ('GET', '/admin/api/v1/me/capabilities'):
          return http.Response(jsonEncode(caps), 200);
        case ('GET', '/admin/api/v1/me/streams'):
          return http.Response(jsonEncode(ownStreams), 200);
        case ('POST', '/admin/api/v1/me/streams/2/split'):
          return splitAnswer(req);
        case ('GET', '/admin/api/v1/me/streams/2/failover-members'):
        case ('GET', '/admin/api/v1/me/channels/949/failover-members'):
          return http.Response(
              jsonEncode({
                'group_name': 'UK: SKY SPORT NEWS',
                if (p.contains('streams')) 'current_member_vid': 593860,
                'members': [
                  {
                    'member_vid': 593860,
                    'title': 'UK: SKY SPORT NEWS',
                    'health': {
                      'state': 'degraded',
                      'resolution': 'P1080',
                      'video_codec': 'H264',
                      'bitrate_kbps': 5500,
                      'qos_24h': 92,
                      'qos_7d': 88,
                    },
                  },
                  {
                    'member_vid': 287937,
                    'title': 'UK| SKY SPORT NEWS',
                    'health': {'state': 'failing', 'retry_after_secs': 30},
                  },
                ],
              }),
              200);
        case ('DELETE', final String path)
            when path.startsWith('/admin/api/v1/me/streams/'):
          return http.Response('', 204);
        case ('POST', '/admin/api/v1/recording/requests'):
          return recordAnswer(req);
        case ('GET', '/admin/api/v1/recording/rules'):
          return http.Response(jsonEncode(rules), 200);
        case ('POST', '/admin/api/v1/recording/rules'):
          final b = jsonDecode(req.body) as Map;
          return http.Response(
              jsonEncode({
                'id': 'rule-1',
                'own': true,
                'source': {'target_id': 'lab', 'virtual_id': b['virtual_id']},
                'body': b['body'],
              }),
              200);
        case ('POST', '/admin/mcp'):
          if (!mcp) return http.Response('', 404);
          return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'result': {
                  'content': [
                    {'type': 'text', 'text': ''}
                  ],
                  'isError': false,
                },
              }),
              200);
        case ('PUT', final String path)
            when path.startsWith('/admin/api/v1/me/progress/'):
          return http.Response('', 204);
        case ('GET', '/admin/api/v1/me/progress'):
          return http.Response(jsonEncode(progress), 200);
        case ('GET', '/admin/api/v1/me/channels'):
          return http.Response(
              jsonEncode([
                {
                  'virtual_id': 1042,
                  'name': 'Sports 1 HD',
                  'group': 'Sports',
                  'epg_channel_id': 'sports1.example.com',
                  'is_group': true,
                }
              ]),
              200);
        case ('GET', '/admin/api/v1/me/epg'):
          return http.Response(
              jsonEncode([
                {
                  'start_ts': 1763679600,
                  'stop_ts': 1763683200,
                  'title': 'Morning Match',
                  'desc': 'League fixture',
                  'categories': ['Sports'],
                  'is_new': true,
                }
              ]),
              200);
        case ('GET', '/admin/api/v1/user/playlist/bouquet'):
          return http.Response(
              jsonEncode({
                'xtream': {
                  'live': ['Sports'],
                  'vod': [],
                  'series': null
                },
                'm3u': null,
              }),
              200);
        case ('POST', '/admin/api/v1/recording/conflicts/preview'):
          return http.Response(
              jsonEncode({'severity': 'possible_capacity_wait'}), 200);
      }
      return http.Response('nope', 404);
    }));
    // An admin sign-in on the server (like Settings > Tuliprox): signing
    // out in tearDown clears every cache (capabilities, targets, logins).
    Tuliprox.instance.login.value = TuliproxLogin(
        base: _base,
        username: 'admin',
        token: 'admin-jwt',
        issuedAt: DateTime.now());
  });

  tearDown(() async => Tuliprox.instance.save(null));

  group('split: a shared stream on its own connection', () {
    test('offered when the own stream is shared, then plays the new address',
        () async {
      final ch = _channel(_url);
      expect(Tuliprox.instance.canSplit(ch), isFalse);
      await Tuliprox.instance.groupFor(ch);
      expect(Tuliprox.instance.canSplit(ch), isTrue);

      final row = Channel(
          id: ch.id,
          rawId: ch.rawId,
          playlistId: ch.playlistId,
          name: 'Your own connection',
          group: ch.group,
          url: '${ch.url}${Tuliprox.splitMark}');
      expect(Tuliprox.instance.isSplit(row), isTrue);
      Channel? played;
      final note = await playPickedLiveSource(ch, row, (c) async {
        played = c;
      });
      expect(played?.url,
          'https://tv.example.com/live/labuser/labpass/949.ts?dedicated=1');
      expect(note, contains('own connection'));
      expect(calls, contains('POST /admin/api/v1/me/streams/2/split'));
      // Still the same channel: Sources mark it and list its sources.
      expect(Tuliprox.sameStream(played!.url, ch.url), isTrue);
      expect(Tuliprox.instance.refOf(played!)?.id, 949);
      expect((await Tuliprox.instance.groupFor(played!))?.uid, 2);
    });

    test('a refusal is said plainly', () async {
      final ch = _channel(_url);
      await Tuliprox.instance.groupFor(ch);
      splitAnswer =
          (_) => http.Response(jsonEncode({'error': 'stream_not_shared'}), 409);
      Object? error;
      try {
        await Tuliprox.instance.split(ch);
      } catch (e) {
        error = e;
      }
      expect(tuliproxSplitRefusalText(error!), contains('only one watching'));
      expect(
          tuliproxSplitRefusalText(
              TuliproxSwitchRefused('split_unsupported_protocol', status: 409)),
          contains('HLS'));
      // A shared-stream switch refusal points at the row when there is one.
      expect(
          tuliproxRefusalText(
              TuliproxSwitchRefused('shared_stream_switch_refused',
                  status: 409),
              canSplit: true),
          contains('Your own connection'));
    });

    test('not offered for HLS, alone, or without the feature', () async {
      final ch = _channel(_url);
      ownStreams.first['protocol'] = 'hls';
      await Tuliprox.instance.groupFor(ch);
      expect(Tuliprox.instance.canSplit(ch), isFalse);
      ownStreams.first['protocol'] = 'ts';
      ownStreams.first['shared'] = false;
      await Tuliprox.instance.groupFor(ch);
      expect(Tuliprox.instance.canSplit(ch), isFalse);
    });

    test('the dedicated marker is the same stream, other channels are not', () {
      expect(Tuliprox.sameStream('$_url?dedicated=1', _url), isTrue);
      expect(Tuliprox.sameStream('$_url?x=1&dedicated=1', '$_url?x=1'), isTrue);
      expect(
          Tuliprox.sameStream(
              'https://tv.example.com/live/labuser/labpass/950.ts', _url),
          isFalse);
    });
  });

  test('a switch the server undid is watched like a switch', () {
    final undone = TuliproxSwitchRefused(
        'Failed to open target member; returned to current member',
        status: 502);
    expect(tuliproxSwitchReopened(undone), isTrue);
    expect(tuliproxRefusalText(undone), contains('Still on the one before'));
    expect(
        tuliproxSwitchReopened(
            TuliproxSwitchRefused('shared_stream_switch_refused', status: 409)),
        isFalse);
    expect(tuliproxSwitchReopened(TuliproxException('timeout')), isFalse);
  });

  test('sources say how reliable they are and when a failing one retries',
      () async {
    final g = (await Tuliprox.instance.groupFor(_channel(_url)))!;
    expect(tuliproxMemberLabel(g.members.first),
        'Unstable · 1080p · H.264 · 5.5 Mbit/s · 92 % reliable');
    expect(tuliproxMemberLabel(g.members.last),
        'Not working right now · tried again in 30 s');
    expect(g.members.first.qos7d, 88);
  });

  group('recording on the server', () {
    final start = DateTime.utc(2026, 11, 25, 20);
    final end = DateTime.utc(2026, 11, 25, 21);

    Future<Object?> record() async {
      try {
        await Tuliprox.instance.recordOnServer(_channel(_url),
            title: 'Match', start: start, end: end);
      } catch (e) {
        return e;
      }
      return null;
    }

    test('with the target the server names: the REST request', () async {
      caps['target_name'] = 'main';
      expect(await record(), isNull);
      final b = bodies['POST /admin/api/v1/recording/requests'] as Map;
      expect(b['source'], {
        'target_id': 'main',
        'virtual_id': '949',
        'cluster': 'Live',
        'input_name': '',
      });
      expect(b['program_start'], start.millisecondsSinceEpoch ~/ 1000);
      expect(b['pre_roll_secs'], 60);
      expect(b['post_roll_secs'], 300);
      expect(
          headersOf['POST /admin/api/v1/recording/requests']
              ?['Idempotency-Key'],
          isNotNull);
    });

    test('the target from an own rule; less padding when the server says so',
        () async {
      rules = [
        {
          'id': 'r1',
          'own': true,
          'source': {'target_id': 'lab', 'virtual_id': '1'},
          'body': {'kind': 'weekly_timeslot', 'weekday': 1},
        }
      ];
      var tries = 0;
      recordAnswer = (_) => ++tries == 1
          ? http.Response(
              jsonEncode({'error': 'recording_padding_limit_exceeded'}), 400)
          : http.Response('', 204);
      expect(await record(), isNull);
      final b = bodies['POST /admin/api/v1/recording/requests'] as Map;
      expect((b['source'] as Map)['target_id'], 'lab');
      expect(b['pre_roll_secs'], 0);
      expect(tries, 2);
    });

    test('no target known: sent empty, the server fills in its own', () async {
      expect(await record(), isNull);
      final b = bodies['POST /admin/api/v1/recording/requests'] as Map;
      expect((b['source'] as Map)['target_id'], '');
      expect(calls, isNot(contains('POST /admin/mcp')));
    });

    test('3.3.207 refuses an empty target: the MCP tool, else it says why',
        () async {
      recordAnswer = (_) =>
          http.Response(jsonEncode({'error': 'recording_invalid_source'}), 400);
      expect(await record(), isNull);
      final b = bodies['POST /admin/mcp'] as Map;
      expect((b['params'] as Map)['name'], 'me_record_program');
      expect(((b['params'] as Map)['arguments'] as Map)['vid'], 949);

      mcp = false;
      final e = await record();
      expect(e, isA<TuliproxRecordingError>());
      expect((e as TuliproxRecordingError).code, 'recording_needs_target');
      expect(tuliproxRecordingErrorText(e), contains('weekly'));
    });

    test('refusals in words', () async {
      caps['target_name'] = 'main';
      recordAnswer = (_) =>
          http.Response(jsonEncode({'error': 'recording_quota_exceeded'}), 400);
      expect(tuliproxRecordingErrorText((await record())!), contains('full'));
      caps['recording'] = 'read';
      // Capabilities are kept 5 minutes: a new sign-in reads them again.
      await Tuliprox.instance.save(null);
      Tuliprox.instance.login.value = TuliproxLogin(
          base: _base,
          username: 'admin',
          token: 'admin-jwt',
          issuedAt: DateTime.now());
      final e = await record();
      expect((e as TuliproxRecordingError).code, 'recording_forbidden');
    });

    test('weekly: the device time, its zone (UTC when unknown)', () async {
      final rule = await Tuliprox.instance.recordWeeklyOnServer(_channel(_url),
          start: start, duration: const Duration(minutes: 90));
      final b = bodies['POST /admin/api/v1/recording/rules'] as Map;
      expect(b['virtual_id'], '949');
      expect(b['body'], {
        'kind': 'weekly_timeslot',
        'weekday': 3, // Wednesday
        'local_start_time': '20:00',
        'duration_secs': 5400,
        'timezone': 'UTC',
      });
      expect(rule?.targetId, 'lab');
      // That rule taught the target: a one-off now goes over REST.
      await record();
      expect(calls, contains('POST /admin/api/v1/recording/requests'));
    });
  });

  group('the recordings snapshot over /ws', () {
    late HttpServer server;
    late String base;
    late FutureOr<void> Function(WebSocket ws) script;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}/admin';
      server.listen((req) async {
        if (req.uri.path != '/admin/ws') {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(req);
        await script(ws);
      });
    });
    tearDown(() => server.close(force: true));

    TuliproxLogin login() => TuliproxLogin(
        base: base, username: 'u', token: 'tok', issuedAt: DateTime.now());

    test('version byte, auth, request: the tasks', () async {
      final got = <Object>[];
      script = (ws) {
        ws.listen((frame) {
          got.add(frame);
          final text = frame is List<int> ? utf8.decode(frame) : '$frame';
          if (frame is List<int> && frame.length == 1) {
            ws.add([4]);
          } else if (text.contains('"Auth"')) {
            ws.add(utf8.encode('"Authorized"'));
          } else if (text.contains('RecordingSnapshotRequest')) {
            ws.add(utf8.encode(jsonEncode({
              'RecordingSnapshotResponse': {
                'revision': 12,
                'available': true,
                'quota': {
                  'private_used_bytes': 4294967296,
                  'private_limit_bytes': 21474836480,
                },
                'tasks': [
                  {
                    'id': 'a',
                    'title': 'Morning Match',
                    'program_title': 'Morning Match',
                    'status': 'completed',
                    'owner_id': 'api:u',
                    'channel_name': 'Sports 1 HD',
                    'program_start': 1763679600,
                    'completed_at': 1763683300,
                    'transferred_bytes': 4294967296,
                    'allowed_actions': {'remove': true, 'cancel': false},
                  },
                  {
                    'id': 'b',
                    'program_title': 'Evening News',
                    'status': 'scheduled',
                    'allowed_actions': {'cancel': true},
                  },
                ],
              }
            })));
          }
        });
      };
      final snap = await Tuliprox.instance.api.recordingSnapshot(login());
      expect(got.first, [4]);
      expect(utf8.decode(got[1] as List<int>), '{"Auth":"tok"}');
      expect(snap.revision, 12);
      expect(snap.privateLimitBytes, 21474836480);
      expect(snap.tasks.map((t) => t.id), ['a', 'b']);
      expect(snap.tasks.first.completed, isTrue);
      expect(snap.tasks.first.own, isTrue);
      expect(snap.tasks.first.actions, {'remove'});
      expect(snap.tasks.last.upcoming, isTrue);
      expect(snap.tasks.last.actions, {'cancel'});
    });

    test('an expired token and a switched-off DVR say so', () async {
      script = (ws) => ws.listen((frame) {
            if (frame is List<int> && frame.length == 1) {
              ws.add([4]);
            } else {
              ws.add(utf8.encode('"Unauthorized"'));
            }
          });
      await expectLater(Tuliprox.instance.api.recordingSnapshot(login()),
          throwsA(isA<TuliproxLoginException>()));
      script = (ws) => ws.listen((frame) {
            if (frame is List<int> && frame.length == 1) {
              ws.add([4]);
            } else {
              ws.add(utf8.encode(jsonEncode({
                'RecordingWsError': {'code': 'recording_disabled'}
              })));
            }
          });
      await expectLater(
          Tuliprox.instance.api.recordingSnapshot(login()),
          throwsA(isA<TuliproxRecordingError>()
              .having((e) => e.code, 'code', 'recording_disabled')));
    });
  });

  group('the event stream', () {
    test('the socket signs in with the token and hands over the frames',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      String? auth;
      server.listen((req) async {
        auth = req.headers.value('authorization');
        final ws = await WebSocketTransformer.upgrade(req);
        ws.add(jsonEncode({'type': 'connected', 'server_time': 1}));
        ws.add(jsonEncode({'type': 'connection_denied', 'max_connections': 2}));
      });
      final events = <String>[];
      final got = Completer<void>();
      final socket = TuliproxEventSocket(
          TuliproxLogin(
              base: 'http://127.0.0.1:${server.port}/admin',
              username: 'u',
              token: 'tok',
              issuedAt: DateTime.now()), (e) {
        events.add('${e['type']}');
        if (events.length == 2) got.complete();
      });
      await socket.open();
      await got.future.timeout(const Duration(seconds: 5));
      expect(auth, 'Bearer tok');
      expect(events, ['connected', 'connection_denied']);
      expect(socket.connected, isTrue);
      await socket.close();
    });

    test('what each event means for the channel playing', () async {
      final ch = _channel(_url);
      Tuliprox.instance.noteStarted(ch);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final l =
          (await Tuliprox.instance.playerLogin(Tuliprox.instance.refOf(ch)!))!;

      // A computer can't read X-Tuliprox-Fallback: the event says it.
      Tuliprox.instance.onEventForTest(l, {'type': 'connection_denied'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(Tuliprox.instance.fallbackOf(ch), 'user_connections_exhausted');
      expect(Tuliprox.instance.fallbackNotice.value?.url, ch.url);

      // Another device took it.
      Tuliprox.instance.onEventForTest(
          l, {'type': 'stream_ended', 'uid': 2, 'reason': 'kicked'});
      expect(Tuliprox.instance.eventNotice.value?.text,
          contains('Another device'));

      // The server moved it (not our own switch).
      Tuliprox.instance.eventNotice.value = null;
      Tuliprox.instance.onEventForTest(l, {
        'type': 'failover_member_switched',
        'group_virtual_id': 949,
        'from_member_vid': 593860,
        'to_member_vid': 287937,
      });
      expect(Tuliprox.instance.eventNotice.value?.text,
          contains('another of its sources'));

      // A recording finished: Recordings reload.
      final before = Tuliprox.instance.recordingsChanged.value;
      Tuliprox.instance.onEventForTest(
          l, {'type': 'recording_finished', 'id': 'x', 'state': 'completed'});
      expect(Tuliprox.instance.recordingsChanged.value, before + 1);
      await Tuliprox.instance.release(ch);
    });
  });

  group('watch progress', () {
    const movie = 'https://tv.example.com/movie/labuser/labpass/77.mkv';
    const episode = 'https://tv.example.com/series/labuser/labpass/4711.mp4';

    test('a Tuliprox movie / episode is known by its Xtream id', () {
      final m = Tuliprox.instance.vodRefOf(_channel(movie, id: 'xt_vod_77'))!;
      expect((m.kind, m.ref.id, m.ref.username), ('movie', 77, 'labuser'));
      final e =
          Tuliprox.instance.vodRefOf(_channel(episode, id: 'xt_ep_4711'))!;
      expect((e.kind, e.ref.id), ('episode', 4711));
      expect(Tuliprox.instance.vodRefOf(_channel(_url)), isNull);
      expect(
          Tuliprox.instance.vodRefOf(
              _channel('https://other.example/movie/a/b/1.mkv', id: 'x')),
          isNull);
    });

    test('saved on the server every 30 s and when it stops', () async {
      final c = _channel(movie, id: 'xt_vod_77');
      const d = Duration(minutes: 100);
      await Tuliprox.instance
          .noteVodProgress(c, const Duration(minutes: 25), d);
      expect(bodies['PUT /admin/api/v1/me/progress/movie/77'],
          {'position_secs': 1500, 'duration_secs': 6000});
      await Tuliprox.instance
          .noteVodProgress(c, const Duration(minutes: 26), d);
      expect(calls.where((x) => x.startsWith('PUT ')), hasLength(1));
      await Tuliprox.instance
          .noteVodProgress(c, const Duration(minutes: 27), d, done: true);
      expect(calls.where((x) => x.startsWith('PUT ')), hasLength(2));
    });

    test('what another app saved shows as Resume here', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      progress = [
        {
          'kind': 'movie',
          'item_id': 77,
          'position_secs': 1500,
          'duration_secs': 6000,
          'watched': false,
        },
        {
          'kind': 'episode',
          'item_id': 4711,
          'position_secs': 2900,
          'duration_secs': 3000,
          'watched': true,
        },
      ];
      final m = _channel(movie, id: 'xt_vod_77');
      final e = _channel(episode, id: 'xt_ep_4711');
      final played = _channel(
          'https://tv.example.com/movie/labuser/labpass/78.mkv',
          id: 'xt_vod_78');
      await storage.setLastPosition(played.id, 42000);
      expect(await Tuliprox.instance.pullVodProgress([m, e, played], storage),
          isTrue);
      expect(storage.getLastPosition(m.id), 1500000);
      expect(storage.getLastDuration(m.id), 6000000);
      expect(storage.getLastPosition(e.id), 3000000, reason: 'watched');
      expect(storage.getLastPosition(played.id), 42000,
          reason: 'a position from here wins');
      expect(calls.where((x) => x == 'GET /admin/api/v1/me/progress'),
          hasLength(1));
    });
  });

  test('channels, EPG, bouquet, members before playback, conflicts', () async {
    final l = (await Tuliprox.instance
        .playerLogin(Tuliprox.instance.refOf(_channel(_url))!))!;
    final api = Tuliprox.instance.api;
    final ch = (await api.searchChannels(l, query: 'sports')).single;
    expect((ch.virtualId, ch.isGroup, ch.epgChannelId),
        (1042, true, 'sports1.example.com'));
    final p = (await api.epg(l, 1042)).single;
    expect((p.title, p.isNew), ('Morning Match', true));
    expect(p.start.millisecondsSinceEpoch, 1763679600000);
    final b = await api.bouquet(l);
    expect(b['xtream']?['live'], ['Sports']);
    expect(b['xtream']?['series'], isNull);
    expect(b['m3u'], isNull);
    final g = (await api.channelMembers(l, 949))!;
    expect(g.members, hasLength(2));
    expect(g.currentVid, isNull);
    expect(
        await api.recordingConflicts(l,
            targetName: 'main',
            vid: 949,
            start: DateTime(2026),
            end: DateTime(2026, 1, 1, 1)),
        'possible_capacity_wait');
  });
}
