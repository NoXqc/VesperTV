import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trailer.dart';
import '../utils/display_title.dart';

class TrailerRequest {
  const TrailerRequest(
      {required this.title,
      required this.series,
      this.year,
      this.imdbId,
      this.tmdbId,
      this.supplied = const [],
      this.language = 'en',
      this.tmdbKey = ''});
  final String title;
  final bool series;
  final int? year;
  final String? imdbId;
  final String? tmdbId;
  final List<String> supplied;
  final String language;
  final String tmdbKey;
  String get cacheKey => jsonEncode([
        title,
        series,
        year,
        imdbId,
        tmdbId,
        supplied,
        language,
        tmdbKey.hashCode
      ]);
}

/// Detail-page discovery only. Bounded cache, negative expiry, and one lookup
/// per identity in flight. Never accepts provider/server credentials or URLs.
class TrailerService {
  TrailerService({http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;
  static final instance = TrailerService();
  final http.Client _client;
  final DateTime Function() _now;
  final _cache = <String, ({DateTime until, Uri? url})>{};
  final _pending = <String, Future<Uri?>>{};
  Future<Uri?> resolve(TrailerRequest request) {
    final key = request.cacheKey;
    final cached = _cache[key];
    if (cached != null && cached.until.isAfter(_now())) {
      return Future.value(cached.url);
    }
    return _pending.putIfAbsent(
        key,
        () => _resolve(request)
                .timeout(const Duration(seconds: 15), onTimeout: () => null)
                .catchError((_) => null)
                .then((url) {
              if (_cache.length >= 128) _cache.remove(_cache.keys.first);
              _cache[key] = (
                until: _now().add(Duration(minutes: url == null ? 10 : 360)),
                url: url
              );
              return url;
            }).whenComplete(() {
              _pending.remove(key);
            }));
  }

  Future<Map> _get(Uri uri) async {
    final response = await _client.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return {};
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data is Map ? data : {};
  }

  Uri _youtube(String id) => Uri.https('www.youtube.com', '/watch', {'v': id});
  Future<Uri?> _resolve(TrailerRequest r) async {
    for (final raw in r.supplied) {
      if (TrailerLinks.videoId(raw) case final id?) return _youtube(id);
    }
    final type = r.series ? 'series' : 'movie';
    final tmdbType = r.series ? 'tv' : 'movie';
    if (r.tmdbKey.trim().isNotEmpty) {
      try {
        var tmdb = r.tmdbId;
        if (tmdb == null && r.imdbId != null) {
          final found = await _get(Uri.https(
              'api.themoviedb.org',
              '/3/find/${r.imdbId}',
              {'api_key': r.tmdbKey, 'external_source': 'imdb_id'}));
          final matches =
              found[r.series ? 'tv_results' : 'movie_results'] as List? ?? [];
          if (matches.length == 1) {
            tmdb = (matches.single as Map)['id']?.toString();
          }
        }
        if (tmdb != null && RegExp(r'^\d+$').hasMatch(tmdb)) {
          final data = await _get(
              Uri.https('api.themoviedb.org', '/3/$tmdbType/$tmdb/videos', {
            'api_key': r.tmdbKey,
            'language': r.language,
            'include_video_language': '${r.language},en,null'
          }));
          final videos = (data['results'] as List? ?? [])
              .whereType<Map>()
              .where((v) =>
                  v['site'] == 'YouTube' &&
                  ['Trailer', 'Teaser'].contains(v['type']) &&
                  TrailerLinks.videoId(v['key']) != null)
              .toList();
          int rank(Map v) =>
              (v['type'] == 'Trailer' ? 100 : 0) +
              (v['official'] == true ? 40 : 0) +
              (v['iso_639_1'] == r.language
                  ? 20
                  : v['iso_639_1'] == 'en'
                      ? 10
                      : 0);
          videos.sort((a, b) => rank(b).compareTo(rank(a)));
          if (videos.isNotEmpty) {
            return _youtube(TrailerLinks.videoId(videos.first['key'])!);
          }
        }
      } catch (_) {/* Missing/invalid key or metadata never blocks Play. */}
    }
    var imdb = r.imdbId;
    if (imdb == null) {
      final year = r.year ??
          int.tryParse(
              RegExp(r'(19|20)\d{2}').firstMatch(r.title)?.group(0) ?? '');
      final title = cleanDisplayTitle(r.title);
      if (title.trim().isEmpty) return null;
      final data = await _get(Uri.parse(
          'https://v3-cinemeta.strem.io/catalog/$type/top/search=${Uri.encodeComponent(title)}.json'));
      final matches = (data['metas'] as List? ?? [])
          .whereType<Map>()
          .where((m) =>
              m['type'] == type &&
              normalizeTitle(m['name']?.toString() ?? '') ==
                  normalizeTitle(title) &&
              (year == null ||
                  RegExp(r'(19|20)\d{2}')
                          .firstMatch(m['releaseInfo']?.toString() ?? '')
                          ?.group(0) ==
                      '$year'))
          .toList();
      if (matches.length != 1) return null;
      imdb = matches.single['id']?.toString();
    }
    if (imdb == null || !RegExp(r'^tt\d+$').hasMatch(imdb)) return null;
    final meta = (await _get(
        Uri.https('v3-cinemeta.strem.io', '/meta/$type/$imdb.json')))['meta'];
    if (meta is! Map ||
        meta['id'] != imdb ||
        (meta['type'] != null && meta['type'] != type)) {
      return null;
    }
    final ids = TrailerLinks.fromMetadata(meta);
    return ids.isEmpty ? null : _youtube(ids.first);
  }

  static String normalizeTitle(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
