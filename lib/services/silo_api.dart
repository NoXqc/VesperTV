import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/archive_models.dart';
import 'archive_api_service.dart';
import 'media_server_errors.dart';

/// A TV code to approve on the Silo server's `/activate` page (or with the
/// QR code), from `POST /auth/device/start`.
class SiloDeviceCode {
  const SiloDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.verificationUrlComplete,
    required this.expiresAt,
    required this.interval,
  });

  /// Secret: only this device polls with it.
  final String deviceCode;

  /// Eight digits, shown as two groups of four (`4821-7730`).
  final String userCode;
  final String verificationUrl;

  /// The same page with the code filled in (the QR code).
  final String verificationUrlComplete;
  final DateTime expiresAt;
  final Duration interval;
}

/// A finished sign-in, before a profile is chosen (a code approved on the
/// server's page may already carry the profile picked there).
class SiloSignIn {
  const SiloSignIn({
    required this.base,
    required this.deviceId,
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.userName,
    this.profileId,
    this.profileToken,
  });

  final String base, deviceId, accessToken, refreshToken, userId, userName;
  final String? profileId, profileToken;
}

/// A household profile of the signed-in account.
class SiloProfile {
  const SiloProfile(
    this.id,
    this.name, {
    this.hasPin = false,
    this.isPrimary = false,
  });
  final String id, name;
  final bool hasPin, isPrimary;
}

/// The code sign-in ended without the device getting in: refused on the
/// server's page, expired (15 minutes) or withdrawn.
class SiloSignInEndedException implements Exception {
  SiloSignInEndedException(this.status);
  final String status;
  @override
  String toString() => 'SiloSignInEndedException($status)';
}

/// Too many tries (sign-in or profile PIN): the server waits [retryAfter].
class SiloRateLimitedException implements Exception {
  SiloRateLimitedException(this.retryAfter);
  final Duration? retryAfter;
  @override
  String toString() => 'SiloRateLimitedException';
}

/// The server answered Play without a playable plan (`terminal.message`).
class SiloPlaybackRefusedException implements Exception {
  SiloPlaybackRefusedException(this.reason, this.message);
  final String reason, message;
  @override
  String toString() => 'SiloPlaybackRefusedException($reason)';
}

/// One started play on a Silo server: the stream URL the player opens and
/// what progress reports and the stop need.
class SiloPlay {
  SiloPlay(
    this.source,
    this.sessionId,
    this.installationId,
    this.url,
    this.headers,
  );
  final ArchiveSource source;
  final String sessionId, installationId, url;
  final Map<String, String> headers;
  int sequence = 0;
  Duration lastPosition = Duration.zero;
}

/// Silo (siloserver.org, open source, AGPL), spoken through its own API
/// (`/api/v2`), not its Jellyfin-compatible port: the viewer types the
/// server's usual address, signs in with a TV code approved on the
/// server's `/activate` page (or a password) and picks a household
/// profile. Libraries are catalogs like a Jellyfin server's; Play asks the
/// server for the original file (`POST /playback/start`, delivery
/// `original_http`), which it hands out as a signed link that needs no
/// header, so both players open it as is. Details: dev-notes/silo.md.
///
/// The sign-in is a login session: an 8-hour access token renewed with its
/// refresh token on a 401 ([onLoginChanged] saves the new pair).
class SiloApi {
  SiloApi(this._client);

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  /// Called after the sign-in was renewed, so the caller keeps the new
  /// tokens (`ArchiveService`).
  void Function(ArchiveSource source, MediaServerLogin login)? onLoginChanged;

  final Map<String, MediaServerLogin> _fresh = {};
  final Map<String, Future<MediaServerLogin>> _refreshing = {};
  final Map<String, Future<String>> _installations = {};

