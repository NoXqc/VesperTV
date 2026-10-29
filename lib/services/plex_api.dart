import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/archive_models.dart';
import '../models/media_subtitle.dart';
import 'archive_api_service.dart';
import 'media_server_errors.dart';

class PlexPin {
  PlexPin(this.id, this.code, this.expiresAt);
  final String id, code;
  final DateTime expiresAt;
  Uri get verificationUrl => Uri.https('plex.tv', '/link', {'pin': code});
}

class PlexServer {
  const PlexServer(this.id, this.name, this.token, this.connections);
  final String id, name, token;
  final List<Uri> connections;
}

/// Plex's JSON API, kept behind the same Media Hub server routing as
/// Jellyfin/Emby. Account credentials never pass through VesperTV: the
/// viewer approves a short-lived code on plex.tv. Only the selected server's
/// access token is persisted. No transcoding or server-side library writes.
class PlexApi {
  PlexApi(this.client);
  final http.Client client;
  static const timeout = Duration(seconds: 12);
  static const pageSize = 100;

  static Map<String, String> headers(String deviceId, [String? token]) => {
        'Accept': 'application/json',
        'X-Plex-Product': 'VesperTV',
        'X-Plex-Version': '1.0',
        'X-Plex-Client-Identifier': deviceId,
        if (token != null) 'X-Plex-Token': token,
      };

