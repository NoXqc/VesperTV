import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/archive_models.dart';

/// App ids from the owner's Trakt / Simkl developer pages (public — they
/// ship in every app; forks must register their own). Empty = that tracker
/// isn't set up in this build and its Connect button says so. Neither needs
/// a secret: the Trakt app (developer.trakt.tv, Production) is a public
/// client — device sign-in and refresh take the client id alone (checked
/// against the live API, 2026-10-19) — and the Simkl app is AUTH V2 of type
/// "TV, devices & command line" (device flow at /oauth2/, no secret).
const String kTraktClientId = 'tlQvMtQLHSWR4BkAIq5GW-1Wlt3vNR-y3-1EObmeXNo';
const String kSimklClientId =
    '3a52e9ae19612f2c38d983b9a46538e09dfd767842eb4e112ea4333e799df56f';

/// Must equal the redirect URI registered on developer.trakt.tv (a
/// Production app needs an https one; the device flow never redirects).
const String kTraktRedirectUri = 'https://vespertv.app/trakt';

/// The device sign-in did not finish: code expired, denied, or used.
class TrackerAuthException implements Exception {
  TrackerAuthException(this.reason);
  final String reason;
  @override
  String toString() => 'TrackerAuthException: $reason';
}

/// What the TV shows while the viewer signs in on their phone: "go to
/// [verificationUrl] and enter [userCode]".
class TrackerDeviceCode {
  const TrackerDeviceCode({
    required this.kind,
    required this.userCode,
    required this.verificationUrl,
    required this.deviceCode,
    required this.expiresIn,
    required this.interval,
    this.qrUrl,
  });

  final TrackerKind kind;
  final String userCode;
  final String verificationUrl;
  final String deviceCode;
  final Duration expiresIn;
  final Duration interval;

  /// The page with the code already filled in, when the service offers
  /// one (Simkl) — the QR code opens it; else [verificationUrl].
  final String? qrUrl;
}

/// A Media Hub play reported to Trakt/Simkl: a movie, or an episode of a
/// show, both by IMDb id.
class TrackedItem {
  const TrackedItem.movie(this.imdb)
      : season = null,
        episode = null;
  const TrackedItem.episode(this.imdb,
      {required int this.season, required int this.episode});

  /// The movie's or the show's IMDb id.
  final String imdb;
  final int? season;
  final int? episode;

  bool get isEpisode => season != null;

  /// The body both services' scrobble endpoints take (Simkl copied
  /// Trakt's format).
  Map<String, dynamic> toBody() => isEpisode
      ? {
          'show': {
            'ids': {'imdb': imdb}
          },
          'episode': {'season': season, 'number': episode},
        }
      : {
          'movie': {
            'ids': {'imdb': imdb}
          }
        };
}

