import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/tuliprox.dart';

/// Tuliprox failover groups in the player's Sources (owner, 2026-11-19).
/// Fixtures follow Tuliprox 3.3.204's JSON (snake_case, `StreamInfo`,
/// `StreamFailoverMembersDto`).

const _base = 'https://tv.example.com/admin';

Channel _channel(String url) => Channel(
    id: 'p1::1234',
    rawId: '1234',
    playlistId: 'p1',
    name: 'UK: Sky Sports F1',
    group: 'UK| Sports',
    url: url);

Map<String, dynamic> _stream(int uid, String user, int vid,
        {int? group, int started = 100, int? member}) =>
    {
      'uid': uid,
      'username': user,
      'channel': {
        'target_id': 1,
        'virtual_id': vid,
        if (group != null) 'group_virtual_id': group,
        'provider_id': 7,
        'input_name': 'DM200 Lab',
        'item_type': 'live',
        'cluster': 'live',
        'group': 'UK| Sports',
        'title': 'UK: Sky Sports F1',
        'url': 'http://provider/x',
        'shared': false,
      },
      'provider': 'DM200 Lab',
      'addr': '1.2.3.4:5',
      'client_ip': '1.2.3.4',
      'started_at': started,
      if (member != null)
        'member_info': {
          'title': 'UK: SKY SPORT F1 RAW',
          'input_name': 'DM200 Lab',
          'provider': 'x',
          'member_vid': member,
        },
    };