  Object _decode(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw MediaServerLoginException();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      // Neither URLs nor server replies belong in errors (tokens may be in
      // either). The UI supplies the contextual, translated explanation.
      throw ArchiveApiException('Plex HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<Object> _get(Uri uri, String deviceId, [String? token]) async =>
      _decode(await client
          .get(uri, headers: headers(deviceId, token))
          .timeout(timeout));

  Future<PlexPin> createPin(String deviceId) async {
    final result = _decode(await client
        .post(Uri.https('plex.tv', '/api/v2/pins'), headers: headers(deviceId))
        .timeout(timeout)) as Map;
    final id = result['id']?.toString(), code = result['code']?.toString();
    if (id == null || code == null || code.isEmpty) {
      throw ArchiveApiException('Invalid Plex sign-in response');
    }
    final seconds = _number(result['expiresIn']) ?? 300;
    return PlexPin(id, code, DateTime.now().add(Duration(seconds: seconds)));
  }

  Future<String?> pollPin(String deviceId, PlexPin pin) async {
    final result =
        await _get(Uri.https('plex.tv', '/api/v2/pins/${pin.id}'), deviceId)
            as Map;
    return _text(result['authToken']);
  }

  Future<List<PlexServer>> servers(String deviceId, String accountToken) async {
    final result = await _get(
        Uri.https('plex.tv', '/api/v2/resources',
            {'includeHttps': '1', 'includeRelay': '1'}),
        deviceId,
        accountToken);
    if (result is! List) throw ArchiveApiException('Invalid Plex server list');
    final servers = <PlexServer>[];
    for (final server in result.whereType<Map>()) {
      if (!'${server['provides']}'.split(',').contains('server')) continue;
      final token = _text(server['accessToken']);
      final id = _text(server['clientIdentifier']);
      if (token == null || id == null) continue;
      final connections = _maps(server['connections']).toList()
        ..sort((a, b) => _connectionRank(a).compareTo(_connectionRank(b)));
      servers.add(PlexServer(id, _text(server['name']) ?? 'Plex', token, [
        for (final connection in connections)
          if (Uri.tryParse('${connection['uri']}') case final uri?)
            if (['http', 'https'].contains(uri.scheme) &&
                uri.host.isNotEmpty &&
                uri.userInfo.isEmpty)
              uri,
      ]));
    }
    return servers;
  }

  static bool _on(Object? value) => value == true || value == 1 || value == '1';
  static int _connectionRank(Map value) =>
      (_on(value['relay']) ? 10 : 0) +
      (_on(value['local']) ? 0 : 2) +
      ('${value['uri']}'.startsWith('https:') ? 0 : 1);

  Future<ArchiveSource> connect(PlexServer server, String deviceId) async {
    Object? lastError;
    for (final connection in server.connections) {
      final base = '${connection.scheme}://${connection.authority}'
          '${connection.path.replaceAll(RegExp(r'/+$'), '')}';
      final source = ArchiveSource(
          manifestUrl: '$base#${Uri.encodeComponent(server.id)}',
          name: server.name,
          description: 'Plex',
          server: MediaServerLogin(
              kind: MediaServerKind.plex,
              userId: server.id,
              token: server.token,
              deviceId: deviceId));
      try {
        final catalogs = await libraries(source);
        if (catalogs.isEmpty) throw MediaServerNoLibraryException();
        return source.copyWith(catalogs: catalogs);
      } on MediaServerNoLibraryException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError is MediaServerLoginException) throw lastError;
    throw ArchiveApiException('Plex server is unreachable');
  }

  Future<Map> _container(ArchiveSource source, String path,
      [Map<String, String> query = const {}]) async {
    final result = await _get(
        Uri.parse('${source.baseUrl}$path')
            .replace(queryParameters: query.isEmpty ? null : query),
        source.server!.deviceId,
        source.server!.token);
    if (result is! Map || result['MediaContainer'] is! Map) {
      throw ArchiveApiException('Invalid Plex library response');
    }
    return result['MediaContainer'] as Map;
  }

  Future<List<ArchiveCatalog>> libraries(ArchiveSource source) async {
    final result = await _container(source, '/library/sections');
    return [
      for (final library in _maps(result['Directory']))
        if (_text(library['key']) case final id?)
          if (library['type'] == 'movie' || library['type'] == 'show')
            ArchiveCatalog(
                type: library['type'] == 'show'
                    ? ArchiveType.series
                    : ArchiveType.movie,
                id: id,
                name: _text(library['title']) ?? 'Plex',
                searchable: true),
    ];
  }

  Future<List<ArchiveMeta>> catalog(
      ArchiveSource source, ArchiveCatalog catalog,
      {int skip = 0, String? search}) async {
    final result = await _container(
        source, '/library/sections/${Uri.encodeComponent(catalog.id)}/all', {
      'type': catalog.type == ArchiveType.series ? '2' : '1',
      'sort': search == null ? 'addedAt:desc' : 'titleSort:asc',
      'X-Plex-Container-Start': '$skip',
      'X-Plex-Container-Size': '$pageSize',
      'includeGuids': '1',
      if (search != null) 'title': search,
    });
    return [
      for (final item in _maps(result['Metadata']))
        if (_meta(source, item) case final meta?) meta
    ];
  }

  Future<ArchiveMeta?> meta(ArchiveSource source, ArchiveMeta preview) async {
    final result = await _container(
        source,
        '/library/metadata/${Uri.encodeComponent(preview.id)}',
        {'includeGuids': '1'});
    final item = _maps(result['Metadata']).firstOrNull;
    if (item == null) return null;
    final videos = <ArchiveVideo>[];
    if (item['type'] == 'show') {
      var skip = 0;
      while (true) {
        final episodes = await _container(source,
            '/library/metadata/${Uri.encodeComponent(preview.id)}/allLeaves', {
          'X-Plex-Container-Start': '$skip',
          'X-Plex-Container-Size': '$pageSize',
        });
        final page = _maps(episodes['Metadata']).toList();
        for (final episode in page) {
          final id = _text(episode['ratingKey']);
          if (id == null || episode['type'] != 'episode') continue;
          videos.add(ArchiveVideo(
              id: id,
              title: _text(episode['title']) ?? '',
              season: _number(episode['parentIndex']) ?? 0,
              episode: _number(episode['index']) ?? 0,
              thumbnailUrl: _asset(source, episode['thumb']),
              overview: _text(episode['summary']),
              released: _text(episode['originallyAvailableAt'])));
        }
        skip += page.length;
        final total = _number(episodes['totalSize']);
        if (page.isEmpty ||
            (total != null ? skip >= total : page.length < pageSize)) {
          break;
        }
      }
      videos.sort((a, b) => a.season != b.season
          ? a.season.compareTo(b.season)
          : a.episode.compareTo(b.episode));
    }
    return _meta(source, item, videos: videos);
  }

  Future<List<ArchiveStream>> streams(ArchiveSource source, String id) async {
    final result = await _container(
        source, '/library/metadata/${Uri.encodeComponent(id)}');
    return [
      for (final item in _maps(result['Metadata']))
        for (final media in _maps(item['Media']))
          // A multipart movie needs a queue rather than silently playing
          // just its first file. Only complete, directly playable versions.
          if (_maps(media['Part']).length == 1)
            for (final part in _maps(media['Part']))
              if (_asset(source, part['key']) case final url?)
                ArchiveStream(
                    url: url,
                    name: source.name,
                    title: [
                      'Plex',
                      media['videoResolution'],
                      media['videoCodec']
                    ].where((v) => v != null).join(' · '),
                    sizeBytes: _number(part['size']),
                    fileName: _text(part['file'])?.split(RegExp(r'[/\\]')).last,
                    subtitles: [
                      for (final stream in _maps(part['Stream']))
                        if (_number(stream['streamType']) == 3)
                          if (_asset(source, stream['key'])
                              case final subtitle?)
                            MediaSubtitle(
                                url: subtitle,
                                language:
                                    _text(stream['languageCode']) ?? 'und')
                    ]),
    ];
  }

  ArchiveMeta? _meta(ArchiveSource source, Map item,
      {List<ArchiveVideo> videos = const []}) {
    final id = _text(item['ratingKey']), name = _text(item['title']);
    if (id == null || name == null) return null;
    final guids = [
      _text(item['guid']),
      for (final guid in _maps(item['Guid'])) _text(guid['id'])
    ];
    final imdb = guids
        .whereType<String>()
        .map(
            (g) => RegExp(r'(?:imdb://|imdb\|)(tt\d+)').firstMatch(g)?.group(1))
        .whereType<String>()
        .firstOrNull;
    final duration = _number(item['duration']);
    return ArchiveMeta(
        id: id,
        name: name,
        imdbId: imdb,
        type: item['type'] == 'show' ? ArchiveType.series : ArchiveType.movie,
        posterUrl: _asset(source, item['thumb']),
        backgroundUrl: _asset(source, item['art']),
        year: _text(item['year']),
        description: _text(item['summary']),
        rating: _text(item['rating']),
        runtime: duration != null ? '${(duration / 60000).round()} min' : null,
        genres: [
          for (final tag in _maps(item['Genre']))
            if (_text(tag['tag']) case final value?) value
        ],
        cast: [
          for (final tag in _maps(item['Role']))
            if (_text(tag['tag']) case final value?) value
        ],
        director: [
          for (final tag in _maps(item['Director']))
            if (_text(tag['tag']) case final value?) value
        ],
        videos: videos);
  }

  /// Only server-relative keys can carry the server token. Never attach it
  /// to an absolute/cross-origin URL returned in metadata.
  static String? _asset(ArchiveSource source, Object? key) {
    final path = _text(key);
    if (path == null ||
        !path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('\\')) {
      return null;
    }
    final base = Uri.parse(source.baseUrl);
    final uri = Uri.parse('${source.baseUrl}$path');
    if (uri.origin != base.origin) return null;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'X-Plex-Token': source.server!.token,
    }).toString();
  }

  static Iterable<Map> _maps(Object? value) =>
      value is List ? value.whereType<Map>() : const [];
  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _number(Object? value) => num.tryParse('$value')?.toInt();
}