/// Plain HTTP client for Trakt and Simkl, mapped onto the Media Hub: sign in
/// with a code on the TV (device flow — nothing to type on the remote but
/// the viewer's phone), their lists as catalogs (posters by IMDb id from
/// Stremio's public image service, like [ArchiveCatalogProvider]'s rows),
/// and scrobbling. No state: the login lives on the [ArchiveSource].
class TrackerApi {
  TrackerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);
  static const _trakt = 'https://api.trakt.tv';
  static const _simkl = 'https://api.simkl.com';
  static const _pageSize = 100;

  static String clientId(TrackerKind k) =>
      k == TrackerKind.trakt ? kTraktClientId : kSimklClientId;

  static bool isConfigured(TrackerKind k) => clientId(k).isNotEmpty;

  Map<String, String> _headers(TrackerKind k, [String? token]) => {
        'Content-Type': 'application/json',
        if (k == TrackerKind.trakt) ...{
          'trakt-api-version': '2',
          'trakt-api-key': kTraktClientId,
        } else
          'simkl-api-key': kSimklClientId,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Object? _decode(http.Response r) {
    if (r.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  // ---- sign-in ------------------------------------------------------------

  /// Starts a device sign-in: the code to show on the TV.
  Future<TrackerDeviceCode> startSignIn(TrackerKind k) async {
    final http.Response r;
    if (k == TrackerKind.trakt) {
      r = await _client
          .post(Uri.parse('$_trakt/oauth/device/code'),
              headers: _headers(k),
              body: jsonEncode({'client_id': kTraktClientId}))
          .timeout(_timeout);
    } else {
      // Simkl AUTH V2 device flow (RFC 8628). Write scope: scrobbling.
      r = await _client
          .post(Uri.parse('$_simkl/oauth2/device'),
              headers: _headers(k),
              body: jsonEncode({
                'client_id': kSimklClientId,
                'scope': 'media:read media:write',
              }))
          .timeout(_timeout);
    }
    final j = _decode(r);
    if (r.statusCode != 200 || j is! Map || j['user_code'] == null) {
      throw TrackerAuthException('start ${r.statusCode}');
    }
    final page = j['verification_url'] ?? j['verification_uri'];
    return TrackerDeviceCode(
      kind: k,
      userCode: '${j['user_code']}',
      verificationUrl:
          '${page ?? (k == TrackerKind.trakt ? 'https://auth.trakt.tv/activate' : 'https://simkl.com/pin')}',
      // Simkl: the page with the code filled in — what the QR code opens.
      qrUrl: j['verification_uri_complete']?.toString(),
      deviceCode: '${j['device_code']}',
      expiresIn: Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 600),
      interval: Duration(seconds: (j['interval'] as num?)?.toInt() ?? 5),
    );
  }

  /// One poll of a running sign-in: the login once approved, null while
  /// it's still pending. Throws [TrackerAuthException] when it can't finish.
  Future<TrackerLogin?> pollSignIn(TrackerDeviceCode code) async {
    final trakt = code.kind == TrackerKind.trakt;
    final r = await _client
        .post(
            Uri.parse(
                trakt ? '$_trakt/oauth/device/token' : '$_simkl/oauth2/token'),
            headers: _headers(code.kind),
            body: jsonEncode(trakt
                ? {'code': code.deviceCode, 'client_id': kTraktClientId}
                : {
                    'grant_type':
                        'urn:ietf:params:oauth:grant-type:device_code',
                    'device_code': code.deviceCode,
                    'client_id': kSimklClientId,
                  }))
        .timeout(_timeout);
    final j = _decode(r);
    if (r.statusCode == 200 && j is Map && j['access_token'] != null) {
      return _withUser(_login(code.kind, Map<String, dynamic>.from(j)));
    }
    // Trakt: 400 pending, 429 slow down (404/409/410/418 = never). Simkl:
    // 400 with authorization_pending / slow_down (expired_token = never).
    if (trakt && (r.statusCode == 400 || r.statusCode == 429)) return null;
    final error = j is Map ? j['error']?.toString() : null;
    if (!trakt && (error == 'authorization_pending' || error == 'slow_down')) {
      return null;
    }
    throw TrackerAuthException('${code.kind.name} ${r.statusCode} $error');
  }

  /// A token response as a login. Both services' tokens expire (Trakt: a
  /// day or more, Simkl V2: 7 days) and refresh with the client id alone.
  TrackerLogin _login(TrackerKind kind, Map<String, dynamic> j) {
    final created = (j['created_at'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresIn = (j['expires_in'] as num?)?.toInt() ??
        (kind == TrackerKind.trakt ? 86400 : 604800);
    return TrackerLogin(
      kind: kind,
      accessToken: '${j['access_token']}',
      refreshToken: j['refresh_token']?.toString(),
      expiresAtMs: (created + expiresIn) * 1000,
    );
  }

  /// Adds the account's display name (best effort; the login works without).
  Future<TrackerLogin> _withUser(TrackerLogin login) async {
    try {
      final base = login.kind == TrackerKind.trakt ? _trakt : _simkl;
      final r = await _client
          .get(Uri.parse('$base/users/settings'),
              headers: _headers(login.kind, login.accessToken))
          .timeout(_timeout);
      final j = _decode(r);
      final user = j is Map ? j['user'] : null;
      final name =
          user is Map ? (user['username'] ?? user['name'])?.toString() : null;
      if (name == null || name.isEmpty) return login;
      return TrackerLogin(
        kind: login.kind,
        accessToken: login.accessToken,
        refreshToken: login.refreshToken,
        expiresAtMs: login.expiresAtMs,
        userName: name,
      );
    } catch (_) {
      return login;
    }
  }

  /// A fresh token ([login] as is when it has no refresh token — a Simkl
  /// AUTH V1 login never expires).
  Future<TrackerLogin> refresh(TrackerLogin login) async {
    if (login.refreshToken == null) return login;
    final trakt = login.kind == TrackerKind.trakt;
    final r = await _client
        .post(Uri.parse(trakt ? '$_trakt/oauth/token' : '$_simkl/oauth2/token'),
            headers: _headers(login.kind),
            body: jsonEncode({
              'refresh_token': login.refreshToken,
              'client_id': trakt ? kTraktClientId : kSimklClientId,
              'grant_type': 'refresh_token',
              if (trakt) 'redirect_uri': kTraktRedirectUri,
            }))
        .timeout(_timeout);
    final j = _decode(r);
    if (r.statusCode != 200 || j is! Map || j['access_token'] == null) {
      throw TrackerAuthException('refresh ${r.statusCode}');
    }
    final fresh = _login(login.kind, Map<String, dynamic>.from(j));
    return TrackerLogin(
      kind: fresh.kind,
      accessToken: fresh.accessToken,
      // Simkl keeps the same refresh token (window extended).
      refreshToken: fresh.refreshToken ?? login.refreshToken,
      expiresAtMs: fresh.expiresAtMs,
      userName: login.userName,
    );
  }

  // ---- lists as Media Hub rows --------------------------------------------

  /// The rows an account gets. Ids are `{tracker}.{list}`; names are
  /// translated where they're shown.
  static List<ArchiveCatalog> catalogsFor(TrackerKind k) => switch (k) {
        TrackerKind.trakt => const [
            ArchiveCatalog(
                type: ArchiveType.movie,
                id: 'trakt.watchlist',
                name: 'Trakt watchlist'),
            ArchiveCatalog(
                type: ArchiveType.series,
                id: 'trakt.watchlist',
                name: 'Trakt watchlist'),
            ArchiveCatalog(
                type: ArchiveType.movie,
                id: 'trakt.trending',
                name: 'Trending on Trakt'),
            ArchiveCatalog(
                type: ArchiveType.series,
                id: 'trakt.trending',
                name: 'Trending on Trakt'),
          ],
        TrackerKind.simkl => const [
            ArchiveCatalog(
                type: ArchiveType.series,
                id: 'simkl.watching',
                name: 'Watching on Simkl'),
            ArchiveCatalog(
                type: ArchiveType.movie,
                id: 'simkl.plantowatch',
                name: 'Simkl plan to watch'),
            ArchiveCatalog(
                type: ArchiveType.series,
                id: 'simkl.plantowatch',
                name: 'Simkl plan to watch'),
          ],
      };

  /// One page of an account list. Simkl lists come whole (page 0 only).
  Future<List<ArchiveMeta>> fetchCatalog(
      TrackerLogin login, ArchiveCatalog catalog,
      {int skip = 0}) async {
    final movies = catalog.type == ArchiveType.movie;
    final Uri uri;
    if (login.kind == TrackerKind.trakt) {
      final page = '${skip ~/ _pageSize + 1}';
      final path = switch (catalog.id) {
        'trakt.trending' => movies ? '/movies/trending' : '/shows/trending',
        _ => movies ? '/sync/watchlist/movies' : '/sync/watchlist/shows',
      };
      uri = Uri.parse('$_trakt$path')
          .replace(queryParameters: {'page': page, 'limit': '$_pageSize'});
    } else {
      if (skip > 0) return const [];
      final status =
          catalog.id == 'simkl.watching' ? 'watching' : 'plantowatch';
      uri = Uri.parse(
          '$_simkl/sync/all-items/${movies ? 'movies' : 'shows'}/$status');
    }
    final r = await _client
        .get(uri, headers: _headers(login.kind, login.accessToken))
        .timeout(_timeout);
    if (r.statusCode == 401) throw TrackerAuthException('401');
    if (r.statusCode != 200) return const [];
    final j = _decode(r);
    // Trakt: a list of {movie|show: {...}}; Simkl: {movies|shows: [...]}.
    final items = j is List
        ? j
        : j is Map
            ? (j[movies ? 'movies' : 'shows'] as List? ?? const [])
            : const [];
    final key = movies ? 'movie' : 'show';
    return [
      for (final it in items)
        if (it is Map && it[key] is Map)
          if (metaFor(Map<String, dynamic>.from(it[key] as Map),
                  movies ? ArchiveType.movie : ArchiveType.series)
              case final m?)
            m,
    ];
  }

  /// A tracker title as a Media Hub meta, by IMDb id (no IMDb id = left
  /// out: nothing could play or show it).
  static ArchiveMeta? metaFor(Map<String, dynamic> j, ArchiveType type) {
    final ids = j['ids'];
    final imdb = ids is Map ? ids['imdb']?.toString() : null;
    final title = j['title']?.toString().trim();
    if (imdb == null || !imdb.startsWith('tt') || title == null) return null;
    return ArchiveMeta(
      id: imdb,
      type: type,
      name: title,
      year: j['year']?.toString(),
      posterUrl: 'https://images.metahub.space/poster/medium/$imdb/img',
      backgroundUrl: 'https://images.metahub.space/background/medium/$imdb/img',
    );
  }

  // ---- scrobbling ----------------------------------------------------------

  /// Tells [login]'s service that [item] started / paused / stopped at
  /// [progress] percent. A stop at 80 %+ marks it watched (both services).
  /// Best effort: a failure is only returned, never thrown.
  Future<bool> scrobble(TrackerLogin login, TrackedItem item, String action,
      double progress) async {
    final base = login.kind == TrackerKind.trakt ? _trakt : _simkl;
    try {
      final r = await _client
          .post(Uri.parse('$base/scrobble/$action'),
              headers: _headers(login.kind, login.accessToken),
              body: jsonEncode({
                ...item.toBody(),
                'progress': double.parse(progress.toStringAsFixed(2)),
              }))
          .timeout(_timeout);
      // Trakt answers 409 when the same stop was just sent: fine.
      return r.statusCode == 201 || r.statusCode == 200 || r.statusCode == 409;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}