void main() {
  group('tuliproxChannelRef', () {
    test('reads the Xtream user and channel id on the same host', () {
      final r = tuliproxChannelRef(
          _base, 'https://tv.example.com/live/DM200lab/DOM002/1234.ts')!;
      expect(r.username, 'DM200lab');
      expect(r.id, 1234);
      expect(
          tuliproxChannelRef(
                  _base, 'https://TV.example.com/DM200lab/DOM002/77.m3u8')!
              .id,
          77);
    });

    test('another host or shape is not a Tuliprox channel', () {
      expect(tuliproxChannelRef(_base, 'https://other.example/live/u/p/1.ts'),
          isNull);
      expect(
          tuliproxChannelRef(_base, 'https://tv.example.com/movie/u/p/1.mkv'),
          isNull);
      expect(tuliproxChannelRef(_base, 'https://tv.example.com/x/y'), isNull);
    });
  });

  test('normalizeUrl keeps the Web UI path, drops the page', () {
    expect(TuliproxApi.normalizeUrl('tv.example.com/admin/'), _base);
    expect(TuliproxApi.normalizeUrl('https://tv.example.com/admin/#/dashboard'),
        _base);
    expect(TuliproxApi.normalizeUrl('http://10.0.0.5:8901'),
        'http://10.0.0.5:8901');
  });

  group('TuliproxApi', () {
    test('signs in, keeps the token, not the password', () async {
      late Map<String, dynamic> sent;
      final api = TuliproxApi(client: MockClient((req) async {
        expect(req.url.toString(), '$_base/auth/token');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({'token': 'jwt-1', 'username': 'admin'}), 200);
      }));
      final l = await api.signIn(_base, 'admin', 'secret');
      expect(sent, {'username': 'admin', 'password': 'secret'});
      expect(l.token, 'jwt-1');
      expect(jsonEncode(l.toJson()), isNot(contains('secret')));
      expect(TuliproxLogin.parse(jsonEncode(l.toJson()))!.token, 'jwt-1');
    });

    test('wrong password and no Web UI are told apart', () async {
      Future<Object?> fail(int status) async {
        final api = TuliproxApi(
            client: MockClient((_) async => http.Response('', status)));
        try {
          await api.signIn(_base, 'a', 'b');
        } catch (e) {
          return e;
        }
        return null;
      }

      expect(await fail(401), isA<TuliproxLoginException>());
      expect(await fail(404), isA<TuliproxException>());
      expect(await fail(404), isNot(isA<TuliproxLoginException>()));
    });

    test('a non-admin login reads no streams (403)', () async {
      final api = TuliproxApi(
          client: MockClient((_) async => http.Response('forbidden', 403)));
      final l = TuliproxLogin(
          base: _base, username: 'u', token: 't', issuedAt: DateTime.now());
      expect(() => api.streams(l), throwsA(isA<TuliproxForbiddenException>()));
    });
  });

  group('Tuliprox sources of the playing channel', () {
    late List<String> calls;
    late Map<String, dynamic>? switched;

    setUp(() {
      calls = [];
      switched = null;
      Tuliprox.instance.api = TuliproxApi(client: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        expect(req.headers['Authorization'], 'Bearer t');
        final p = req.url.path;
        if (p == '/admin/api/v1/streams') {
          return http.Response(
              jsonEncode([
                _stream(5, 'someone', 1234, group: 1234), // another user
                _stream(9, 'DM200lab', 88001, group: 1234, started: 50),
                _stream(11, 'DM200lab', 88002,
                    group: 1234, started: 200, member: 88002), // newest
              ]),
              200);
        }
        if (p == '/admin/api/v1/streams/11/failover-members') {
          return http.Response(
              jsonEncode({
                'group_name': 'UK: Sky Sports F1',
                'current_member_vid': 88002,
                'members': [
                  {
                    'member_vid': 88001,
                    'member_ref': {'input': 'DM200 Lab', 'stream_id': '1'},
                    'title': 'UK: SKY SPORT F1 HD',
                    'input_name': 'DM200 Lab',
                    'provider_id': 1,
                    'has_archive': false,
                  },
                  {
                    'member_vid': 88002,
                    'member_ref': {'input': 'DM200 Lab', 'stream_id': '2'},
                    'title': 'UK: SKY SPORT F1 RAW',
                    'input_name': 'DM200 Lab',
                    'provider_id': 2,
                    'has_archive': true,
                  },
                  {
                    'member_vid': 88003,
                    'member_ref': {'input': 'AA TREX', 'stream_id': '3'},
                    'title': 'UK| SKY SPORTS F1 FHD',
                    'input_name': 'AA TREX',
                    'provider_id': 3,
                    'has_archive': false,
                  },
                ],
              }),
              200);
        }
        if (p == '/admin/api/v1/streams/11/failover-switch') {
          switched = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('', 200);
        }
        return http.Response('nope', 404);
      }));
      Tuliprox.instance.login.value = TuliproxLogin(
          base: _base, username: 'admin', token: 't', issuedAt: DateTime.now());
    });

    tearDown(() => Tuliprox.instance.login.value = null);

    test('lists the members of this user\'s newest stream of the channel',
        () async {
      final g = await Tuliprox.instance.groupFor(
          _channel('https://tv.example.com/live/DM200lab/DOM002/1234.ts'));
      expect(g, isNotNull);
      expect(g!.uid, 11);
      expect(g.currentVid, 88002);
      expect(
          g.members.map((m) => m.input), ['DM200 Lab', 'DM200 Lab', 'AA TREX']);
      expect(g.members[1].hasArchive, isTrue);
    });

    test('a channel of another server asks nothing', () async {
      final g = await Tuliprox.instance
          .groupFor(_channel('https://elsewhere.example/live/u/p/1234.ts'));
      expect(g, isNull);
      expect(calls, isEmpty);
    });

    test('picking a member row switches the open stream on the server',
        () async {
      final own =
          _channel('https://tv.example.com/live/DM200lab/DOM002/1234.ts');
      final g = (await Tuliprox.instance.groupFor(own))!;
      final url = Tuliprox.instance.notePick(own, g.uid, g.members[2]);
      // The row's URL is the channel's own, with a fragment no server sees.
      expect(Uri.parse(url).removeFragment().toString(), own.url);
      final row = Channel(
          id: own.id,
          rawId: own.rawId,
          playlistId: own.playlistId,
          name: g.members[2].title,
          group: own.group,
          url: url);
      expect(Tuliprox.instance.isPick(row), isTrue);
      expect(Tuliprox.instance.isPick(own), isFalse);
      expect(await Tuliprox.instance.switchTo(row), 'UK| SKY SPORTS F1 FHD');
      expect(switched, {'member_vid': 88003});
    });
  });

  group('playlist users', () {
    final apiproxy = {
      'server': [
        {
          'name': 'default',
          'protocol': 'https',
          'host': 'tv.example.com',
          'port': '443',
          'timezone': 'America/Toronto',
          'message': 'Welcome',
        },
        {
          'name': 'lan',
          'protocol': 'http',
          'host': '10.0.0.5',
          'port': '8901',
          'timezone': 'UTC',
          'message': '',
          'path': 'tv/',
        },
      ],
      'user': [
        {
          'target': 'DM200_lab',
          'credentials': [
            {
              'username': 'DM200lab',
              'password': '***',
              'server': 'default',
              'max_connections': 1,
              'status': 'Active',
            },
          ],
        },
        {
          'target': 'trex_1',
          'credentials': [
            {'username': 'aa', 'password': '***', 'server': 'lan'},
            {'username': 'bb', 'password': '***', 'server': 'lan'},
          ],
        },
      ],
    };

    test('lists users, playlists and the address each streams from', () {
      final u = TuliproxUsers.fromJson(apiproxy);
      expect(u.users.map((x) => x.username), ['DM200lab', 'aa', 'bb']);
      expect(u.targets, ['DM200_lab', 'trex_1']);
      expect(u.addressOf(u.users.first), 'https://tv.example.com');
      expect(u.addressOf(u.users[1]), 'http://10.0.0.5:8901/tv');
      expect(u.serverNameFor('trex_1'), 'lan');
      expect(u.serverNameFor('nobody'), 'default');
    });

    test('creating a user sends a 1-connection active user', () async {
      late http.Request sent;
      final api = TuliproxApi(client: MockClient((req) async {
        sent = req;
        return http.Response('', 200);
      }));
      await api.createUser(
          TuliproxLogin(
              base: _base,
              username: 'admin',
              token: 't',
              issuedAt: DateTime.now()),
          'DM200_lab',
          username: 'vesperab12',
          password: 'pw',
          server: 'default',
          comment: 'Created by VesperTV');
      expect(sent.method, 'POST');
      expect(sent.url.path, '/admin/api/v1/user/DM200_lab');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['username'], 'vesperab12');
      expect(body['password'], 'pw');
      expect(body['max_connections'], 1);
      expect(body['status'], 'Active');
      expect(body['ui_enabled'], false);
      expect(body['server'], 'default');
    });

    test('a generated login is vesper + 4, password 12 letters/digits', () {
      final c = newTuliproxCredentials();
      expect(c.username, matches(RegExp(r'^vesper[a-z0-9]{4}$')));
      expect(c.password, matches(RegExp(r'^[A-Za-z0-9]{12}$')));
      expect(newTuliproxCredentials().password, isNot(c.password));
    });
  });
}
