import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import 'live_stream_format.dart';
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
/// stream preview; no login, the server's network rules apply), in the
/// format `?output_format=` asks for (else the user's / server's default).
/// Admins: `POST /proxy/ts/change_stream/{channel uuid}` `{"stream_id"}`
/// switches a playing channel to another of its streams (what Dispatcharr's
/// own Switch Stream does; the viewers keep their connection) and
/// `GET /proxy/ts/status/{channel uuid}` says which stream it is on.
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

/// The format Dispatcharr serves the channel at [url] in, as its
/// `output_format` names it: an Xtream link's extension decides (`.ts` =
/// mpegts, `.m3u8` = hls, `.mp4` = fmp4; VesperTV's Stream format HLS
/// turns `.ts` into `.m3u8` when it plays, [LiveStreamFormat]), else an
/// `output_format` / `output` query. Null = Dispatcharr's default for the
/// user (an M3U channel link). A picked stream asks for the same, or it
/// played in the other format (clayts450, 2026-11-18: MPEG-TS channel,
/// HLS stream, or the reverse, whenever the two settings differed).
String? dispatcharrOutputFormat(String url) {
  final u = Uri.tryParse(LiveStreamFormat.urlFor(url));
  if (u == null) return null;
  final path = u.path.toLowerCase();
  if (path.endsWith('.m3u8')) return 'hls';
  if (path.endsWith('.ts')) return 'mpegts';
  if (path.endsWith('.mp4')) return 'fmp4';
  final q = (u.queryParameters['output_format'] ?? u.queryParameters['output'])
      ?.toLowerCase();
  return switch (q) {
    'hls' || 'm3u8' => 'hls',
    'ts' || 'mpegts' => 'mpegts',
    'mp4' || 'fmp4' => 'fmp4',
    _ => null,
  };
}

