import '../models/trailer.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/archive_models.dart';
import 'archive_api_service.dart';
import 'media_server_errors.dart';
import 'plex_api.dart';
import 'silo_api.dart';
import 'stream_headers.dart';

export 'media_server_errors.dart';

/// HTTP client for Jellyfin, Emby, Plex and Silo, mapped onto the Media
/// Hub's models: the user's movie and TV libraries are catalogs, a series'
/// episodes are its `videos`, and Play is the server's direct (original
/// file, no transcode) stream URL. No state: the login lives on the
/// [ArchiveSource] ([ArchiveSource.server]).
///
/// The two speak the same API (Jellyfin is a 2018 fork of Emby). What
/// differs, and is handled here:
/// - auth header: Jellyfin `Authorization: MediaBrowser …`; Emby
///   `X-Emby-Authorization` + `X-Emby-Token` (newer Jellyfin turns those
///   legacy headers off), and the stream URL's key is `ApiKey` vs
///   `api_key`;
/// - path: Emby usually lives under `/emby` (tried when the plain address
///   isn't a server);
/// - which one it is: `/System/Info/Public` (no login needed) —
///   `ProductName` "Jellyfin Server", or a 10.x version, is Jellyfin.
class MediaServerApi {
  MediaServerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  late final _plex = PlexApi(_client);

  /// Silo servers (`SiloApi`): sign-in, browse and Play's sessions.
  late final silo = SiloApi(_client);

  Future<ArchiveSource> connectPlex(PlexServer server, String deviceId) =>
      _plex.connect(server, deviceId);
  static const _timeout = Duration(seconds: 20);
  static const catalogPageSize = PlexApi.pageSize;

  /// What the user typed into a base URL: `http://` by default (servers
  /// on a home network rarely have a certificate), no trailing slash, no
  /// web-UI path (`…/web/index.html#!/home` pasted from the browser).
  static String normalizeUrl(String input) {
    var u = input.trim();
    final hash = u.indexOf('#');
    if (hash >= 0) u = u.substring(0, hash);
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    u = u.replaceFirst(RegExp(r'/web(/.*)?$', caseSensitive: false), '');
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  static String _authValue(String deviceId, String? token) =>
      'MediaBrowser Client="VesperTV", Device="VesperTV", '
      'DeviceId="$deviceId", Version="1.0"'
      '${token == null ? '' : ', Token="$token"'}';

  static Map<String, String> _headers(
      MediaServerKind kind, String deviceId, String? token) {
    final auth = _authValue(deviceId, token);
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (kind == MediaServerKind.jellyfin)
        'Authorization': auth
      else ...{
        'X-Emby-Authorization': auth,
        if (token != null) 'X-Emby-Token': token,
      },
    };
  }