  /// Told to the server with each Play (required): `tv`, `mobile` or
  /// `desktop`. main.dart sets it once it knows the device is a TV box.
  static String formFactor = switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS =>
      'desktop',
    _ => 'mobile',
  };

  static String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.windows => 'windows',
        TargetPlatform.macOS => 'macos',
        TargetPlatform.linux => 'linux',
        _ => 'other',
      };

  /// What the viewer typed, as a base URL: `http://` by default (a server
  /// on the home network rarely has a certificate), no trailing slash, no
  /// page of the web app pasted from the browser.
  static String normalizeUrl(String input) {
    var u = input.trim();
    for (final cut in ['#', '?']) {
      final at = u.indexOf(cut);
      if (at >= 0) u = u.substring(0, at);
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    u = u.replaceFirst(
      RegExp(r'/(activate|login|api)(/.*)?$', caseSensitive: false),
      '',
    );
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  static Map<String, String> _deviceHeaders(String deviceId) => {
        'Accept': 'application/json',
        'X-Silo-Device-Id': deviceId,
        'X-Silo-Device-Name': 'VesperTV',
        'X-Silo-Device-Platform': _platform,
      };

  static Map<String, String> _headers(MediaServerLogin l) => {
        ..._deviceHeaders(l.deviceId),
        'Authorization': 'Bearer ${l.token}',
        if (l.profileId != null) 'X-Profile-Id': l.profileId!,
        if (l.profileToken != null) 'X-Profile-Token': l.profileToken!,
      };

  static Map<String, dynamic> _map(http.Response r) {
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is! Map) throw ArchiveApiException('Silo: not a JSON object');
    return Map<String, dynamic>.from(body);
  }

  static Duration? _retryAfter(http.Response r) {
    final s = int.tryParse(r.headers['retry-after'] ?? '');
    return s == null ? null : Duration(seconds: s);
  }

  /// Errors never carry the URL or the server's reply (tokens can be in
  /// either); the screens say what went wrong in the viewer's language.
  static Never _fail(http.Response r) {
    if (r.statusCode == 400 || r.statusCode == 422) {
      // Which fields the server refused (names and codes only), for the
      // Send log when a server version changes its contract.
      try {
        final errors = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['errors'];
        debugPrint('Silo: HTTP ${r.statusCode} '
            '${[
          for (final e in errors as List)
            '${(e as Map)['location']} ${e['code']}'
        ].join(', ')}');
      } catch (_) {}
    }
    if (r.statusCode == 401) throw MediaServerLoginException();
    if (r.statusCode == 429) throw SiloRateLimitedException(_retryAfter(r));
    throw ArchiveApiException('Silo HTTP ${r.statusCode}');
  }

  Future<http.Response> _plain(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return http.Response.fromStream(
      await _client.send(request).timeout(_timeout),
    );
  }

  /// Finds the server at [input]: the address as typed, then its origin
  /// (a page path pasted from the browser). Returns the API's base URL.
  Future<String> discover(String input) async {
    final typed = normalizeUrl(input);
    final uri = Uri.parse(typed);
    final origin = '${uri.scheme}://${uri.authority}';
    for (final base in {typed, origin}) {
      try {
        final r = await _client.get(
          Uri.parse('$base/api/v2/system/info'),
          headers: const {'Accept': 'application/json'},
        ).timeout(_timeout);
        if (r.statusCode != 200) continue;
        if (_map(r)['api_major'] == 2) return base;
      } catch (_) {
        continue;
      }
    }
    throw ArchiveApiException('No Silo server there');
  }

  // ---- Sign-in -----------------------------------------------------------

  Future<SiloDeviceCode> startDeviceLogin(String base, String deviceId) async {
    final r = await _plain(
      'POST',
      Uri.parse('$base/api/v2/auth/device/start'),
      _deviceHeaders(deviceId),
      {'device_name': 'VesperTV', 'device_platform': _platform},
    );
    if (r.statusCode != 201 && r.statusCode != 200) _fail(r);
    final j = _map(r);
    final seconds = (j['expires_in'] as num?)?.toInt() ?? 900;
    return SiloDeviceCode(
      deviceCode: '${j['device_code']}',
      userCode: '${j['user_code']}',
      verificationUrl: '${j['verification_uri'] ?? '$base/activate'}',
      verificationUrlComplete:
          '${j['verification_uri_complete'] ?? j['verification_uri'] ?? '$base/activate'}',
      expiresAt: DateTime.now().add(Duration(seconds: seconds)),
      interval: Duration(
        seconds: max(2, (j['interval'] as num?)?.toInt() ?? 5),
      ),
    );
  }

  /// Null while the code waits for approval; the sign-in once approved.
  /// Throws [SiloSignInEndedException] when it was refused or ran out.
  Future<SiloSignIn?> pollDeviceLogin(
    String base,
    String deviceId,
    SiloDeviceCode code,
  ) async {
    final r = await _plain(
      'POST',
      Uri.parse('$base/api/v2/auth/device/poll'),
      _deviceHeaders(deviceId),
      {'device_code': code.deviceCode},
    );
    if (r.statusCode == 404 || r.statusCode == 410) {
      throw SiloSignInEndedException('expired');
    }
    if (r.statusCode != 200) _fail(r);
    final j = _map(r);
    final status = '${j['status']}';
    if (status == 'pending') return null;
    final tokens = j['tokens'];
    if (status != 'approved' || tokens is! Map) {
      throw SiloSignInEndedException(status);
    }
    String? text(Object? v) =>
        v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    final user = tokens['user'] is Map ? tokens['user'] as Map : const {};
    return SiloSignIn(
      base: base,
      deviceId: deviceId,
      accessToken: '${tokens['access_token']}',
      refreshToken: '${tokens['refresh_token']}',
      userId: '${user['id'] ?? ''}',
      userName: '${user['username'] ?? ''}',
      profileId: text(j['profile_id']),
      profileToken: text(j['profile_token']),
    );
  }

  /// Withdraws a code nobody approved yet (the screen was left), so it
  /// can't be approved later. Best effort.
  Future<void> cancelDeviceLogin(
    String base,
    String deviceId,
    SiloDeviceCode code,
  ) async {
    try {
      await _plain(
        'POST',
        Uri.parse('$base/api/v2/auth/device/cancel'),
        _deviceHeaders(deviceId),
        {'device_code': code.deviceCode},
      );
    } catch (_) {}
  }

  /// Password sign-in. Throws [MediaServerLoginException] for a wrong
  /// name or password and [SiloRateLimitedException] after too many tries.
  Future<SiloSignIn> login(
    String base,
    String deviceId,
    String userName,
    String password,
  ) async {
    final r = await _plain(
      'POST',
      Uri.parse('$base/api/v2/auth/login'),
      _deviceHeaders(deviceId),
      {'username': userName, 'password': password},
    );
    if (r.statusCode == 403 || r.statusCode == 422) {
      throw MediaServerLoginException();
    }
    if (r.statusCode != 200) _fail(r);
    final j = _map(r);
    final user = j['user'] is Map ? j['user'] as Map : const {};
    return SiloSignIn(
      base: base,
      deviceId: deviceId,
      accessToken: '${j['access_token']}',
      refreshToken: '${j['refresh_token']}',
      userId: '${user['id'] ?? ''}',
      userName: '${user['username'] ?? userName}',
    );
  }

  Future<List<SiloProfile>> profiles(SiloSignIn s) async {
    final r = await _plain(
        'GET',
        Uri.parse('${s.base}/api/v2/profiles'),
        {
          ..._deviceHeaders(s.deviceId),
          'Authorization': 'Bearer ${s.accessToken}',
        },
        null);
    if (r.statusCode != 200) _fail(r);
    return [
      for (final p in (_map(r)['items'] as List? ?? const []))
        if (p is Map && p['id'] != null)
          SiloProfile(
            '${p['id']}',
            '${p['name'] ?? ''}'.trim(),
            hasPin: p['has_pin'] == true,
            isPrimary: p['is_primary'] == true,
          ),
    ];
  }

  /// The token that unlocks a PIN profile for this sign-in; null for a
  /// wrong PIN. Never retried by itself: every try counts toward the
  /// server's lock (five wrong PINs = five minutes).
  Future<String?> verifyPin(SiloSignIn s, String profileId, String pin) async {
    final r = await _plain(
      'POST',
      Uri.parse(
        '${s.base}/api/v2/profiles/${Uri.encodeComponent(profileId)}/verify-pin',
      ),
      {
        ..._deviceHeaders(s.deviceId),
        'Authorization': 'Bearer ${s.accessToken}',
      },
      {'pin': pin},
    );
    if (r.statusCode != 200) _fail(r);
    final j = _map(r);
    return j['valid'] == true ? j['profile_token']?.toString() : null;
  }

  /// The source for [sign] acting as [profile]: one catalog per movie /
  /// TV library the profile can see.
  Future<ArchiveSource> connect(
    SiloSignIn sign,
    SiloProfile profile, {
    String? profileToken,
  }) async {
    final login = MediaServerLogin(
      kind: MediaServerKind.silo,
      userId: sign.userId,
      token: sign.accessToken,
      deviceId: sign.deviceId,
      userName: sign.userName,
      refreshToken: sign.refreshToken,
      profileId: profile.id,
      profileName: profile.name,
      profileToken: profileToken ??
          (sign.profileId == profile.id ? sign.profileToken : null),
    );
    final host = Uri.parse(sign.base).host;
    final draft = ArchiveSource(
      manifestUrl: '${sign.base}#${sign.userId}:${profile.id}',
      name: 'Silo · $host',
      server: login,
    );
    final catalogs = await libraries(draft);
    if (catalogs.isEmpty) throw MediaServerNoLibraryException();
    return ArchiveSource(
      manifestUrl: draft.manifestUrl,
      name: draft.name,
      description: [
        'Silo',
        if (sign.userName.isNotEmpty) sign.userName,
        if (profile.name.isNotEmpty && profile.name != sign.userName)
          profile.name,
      ].join(' · '),
      catalogs: catalogs,
      server: login,
    );
  }

  // ---- Authenticated requests ---------------------------------------------

  /// The newest sign-in of [s] (renewed ones live here until the saved
  /// source catches up).
  MediaServerLogin loginOf(ArchiveSource s) =>
      _fresh[s.manifestUrl] ?? s.server!;

  Future<http.Response> _send(
    ArchiveSource s,
    String method,
    String path, {
    Object? body,
  }) async {
    var login = loginOf(s);
    final uri = Uri.parse('${s.baseUrl}/api/v2$path');
    var r = await _plain(method, uri, _headers(login), body);
    if (r.statusCode == 401 && login.refreshToken != null) {
      login = await _refresh(s, login);
      r = await _plain(method, uri, _headers(login), body);
    }
    if (r.statusCode == 401) throw MediaServerLoginException();
    return r;
  }

  Future<Map<String, dynamic>> _getJson(ArchiveSource s, String path) async {
    final r = await _send(s, 'GET', path);
    if (r.statusCode != 200) _fail(r);
    return _map(r);
  }

  Future<MediaServerLogin> _refresh(ArchiveSource s, MediaServerLogin old) {
    final key = s.manifestUrl;
    return _refreshing[key] ??= () async {
      try {
        final r = await _plain(
          'POST',
          Uri.parse('${s.baseUrl}/api/v2/auth/refresh'),
          _deviceHeaders(old.deviceId),
          {'refresh_token': old.refreshToken},
        );
        if (r.statusCode == 401 || r.statusCode == 403) {
          throw MediaServerLoginException();
        }
        if (r.statusCode != 200) _fail(r);
        final j = _map(r);
        final fresh = old.withTokens(
          '${j['access_token']}',
          j['refresh_token']?.toString(),
        );
        _fresh[key] = fresh;
        onLoginChanged?.call(s, fresh);
        return fresh;
      } finally {
        // Runs after the first await: the map entry is set by then.
        _refreshing.remove(key);
      }
    }();
  }

  /// A server path (`/api/v2/stream/…`) or a full URL, as a full URL.
  static String? absolute(String base, Object? value) {
    final v = value?.toString().trim();
    if (v == null || v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) return '$base$v';
    return null;
  }

  /// Image query used on every browse call: big enough for the TV's
  /// posters and backdrops (the default poster is 300 px wide).
  static const _imageQuery =
      'poster_width=500&backdrop_width=1280&still_width=480&logo_width=600';

  // ---- Browse ---------------------------------------------------------------

  Future<List<ArchiveCatalog>> libraries(ArchiveSource s) async {
    final j = await _getJson(s, '/user/libraries');
    return [
      for (final l in (j['items'] as List? ?? const []))
        if (l is Map && l['id'] != null)
          if (switch ('${l['type'] ?? ''}'.toLowerCase()) {
            'movies' || 'movie' => ArchiveType.movie,
            'series' || 'shows' || 'tvshows' || 'tv' => ArchiveType.series,
            _ => null,
          }
              case final type?)
            ArchiveCatalog(
              type: type,
              id: '${l['id']}',
              name: '${l['name'] ?? ''}'.trim(),
              searchable: true,
            ),
    ];
  }

  /// One page of a library, newest first (a search: best match first).
  Future<List<ArchiveMeta>> fetchCatalog(
    ArchiveSource s,
    ArchiveCatalog catalog, {
    int skip = 0,
    int limit = 100,
    String? search,
  }) async {
    final q = {
      'library_id': catalog.id,
      'type': catalog.type == ArchiveType.series ? 'series' : 'movie',
      'limit': '$limit',
      if (skip > 0) 'seek': '$skip',
      'skip_total': 'true',
      if (search != null) 'q': search else 'sort': '-added_at',
      if (catalog.extra['genre'] case final genre?) 'genre': genre,
    };
    final j = await _getJson(
      s,
      '/catalog?${Uri(queryParameters: q).query}&$_imageQuery',
    );
    return [
      for (final it in (j['items'] as List? ?? const []))
        if (it is Map)
          if (_meta(s, Map<String, dynamic>.from(it)) case final m?) m,
    ];
  }

  /// The full item; a series also gets its episodes as `videos`.
  Future<ArchiveMeta?> fetchMeta(ArchiveSource s, ArchiveMeta preview) async {
    final id = Uri.encodeComponent(preview.id);
    final item = await _getJson(s, '/catalog/items/$id?$_imageQuery');
    final meta = _meta(s, item) ?? preview;
    if (meta.type != ArchiveType.series) return meta;
    final seasons = await _getJson(s, '/catalog/series/$id/seasons');
    final videos = <ArchiveVideo>[];
    for (final season in (seasons['items'] as List? ?? const [])) {
      if (season is! Map) continue;
      final number = (season['season_number'] as num?)?.toInt();
      if (number == null) continue;
      final eps = await _getJson(
        s,
        '/catalog/series/$id/seasons/$number/episodes?$_imageQuery',
      );
      for (final e in (eps['items'] as List? ?? const [])) {
        if (e is! Map || e['content_id'] == null) continue;
        // An episode the server only knows from metadata has no file.
        if (e['files'] is List && (e['files'] as List).isEmpty) continue;
        videos.add(
          ArchiveVideo(
            id: '${e['content_id']}',
            title: _str(e['title']) ?? '',
            season: (e['season_number'] as num?)?.toInt() ?? number,
            episode: (e['episode_number'] as num?)?.toInt() ?? 0,
            thumbnailUrl: absolute(s.baseUrl, e['still_url']),
            overview: _str(e['overview']),
            released: _str(e['air_date']),
          ),
        );
      }
    }
    videos.sort((a, b) {
      final c = a.season.compareTo(b.season);
      return c != 0 ? c : a.episode.compareTo(b.episode);
    });
    return ArchiveMeta(
      id: meta.id,
      imdbId: meta.imdbId,
      type: meta.type,
      name: meta.name,
      posterUrl: meta.originalPosterUrl,
      backgroundUrl: meta.backgroundUrl,
      logoUrl: meta.logoUrl,
      year: meta.year,
      description: meta.description,
      genres: meta.genres,
      runtime: meta.runtime,
      rating: meta.rating,
      videos: videos,
    );
  }

  /// The files of a movie or episode, one stream per version. Each link is
  /// a placeholder ([playLink]) that Play turns into a session of its own
  /// ([startPlayback]): Silo's media links belong to one play.
  Future<List<ArchiveStream>> streams(ArchiveSource s, String itemId) async {
    final item = await _getJson(
      s,
      '/catalog/items/${Uri.encodeComponent(itemId)}',
    );
    final versions = [
      for (final v in (item['versions'] as List? ?? const []))
        if (v is Map && v['file_id'] != null) v,
    ];
    return [
      for (final v in versions)
        ArchiveStream(
          url: playLink(s, itemId, '${v['file_id']}'),
          name: s.name,
          title: [
            'Silo',
            if (_str(v['resolution']) case final res?) res,
            if (v['hdr'] == true) 'HDR',
            if (_str(v['codec_video']) case final codec?) codec.toUpperCase(),
            if (_str(v['container']) case final c?) c.toUpperCase(),
          ].join(' · '),
          fileName: _str(v['file_name']),
          sizeBytes: (v['file_size'] as num?)?.toInt(),
        ),
    ];
  }

  // ---- Play ------------------------------------------------------------------

  static const _fileMark = '#silo-file=';

  /// A version's stable link: the item's address plus the file id. Never
  /// opened as is; it keeps the resume pick and the history matching.
  static String playLink(ArchiveSource s, String itemId, String fileId) =>
      '${s.baseUrl}/api/v2/catalog/items/${Uri.encodeComponent(itemId)}'
      '$_fileMark${Uri.encodeComponent(fileId)}';

  static bool isPlayLink(String url) => url.contains(_fileMark);

  static String? _fileOf(String url) {
    final at = url.indexOf(_fileMark);
    return at < 0
        ? null
        : Uri.decodeComponent(url.substring(at + _fileMark.length));
  }

  Future<String> _installation(ArchiveSource s) {
    final key = s.baseUrl;
    return _installations[key] ??= () async {
      try {
        final j = await _getJson(s, '/playback/capabilities');
        final id = _str(j['installation_id']);
        if (id == null) throw ArchiveApiException('Silo: no installation id');
        return id;
      } catch (_) {
        _installations.remove(key);
        rethrow;
      }
    }();
  }

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static const _videoCodecs = [
    'h264', 'hevc', 'av1', 'vp9', 'vp8', 'mpeg2video', 'mpeg4', 'vc1', //
  ];
  static const _audioCodecs = [
    'aac', 'ac3', 'eac3', 'dts', 'truehd', 'flac', 'opus', 'mp3', 'mp2', //
    'vorbis', 'pcm', 'alac',
  ];
  static const _containers = [
    'mkv', 'matroska', 'mp4', 'mov', 'm4v', 'ts', 'mpegts', 'm2ts', 'avi', //
    'webm', 'wmv', 'asf', 'flv', 'ogg',
  ];
  static const _hdr = {
    'hdr10': true,
    'hdr10_plus': true,
    'hlg': true,
    'dolby_vision_profiles': [5, 7, 8],
  };

  /// What the players can open. Both decode nearly everything in software
  /// when the box can't (ExoPlayer + FFmpeg, mpv), and VesperTV plays
  /// server files as stored, like its Jellyfin / Emby / Plex connectors:
  /// so the claim is broad, at the `declared` evidence tier (no per-codec
  /// probe, as Silo's web player), and HLS is only the server's fallback
  /// when a rule of its own (a bitrate limit) rules the original out.
  static Map<String, dynamic> _playbackBody(
    String fileId,
    String profileId,
    String installationId,
    Duration start,
  ) =>
      {
        'protocol_version': 3,
        'file_id': fileId,
        'profile_id': profileId,
        'playback_attempt_id': _uuid(),
        'installation_id': installationId,
        'quality_preference': 'original',
        'subtitle_fidelity_preference': 'preserve',
        'allow_alternate_versions': false,
        'client_features': const <String>[],
        if (start > Duration.zero)
          'start_position': start.inMilliseconds / 1000,
        'client_capabilities': {
          'video_evidence': 'declared',
          'audio_evidence': 'declared',
          'codecs_video': _videoCodecs,
          'codecs_video_hardware': _videoCodecs,
          'codecs_audio': _audioCodecs,
          'containers': _containers,
          'hdr': true,
          'hdr_details': _hdr,
        },
        'client_playback_context': {
          'protocol_version': 3,
          'form_factor': formFactor,
          'app_version': '1',
          'device': {'platform': _platform},
          'output': {'hdr_details': _hdr},
          'deliveries': {
            'original_http': _delivery(
              containers: _containers,
              video: _videoCodecs,
              audio: _audioCodecs,
            ),
            'hls': _delivery(
              containers: const ['mpegts', 'ts', 'fmp4', 'mp4'],
              video: const ['h264', 'hevc'],
              audio: const ['aac', 'ac3', 'eac3'],
            ),
          },
        },
      };

  static Map<String, dynamic> _delivery({
    required List<String> containers,
    required List<String> video,
    required List<String> audio,
  }) =>
      {
        'enabled': true,
        'supported_on_device': true,
        'containers': containers,
        'video_codecs': video,
        'audio_decode_codecs': audio,
        'audio_passthrough_codecs': const <String>[],
        'auth_header_refresh': false,
        'features': const <String>[],
        'validated_claims': const <String>[],
        'transformations': const <Object>[],
        'subtitles': const {
          'embedded_text': true,
          'sidecar_text': false,
          'ass_styling': false,
          'embedded_bitmap': true,
          'sidecar_bitmap': false,
          'font_attachments': false,
        },
      };

  /// Starts a play of [link]'s file and returns the URL the player opens.
  /// Throws [SiloPlaybackRefusedException] when the server has no plan for
  /// this device (`terminal.message` says why).
  Future<SiloPlay> startPlayback(
    ArchiveSource s,
    String link, {
    Duration start = Duration.zero,
  }) async {
    final fileId = _fileOf(link);
    if (fileId == null) throw ArchiveApiException('Silo: not a play link');
    final installation = await _installation(s);
    final login = loginOf(s);
    final r = await _send(
      s,
      'POST',
      '/playback/start',
      body: _playbackBody(fileId, login.profileId ?? '', installation, start),
    );
    if (r.statusCode != 201 && r.statusCode != 200) _fail(r);
    final j = _map(r);
    final plan = j['playback_plan'];
    final stream = plan is Map ? plan['stream'] : null;
    final url = stream is Map ? absolute(s.baseUrl, stream['url']) : null;
    final session = _str(j['session_id']) ??
        (plan is Map ? _str(plan['session_id']) : null);
    if (j['outcome'] != 'playable' || url == null || session == null) {
      final t = j['terminal'] is Map ? j['terminal'] as Map : const {};
      throw SiloPlaybackRefusedException(
        '${t['reason'] ?? j['outcome']}',
        '${t['message'] ?? ''}',
      );
    }
    debugPrint(
      'Silo: play ${(plan as Map)['delivery']} '
      '(${plan['decision_reason']})',
    );
    final headers = {
      if (stream is Map && stream['headers'] is Map)
        for (final e in (stream['headers'] as Map).entries)
          '${e.key}': '${e.value}',
    };
    final play = SiloPlay(s, session, installation, url, headers);
    SiloSessions.instance._add(this, play);
    return play;
  }

  /// The heartbeat (Silo ends a play after 5 minutes without one, or 30
  /// paused) and the viewer's place for the server's Continue watching.
  Future<bool> _progress(SiloPlay play, Duration position, bool paused) async {
    final r = await _send(
      play.source,
      'POST',
      '/playback/${play.sessionId}/progress',
      body: {
        'installation_id': play.installationId,
        'sequence': ++play.sequence,
        'position': position.inMilliseconds / 1000,
        'is_paused': paused,
      },
    );
    // 404 / 410: the play ended on the server (expired, stopped, ended by
    // an admin). Nothing to keep alive.
    return r.statusCode == 200;
  }

  Future<void> _stop(SiloPlay play, Duration position) async {
    await _send(
      play.source,
      'DELETE',
      '/playback/${play.sessionId}',
      body: {
        'installation_id': play.installationId,
        'stop_id': _uuid(),
        'sequence': ++play.sequence,
        'position': position.inMilliseconds / 1000,
        'is_paused': true,
      },
    );
  }

  ArchiveMeta? _meta(ArchiveSource s, Map<String, dynamic> j) {
    final id = _str(j['content_id']);
    final name = _str(j['title']);
    if (id == null || name == null) return null;
    // Cards carry `duration_seconds`, title pages `runtime` in minutes.
    final minutes = j['duration_seconds'] is num
        ? (j['duration_seconds'] as num) / 60
        : (j['runtime'] as num?);
    final rating = (j['rating_imdb'] as num?) ?? (j['rating_tmdb'] as num?);
    final imdb = _str(j['imdb_id']);
    final logo = absolute(s.baseUrl, j['logo_url']);
    return ArchiveMeta(
      id: id,
      imdbId: imdb != null && imdb.startsWith('tt') ? imdb : null,
      type: j['type'] == 'series' ? ArchiveType.series : ArchiveType.movie,
      name: name,
      posterUrl: absolute(s.baseUrl, j['poster_url']),
      backgroundUrl: absolute(s.baseUrl, j['backdrop_url']),
      // Silo hands out TMDB's SVG logos, which the app can't draw.
      logoUrl:
          logo != null && !logo.toLowerCase().endsWith('.svg') ? logo : null,
      year: _str(j['year']),
      description: _str(j['overview']),
      genres: [
        for (final g in (j['genres'] as List? ?? const []))
          if (_str(g) case final t?) t,
      ],
      runtime:
          minutes != null && minutes >= 1 ? '${minutes.round()} min' : null,
      rating: rating != null && rating > 0 ? rating.toStringAsFixed(1) : null,
    );
  }

  static String? _str(Object? v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// The Silo plays the players have open, by stream URL: both players say
/// when a Silo stream starts ([playing], with a way to read its position)
/// and stops ([stopped]); in between this sends the heartbeat every 60 s.
/// Not a Silo URL = nothing happens, so the players call it for every
/// channel. A player that went away (its position reader answers null)
/// ends the play with the last position it gave.
class SiloSessions {
  SiloSessions._();
  static final instance = SiloSessions._();

  static const beat = Duration(seconds: 60);

  final Map<String, _SiloLive> _live = {};

  void _add(SiloApi api, SiloPlay play) {
    _live[play.url] = _SiloLive(api, play);
    // Plays resolved but never opened (the viewer backed out): ended after
    // 5 minutes by the server; forget them here too.
    if (_live.length > 6) {
      final oldest = _live.keys.first;
      _live.remove(oldest)?.end(null);
    }
  }

  bool isSilo(String url) => _live.containsKey(url);

  void playing(
    String url,
    ({Duration position, bool paused})? Function() sample,
  ) {
    final live = _live[url];
    if (live == null) return;
    live.sample = sample;
    live.timer?.cancel();
    live.timer = Timer.periodic(
      beat,
      (_) => live.tick(() => _live.remove(url)),
    );
  }

  void stopped(String url, Duration position) {
    _live.remove(url)?.end(position);
  }
}

class _SiloLive {
  _SiloLive(this.api, this.play);
  final SiloApi api;
  final SiloPlay play;
  Timer? timer;
  ({Duration position, bool paused})? Function()? sample;

  Future<void> tick(void Function() forget) async {
    final now = sample?.call();
    if (now == null) {
      forget();
      return end(play.lastPosition);
    }
    play.lastPosition = now.position;
    try {
      if (!await api._progress(play, now.position, now.paused)) {
        timer?.cancel();
        forget();
      }
    } catch (e) {
      debugPrint('Silo: progress failed (${e.runtimeType})');
    }
  }

  Future<void> end(Duration? position) async {
    timer?.cancel();
    try {
      await api._stop(play, position ?? play.lastPosition);
    } catch (e) {
      debugPrint('Silo: stop failed (${e.runtimeType})');
    }
  }
}
