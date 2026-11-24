import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/tuliprox.dart';

/// Tuliprox's Player API (`feature/player_user_api`, 2026-11-23): Sources and
/// "drop the previous stream on a channel change" as the playlist user
/// itself, not the admin. Fixtures follow the branch's docs/src/player-api.md
/// and what the owner's server answered for the lab user.
const _base = 'https://tv.example.com/admin';
const _url = 'https://tv.example.com/live/labuser/labpass/949.ts';

Channel _channel(String url) => Channel(
    id: 'p1::949',
    rawId: '949',
    playlistId: 'p1',
    name: 'UK: Sky Sport News',
    group: 'UK| News',
    url: url);

void main() {
  late List<String> calls;
  late Map<String, Object?> signIns;
  late bool playerRoutes;
  late List<Map<String, Object?>> ownStreams;
  late http.Response Function(http.Request) switchAnswer;
  late List<int> deleted;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    calls = [];
    signIns = {};
    playerRoutes = true;
    deleted = [];
    ownStreams = [
      // This box, just now.
      {
        'uid': 2,
        'virtual_id': 593860,
        'group_virtual_id': 949,
        'member_vid': 593860,
        'protocol': 'ts',
        'shared': true,
        'started_at': now,
        'user_agent': 'VesperTV',
      },
    ];
    switchAnswer = (_) => http.Response('', 200);
    Tuliprox.instance.ownLookupDelay = Duration.zero;
    Tuliprox.instance.api = TuliproxApi(client: MockClient((req) async {
      final p = req.url.path;
      calls.add('${req.method} $p');
      if (p == '/admin/auth/token') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        signIns[body['username'] as String] = body['password'];
        return http.Response(
            jsonEncode({'token': 'player-jwt', 'username': body['username']}),
            200);
      }
      final bearer = req.headers['Authorization'];
      if (p.startsWith('/admin/api/v1/me/')) {
        expect(bearer, 'Bearer player-jwt',
            reason: 'player routes use the playlist user, never the admin');
        if (!playerRoutes) return http.Response('', 404);
      }
      switch ((req.method, p)) {
        case ('GET', '/admin/api/v1/me/capabilities'):
          return http.Response(
              jsonEncode({
                'source_switch': true,
                'joinable_streams': true,
                'max_connections': 2,
                'active_connections': 1,
              }),
              200);
        case ('GET', '/admin/api/v1/me/streams'):
          return http.Response(jsonEncode(ownStreams), 200);
        case ('GET', '/admin/api/v1/me/streams/joinable'):
          return http.Response(
              jsonEncode([
                {
                  'virtual_id': 1042,
                  'title': 'Sports 1 HD',
                  'protocol': 'ts',
                  'requires_free_slot': false,
                },
                {
                  'virtual_id': 1043,
                  'title': 'Movies 2',
                  'protocol': 'ts',
                  'requires_free_slot': true, // costs a slot: not offered
                },
              ]),
              200);
        case ('GET', '/admin/api/v1/me/streams/2/failover-members'):
          return http.Response(
              jsonEncode({
                'group_name': 'UK: SKY SPORT NEWS',
                'current_member_vid': 593860,
                'members': [
                  {
                    'member_vid': 593860,
                    'index': 0,
                    'title': 'UK: SKY SPORT NEWS',
                    'has_archive': false,
                    'current': true,
                    'health': {
                      'state': 'ok',
                      'resolution': 'P1080',
                      'video_codec': 'H264',
                      'bitrate_kbps': 5500,
                    },
                  },
                  {
                    'member_vid': 287937,
                    'index': 1,
                    'title': 'UK| SKY SPORT NEWS',
                    'has_archive': false,
                    'current': false,
                    'health': {'state': 'failing', 'retry_after_secs': 30},
                  },
                ],
              }),
              200);
        case ('POST', '/admin/api/v1/me/streams/2/failover-switch'):
          return switchAnswer(req);
        case ('DELETE', final String path)
            when path.startsWith('/admin/api/v1/me/streams/'):
          deleted.add(int.parse(path.split('/').last));
          return http.Response('', 204);
        case ('GET', '/admin/api/v1/streams'):
          expect(bearer, 'Bearer admin-jwt');
          return http.Response('[]', 200);
      }
      return http.Response('nope', 404);
    }));
    Tuliprox.instance.login.value = TuliproxLogin(
        base: _base,
        username: 'admin',
        token: 'admin-jwt',
        issuedAt: DateTime.now());
  });

  tearDown(() async => Tuliprox.instance.save(null));

  test('the URL gives the playlist login; the player routes sign it in once',
      () async {
    final ref = tuliproxChannelRef(_base, _url)!;
    expect(ref.password, 'labpass');
    final l = await Tuliprox.instance.playerLogin(ref);
    expect(l!.username, 'labuser');
    expect(signIns, {'labuser': 'labpass'});
    await Tuliprox.instance.playerLogin(ref);
    expect(calls.where((c) => c == 'POST /admin/auth/token'), hasLength(1));
  });

  test('Sources list this viewer\'s own stream through the player routes',
      () async {
    final g = await Tuliprox.instance.groupFor(_channel(_url));
    expect(g, isNotNull);
    expect(g!.uid, 2);
    expect(g.player, isNotNull);
    expect(g.currentVid, 593860);
    expect(g.members.first.quality, '1080p · H.264 · 5.5 Mbit/s');
    expect(g.members.last.failing, isTrue);
    expect(calls, isNot(contains('GET /admin/api/v1/streams')),
        reason: 'no admin route when the player routes answer');
  });

  test('a server without player routes falls back to the admin routes',
      () async {
    playerRoutes = false;
    await Tuliprox.instance.groupFor(_channel(_url));
    expect(calls, contains('GET /admin/api/v1/streams'));
  });

  test('a picked source switches only this viewer\'s stream', () async {
    final own = _channel(_url);
    final g = (await Tuliprox.instance.groupFor(own))!;
    final url = Tuliprox.instance
        .notePick(own, g.uid, g.members.last, player: g.player);
    final row = _channel(url);
    expect(await Tuliprox.instance.switchTo(row), 'UK| SKY SPORT NEWS');
    expect(calls, contains('POST /admin/api/v1/me/streams/2/failover-switch'));

    // Others on the same shared stream: refused, said plainly.
    switchAnswer = (_) => http.Response('shared_stream_switch_refused', 409);
    Object? error;
    try {
      await Tuliprox.instance.switchTo(row);
    } catch (e) {
      error = e;
    }
    expect(error, isA<TuliproxSwitchRefused>());
    expect(tuliproxRefusalText(error!), contains('Someone else'));
    expect(
        tuliproxRefusalText(
            TuliproxSwitchRefused('switch_cooldown', status: 429)),
        contains('Wait a moment'));
  });

  test('leaving a channel ends its stream on the server', () async {
    final ch = _channel(_url);
    Tuliprox.instance.noteStarted(ch);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, contains('GET /admin/api/v1/me/streams'),
        reason: 'the stream is found after the start');
    await Tuliprox.instance.release(ch);
    expect(deleted, [2]);
    // Twice is nothing more.
    await Tuliprox.instance.release(ch);
    expect(deleted, [2]);
  });

  test('a quick zap before the lookup still drops the previous stream',
      () async {
    Tuliprox.instance.ownLookupDelay = const Duration(hours: 1);
    final ch = _channel(_url);
    Tuliprox.instance.noteStarted(ch);
    await Tuliprox.instance.release(ch);
    expect(deleted, [2]);
  });

  test('never another TV\'s older stream of the same channel', () async {
    ownStreams = [
      {
        'uid': 7,
        'virtual_id': 593860,
        'group_virtual_id': 949,
        'started_at': now - 3600, // the bedroom TV, an hour ago
      },
    ];
    final ch = _channel(_url);
    Tuliprox.instance.noteStarted(ch);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await Tuliprox.instance.release(ch);
    expect(deleted, isEmpty);
  });

  test('a refusal names its reason and the channels ready to join', () async {
    // What ExoPlayerEventListener.describeCause writes for a 502 slate.
    const raw = 'ExoPlaybackException: Source error [HTTP 502 Bad Gateway] '
        '[Tuliprox provider_connections_exhausted] '
        '[ERROR_CODE_IO_BAD_HTTP_STATUS]';
    expect(tuliproxReasonOf(raw), 'provider_connections_exhausted');
    expect(tuliproxReasonOf('[HTTP 502 Bad Gateway]'), isNull);
    final ch = _channel(_url);
    expect(
        await Tuliprox.instance
            .noteFallback(ch, 'provider_connections_exhausted'),
        isTrue);
    expect(Tuliprox.instance.fallbackOf(ch), 'provider_connections_exhausted');
    expect(Tuliprox.instance.joinableFor(ch).map((j) => j.virtualId), [1042]);
    final text = tuliproxFallbackMessage('provider_connections_exhausted')!;
    expect(text, contains('provider connections are in use'));
    expect(text, contains('Sports 1 HD'));
    expect(text, isNot(contains('Movies 2')));
    expect(Tuliprox.instance.fallbackNotice.value?.url, ch.url);
    // Another channel's list is not this one's.
    expect(
        Tuliprox.instance
            .joinableFor(_channel('https://tv.example.com/live/a/b/1.ts')),
        isEmpty);
    // A new start of the channel forgets it.
    Tuliprox.instance.noteStarted(ch);
    expect(Tuliprox.instance.fallbackOf(ch), isNull);
    expect(tuliproxFallbackText('something_new'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('Sources on the busy video read the channels to join themselves',
      () async {
    // Tuliprox serves its busy video: no stream of this viewer is open.
    ownStreams = [];
    final ch = _channel(_url);
    expect(await Tuliprox.instance.groupFor(ch), isNull);
    expect(calls, contains('GET /admin/api/v1/me/streams/joinable'));
    expect(Tuliprox.instance.joinableFor(ch).map((j) => j.virtualId), [1042]);
    // A new start of the channel forgets them.
    Tuliprox.instance.noteStarted(ch);
    expect(Tuliprox.instance.joinableFor(ch), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('Sources opened as the busy video is found wait for its list', () async {
    final ch = _channel(_url);
    // The fallback's read is still running when Sources ask.
    final read =
        Tuliprox.instance.noteFallback(ch, 'provider_connections_exhausted');
    expect(Tuliprox.instance.joinableFor(ch), isEmpty);
    await Tuliprox.instance.joinableSettled(ch);
    expect(Tuliprox.instance.joinableFor(ch).map((j) => j.virtualId), [1042]);
    expect(await read, isTrue);
  });

  test('a server found through player_api.php needs no Settings sign-in',
      () async {
    Tuliprox.instance.login.value = null;
    final ch = _channel(_url);
    expect(Tuliprox.instance.refOf(ch), isNull);
    // server_info.player_api_path (Tuliprox e5704880).
    Tuliprox.instance.noteServer('https://tv.example.com', '/admin');
    expect(Tuliprox.instance.refOf(ch)?.base, _base);
    final g = await Tuliprox.instance.groupFor(ch);
    expect(g?.uid, 2);
    expect(signIns, {'labuser': 'labpass'});
    expect(calls, isNot(contains('GET /admin/api/v1/streams')));
    // Root path: the host itself.
    Tuliprox.instance.noteServer('https://tv.example.com', '/');
    expect(Tuliprox.instance.refOf(ch)?.base, 'https://tv.example.com');
    // No field any more: forgotten.
    Tuliprox.instance.noteServer('https://tv.example.com', null);
    expect(Tuliprox.instance.refOf(ch), isNull);
  });

  test('the stream uid from the answer is released, no lookup', () async {
    Tuliprox.instance.ownLookupDelay = const Duration(milliseconds: 30);
    final ch = _channel(_url);
    Tuliprox.instance.noteStarted(ch);
    Tuliprox.instance.noteOwnUid(ch, 77); // X-Tuliprox-Stream-Uid
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, isNot(contains('GET /admin/api/v1/me/streams')));
    await Tuliprox.instance.release(ch);
    expect(deleted, [77]);
  });

  test('a join row plays the playlist\'s own channel', () {
    final c = _channel('https://tv.example.com/live/labuser/labpass/1042.ts');
    final row = c.copyWith(url: '${c.url}${Tuliprox.joinMark}');
    expect(Tuliprox.instance.isJoin(row), isTrue);
    expect(Tuliprox.instance.isJoin(c), isFalse);
    expect(Tuliprox.instance.joinTarget(row).url, c.url);
  });

  test('channels of other servers or never started ask nothing', () async {
    await Tuliprox.instance
        .release(_channel('https://other.example/live/u/p/1.ts'));
    await Tuliprox.instance.release(_channel(_url));
    expect(calls, isEmpty);
  });
}
