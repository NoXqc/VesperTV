import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import 'storage_service.dart';

/// Tuliprox (github.com/euzu/tuliprox): an IPTV proxy whose **failover
/// groups** (develop builds, 3.3.2xx) merge the same channel from several
/// provider streams into ONE playlist channel and pick / switch the source on
/// the server, under the open stream (owner, 2026-11-19, DM200 lab target).
/// Like Dispatcharr ([Dispatcharr]) the other sources are only visible through
/// its REST API, and only to a Web UI login with `system.read` (an admin).
///
/// API (base = `https://host[:port]/<web ui path>`, e.g. `…/admin`):
/// `POST {base}/auth/token` `{"username","password"}` -> `{"token"}` (JWT,
/// `web_ui.auth.token_ttl_mins`, 12 h on the owner's server),
/// `POST {base}/auth/refresh` (Bearer, still valid) -> a fresh token,
/// `GET {base}/api/v1/status` (`version`, `active_provider_connections`),
/// `GET {base}/api/v1/streams` (the open streams: `uid`, `username`,
/// `channel.virtual_id` / `group_virtual_id`, `member_info`),
/// `GET {base}/api/v1/streams/{uid}/failover-members` (`current_member_vid`,
/// `members[{member_vid, title, input_name, has_archive}]`) and
/// `POST {base}/api/v1/streams/{uid}/failover-switch` `{"member_vid"}`: the
/// server splices that member into the open stream (MPEG-TS live only; a
/// shared stream switches for everyone on it). Only the token is kept, never
/// the password; it is refreshed while valid, so a box used at least every
/// 12 h stays signed in.
class TuliproxLogin {
  const TuliproxLogin(
      {required this.base,
      required this.username,
      required this.token,
      required this.issuedAt});

  /// `https://host[:port]/<web ui path>`, no trailing slash.
  final String base;
  final String username;
  final String token;
  final DateTime issuedAt;

  TuliproxLogin withToken(String t) => TuliproxLogin(
      base: base, username: username, token: t, issuedAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'base': base,
        'username': username,
        'token': token,
        'issuedAt': issuedAt.toIso8601String(),
      };

