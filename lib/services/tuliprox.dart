import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';
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
      this.hasArchive = false,
      this.quality,
      this.failing = false});
  final int vid;
  final String title;

  /// The Tuliprox input (provider account) it comes from; empty on the
  /// player routes (they never name the server's inputs).
  final String input;
  final bool hasArchive;

  /// `1080p · H.264 · 5.5 Mbit/s` from the player routes' `health`, null when
  /// the server hasn't probed it.
  final String? quality;

  /// The server's breaker has this source paused after repeated failures.
  final bool failing;
}

/// [health] (the player routes' redacted member health) as a short label.
String? tuliproxHealthLabel(Object? health) {
  if (health is! Map) return null;
  final parts = <String>[];
  final res = '${health['resolution'] ?? ''}';
  final height = int.tryParse(res.replaceFirst(RegExp(r'^P'), ''));
  if (height != null) {
    parts.add(height >= 2160
        ? '4K'
        : height >= 1440
            ? '1440p'
            : '${height}p');
  } else if (res == 'SD') {
    parts.add('SD');
  }
  final codec = switch ('${health['video_codec'] ?? ''}') {
    'H264' => 'H.264',
    'H265' => 'HEVC',
    'AV1' => 'AV1',
    'MPEG4' => 'MPEG-4',
    _ => null,
  };
  if (codec != null) parts.add(codec);
  final kbps = _int(health['bitrate_kbps']);
  if (kbps != null && kbps > 0) {
    parts.add('${(kbps / 1000).toStringAsFixed(1)} Mbit/s');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The playing group, its sources and the one on air now.
class TuliproxGroup {
  const TuliproxGroup(
      {required this.uid,
      required this.name,
      required this.members,
      this.currentVid,
      this.player});
  final int uid;
  final String name;
  final List<TuliproxMember> members;
  final int? currentVid;

  /// Listed through the player routes, as this playlist user: switching
  /// goes through them too (only this viewer's stream). Null = the admin
  /// routes.
  final TuliproxLogin? player;

  static TuliproxGroup fromJson(int uid, Map<String, dynamic> j,
      {TuliproxLogin? player}) {
    final members = <TuliproxMember>[];
    for (final m in (j['members'] as List? ?? const [])) {
      if (m is! Map) continue;
      final vid = _int(m['member_vid']);
      if (vid == null) continue;
      final health = m['health'];
      members.add(TuliproxMember(
        vid: vid,
        title: '${m['title'] ?? ''}',
        input: '${m['input_name'] ?? ''}',
        hasArchive: m['has_archive'] == true,
        quality: tuliproxHealthLabel(health),
        failing: health is Map && health['state'] == 'failing',
      ));
    }
    var current = _int(j['current_member_vid']);
    if (current == null) {
      for (final m in (j['members'] as List? ?? const [])) {
        if (m is Map && m['current'] == true) current = _int(m['member_vid']);
      }
    }
    return TuliproxGroup(
      uid: uid,
      name: '${j['group_name'] ?? ''}',
      members: members,
      currentVid: current,
      player: player,
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
  const TuliproxChannelRef(
      {required this.username,
      required this.id,
      this.password = '',
      this.base = ''});
  final String username;
  final int id;

  /// The Tuliprox address (with its Web UI path) the channel plays from.
  final String base;

  /// The playlist's own password, from the stream URL (it travels there in
  /// every stream request already): signs the player routes in as this
  /// playlist user ([Tuliprox.playerLogin]). Never logged or stored.
  final String password;
  @override
  String toString() => 'channel $id';
}

/// What a playlist user may do (`GET /api/v1/me/capabilities`, Tuliprox's
/// Player API since the `feature/player_user_api` branch, 2026-11-23).
class TuliproxCapabilities {
  const TuliproxCapabilities(
      {this.sourceSwitch = false,
      this.joinable = false,
      this.maxConnections = 0,
      this.activeConnections = 0});
  final bool sourceSwitch;
  final bool joinable;
  final int maxConnections;
  final int activeConnections;

  static TuliproxCapabilities fromJson(Map<String, dynamic> j) =>
      TuliproxCapabilities(
        sourceSwitch: j['source_switch'] == true,
        joinable: j['joinable_streams'] == true,
        maxConnections: _int(j['max_connections']) ?? 0,
        activeConnections: _int(j['active_connections']) ?? 0,
      );
}

/// One of the playlist user's own open streams (`GET /api/v1/me/streams`).
class TuliproxOwnStream {
  const TuliproxOwnStream(
      {required this.uid,
      required this.virtualId,
      this.groupVirtualId,
      this.memberVid,
      this.startedAt = 0,
      this.userAgent = ''});
  final int uid;
  final int virtualId;
  final int? groupVirtualId;
  final int? memberVid;

  /// Unix seconds.
  final int startedAt;
  final String userAgent;

  bool isOf(int id) => virtualId == id || groupVirtualId == id;

  static TuliproxOwnStream? fromJson(Map<String, dynamic> j) {
    final uid = _int(j['uid']);
    final vid = _int(j['virtual_id']);
    if (uid == null || vid == null) return null;
    return TuliproxOwnStream(
      uid: uid,
      virtualId: vid,
      groupVirtualId: _int(j['group_virtual_id']),
      memberVid: _int(j['member_vid']),
      startedAt: _int(j['started_at']) ?? 0,
      userAgent: '${j['user_agent'] ?? ''}',
    );
  }
}

/// A channel the playlist user can join without a new provider connection
/// (`GET /api/v1/me/streams/joinable`): already playing on the server.
class TuliproxJoinable {
  const TuliproxJoinable(
      {required this.virtualId,
      required this.title,
      this.freeSlotNeeded = false});
  final int virtualId;
  final String title;

  /// Joining costs one of the user's own connections and none is free.
  final bool freeSlotNeeded;
}

/// Why a player-route switch was refused, in words for the viewer.
class TuliproxSwitchRefused extends TuliproxException {
  TuliproxSwitchRefused(super.message, {super.status});
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
  return TuliproxChannelRef(
      username: Uri.decodeComponent(rest[0]),
      password: Uri.decodeComponent(rest[1]),
      id: id,
      base: base);
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

  // --- Player routes (`/api/v1/me/*`): a playlist user, its own streams ---

  /// What [l] (a playlist user) may do; null when the server has no player
  /// routes (404, older Tuliprox) or they are off for this user (403).
  Future<TuliproxCapabilities?> capabilities(TuliproxLogin l) async {
    try {
      final j = await _get(l, '/api/v1/me/capabilities');
      return j is Map<String, dynamic>
          ? TuliproxCapabilities.fromJson(j)
          : null;
    } on TuliproxForbiddenException {
      return null;
    } on TuliproxException catch (e) {
      if (e.status == 404 || e.status == 405) return null;
      rethrow;
    }
  }

  Future<List<TuliproxOwnStream>> ownStreams(TuliproxLogin l) async {
    final j = await _get(l, '/api/v1/me/streams');
    return [
      for (final s in (j is List ? j : const []))
        if (s is Map<String, dynamic>) TuliproxOwnStream.fromJson(s),
    ].whereType<TuliproxOwnStream>().toList();
  }

  /// The sources of [l]'s own group stream [uid]; null when it isn't a
  /// failover group or has gone.
  Future<TuliproxGroup?> ownMembers(TuliproxLogin l, int uid) async {
    try {
      final j = await _get(l, '/api/v1/me/streams/$uid/failover-members');
      return j is Map<String, dynamic>
          ? TuliproxGroup.fromJson(uid, j, player: l)
          : null;
    } on TuliproxException catch (e) {
      if (e.status == 400 || e.status == 404) return null;
      rethrow;
    }
  }

  /// Switches [l]'s own stream [uid]; a refusal comes back as
  /// [TuliproxSwitchRefused] with the server's reason code.
  Future<void> switchOwn(TuliproxLogin l, int uid, int memberVid) async {
    final r = await _client
        .post(Uri.parse('${l.base}/api/v1/me/streams/$uid/failover-switch'),
            headers: _headers(bearer: l.token),
            body: jsonEncode({'member_vid': memberVid}))
        .timeout(_timeout);
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 401) throw TuliproxLoginException(status: 401);
    throw TuliproxSwitchRefused(utf8.decode(r.bodyBytes).trim(),
        status: r.statusCode);
  }

  /// Ends [l]'s own stream [uid] on the server at once: its provider slot
  /// is free for the next channel (uzumaki, 2026-11-23). True when the
  /// server ended it (204), false when it was gone already (404).
  Future<bool> stopOwn(TuliproxLogin l, int uid) async {
    final r = await _client
        .delete(Uri.parse('${l.base}/api/v1/me/streams/$uid'),
            headers: _headers(bearer: l.token))
        .timeout(const Duration(seconds: 3));
    if (r.statusCode == 404) return false;
    _decode(r, empty: true);
    return true;
  }

  /// Channels [l] can join without a new provider connection.
  Future<List<TuliproxJoinable>> joinable(TuliproxLogin l) async {
    final j = await _get(l, '/api/v1/me/streams/joinable');
    return [
      for (final s in (j is List ? j : const []))
        if (s is Map && _int(s['virtual_id']) != null)
          TuliproxJoinable(
            virtualId: _int(s['virtual_id'])!,
            title: '${s['title'] ?? ''}',
            freeSlotNeeded: s['requires_free_slot'] == true,
          ),
    ];
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

  /// The sources the last Sources list offered, by row URL; [player] = the
  /// playlist user's login when listed through the player routes.
  final Map<String, ({int uid, TuliproxMember member, TuliproxLogin? player})>
      _picks = {};

  /// Player-route sign-ins per playlist user (`base|user`), in memory only
  /// (the password comes from the stream URL each time).
  final Map<String, TuliproxLogin> _players = {};
  final Map<String, DateTime> _playerRefused = {};
  final Map<String, ({DateTime at, TuliproxCapabilities? caps})> _caps = {};

  /// The playing channel's own stream on the server, by channel URL: found a
  /// few seconds after the start ([noteStarted]), ended when the viewer
  /// leaves ([release]).
  final Map<String, int> _ownUid = {};
  final Map<String, DateTime> _playStart = {};

  /// Tests shorten it.
  @visibleForTesting
  Duration ownLookupDelay = const Duration(seconds: 3);

  /// Why Tuliprox served its fallback for a channel URL
  /// (`X-Tuliprox-Fallback`), and the channels already playing on the server
  /// this viewer could join instead (for [_joinableFor]).
  final Map<String, String> _fallbackOf = {};
  List<TuliproxJoinable> _joinable = const [];
  String? _joinableFor;

  /// Joinable lists being read, by channel URL ([joinableSettled]).
  final Map<String, Future<bool>> _joinableReads = {};

  /// Marks a Sources row that joins a channel already playing on the server.
  static const joinMark = '#tuliprox-join';

  /// The latest fallback ([noteFallback]): the player says it when the
  /// stream is Tuliprox's busy video (a refusal shows the error screen).
  final fallbackNotice = ValueNotifier<({String url, String reason})?>(null);

  void attach(StorageService storage) {
    _storage = storage;
    _found.clear();
    try {
      final found = jsonDecode(storage.getTuliproxFound());
      if (found is Map) {
        for (final e in found.entries) {
          if (e.value is String) _found['${e.key}'] = e.value as String;
        }
      }
    } catch (_) {
      // Nothing found yet.
    }
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
    final old = login.value;
    login.value = value;
    _picks.clear();
    // A token refresh keeps the rest; another server or login drops it.
    if (old?.base != value?.base || old?.username != value?.username) {
      _players.clear();
      _playerRefused.clear();
      _caps.clear();
      _ownUid.clear();
      _playStart.clear();
      _fallbackOf.clear();
      _joinable = const [];
      _joinableFor = null;
    }
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
    if (channel.url.isEmpty) return null;
    final l = login.value;
    if (l != null) {
      final ref = tuliproxChannelRef(l.base, channel.url);
      if (ref != null) return ref;
    }
    if (_found.isEmpty) return null;
    final host = Uri.tryParse(channel.url)?.host.toLowerCase() ?? '';
    final base = _found[host];
    return base == null ? null : tuliproxChannelRef(base, channel.url);
  }

  /// Player API addresses found through playlists ([noteServer]), by host.
  final Map<String, String> _found = {};

  /// An Xtream playlist on [server] signed in: Tuliprox (since e5704880)
  /// names its Player API path in `server_info.player_api_path` when that
  /// login may use it, so Sources, the stream release and the busy reasons
  /// work without Settings > Tuliprox (uzumaki, 2026-11-23). Without the
  /// field the host is forgotten (feature turned off, or not Tuliprox).
  void noteServer(String server, Object? playerApiPath) {
    final u = Uri.tryParse(server);
    final host = u?.host.toLowerCase() ?? '';
    if (host.isEmpty) return;
    final old = _found[host];
    if (playerApiPath is String && playerApiPath.startsWith('/')) {
      final path = playerApiPath == '/'
          ? ''
          : playerApiPath.replaceFirst(RegExp(r'/+$'), '');
      final base = '${hostOf(server)}$path';
      if (old == base) return;
      _found[host] = base;
      debugPrint('Tuliprox: Player API found on ${hostOf(server)}');
    } else {
      if (old == null) return;
      _found.remove(host);
      debugPrint('Tuliprox: no Player API on ${hostOf(server)} any more');
    }
    unawaited(
        _storage?.setTuliproxFound(_found.isEmpty ? '' : jsonEncode(_found)));
  }

  /// The player read [channel]'s stream uid from Tuliprox's answer
  /// (`X-Tuliprox-Stream-Uid`, live MPEG-TS on Android): its own stream
  /// for sure, so no lookup by start time ([noteStarted]).
  void noteOwnUid(Channel channel, int uid) {
    if (_playStart[channel.url] == null || _ownUid[channel.url] == uid) {
      return;
    }
    _ownUid[channel.url] = uid;
    debugPrint('Tuliprox: own stream $uid for ${refOf(channel)} (header)');
  }

  // --- Player routes: the playlist user itself, its own streams only ---

  /// [ref]'s playlist user signed in to the player routes of the connected
  /// server: the saved login when it is that user, else a sign-in with the
  /// playlist's own name + password (from the stream URL; Tuliprox accepts
  /// it when `player_features.api_enabled` is on for that user). Kept 20
  /// minutes in memory; a refusal is not retried for 10. Null = not
  /// available.
  Future<TuliproxLogin?> playerLogin(TuliproxChannelRef ref) async {
    final l0 = login.value;
    if (l0 != null && l0.base == ref.base && l0.username == ref.username) {
      return _fresh(l0);
    }
    if (ref.base.isEmpty) return null;
    final key = '${ref.base}|${ref.username}';
    final now = DateTime.now();
    final cached = _players[key];
    if (cached != null &&
        now.difference(cached.issuedAt) < const Duration(minutes: 20)) {
      return cached;
    }
    final refused = _playerRefused[key];
    if (refused != null &&
        now.difference(refused) < const Duration(minutes: 10)) {
      return null;
    }
    if (ref.password.isEmpty) return null;
    try {
      final l = await api.signIn(ref.base, ref.username, ref.password);
      _players[key] = l;
      debugPrint('Tuliprox: player routes signed in for this playlist');
      return l;
    } catch (e) {
      _playerRefused[key] = now;
      debugPrint('Tuliprox: no player routes for this playlist ($e)');
      return null;
    }
  }

  /// [l]'s capabilities, kept 5 minutes; null = no player routes.
  Future<TuliproxCapabilities?> _capsOf(TuliproxLogin l) async {
    final key = '${l.base}|${l.username}';
    final now = DateTime.now();
    final cached = _caps[key];
    if (cached != null &&
        now.difference(cached.at) < const Duration(minutes: 5)) {
      return cached.caps;
    }
    TuliproxCapabilities? caps;
    try {
      caps = await api.capabilities(l);
    } catch (e) {
      debugPrint('Tuliprox: capabilities not read ($e)');
    }
    _caps[key] = (at: now, caps: caps);
    return caps;
  }

  /// [ref]'s own open stream: the one found after the start ([noteStarted]),
  /// else the newest of that channel started since this device pressed
  /// play (another TV on the same login may watch it too: never an older
  /// one). Null when none.
  Future<TuliproxOwnStream?> _ownStream(
      TuliproxLogin l, TuliproxChannelRef ref, String url) async {
    final mine = (await api.ownStreams(l)).where((s) => s.isOf(ref.id)).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final known = _ownUid[url];
    if (known != null) {
      for (final s in mine) {
        if (s.uid == known) return s;
      }
    }
    final start = _playStart[url];
    final since = start == null ? 0 : start.millisecondsSinceEpoch ~/ 1000 - 5;
    for (final s in mine) {
      if (s.startedAt >= since || s.startedAt == 0) return s;
    }
    return null;
  }

  /// The player started [channel] (a live channel of the connected
  /// Tuliprox): its stream is looked up [ownLookupDelay] later, so leaving
  /// it can end it on the server ([release]).
  void noteStarted(Channel channel) {
    final ref = refOf(channel);
    if (ref == null) return;
    final url = channel.url;
    final at = DateTime.now();
    _playStart[url] = at;
    _ownUid.remove(url);
    _fallbackOf.remove(url);
    if (_joinableFor == url) {
      _joinable = const [];
      _joinableFor = null;
    }
    unawaited(Future<void>.delayed(ownLookupDelay, () async {
      if (_playStart[url] != at) return; // left or restarted since
      if (_ownUid.containsKey(url)) return; // the stream said it
      try {
        final l = await playerLogin(ref);
        if (l == null || await _capsOf(l) == null) return;
        final own = await _ownStream(l, ref, url);
        if (_playStart[url] != at || own == null) return;
        _ownUid[url] = own.uid;
        debugPrint('Tuliprox: own stream ${own.uid} for ${ref.toString()}');
      } catch (e) {
        debugPrint('Tuliprox: own stream lookup failed ($e)');
      }
    }));
  }

  /// The viewer left [channel] (another channel, stop, the player closed):
  /// its stream ends on the server now instead of when Tuliprox notices the
  /// closed connection, so a one-connection account is free for the next
  /// channel (uzumaki, 2026-11-23). Nothing when its stream isn't known.
  Future<void> release(Channel channel) async {
    final url = channel.url;
    final started = _playStart.containsKey(url);
    var uid = _ownUid.remove(url);
    final ref = refOf(channel);
    if (ref == null || (uid == null && !started)) {
      _playStart.remove(url);
      return;
    }
    try {
      final l = await playerLogin(ref);
      if (l == null) return;
      // Zapping on before the lookup ([noteStarted]): find it now (uzumaki:
      // "on channel switch, drop the previous").
      if (uid == null) {
        if (await _capsOf(l) == null) return;
        uid = (await _ownStream(l, ref, url))?.uid;
        if (uid == null) return;
      }
      final ended = await api.stopOwn(l, uid);
      debugPrint('Tuliprox: released stream $uid '
          '(${ended ? 'ended' : 'already gone'})');
    } catch (e) {
      debugPrint('Tuliprox: release of stream $uid failed ($e)');
    } finally {
      _playStart.remove(url);
    }
  }

  /// Tuliprox served [channel] its fallback for [reason] (a refusal or its
  /// busy video): kept for Sources and the error screen. When the account or
  /// the provider is full, the channels already playing on the server that
  /// join for free are read (`/me/streams/joinable`). True when that list
  /// is new.
  Future<bool> noteFallback(Channel channel, String reason) async {
    final url = channel.url;
    if (_fallbackOf[url] == reason) return false;
    _fallbackOf[url] = reason;
    debugPrint('Tuliprox: fallback "$reason" for ${channel.name}');
    if (_joinableFor != url) {
      _joinable = const [];
      _joinableFor = null;
    }
    try {
      if (reason != 'provider_connections_exhausted' &&
          reason != 'user_connections_exhausted') {
        return false;
      }
      return await _readJoinable(channel);
    } finally {
      fallbackNotice.value = (url: url, reason: reason);
    }
  }

  /// Reads the channels already playing that [channel]'s viewer can join
  /// for free (`/me/streams/joinable`); [joinableSettled] waits for it.
  Future<bool> _readJoinable(Channel channel) {
    final url = channel.url;
    final running = _joinableReads[url];
    if (running != null) return running;
    final read = _fetchJoinable(channel);
    _joinableReads[url] = read;
    return read.whenComplete(() => _joinableReads.remove(url));
  }

  Future<bool> _fetchJoinable(Channel channel) async {
    final url = channel.url;
    final ref = refOf(channel);
    if (ref == null) return false;
    try {
      final l = await playerLogin(ref);
      if (l == null) return false;
      final caps = await _capsOf(l);
      if (caps == null || !caps.joinable) return false;
      final list = [
        for (final j in await api.joinable(l))
          if (!j.freeSlotNeeded) j
      ];
      _joinable = list;
      _joinableFor = url;
      debugPrint('Tuliprox: ${list.length} channels playing on the server '
          'can be joined');
      return list.isNotEmpty;
    } catch (e) {
      debugPrint('Tuliprox: joinable streams not read ($e)');
      return false;
    }
  }

  /// Waits (at most [max]) for [channel]'s joinable list when it is being
  /// read: Sources opened as the busy video was found (owner's phone,
  /// 2026-11-23: built 0.1 s before the list landed, CNN missing).
  Future<void> joinableSettled(Channel channel,
      {Duration max = const Duration(seconds: 3)}) async {
    final read = _joinableReads[channel.url];
    if (read == null) return;
    try {
      await read.timeout(max);
    } catch (_) {
      // Slow server: Sources open without them.
    }
  }

  /// [channel]'s fallback reason, when Tuliprox served one.
  String? fallbackOf(Channel channel) => _fallbackOf[channel.url];

  /// Channels already playing on the server to offer instead of [channel]
  /// ([noteFallback]); empty otherwise.
  List<TuliproxJoinable> joinableFor(Channel channel) =>
      _joinableFor == channel.url ? _joinable : const [];

  /// The last fallback's joinable channel names, for the error screen.
  List<String> get joinableTitles => [
        for (final j in _joinable)
          if (j.title.isNotEmpty) j.title
      ];

  /// [c] is a Sources row joining a channel already playing ([joinMark]).
  bool isJoin(Channel c) => c.url.endsWith(joinMark);

  /// The channel a join row plays.
  Channel joinTarget(Channel c) => isJoin(c)
      ? c.copyWith(url: c.url.substring(0, c.url.length - joinMark.length))
      : c;

  /// [channel]'s group through the player routes: `usable` false when this
  /// playlist user has none (or no source switch), then the admin routes
  /// are asked instead.
  Future<({bool usable, TuliproxGroup? group})> _playerGroup(
      TuliproxChannelRef ref, Channel channel) async {
    final l = await playerLogin(ref);
    if (l == null) return (usable: false, group: null);
    final caps = await _capsOf(l);
    if (caps == null || !caps.sourceSwitch) {
      return (usable: false, group: null);
    }
    final own = await _ownStream(l, ref, channel.url);
    if (own == null) {
      debugPrint('Tuliprox: no own open stream of $ref');
      // Playing without a stream of its own on the server = Tuliprox's
      // busy video: channels already playing can be joined instead (also
      // where the player can't read X-Tuliprox-Fallback, the computers).
      if (caps.joinable && _joinableFor != channel.url) {
        await _readJoinable(channel);
      }
      return (usable: true, group: null);
    }
    _ownUid[channel.url] = own.uid;
    final g = await api.ownMembers(l, own.uid);
    debugPrint(g == null
        ? 'Tuliprox: $ref is not a failover group'
        : 'Tuliprox: $ref has ${g.members.length} sources (player routes), '
            'on ${g.currentVid}');
    return (usable: true, group: g);
  }

  /// The failover group [channel] plays from on the server now, with its
  /// sources; null when it isn't a Tuliprox group channel, this login may
  /// not see streams, or no answer within [timeout]. The player routes
  /// (this viewer's own stream) come first, the admin routes after.
  Future<TuliproxGroup?> groupFor(Channel channel,
      {Duration timeout = const Duration(seconds: 4)}) async {
    final l0 = login.value;
    final ref = refOf(channel);
    if (ref == null) {
      if (l0 != null) {
        debugPrint('Tuliprox: "${channel.name}" plays from '
            '${hostOf(channel.url)}, not ${hostOf(l0.base)}: '
            'no sources listed');
      }
      return null;
    }
    try {
      return await () async {
        final player = await _playerGroup(ref, channel);
        if (player.usable) return player.group;
        // The admin routes: only with Settings > Tuliprox on this server.
        if (l0 == null || l0.base != ref.base) return null;
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
  String notePick(Channel own, int uid, TuliproxMember member,
      {TuliproxLogin? player}) {
    final url = '${own.url}#tuliprox-${member.vid}';
    _picks[url] = (uid: uid, member: member, player: player);
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
    final player = pick.player;
    if (player != null) {
      // Only this viewer's stream; Tuliprox refuses a stream others share.
      await api
          .switchOwn(player, pick.uid, pick.member.vid)
          .timeout(const Duration(seconds: 12));
      debugPrint('Tuliprox: own stream ${pick.uid} switched to source '
          '${pick.member.vid} (player routes)');
      return pick.member.title;
    }
    final l = await _fresh(l0);
    await api
        .switchMember(l, pick.uid, pick.member.vid)
        .timeout(const Duration(seconds: 10));
    debugPrint('Tuliprox: stream ${pick.uid} switched to source '
        '${pick.member.vid} (${pick.member.input})');
    return pick.member.title;
  }
}

/// The `X-Tuliprox-Fallback` reason in a player error (`[Tuliprox reason]`,
/// added by ExoPlayerEventListener.describeCause), or null.
String? tuliproxReasonOf(String raw) =>
    RegExp(r'\[Tuliprox ([a-z_]+)\]').firstMatch(raw)?.group(1);

/// What a Tuliprox fallback [reason] means for the viewer (Player API docs,
/// "X-Tuliprox-Fallback values"); null for one it doesn't know.
String? tuliproxFallbackText(String reason) {
  switch (reason) {
    case 'channel_unavailable':
      return tr(
          "Tuliprox couldn't start this channel from any of its sources. Try again later, or pick another channel.");
    case 'user_connections_exhausted':
      return tr(
          'Your account is already watching on all the screens it allows. Stop one of them, or wait a moment and try again.');
    case 'provider_connections_exhausted':
      return tr(
          "All of the server's provider connections are in use. Try again later, or watch a channel that's already playing.");
    case 'low_priority_preempted':
      return tr(
          'A stream or recording with a higher priority took this connection.');
    case 'user_account_expired':
      return tr('Your account on this server has expired.');
    case 'provisioning':
      return tr(
          'The server is still setting up this account. Try again in a few minutes.');
    case 'hls_session_or_lease_expired':
      return tr('The stream session ended. Start the channel again.');
    case 'maintenance':
      return tr('This source is in maintenance. Try again later.');
  }
  return null;
}

/// [reason]'s words ([tuliproxFallbackText]) plus the channels already
/// playing that can be joined; null for an unknown reason.
String? tuliproxFallbackMessage(String reason) {
  final said = tuliproxFallbackText(reason);
  if (said == null) return null;
  final join = Tuliprox.instance.joinableTitles.take(4).join(', ');
  return [
    said,
    if (join.isNotEmpty)
      tr('Playing now on the server, ready to join (in Sources): {channels}',
          {'channels': join}),
  ].join('\n');
}

/// What to tell the viewer when Tuliprox refused a player-route switch
/// (`TuliproxSwitchRefused.message` = the server's reason code).
String tuliproxRefusalText(Object error) {
  if (error is! TuliproxSwitchRefused) {
    return tr("Tuliprox didn't switch the source.");
  }
  final code = error.message;
  if (code.contains('shared_stream')) {
    return tr(
        "Someone else is watching this channel on the server, so its source can't be switched just for you.");
  }
  if (code.contains('in_progress')) {
    return tr('Tuliprox is already switching. Try again in a moment.');
  }
  if (error.status == 429 || code.contains('cooldown')) {
    return tr('Wait a moment before switching again.');
  }
  if (error.status == 502) {
    return tr("That source didn't start. Still on the one before.");
  }
  return tr("Tuliprox didn't switch the source.");
}