/// [url] (a Dispatcharr channel) as one MPEG-TS stream: `.m3u8` -> `.ts`,
/// an `output_format` / `output` query -> `mpegts`. [Dispatcharr.holdChannel]
/// reads it as one long download (an HLS playlist would end at once).
String dispatcharrTsUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return url;
  var out = u;
  if (u.path.toLowerCase().endsWith('.m3u8')) {
    out = out.replace(
        path: '${u.path.substring(0, u.path.length - '.m3u8'.length)}.ts');
  }
  final q = Map<String, String>.of(out.queryParameters);
  var changed = false;
  for (final key in const ['output_format', 'output']) {
    if (q.containsKey(key)) {
      q[key] = 'mpegts';
      changed = true;
    }
  }
  if (changed) out = out.replace(queryParameters: q);
  return out == u ? url : out.toString();
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

  /// The URL that plays one stream through Dispatcharr's proxy, in
  /// [format] ([dispatcharrOutputFormat]) when given.
  static String streamUrl(String server, String hash, {String? format}) =>
      '$server/proxy/ts/stream/$hash'
      '${format == null ? '' : '?output_format=$format'}';

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

  /// Channel [channelId]'s uuid (what the proxy routes take).
  Future<String?> channelUuid(DispatcharrLogin login, int channelId) async {
    final j = await _get(login.server, '/api/channels/channels/$channelId/',
        apiKey: login.apiKey);
    final uuid = j is Map ? j['uuid'] : null;
    return uuid is String && uuid.isNotEmpty ? uuid : null;
  }

  /// Switches the playing channel [uuid] to its stream [streamId], for
  /// every viewer of it (admins only: 403 otherwise; an error when the
  /// channel isn't playing on the server).
  Future<void> changeStream(
      DispatcharrLogin login, String uuid, int streamId) async {
    await _post(
        login.server, '/proxy/ts/change_stream/$uuid', {'stream_id': streamId},
        apiKey: login.apiKey);
  }

  /// The stream channel [uuid] plays now, or null when it isn't playing
  /// (admins only).
  Future<int?> activeStreamId(DispatcharrLogin login, String uuid) async {
    final j = await _get(login.server, '/proxy/ts/status/$uuid',
        apiKey: login.apiKey);
    final id = j is Map ? j['stream_id'] : null;
    return id is num ? id.toInt() : (id is String ? int.tryParse(id) : null);
  }

  /// Opens [url] (a channel's stream) and gives its bytes as they come.
  Future<Stream<List<int>>> openStream(
      String url, Map<String, String> headers) async {
    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll({'User-Agent': 'VesperTV', ...headers});
    final r = await _client.send(request).timeout(_timeout);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      unawaited(r.stream.listen(null).cancel());
      throw DispatcharrException('HTTP ${r.statusCode}', status: r.statusCode);
    }
    return r.stream;
  }

  /// How far behind live the proxy starts a new viewer (Settings > Proxy
  /// in Dispatcharr, `new_client_behind_seconds`, 5 by default), or null
  /// when this login may not read the settings or they don't say.
  Future<int?> newClientBehindSeconds(DispatcharrLogin login) async {
    final j =
        await _get(login.server, '/api/core/settings/', apiKey: login.apiKey);
    final list = j is List ? j : (j is Map ? j['results'] : null);
    if (list is! List) return null;
    for (final s in list) {
      if (s is! Map || s['key'] != 'proxy_settings') continue;
      var value = s['value'];
      if (value is String) {
        try {
          value = jsonDecode(value);
        } catch (_) {
          return null;
        }
      }
      final behind = value is Map ? value['new_client_behind_seconds'] : null;
      return behind is num
          ? behind.round()
          : (behind is String ? int.tryParse(behind) : null);
    }
    return null;
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

/// What the player's Sources lists for a channel of the connected
/// Dispatcharr (Settings > Dispatcharr > Sources in the player). AMD,
/// 2026-11-18: he expected only the streams he assigned in Dispatcharr,
/// not VesperTV's own matches (quality copies, fallbacks, other
/// playlists) as well.
enum DispatcharrSources {
  /// The channel, Dispatcharr's streams, then VesperTV's matches.
  first,

  /// The channel and Dispatcharr's streams only.
  only,

  /// VesperTV's matches only, as without Dispatcharr.
  vesper;

  static DispatcharrSources parse(String? name) =>
      values.where((v) => v.name == name).firstOrNull ?? first;
}

/// The Sources rows of a Dispatcharr channel in [mode]'s order: [app] is
/// VesperTV's list (the channel itself first), [streams] Dispatcharr's.
/// The row playing now ([isCurrent]) always stays.
List<T> arrangeDispatcharrSources<T>(DispatcharrSources mode, List<T> app,
    List<T> streams, bool Function(T) isCurrent) {
  if (app.isEmpty) return streams;
  final rest = app.skip(1);
  return switch (mode) {
    DispatcharrSources.first => [app.first, ...streams, ...rest],
    DispatcharrSources.only => [
        app.first,
        ...streams,
        ...rest.where(isCurrent)
      ],
    DispatcharrSources.vesper => [
        ...app,
        ...streams.where(isCurrent),
      ],
  };
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
  final Map<int, String?> _idUuids = {};

  /// Whether the signed-in account is an admin (only admins may switch a
  /// channel's stream), asked once per sign-in.
  Future<bool>? _admin;

  /// The proxy's new_client_behind_seconds, asked once per sign-in.
  Future<int?>? _behind;

  /// The Dispatcharr streams the last Sources lists offered, by URL: the
  /// channel they belong to and the stream id ([switchChannelTo]).
  final Map<String, ({Channel channel, DispatcharrChannelRef ref, int id})>
      _picks = {};
  final Map<int, ({DateTime at, List<DispatcharrStream> streams})> _streams =
      {};
  ({DateTime at, Map<int, String> names})? _names;

  /// See [DispatcharrSources].
  DispatcharrSources get sources =>
      DispatcharrSources.parse(_storage?.getDispatcharrSources());
  Future<void> setSources(DispatcharrSources value) async =>
      _storage?.setDispatcharrSources(value.name);

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
    _idUuids.clear();
    _admin = null;
    _behind = null;
    _picks.clear();
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

  /// Remembers that the Sources row [url] is stream [streamId] of
  /// [channel] (a playlist channel of this server).
  void notePick(String url, Channel channel, int streamId) {
    final ref = refOf(channel);
    if (ref != null) _picks[url] = (channel: channel, ref: ref, id: streamId);
  }

  /// Whether the signed-in account is a Dispatcharr admin.
  Future<bool> isAdmin() {
    final l = login.value;
    if (l == null) return Future.value(false);
    return _admin ??= api.check(l).then((a) => a.admin).catchError((Object e) {
      debugPrint('Dispatcharr: account check failed ($e)');
      _admin = null;
      return false;
    });
  }

  Future<String?> _uuidOf(DispatcharrLogin l, DispatcharrChannelRef ref) async {
    if (ref.uuid != null) return ref.uuid;
    final id = ref.id;
    if (id == null) return null;
    if (!_idUuids.containsKey(id)) _idUuids[id] = await api.channelUuid(l, id);
    return _idUuids[id];
  }

  /// [source] is a Dispatcharr stream from the Sources list and this
  /// account is an admin: Dispatcharr switches its channel to that stream
  /// (Switch Stream in its own web page), so the player stays on the
  /// channel, in the same format, and Dispatcharr's failover keeps working
  /// (clayts450, 2026-11-18: playing the stream on its own took that away).
  /// It switches the channel for everyone watching it on that server.
  /// Returns the channel to be on; null = not switched (not a Dispatcharr
  /// stream, not an admin, or the server refused): play [source] itself.
  Future<Channel?> switchChannelTo(Channel source) async {
    final pick = _picks[source.url];
    final l = login.value;
    if (pick == null || l == null) return null;
    try {
      if (!await isAdmin().timeout(const Duration(seconds: 4))) {
        debugPrint('Dispatcharr: not an admin, the stream plays on its own');
        return null;
      }
      final uuid =
          await _uuidOf(l, pick.ref).timeout(const Duration(seconds: 4));
      if (uuid == null) return null;
      await api
          .changeStream(l, uuid, pick.id)
          .timeout(const Duration(seconds: 8));
      debugPrint('Dispatcharr: channel ${pick.ref} switched to stream '
          '${pick.id}');
      return pick.channel;
    } catch (e) {
      debugPrint('Dispatcharr: switch to stream ${pick.id} failed ($e), '
          'it plays on its own');
      return null;
    }
  }

  /// How long after [switchChannelTo] the player should reconnect to see
  /// the new stream at once (AMD, 2026-11-21, LOG-HZQBLZ). The switch comes
  /// down the open connection only after what the player buffered ahead
  /// (10-30 s), and ExoPlayer stumbled on the splice (timestamps 27 s back,
  /// 1080p SDR -> 4K HDR10, audio sink errors, freezes): 29-42 s per pick.
  /// A new viewer starts `new_client_behind_seconds` behind live (5 by
  /// default, Dispatcharr 0.34.1 `output/ts/generator.py`), on the last
  /// chunk received by then: reconnecting that long after the switch, plus
  /// [_upstreamStart] for the new stream's first bytes, starts the fresh
  /// connection on the new stream, past the splice.
  Future<Duration> reconnectDelay() async {
    final l = login.value;
    int? behind;
    if (l != null) {
      try {
        behind = await (_behind ??=
                api.newClientBehindSeconds(l).catchError((Object e) {
          debugPrint('Dispatcharr: proxy settings not read ($e)');
          return null;
        }))
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
        _behind = null;
      }
    }
    final seconds = (behind ?? 5).clamp(0, 30);
    return Duration(seconds: seconds) + _upstreamStart;
  }

  /// The new upstream's connect + first chunk after a switch (AMD's log:
  /// under a second to his provider).
  static const _upstreamStart = Duration(seconds: 2);

  /// One more viewer of [channel] on the server while the player
  /// reconnects after [switchChannelTo] (its bytes are read and dropped).
  /// Dispatcharr stops a channel as soon as its last viewer leaves
  /// (`channel_shutdown_delay` 0 by default, 0.34.1 `server.py`
  /// `handle_client_disconnect`) and the next viewer starts it again on its
  /// first stream: the switch would be lost while the old player closes
  /// before the new one opens. Returns the release once bytes arrive
  /// (within [wait]), or null. Lets go by itself after [longest].
  Future<Future<void> Function()?> holdChannel(Channel channel,
      {Duration wait = const Duration(seconds: 4),
      Duration longest = const Duration(seconds: 30)}) async {
    StreamSubscription<List<int>>? sub;
    Timer? limit;
    var released = false;
    Future<void> release() async {
      if (released) return;
      released = true;
      limit?.cancel();
      try {
        await sub?.cancel().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    try {
      final stream = await api
          .openStream(dispatcharrTsUrl(channel.url), channel.httpHeaders)
          .timeout(wait);
      final first = Completer<void>();
      sub = stream.listen((_) {
        if (!first.isCompleted) first.complete();
      }, onError: (Object e) {
        if (!first.isCompleted) first.completeError(e);
      }, onDone: () {
        if (!first.isCompleted) first.completeError('closed by the server');
      }, cancelOnError: true);
      await first.future.timeout(wait);
      limit = Timer(longest, () => unawaited(release()));
      debugPrint('Dispatcharr: holding the channel while the player '
          'reconnects');
      return release;
    } catch (e) {
      debugPrint('Dispatcharr: could not hold the channel ($e)');
      await release();
      return null;
    }
  }

  /// The stream [channel] plays on the server now, for an admin; null when
  /// unknown (not an admin, not playing, no answer within [timeout]).
  Future<int?> activeStreamOf(Channel channel,
      {Duration timeout = const Duration(seconds: 2)}) async {
    final l = login.value;
    final ref = refOf(channel);
    if (l == null || ref == null) return null;
    try {
      if (!await isAdmin().timeout(timeout)) return null;
      final uuid = await _uuidOf(l, ref).timeout(timeout);
      if (uuid == null) return null;
      return await api.activeStreamId(l, uuid).timeout(timeout);
    } catch (_) {
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