  static TuliproxLogin? parse(String raw) {
    if (raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final base = j['base'] as String? ?? '';
      final token = j['token'] as String? ?? '';
      if (base.isEmpty || token.isEmpty) return null;
      return TuliproxLogin(
          base: base,
          username: j['username'] as String? ?? '',
          token: token,
          issuedAt: DateTime.tryParse(j['issuedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0));
    } catch (_) {
      return null;
    }
  }
}

class TuliproxException implements Exception {
  TuliproxException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => 'TuliproxException($message)';
}

/// Wrong user name / password, or a token the server no longer accepts.
class TuliproxLoginException extends TuliproxException {
  TuliproxLoginException({super.status}) : super('login');
}

/// Signed in, but the login may not read the server's streams
/// (`system.read`): only an admin gets the Sources rows.
class TuliproxForbiddenException extends TuliproxException {
  TuliproxForbiddenException() : super('forbidden', status: 403);
}

/// What `/api/v1/status` says.
class TuliproxStatus {
  const TuliproxStatus(
      {required this.version,
      required this.activeUsers,
      required this.providerConnections});
  final String version;
  final int activeUsers;

  /// Open provider connections per input (provider account).
  final Map<String, int> providerConnections;

  static TuliproxStatus fromJson(Map<String, dynamic> j) {
    final conns = <String, int>{};
    final raw = j['active_provider_connections'];
    if (raw is Map) {
      for (final e in raw.entries) {
        conns['${e.key}'] = _int(e.value) ?? 0;
      }
    }
    return TuliproxStatus(
      version: '${j['version'] ?? ''}',
      activeUsers: _int(j['active_users']) ?? 0,
      providerConnections: conns,
    );
  }
}

/// One open stream on the server ([TuliproxApi.streams]).
class TuliproxStream {
  const TuliproxStream(
      {required this.uid,
      required this.username,
      required this.virtualId,
      this.groupVirtualId,
      this.startedAt = 0,
      this.title = '',
      this.memberTitle,
      this.memberInput,
      this.memberVid});
  final int uid;
  final String username;
  final int virtualId;
  final int? groupVirtualId;
  final int startedAt;
  final String title;
  final String? memberTitle;
  final String? memberInput;
  final int? memberVid;

  static TuliproxStream? fromJson(Map<String, dynamic> j) {
    final uid = _int(j['uid']);
    final ch = j['channel'];
    if (uid == null || ch is! Map) return null;
    final vid = _int(ch['virtual_id']);
    if (vid == null) return null;
    final m = j['member_info'];
    return TuliproxStream(
      uid: uid,
      username: '${j['username'] ?? ''}',
      virtualId: vid,
      groupVirtualId: _int(ch['group_virtual_id']),
      startedAt: _int(j['started_at']) ?? _int(j['ts']) ?? 0,
      title: '${ch['title'] ?? ''}',
      memberTitle: m is Map ? '${m['title'] ?? ''}' : null,
      memberInput: m is Map ? '${m['input_name'] ?? ''}' : null,
      memberVid: m is Map ? _int(m['member_vid']) : null,
    );
  }

  /// Whether this is [user]'s stream of Xtream channel [id] (the group's id
  /// or one of its members').
  bool isOf(String user, int id) =>
      username == user && (virtualId == id || groupVirtualId == id);
}

/// One source of a failover group.
class TuliproxMember {
  const TuliproxMember(
      {required this.vid,
      required this.title,
      required this.input,
      this.hasArchive = false});
  final int vid;
  final String title;

  /// The Tuliprox input (provider account) it comes from.
  final String input;
  final bool hasArchive;
}

/// The playing group, its sources and the one on air now.
class TuliproxGroup {
  const TuliproxGroup(
      {required this.uid,
      required this.name,
      required this.members,
      this.currentVid});
  final int uid;
  final String name;
  final List<TuliproxMember> members;
  final int? currentVid;

  static TuliproxGroup fromJson(int uid, Map<String, dynamic> j) {
    final members = <TuliproxMember>[];
    for (final m in (j['members'] as List? ?? const [])) {
      if (m is! Map) continue;
      final vid = _int(m['member_vid']);
      if (vid == null) continue;
      members.add(TuliproxMember(
        vid: vid,
        title: '${m['title'] ?? ''}',
        input: '${m['input_name'] ?? ''}',
        hasArchive: m['has_archive'] == true,
      ));
    }
    return TuliproxGroup(
      uid: uid,
      name: '${j['group_name'] ?? ''}',
      members: members,
      currentVid: _int(j['current_member_vid']),
    );
  }
}

int? _int(Object? v) => switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };

/// A playlist channel on a Tuliprox server: its Xtream user and channel id.
class TuliproxChannelRef {
  const TuliproxChannelRef({required this.username, required this.id});
  final String username;
  final int id;
  @override
  String toString() => 'channel $id';
}

/// [url] as an Xtream live channel of the Tuliprox at [base] (same host; the
/// stream URLs carry no Web UI path): `…/live/{user}/{pass}/{id}[.ts|.m3u8]`
/// or `…/{user}/{pass}/{id}`. Null for another server or another URL shape.
TuliproxChannelRef? tuliproxChannelRef(String base, String url) {
  final b = Uri.tryParse(base);
  final u = Uri.tryParse(url);
  if (b == null || u == null || b.host.isEmpty) return null;
  if (u.host.toLowerCase() != b.host.toLowerCase()) return null;
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  List<String>? rest;
  if (segs.length == 4 && segs[0] == 'live') rest = segs.sublist(1);
  if (segs.length == 3) rest = segs;
  if (rest == null) return null;
  final id = int.tryParse(rest[2].split('.').first);
  if (id == null) return null;
  return TuliproxChannelRef(username: Uri.decodeComponent(rest[0]), id: id);
}

class TuliproxApi {
  TuliproxApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  /// What the user typed, as the Web UI's base: `https://` by default (a
  /// Tuliprox is usually behind a reverse proxy), no trailing slash, no
  /// page pasted from the browser (`…/admin/#/dashboard`).
  static String normalizeUrl(String input) {
    var u = input.trim();
    final hash = u.indexOf('#');
    if (hash >= 0) u = u.substring(0, hash);
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    u = u.replaceAll(RegExp(r'/+$'), '');
    u = u.replaceFirst(RegExp(r'/(index\.html|login)$'), '');
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  static Map<String, String> _headers({String? bearer}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'VesperTV',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      };

  dynamic _decode(http.Response r, {bool empty = false}) {
    if (r.statusCode == 401) throw TuliproxLoginException(status: 401);
    if (r.statusCode == 403) throw TuliproxForbiddenException();
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw TuliproxException('HTTP ${r.statusCode}', status: r.statusCode);
    }
    if (empty || r.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw TuliproxException('not Tuliprox');
    }
  }

  Future<dynamic> _get(TuliproxLogin l, String path) async =>
      _decode(await _client
          .get(Uri.parse('${l.base}$path'), headers: _headers(bearer: l.token))
          .timeout(_timeout));

  /// Signs in once; only the token is kept.
  Future<TuliproxLogin> signIn(
      String base, String username, String password) async {
    final http.Response r;
    try {
      r = await _client
          .post(Uri.parse('$base/auth/token'),
              headers: _headers(),
              body: jsonEncode({'username': username, 'password': password}))
          .timeout(_timeout);
    } on TimeoutException {
      throw TuliproxException('timeout');
    }
    if (r.statusCode == 404 || r.statusCode == 405) {
      throw TuliproxException('no Tuliprox Web UI here', status: r.statusCode);
    }
    if (r.statusCode == 400 || r.statusCode == 403) {
      throw TuliproxLoginException(status: r.statusCode);
    }
    final j = _decode(r);
    final token = j is Map ? j['token'] : null;
    if (token is! String || token.isEmpty) {
      throw TuliproxException('not Tuliprox');
    }
    return TuliproxLogin(
        base: base, username: username, token: token, issuedAt: DateTime.now());
  }

  /// A fresh token for a still valid one.
  Future<TuliproxLogin> refresh(TuliproxLogin l) async {
    final j = _decode(await _client
        .post(Uri.parse('${l.base}/auth/refresh'),
            headers: _headers(bearer: l.token))
        .timeout(_timeout));
    final token = j is Map ? j['token'] : null;
    if (token is! String || token.isEmpty) throw TuliproxLoginException();
    return l.withToken(token);
  }

  Future<TuliproxStatus> status(TuliproxLogin l) async {
    final j = await _get(l, '/api/v1/status');
    if (j is! Map<String, dynamic>) throw TuliproxException('not Tuliprox');
    return TuliproxStatus.fromJson(j);
  }

  Future<List<TuliproxStream>> streams(TuliproxLogin l) async {
    final j = await _get(l, '/api/v1/streams');
    final list = j is List ? j : (j is Map ? j['streams'] : null);
    return [
      for (final s in (list as List? ?? const []))
        if (s is Map<String, dynamic>) TuliproxStream.fromJson(s),
    ].whereType<TuliproxStream>().toList();
  }

  /// The sources of open group stream [uid]; null when it isn't a failover
  /// group (HTTP 400) or has gone.
  Future<TuliproxGroup?> members(TuliproxLogin l, int uid) async {
    try {
      final j = await _get(l, '/api/v1/streams/$uid/failover-members');
      return j is Map<String, dynamic> ? TuliproxGroup.fromJson(uid, j) : null;
    } on TuliproxException catch (e) {
      if (e.status == 400 || e.status == 404) return null;
      rethrow;
    }
  }

  /// Every playlist user of the server (needs user.read / config.read).
  Future<TuliproxUsers> users(TuliproxLogin l) async {
    final j = await _get(l, '/api/v1/config/apiproxy');
    if (j is! Map<String, dynamic>) throw TuliproxException('not Tuliprox');
    return TuliproxUsers.fromJson(j);
  }

  /// Creates playlist user [username] on [target] (needs user.write):
  /// [maxConnections] connections, active, no Web UI, using the
  /// `api-proxy.yml` server entry [server]. Tuliprox saves it to
  /// `api-proxy.yml` and serves it at once.
  Future<void> createUser(TuliproxLogin l, String target,
      {required String username,
      required String password,
      required String server,
      int maxConnections = 1,
      String? comment}) async {
    _decode(
        await _client
            .post(
                Uri.parse(
                    '${l.base}/api/v1/user/${Uri.encodeComponent(target)}'),
                headers: _headers(bearer: l.token),
                body: jsonEncode({
                  'username': username,
                  'password': password,
                  'proxy': 'reverse',
                  if (server.isNotEmpty) 'server': server,
                  'max_connections': maxConnections,
                  'status': 'Active',
                  'ui_enabled': false,
                  'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  if (comment != null) 'comment': comment,
                }))
            .timeout(_timeout),
        empty: true);
  }

  Future<void> switchMember(TuliproxLogin l, int uid, int memberVid) async {
    _decode(
        await _client
            .post(Uri.parse('${l.base}/api/v1/streams/$uid/failover-switch'),
                headers: _headers(bearer: l.token),
                body: jsonEncode({'member_vid': memberVid}))
            .timeout(_timeout),
        empty: true);
  }
}

/// A playlist user of the server (`api-proxy.yml`); Tuliprox never hands
/// out the password (masked since 3.3.2xx).
class TuliproxUser {
  const TuliproxUser(
      {required this.target,
      required this.username,
      this.status = '',
      this.maxConnections = 0,
      this.server = ''});

  /// The Tuliprox target (one playlist on the server).
  final String target;
  final String username;
  final String status;
  final int maxConnections;

  /// The `api-proxy.yml` server entry it uses (name).
  final String server;
}

/// The users of the server and the addresses its playlists stream from.
class TuliproxUsers {
  const TuliproxUsers({required this.users, required this.servers});
  final List<TuliproxUser> users;

  /// `api-proxy.yml` server name -> `https://host[:port][/path]`.
  final Map<String, String> servers;

  /// The playlists (targets) that have users, in the server's order.
  List<String> get targets => [
        for (final u in users) u.target,
      ].fold<List<String>>([], (l, t) => l.contains(t) ? l : (l..add(t)));

  /// The address [user]'s playlist streams from (its server entry, else
  /// the first one).
  String? addressOf(TuliproxUser user) =>
      servers[user.server] ?? servers.values.firstOrNull;

  /// The server entry most of [target]'s users use, else the first one.
  String? serverNameFor(String target) {
    final counts = <String, int>{};
    for (final u in users) {
      if (u.target == target && u.server.isNotEmpty) {
        counts[u.server] = (counts[u.server] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return servers.keys.firstOrNull;
    return (counts.entries.toList()..sort((a, b) => b.value - a.value))
        .first
        .key;
  }

  static TuliproxUsers fromJson(Map<String, dynamic> j) {
    final servers = <String, String>{};
    for (final s in (j['server'] as List? ?? const [])) {
      if (s is! Map) continue;
      final name = '${s['name'] ?? ''}';
      final host = '${s['host'] ?? ''}'.trim();
      if (name.isEmpty || host.isEmpty) continue;
      final protocol = '${s['protocol'] ?? 'http'}'.trim().toLowerCase();
      final port = '${s['port'] ?? ''}'.trim();
      final defaultPort = (protocol == 'https' && port == '443') ||
          (protocol == 'http' && port == '80');
      var path = '${s['path'] ?? ''}'.trim();
      if (path.isNotEmpty && !path.startsWith('/')) path = '/$path';
      path = path.replaceAll(RegExp(r'/+$'), '');
      servers[name] =
          '$protocol://$host${port.isEmpty || defaultPort ? '' : ':$port'}$path';
    }
    final users = <TuliproxUser>[];
    for (final t in (j['user'] as List? ?? const [])) {
      if (t is! Map) continue;
      final target = '${t['target'] ?? ''}';
      for (final c in (t['credentials'] as List? ?? const [])) {
        if (c is! Map) continue;
        final name = '${c['username'] ?? ''}';
        if (target.isEmpty || name.isEmpty) continue;
        users.add(TuliproxUser(
          target: target,
          username: name,
          status: '${c['status'] ?? ''}',
          maxConnections: _int(c['max_connections']) ?? 0,
          server: '${c['server'] ?? ''}',
        ));
      }
    }
    return TuliproxUsers(users: users, servers: servers);
  }
}

/// A user name and password for a playlist user VesperTV creates
/// ("Create a user for this TV"): `vesper` + 4 characters, and 12
/// letters and digits, from a secure random source.
({String username, String password}) newTuliproxCredentials([Random? random]) {
  final r = random ?? Random.secure();
  String pick(String chars, int n) =>
      List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  return (
    username: 'vesper${pick('abcdefghjkmnpqrstuvwxyz23456789', 4)}',
    password:
        pick('ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789', 12),
  );
}

/// The signed-in Tuliprox (one server) and the player's lookups on it.
class Tuliprox {
  Tuliprox._();
  static final instance = Tuliprox._();

  /// Tests replace it.
  TuliproxApi api = TuliproxApi();

  StorageService? _storage;

  /// The connected server; null = not connected.
  final login = ValueNotifier<TuliproxLogin?>(null);

  /// The sources the last Sources list offered, by row URL.
  final Map<String, ({int uid, TuliproxMember member})> _picks = {};

  void attach(StorageService storage) {
    _storage = storage;
    login.value = TuliproxLogin.parse(storage.getTuliprox());
    final l = login.value;
    if (l != null) {
      debugPrint('Tuliprox: signed in to ${hostOf(l.base)}');
      unawaited(_fresh(l).then((_) {}, onError: (_) {}));
    }
  }

  /// `https://host:port` of [url] for Send log: never a path or a token.
  static String hostOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return '?';
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  Future<void> save(TuliproxLogin? value) async {
    login.value = value;
    _picks.clear();
    await _storage
        ?.setTuliprox(value == null ? '' : jsonEncode(value.toJson()));
  }

  /// The signed-in login, its token refreshed when it is over an hour old;
  /// null when not connected.
  Future<TuliproxLogin?> fresh() async {
    final l = login.value;
    return l == null ? null : _fresh(l);
  }

  /// The login with a token at most an hour old: refreshed while it is still
  /// valid, so a box used daily never has to sign in again. A refused
  /// refresh (expired) keeps the old one; the next call then says so.
  Future<TuliproxLogin> _fresh(TuliproxLogin l) async {
    if (DateTime.now().difference(l.issuedAt) < const Duration(hours: 1)) {
      return l;
    }
    try {
      final next = await api.refresh(l);
      if (login.value?.base == l.base) await save(next);
      debugPrint('Tuliprox: token refreshed');
      return next;
    } catch (e) {
      debugPrint('Tuliprox: token refresh failed ($e)');
      return l;
    }
  }

  /// [channel] (a playlist channel) on the connected server, or null.
  TuliproxChannelRef? refOf(Channel channel) {
    final l = login.value;
    if (l == null || channel.url.isEmpty) return null;
    return tuliproxChannelRef(l.base, channel.url);
  }

  /// The failover group [channel] plays from on the server now, with its
  /// sources; null when it isn't a Tuliprox group channel, this login may
  /// not see streams, or no answer within [timeout].
  Future<TuliproxGroup?> groupFor(Channel channel,
      {Duration timeout = const Duration(seconds: 4)}) async {
    final l0 = login.value;
    final ref = refOf(channel);
    if (l0 == null) return null;
    if (ref == null) {
      debugPrint('Tuliprox: "${channel.name}" plays from '
          '${hostOf(channel.url)}, not ${hostOf(l0.base)}: no sources listed');
      return null;
    }
    try {
      return await () async {
        final l = await _fresh(l0);
        final mine = (await api.streams(l))
            .where((s) => s.isOf(ref.username, ref.id))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        if (mine.isEmpty) {
          debugPrint('Tuliprox: no open stream of $ref for this user');
          return null;
        }
        final g = await api.members(l, mine.first.uid);
        debugPrint(g == null
            ? 'Tuliprox: $ref is not a failover group'
            : 'Tuliprox: $ref has ${g.members.length} sources, on '
                '${g.currentVid}');
        return g;
      }()
          .timeout(timeout);
    } on TimeoutException {
      debugPrint('Tuliprox: sources of $ref timed out');
    } on TuliproxForbiddenException {
      debugPrint('Tuliprox: this login may not read streams (not an admin)');
    } on TuliproxLoginException {
      debugPrint('Tuliprox: the saved sign-in was refused');
    } catch (e) {
      debugPrint('Tuliprox: sources of $ref failed ($e)');
    }
    return null;
  }

  /// The Sources row URL for [member] of the group playing [own]: the
  /// channel's own URL with a fragment (never sent to the server), so rows
  /// stay distinct; [switchTo] knows it.
  String notePick(Channel own, int uid, TuliproxMember member) {
    final url = '${own.url}#tuliprox-${member.vid}';
    _picks[url] = (uid: uid, member: member);
    return url;
  }

  /// Whether [source] is a Tuliprox source row ([notePick]).
  bool isPick(Channel source) => _picks.containsKey(source.url);

  /// Switches the open stream to the source row [source]: the server
  /// splices it in, the player keeps its connection. Returns the source's
  /// name, null when [source] is not a Tuliprox row; throws when the
  /// server refused.
  Future<String?> switchTo(Channel source) async {
    final pick = _picks[source.url];
    final l0 = login.value;
    if (pick == null || l0 == null) return null;
    final l = await _fresh(l0);
    await api
        .switchMember(l, pick.uid, pick.member.vid)
        .timeout(const Duration(seconds: 10));
    debugPrint('Tuliprox: stream ${pick.uid} switched to source '
        '${pick.member.vid} (${pick.member.input})');
    return pick.member.title;
  }
}
