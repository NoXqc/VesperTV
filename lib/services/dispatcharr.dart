import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import 'storage_service.dart';

/// Dispatcharr (github.com/Dispatcharr/Dispatcharr): a server that merges
/// many provider streams into one channel and switches between them on its
/// side. Its M3U / Xtream output has a single URL per channel, so the other
/// streams are only visible through its REST API (AMD's request,
/// 2026-11-17). Settings > Playlists & sources > Dispatcharr signs in once;
/// the player's Sources drawer then lists the playing channel's streams and
/// plays the one picked through Dispatcharr's proxy, for this viewer only.
///
/// API (Dispatcharr 0.34): `POST /api/accounts/token/` (JWT, 30 min),
/// `GET /api/accounts/api-keys/` (the user's key, or null) and
/// `POST …/api-keys/generate/` (a user has ONE key: generating replaces it,
/// so an existing key is reused, never regenerated), `X-API-Key` header
/// afterwards. `GET /api/accounts/users/me/` (custom_properties
/// .xc_password = the user's Xtream password), `POST /api/channels/channels
/// /by-uuids/`, `GET /api/channels/channels/{id}/streams/` (ordered as the
/// channel uses them, with `stream_hash` and `stream_stats`).
/// `/proxy/ts/stream/{stream_hash}` plays one stream (Dispatcharr's own
/// stream preview; no login, the server's network rules apply).
class DispatcharrLogin {
  const DispatcharrLogin(
      {required this.server, required this.apiKey, required this.username});

  /// `http(s)://host[:port][/path]`, no trailing slash.
  final String server;
  final String apiKey;
  final String username;

  Map<String, dynamic> toJson() =>
      {'server': server, 'apiKey': apiKey, 'username': username};