  Future<Map<String, dynamic>> _json(http.Response r, Uri uri) async {
    if (r.statusCode == 401) throw MediaServerLoginException();
    if (r.statusCode != 200) {
      throw ArchiveApiException('HTTP ${r.statusCode} for $uri');
    }
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is! Map) throw ArchiveApiException('Not a JSON object: $uri');
    return Map<String, dynamic>.from(body);
  }

  Future<Map<String, dynamic>> _get(Uri uri,
          [Map<String, String>? headers]) async =>
      _json(await _client.get(uri, headers: headers).timeout(_timeout), uri);

  Future<Map<String, dynamic>> _getAuthed(
      ArchiveSource s, String pathAndQuery) {
    final login = s.server!;
    return _get(Uri.parse('${s.baseUrl}$pathAndQuery'),
        _headers(login.kind, login.deviceId, login.token));
  }

  /// Finds the server at [input]: the address as typed, then with `/emby`.
  /// Returns its API base, kind and display name.
  Future<({String apiBase, MediaServerKind kind, String name})> discover(
      String input) async {
    final root = normalizeUrl(input);
    final bases = [
      root,
      if (!root.toLowerCase().endsWith('/emby')) '$root/emby',
    ];
    for (final base in bases) {
      Map<String, dynamic> info;
      try {
        info = await _get(Uri.parse('$base/System/Info/Public'));
      } catch (_) {
        continue;
      }
      if (info['Id'] == null && info['Version'] == null) continue;
      final product = '${info['ProductName'] ?? ''}'.toLowerCase();
      final version = '${info['Version'] ?? ''}';
      final kind = product.contains('jellyfin') ||
              (product.isEmpty && version.startsWith('10.'))
          ? MediaServerKind.jellyfin
          : MediaServerKind.emby;
      final name = '${info['ServerName'] ?? ''}'.trim();
      return (
        apiBase: base,
        kind: kind,
        name: name.isEmpty ? Uri.parse(base).host : name,
      );
    }
    throw ArchiveApiException('No Jellyfin or Emby server at $root');
  }

  /// Signs in and returns the source: one catalog per movie / TV library
  /// the user can see. Throws [MediaServerLoginException] (bad user or
  /// password), [MediaServerNoLibraryException] or [ArchiveApiException]
  /// (no server there).
  Future<ArchiveSource> connect(
      String address, String userName, String password) async {
    final found = await discover(address);
    final deviceId = sha1
        .convert(utf8.encode('vespertv|${found.apiBase}|$userName'))
        .toString()
        .substring(0, 16);
    final uri = Uri.parse('${found.apiBase}/Users/AuthenticateByName');
    final auth = await _json(
        await _client
            .post(uri,
                headers: _headers(found.kind, deviceId, null),
                body: jsonEncode({'Username': userName, 'Pw': password}))
            .timeout(_timeout),
        uri);
    final user = auth['User'];
    final token = auth['AccessToken']?.toString();
    final userId = user is Map ? user['Id']?.toString() : null;
    if (token == null || userId == null) {
      throw ArchiveApiException('No access token from ${found.apiBase}');
    }
    final login = MediaServerLogin(
      kind: found.kind,
      userId: userId,
      token: token,
      deviceId: deviceId,
      userName: (user as Map)['Name']?.toString() ?? userName,
    );
    final draft = ArchiveSource(
      manifestUrl: '${found.apiBase}#$userId',
      name: found.name,
      server: login,
    );
    final catalogs = await libraries(draft);
    if (catalogs.isEmpty) throw MediaServerNoLibraryException();
    return ArchiveSource(
      manifestUrl: draft.manifestUrl,
      name: found.name,
      description: '${found.kind.label} · ${login.userName}',
      catalogs: catalogs,
      server: login,
    );
  }

  /// The user's movie and TV libraries as catalogs (library id = catalog
  /// id). Other kinds (music, photos, books…) are left out.
  Future<List<ArchiveCatalog>> libraries(ArchiveSource s) async {
    if (s.server!.kind == MediaServerKind.plex) return _plex.libraries(s);
    if (s.server!.kind == MediaServerKind.silo) return silo.libraries(s);
    final j = await _getAuthed(s, '/Users/${s.server!.userId}/Views');
    return [
      for (final v in (j['Items'] as List? ?? const []))
        if (v is Map && v['Id'] != null)
          if (_aioCatalog(v['Path']) case final aio)
            if (switch ('${v['CollectionType'] ?? ''}'.toLowerCase()) {
                      'movies' => ArchiveType.movie,
                      'tvshows' => ArchiveType.series,
                      _ => null,
                    } ??
                    aio?.type
                case final type?)
              ArchiveCatalog(
                type: type,
                id: '${v['Id']}',
                name: '${v['Name'] ?? ''}'.trim(),
                searchable: true,
                addonCatalogId: aio?.id,
                // A catalog its add-on lists only with a genre picked
                // (AIOMetadata's "not in home"): never a row, a tile can
                // still show it.
                homeHidden: v['aiostreams'] is Map &&
                    (v['aiostreams'] as Map)['genreRequired'] == true,
              ),
    ];
  }

  /// The add-on catalog an AIOStreams library serves, from its path
  /// `/aiostreams/{type}/{instance}.{catalog id}`; null for any other
  /// library.
  static ({ArchiveType? type, String id})? _aioCatalog(Object? path) {
    final m = RegExp(r'^/aiostreams/([^/]+)/[^/.]+\.([^/]+)$')
        .firstMatch('${path ?? ''}');
    if (m == null) return null;
    return (
      type: ArchiveType.fromWire(m[1]),
      id: m[2]!,
    );
  }

  /// One page of a library, newest first (a search: by name).
  Future<List<ArchiveMeta>> fetchCatalog(
    ArchiveSource s,
    ArchiveCatalog catalog, {
    int skip = 0,
    String? search,
  }) async {
    if (s.server!.kind == MediaServerKind.plex) {
      return _plex.catalog(s, catalog, skip: skip, search: search);
    }
    if (s.server!.kind == MediaServerKind.silo) {
      return silo.fetchCatalog(s, catalog,
          skip: skip, limit: catalogPageSize, search: search);
    }
    final q = {
      'ParentId': catalog.id,
      'Recursive': 'true',
      'IncludeItemTypes':
          catalog.type == ArchiveType.series ? 'Series' : 'Movie',
      'Fields': 'Overview,Genres,ProductionYear,ProviderIds,RemoteTrailers',
      'EnableImageTypes': 'Primary,Backdrop,Logo',
      'ImageTypeLimit': '1',
      'StartIndex': '$skip',
      'Limit': '$catalogPageSize',
      // A tile narrowed to a genre (Jellyfin's genre filter; AIOStreams
      // passes it to the add-on as the catalog's genre). A genre-only
      // catalog AIOStreams serves lists nothing without one: "None" is
      // AIOMetadata's no-genre option (checked on a real server).
      if (catalog.extra['genre'] ??
              (catalog.homeHidden && catalog.addonCatalogId != null
                  ? 'None'
                  : null)
          case final genre?)
        'Genres': genre,
      if (search != null) ...{
        'SearchTerm': search,
        'SortBy': 'SortName',
      } else if (catalog.addonCatalogId == null) ...{
        'SortBy': 'DateCreated,SortName',
        'SortOrder': 'Descending',
      },
      // An add-on catalog served by AIOStreams keeps the add-on's order
      // (Popular by popularity, Top 10 as ranked).
    };
    final j = await _getAuthed(
        s, '/Users/${s.server!.userId}/Items?${Uri(queryParameters: q).query}');
    return [
      for (final it in (j['Items'] as List? ?? const []))
        if (it is Map)
          if (_meta(s, Map<String, dynamic>.from(it)) case final m?) m,
    ];
  }

  /// The full item; a series also gets its episodes as `videos`.
  Future<ArchiveMeta?> fetchMeta(ArchiveSource s, ArchiveMeta preview) async {
    if (s.server!.kind == MediaServerKind.plex) return _plex.meta(s, preview);
    if (s.server!.kind == MediaServerKind.silo) {
      return silo.fetchMeta(s, preview);
    }
    final uid = s.server!.userId;
    final item = await _getAuthed(s, '/Users/$uid/Items/${preview.id}');
    final meta = _meta(s, item) ?? preview;
    if (meta.type != ArchiveType.series) return meta;
    final eps = await _getAuthed(
        s,
        '/Shows/${preview.id}/Episodes?${Uri(queryParameters: {
              'UserId': uid,
              'Fields': 'Overview,PremiereDate',
            }).query}');
    final videos = [
      for (final e in (eps['Items'] as List? ?? const []))
        if (e is Map && e['Id'] != null && e['LocationType'] != 'Virtual')
          ArchiveVideo(
            id: '${e['Id']}',
            title: '${e['Name'] ?? ''}'.trim(),
            season: (e['ParentIndexNumber'] as num?)?.toInt() ?? 0,
            episode: (e['IndexNumber'] as num?)?.toInt() ?? 0,
            thumbnailUrl: _image(s, e, 'Primary', 'maxWidth=480'),
            overview: _str(e['Overview']),
            released: _str(e['PremiereDate']),
          ),
    ]..sort((a, b) {
        final c = a.season.compareTo(b.season);
        return c != 0 ? c : a.episode.compareTo(b.episode);
      });
    return ArchiveMeta(
      id: meta.id,
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

  /// The versions of a movie or episode item, each the original file (no
  /// transcoding) with the token in the URL so both players can open it as
  /// is. PlaybackInfo lists them: a Jellyfin/Emby title with several files,
  /// or a configuration served by AIOStreams' Jellyfin API (one version per
  /// stream its add-ons found, up to 25, in the user's sort order). A
  /// server that can't answer it, or one version, plays the item's default
  /// file as before.
  Future<List<ArchiveStream>> streams(ArchiveSource s, String itemId) async {
    if (s.server!.kind == MediaServerKind.plex) return _plex.streams(s, itemId);
    if (s.server!.kind == MediaServerKind.silo) return silo.streams(s, itemId);
    final login = s.server!;
    final key = login.kind == MediaServerKind.jellyfin ? 'ApiKey' : 'api_key';
    String link([String? sourceId]) =>
        '${s.baseUrl}/Videos/${Uri.encodeComponent(itemId)}/stream'
        '?static=true'
        '${sourceId == null ? '' : '&MediaSourceId=${Uri.encodeComponent(sourceId)}'}'
        '&$key=${Uri.encodeComponent(login.token)}';
    final plain = [
      ArchiveStream(url: link(), name: s.name, title: login.kind.label),
    ];
    final List<Map> sources;
    try {
      sources = await _mediaSources(s, itemId);
    } catch (_) {
      return plain;
    }
    // AIOStreams adds its own block to each version: the add-on stream's
    // name and description, exactly as the add-on shows them.
    final aio = sources.any((m) => m['aiostreams'] is Map);
    // A notice ("No streams found", "Load versions") is not a file.
    final files = [
      for (final m in sources)
        if (m['Type'] != 'Placeholder') m
    ];
    if (files.isEmpty) return aio ? const [] : plain;
    if (!aio && files.length == 1) return plain;
    final versions = [
      for (final m in files)
        if (_version(s, m, link) case final v?) v
    ];
    return versions.isEmpty && !aio ? plain : versions;
  }

  /// AIOStreams runs the user's add-ons on this request, which can take a
  /// while.
  static const _versionsTimeout = Duration(seconds: 40);

  Future<List<Map>> _mediaSources(ArchiveSource s, String itemId) async {
    final login = s.server!;
    final uri = Uri.parse(
        '${s.baseUrl}/Items/${Uri.encodeComponent(itemId)}/PlaybackInfo'
        '?UserId=${Uri.encodeComponent(login.userId)}');
    final j = await _json(
        await _client
            .post(uri,
                headers: _headers(login.kind, login.deviceId, login.token),
                body: jsonEncode({
                  'UserId': login.userId,
                  'IsPlayback': false,
                  'AutoOpenLiveStream': false,
                }))
            .timeout(_versionsTimeout),
        uri);
    final list = j['MediaSources'];
    return list is List ? list.whereType<Map>().toList() : const [];
  }

  /// One version as a stream. An AIOStreams version plays its own link
  /// (followed once like any add-on link, `archive_playback._resolve`),
  /// named as the add-on names it; a server file plays through the server.
  ArchiveStream? _version(
      ArchiveSource s, Map m, String Function([String?]) link) {
    final id = _str(m['Id']);
    final aio = m['aiostreams'];
    if (aio is Map) {
      final path = _str(m['Path']);
      final uri = path == null ? null : Uri.tryParse(path);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        return null; // a YouTube trailer or nothing playable
      }
      return ArchiveStream(
        url: path!,
        name: _str(aio['name']) ?? _str(m['Name']) ?? s.name,
        title: _str(aio['description']),
        fileName: _str(aio['filename']),
        bingeGroup: _str(aio['bingeGroup']),
        sizeBytes: _bytes(aio['size']) ?? _bytes(m['Size']),
        requestHeaders: streamRequestHeaders(m['RequiredHttpHeaders']),
      );
    }
    if (id == null) return null;
    final container = _str(m['Container']);
    return ArchiveStream(
      url: link(id),
      name: s.name,
      title: [
        s.server!.kind.label,
        if (_str(m['Name']) case final name?) name,
        if (container != null) container.toUpperCase(),
      ].join(' · '),
      fileName: _str(m['Path'])?.split(RegExp(r'[/\\]')).last,
      sizeBytes: _bytes(m['Size']),
    );
  }

  static int? _bytes(Object? v) {
    final n = v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    return n == null || n <= 0 ? null : n;
  }

  static String? _str(Object? v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// An item's image URL, or null when it has none of that type. Images
  /// need no login on either server.
  static String? _image(ArchiveSource s, Map j, String type, String size) {
    final id = j['Id'];
    if (type == 'Backdrop') {
      final tags = j['BackdropImageTags'];
      if (tags is! List || tags.isEmpty) return null;
      return '${s.baseUrl}/Items/$id/Images/Backdrop/0?$size&tag=${tags.first}';
    }
    final tags = j['ImageTags'];
    final tag = tags is Map ? tags[type] : null;
    if (tag == null) return null;
    return '${s.baseUrl}/Items/$id/Images/$type?$size&tag=$tag';
  }

  ArchiveMeta? _meta(ArchiveSource s, Map<String, dynamic> j) {
    final id = _str(j['Id']);
    final name = _str(j['Name']);
    if (id == null || name == null) return null;
    final ticks = j['RunTimeTicks'];
    final rating = j['CommunityRating'];
    // Lets Trakt/Simkl scrobble server plays (WatchTracker).
    final providers = j['ProviderIds'];
    final imdb = providers is Map
        ? (providers['Imdb'] ?? providers['IMDB'])?.toString()
        : null;
    return ArchiveMeta(
      id: id,
      imdbId: imdb != null && imdb.startsWith('tt') ? imdb : null,
      trailers: TrailerLinks.fromMetadata(j),
      type: j['Type'] == 'Series' ? ArchiveType.series : ArchiveType.movie,
      name: name,
      posterUrl: _image(s, j, 'Primary', 'maxHeight=600'),
      backgroundUrl: _image(s, j, 'Backdrop', 'maxWidth=1280'),
      logoUrl: _image(s, j, 'Logo', 'maxWidth=600'),
      year: _str(j['ProductionYear']),
      description: _str(j['Overview']),
      genres: [
        for (final g in (j['Genres'] as List? ?? const []))
          if (_str(g) case final t?) t,
      ],
      runtime: ticks is num && ticks > 0
          ? '${(ticks / 600000000).round()} min'
          : null,
      rating: rating is num ? rating.toStringAsFixed(1) : null,
    );
  }

  void close() => _client.close();
}