  static DispatcharrLogin? parse(String raw) {
    if (raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final server = j['server'] as String? ?? '';
      final key = j['apiKey'] as String? ?? '';
      if (server.isEmpty || key.isEmpty) return null;
      return DispatcharrLogin(
          server: server,
          apiKey: key,
          username: j['username'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }
}

/// What signing in learned about the account.
class DispatcharrAccount {
  const DispatcharrAccount(
      {required this.login, this.xcPassword, this.admin = false});
  final DispatcharrLogin login;

  /// The Xtream password the admin gave this user, null when unset (then
  /// the playlist is added from the M3U / EPG output links instead).
  final String? xcPassword;
  final bool admin;
}

/// One provider stream behind a Dispatcharr channel.
class DispatcharrStream {
  const DispatcharrStream({
    required this.id,
    required this.name,
    required this.hash,
    this.accountId,
    this.resolution,
    this.videoCodec,
    this.fps,
    this.stale = false,
  });

  factory DispatcharrStream.fromJson(Map<String, dynamic> j) {
    final stats = j['stream_stats'];
    final s = stats is Map ? stats : const {};
    final fps = s['source_fps'];
    return DispatcharrStream(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String? ?? '').trim(),
      hash: j['stream_hash'] as String? ?? '',
      accountId: (j['m3u_account'] as num?)?.toInt(),
      resolution: s['resolution'] as String?,
      videoCodec: s['video_codec'] as String?,
      fps: fps is num ? fps.toDouble() : null,
      stale: j['is_stale'] == true,
    );
  }

  final int id;
  final String name;
  final String hash;
  final int? accountId;

  /// From Dispatcharr's own probe (`stream_stats`), null until it has
  /// played the stream once: `1920x1080`, `h264`, 59.94.
  final String? resolution;
  final String? videoCodec;
  final double? fps;

  /// The provider no longer lists it.
  final bool stale;

  /// `1080p · H.264 · 60 fps`, from what Dispatcharr measured; null when
  /// it never played this stream.
  String? get quality {
    final parts = <String>[];
    final h = int.tryParse(resolution?.split('x').last ?? '');
    if (h != null && h > 0) {
      parts.add(h >= 2000
          ? '4K'
          : h >= 1400
              ? '1440p'
              : '${h}p');
    }
    final codec = switch (videoCodec?.toLowerCase()) {
      'h264' => 'H.264',
      'hevc' || 'h265' => 'HEVC',
      'mpeg2video' => 'MPEG-2',
      'av1' => 'AV1',
      null || '' => null,
      final c => c.toUpperCase(),
    };
    if (codec != null) parts.add(codec);
    final f = fps;
    if (f != null && f > 0) parts.add('${f.round()} fps');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class DispatcharrException implements Exception {
  DispatcharrException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => 'DispatcharrException($message)';
}

/// Wrong user name / password, or a revoked API key.
class DispatcharrLoginException extends DispatcharrException {
  DispatcharrLoginException() : super('login', status: 401);
}

/// The password sign-in was refused by the server's network rules for its
/// web login ("UI" network access: 403 from `/api/accounts/token/`). An
/// API key isn't under that rule (AMD's server on a public domain,
/// 2026-11-18: the key connected, the password got 403).
class DispatcharrNetworkException extends DispatcharrException {
  DispatcharrNetworkException() : super('network', status: 403);
}

/// The password was accepted but the server refused to hand over the
/// user's API key (`/api/accounts/api-keys/` with the sign-in token). AMD's
/// server, 2026-11-18: Dispatcharr logged "Login success", then this step
/// got 403, most likely from a reverse proxy rule in front of it (the same
/// user's key passed the same permission check on users/me).
class DispatcharrKeyLookupException extends DispatcharrException {
  DispatcharrKeyLookupException(int? status)
      : super('API key lookup', status: status);
}

/// The address answered, but not as a Dispatcharr ([version] failed).
class DispatcharrNotFoundException extends DispatcharrException {
  DispatcharrNotFoundException(int? status)
      : super('not Dispatcharr', status: status);
}

/// Where a channel of a playlist points on a Dispatcharr server: its
/// numeric id (Xtream `/live/user/pass/{id}`) or its uuid (M3U
/// `/proxy/ts/stream/{uuid}`).
class DispatcharrChannelRef {
  const DispatcharrChannelRef({this.id, this.uuid});
  final int? id;
  final String? uuid;
  @override
  String toString() => id != null ? 'id $id' : 'uuid ${uuid ?? '?'}';
}

/// [url] as a channel of the Dispatcharr at [server], or null when it is
/// another server or not a channel URL. Host and port must match (the
/// scheme may differ: a reverse proxy can add https).
DispatcharrChannelRef? dispatcharrChannelRef(String server, String url) {
  final base = Uri.tryParse(server);
  final u = Uri.tryParse(url);
  if (base == null || u == null || base.host.isEmpty) return null;
  if (u.host.toLowerCase() != base.host.toLowerCase()) return null;
  int portOf(Uri x) => x.hasPort ? x.port : (x.scheme == 'https' ? 443 : 80);
  if (base.scheme == u.scheme && portOf(base) != portOf(u)) return null;
  if (base.scheme != u.scheme &&
      base.hasPort &&
      u.hasPort &&
      base.port != u.port) {
    return null;
  }
  final prefix = base.pathSegments.where((s) => s.isNotEmpty).toList();
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.length < prefix.length) return null;
  for (var i = 0; i < prefix.length; i++) {
    if (segs[i] != prefix[i]) return null;
  }
  final rest = segs.sublist(prefix.length);
  if (rest.length == 4 && rest[0] == 'live') {
    final id = int.tryParse(rest[3].split('.').first);
    return id == null ? null : DispatcharrChannelRef(id: id);
  }
  if (rest.length == 4 &&
      rest[0] == 'proxy' &&
      rest[1] == 'ts' &&
      rest[2] == 'stream') {
    final id = rest[3];
    // A channel uuid (36 chars with dashes); a stream hash is a stream.
    return RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)
        ? DispatcharrChannelRef(uuid: id)
        : null;
  }
  return null;
}

class DispatcharrApi {
  DispatcharrApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  /// What the user typed: `http://` by default (home servers rarely have a
  /// certificate), no trailing slash, no web page path pasted from the
  /// browser (`…/channels`, `/login`, `/#/…`).
  static String normalizeUrl(String input) {
    var u = input.trim();
    final hash = u.indexOf('#');
    if (hash >= 0) u = u.substring(0, hash);
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    u = u.replaceAll(RegExp(r'/+$'), '');
    u = u.replaceFirst(
        RegExp(
            r'/(channels|login|dashboard|stats|guide|settings|m3u|epg|users|plugins|dvr|vod)(/.*)?$',
            caseSensitive: false),
        '');
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  /// The URL that plays one stream through Dispatcharr's proxy.
  static String streamUrl(String server, String hash) =>
      '$server/proxy/ts/stream/$hash';

  static Map<String, String> _headers({String? apiKey, String? bearer}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'VesperTV',
        if (apiKey != null) 'X-API-Key': apiKey,
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      };

  dynamic _decode(http.Response r) {
    if (r.statusCode == 401) throw DispatcharrLoginException();
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw DispatcharrException('HTTP ${r.statusCode}', status: r.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw DispatcharrException('not Dispatcharr');
    }
  }

  Future<dynamic> _get(String server, String path,
          {String? apiKey, String? bearer}) async =>
      _decode(await _client
          .get(Uri.parse('$server$path'),
              headers: _headers(apiKey: apiKey, bearer: bearer))
          .timeout(_timeout));

  Future<dynamic> _post(String server, String path, Object body,
          {String? apiKey, String? bearer}) async =>
      _decode(await _client
          .post(Uri.parse('$server$path'),
              headers: _headers(apiKey: apiKey, bearer: bearer),
              body: jsonEncode(body))
          .timeout(_timeout));

  /// The server's version (`/api/core/version/`, no login): proves the
  /// address is a Dispatcharr before any password goes to it.
  Future<String> version(String server) async {
    final dynamic j;
    try {
      j = await _get(server, '/api/core/version/');
    } on DispatcharrException catch (e) {
      throw DispatcharrNotFoundException(e.status);
    }
    final v = j is Map ? j['version'] : null;
    if (v is! String) throw DispatcharrNotFoundException(null);
    return v;
  }

  /// Signs in with [username] / [password] once and keeps only the API
  /// key: the user's existing one when there is one (generating would
  /// replace it and break whatever else uses it), else a new one.
  Future<DispatcharrAccount> signIn(
      String server, String username, String password) async {
    await version(server);
    final dynamic tokens;
    try {
      tokens = await _post(server, '/api/accounts/token/',
          {'username': username, 'password': password});
    } on DispatcharrException catch (e) {
      if (e.status == 403) throw DispatcharrNetworkException();
      rethrow;
    }
    final access = tokens is Map ? tokens['access'] as String? : null;
    if (access == null) throw DispatcharrLoginException();
    debugPrint('Dispatcharr: password accepted, asking for the API key');
    String? key;
    try {
      final existing =
          await _get(server, '/api/accounts/api-keys/', bearer: access);
      key = existing is Map ? existing['key'] as String? : null;
      if (key == null || key.isEmpty) {
        final made = await _post(server, '/api/accounts/api-keys/generate/', {},
            bearer: access);
        key = made is Map ? made['key'] as String? : null;
      }
    } on DispatcharrException catch (e) {
      throw DispatcharrKeyLookupException(e.status);
    }
    if (key == null || key.isEmpty) {
      throw DispatcharrException('no API key');
    }
    return check(
        DispatcharrLogin(server: server, apiKey: key, username: username));
  }

  /// Signs in with an API key the user pasted (Dispatcharr > the user's
  /// menu > API key): no password ever reaches VesperTV.
  Future<DispatcharrAccount> withKey(String server, String apiKey) async {
    await version(server);
    return check(
        DispatcharrLogin(server: server, apiKey: apiKey, username: ''));
  }

  /// Checks [login]'s key (`users/me`) and reads the account.
  Future<DispatcharrAccount> check(DispatcharrLogin login) async {
    final dynamic me;
    try {
      me = await _get(login.server, '/api/accounts/users/me/',
          apiKey: login.apiKey);
    } on DispatcharrException catch (e) {
      // Any signed-in user may read users/me: 403 = the key isn't valid.
      if (e.status == 403) throw DispatcharrLoginException();
      rethrow;
    }
    if (me is! Map) throw DispatcharrException('not Dispatcharr');
    final props = me['custom_properties'];
    final xc = props is Map ? props['xc_password'] : null;
    final level = me['user_level'];
    return DispatcharrAccount(
      login: DispatcharrLogin(
          server: login.server,
          apiKey: login.apiKey,
          username: me['username'] as String? ?? login.username),
      xcPassword: xc is String && xc.isNotEmpty ? xc : null,
      admin: level is num && level >= 10,
    );
  }

  /// The channel id of [uuid], or null when this user can't see it.
  Future<int?> channelIdForUuid(DispatcharrLogin login, String uuid) async {
    final j = await _post(
        login.server,
        '/api/channels/channels/by-uuids/',
        {
          'uuids': [uuid]
        },
        apiKey: login.apiKey);
    if (j is! List || j.isEmpty || j.first is! Map) return null;
    return ((j.first as Map)['id'] as num?)?.toInt();
  }

  /// Channel [channelId]'s streams, in the order Dispatcharr tries them.
  Future<List<DispatcharrStream>> channelStreams(
      DispatcharrLogin login, int channelId) async {
    final j = await _get(
        login.server, '/api/channels/channels/$channelId/streams/',
        apiKey: login.apiKey);
    if (j is! List) return const [];
    return [
      for (final s in j)
        if (s is Map<String, dynamic>) DispatcharrStream.fromJson(s),
    ].where((s) => s.hash.isNotEmpty).toList();
  }

  /// M3U account names by id; empty when this user may not list them
  /// (only admins can).
  Future<Map<int, String>> accountNames(DispatcharrLogin login) async {
    try {
      final j =
          await _get(login.server, '/api/m3u/accounts/', apiKey: login.apiKey);
      final list = j is List ? j : (j is Map ? j['results'] : null);
      if (list is! List) return const {};
      return {
        for (final a in list)
          if (a is Map && a['id'] is num && a['name'] is String)
            (a['id'] as num).toInt(): (a['name'] as String).trim(),
      };
    } on DispatcharrException {
      return const {};
    }
  }
}

/// The signed-in Dispatcharr (one server) and the player's lookups on it.
class Dispatcharr {
  Dispatcharr._();
  static final instance = Dispatcharr._();

  /// Tests replace it.
  DispatcharrApi api = DispatcharrApi();

  StorageService? _storage;

  /// The connected server; null = not connected.
  final login = ValueNotifier<DispatcharrLogin?>(null);

  final Map<String, int?> _uuidIds = {};
  final Map<int, ({DateTime at, List<DispatcharrStream> streams})> _streams =
      {};
  ({DateTime at, Map<int, String> names})? _names;

  void attach(StorageService storage) {
    _storage = storage;
    login.value = DispatcharrLogin.parse(storage.getDispatcharr());
    final l = login.value;
    if (l != null) debugPrint('Dispatcharr: signed in to ${hostOf(l.server)}');
  }

  /// `https://host:port` of [url] for Send log: never a path (Xtream URLs
  /// carry the login there) nor a key.
  static String hostOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return '?';
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  Future<void> save(DispatcharrLogin? value) async {
    login.value = value;
    _uuidIds.clear();
    _streams.clear();
    _names = null;
    await _storage
        ?.setDispatcharr(value == null ? '' : jsonEncode(value.toJson()));
  }

  /// [channel] (a playlist channel, not a picked source) on the connected
  /// server, or null.
  DispatcharrChannelRef? refOf(Channel channel) {
    final l = login.value;
    if (l == null || channel.url.isEmpty) return null;
    return dispatcharrChannelRef(l.server, channel.url);
  }

  /// Every stream behind [channel] on the connected Dispatcharr, with the
  /// provider (M3U account) names when this user may read them. Null when
  /// [channel] isn't one of its channels or the server doesn't answer
  /// within [timeout] (the drawer then opens without them).
  Future<({List<DispatcharrStream> streams, Map<int, String> accounts})?>
      streamsFor(Channel channel,
          {Duration timeout = const Duration(seconds: 4)}) async {
    final l = login.value;
    final ref = refOf(channel);
    if (l == null) return null;
    if (ref == null) {
      // The usual reason Sources shows no Dispatcharr streams: the playlist
      // uses another address than the one signed in (LAN IP vs domain).
      debugPrint('Dispatcharr: "${channel.name}" plays from '
          '${hostOf(channel.url)}, not ${hostOf(l.server)}: no streams listed');
      return null;
    }
    try {
      return await _streamsFor(l, ref).timeout(timeout);
    } on TimeoutException {
      debugPrint('Dispatcharr: streams for $ref timed out');
      return null;
    } on DispatcharrLoginException {
      debugPrint('Dispatcharr: the API key was refused');
      return null;
    } catch (e) {
      debugPrint('Dispatcharr: streams for $ref failed ($e)');
      return null;
    }
  }

  Future<({List<DispatcharrStream> streams, Map<int, String> accounts})?>
      _streamsFor(DispatcharrLogin l, DispatcharrChannelRef ref) async {
    var id = ref.id;
    final uuid = ref.uuid;
    if (id == null && uuid != null) {
      if (!_uuidIds.containsKey(uuid)) {
        _uuidIds[uuid] = await api.channelIdForUuid(l, uuid);
      }
      id = _uuidIds[uuid];
    }
    if (id == null) return null;
    final now = DateTime.now();
    var cached = _streams[id];
    if (cached == null || now.difference(cached.at).inSeconds > 30) {
      cached = (at: now, streams: await api.channelStreams(l, id));
      _streams[id] = cached;
    }
    var names = _names;
    if (names == null || now.difference(names.at).inMinutes > 10) {
      names = (at: now, names: await api.accountNames(l));
      _names = names;
    }
    debugPrint('Dispatcharr: channel $id has ${cached.streams.length} '
        'streams');
    return (streams: cached.streams, accounts: names.names);
  }
}
