import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trailer.dart';
import '../models/archive_models.dart';
import 'archive_api_service.dart';
import '../utils/display_title.dart';

class TrailerRequest {
  const TrailerRequest(
      {required this.title,
      required this.series,
      this.year,
      this.imdbId,
      this.tmdbId,
      this.supplied = const [],
      this.suppliedStreams = const [],
      this.language = 'en',
      this.tmdbKey = ''});
  final String title;
  final bool series;
  final int? year;
  final String? imdbId;
  final String? tmdbId;
  final List<String> supplied;
  final List<ArchiveStream> suppliedStreams;
  final String language;
  final String tmdbKey;
  String get cacheKey => jsonEncode([
        title,
        series,
        year,
        imdbId,
        tmdbId,
        supplied,
        [for (final stream in suppliedStreams) stream.identity],
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
  final _capabilities = <String, ({DateTime until, ArchiveSource source})>{};
  Future<Uri?> resolve(TrailerRequest request,
      {List<ArchiveSource> addons = const []}) {
    final key = jsonEncode([
      request.cacheKey,
      for (final s in addons.where((s) => s.enabled)) [s.key, s.imdbResources]
    ]);
    final cached = _cache[key];
    if (cached != null && cached.until.isAfter(_now())) {
      return Future.value(cached.url);
    }
    return _pending.putIfAbsent(
        key,
        () => _resolve(request, addons)
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
  Future<Uri?> _resolve(TrailerRequest r, List<ArchiveSource> addons) async {
    for (final raw in r.supplied) {
      if (TrailerLinks.videoId(raw) case final id?) return _youtube(id);
    }
    for (final stream in r.suppliedStreams) {
      final uri = stream.playbackUri;
      if (uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty) {
        return uri;
      }
    }
    final type = r.series ? 'series' : 'movie';
    final timer = Stopwatch()..start();
    final sources = <ArchiveSource>[];
    for (var source in addons) {
      if (!source.enabled || source.server != null || source.tracker != null) {
        continue;
      }
      // Older saved sources predate resource declarations. Re-read only their
      // own manifest in memory; never rewrite user settings or assume IMDb support.
      if (source.imdbResources.isEmpty && !source.streamOnly) {
        final cached = _capabilities[source.key];
        if (cached != null && cached.until.isAfter(_now())) {
          source = cached.source;
        } else {
          if (timer.elapsed.inSeconds >= 12) continue;
          try {
            final fresh = await ArchiveApiService(client: _client)
                .fetchManifest(source.manifestUrl)
                .timeout(const Duration(seconds: 5));
            if (_capabilities.length >= 128) {
              _capabilities.remove(_capabilities.keys.first);
            }
            _capabilities[source.key] =
                (until: _now().add(const Duration(hours: 6)), source: fresh);
            source = fresh;
          } catch (_) {
            continue;
          }
        }
      }
      if (source.supportsImdb('meta', type) ||
          source.supportsImdb('stream', type)) {
        sources.add(source);
      }
    }
    final imdb = await _imdb(r);
    if (imdb == null) return null;
    for (final source in sources) {
      for (final resource in ['meta', 'stream']) {
        if (!source.supportsImdb(resource, type) ||
            timer.elapsed.inSeconds >= 12) {
          continue;
        }
        try {
          final base = source.baseUrl.replaceAll(RegExp(r'/+$'), '');
          final data =
              await _get(Uri.parse('$base/$resource/$type/$imdb.json'));
          List<ArchiveStream> candidates;
          if (resource == 'meta') {
            final meta = data['meta'];
            if (meta is! Map ||
                meta['id'] != imdb ||
                (meta['type'] != null && meta['type'] != type)) {
              continue;
            }
            candidates = [
              for (final id in TrailerLinks.fromMetadata(meta))
                ArchiveStream(ytId: id),
              ...ArchiveStream.trailersFromMetadata(meta)
            ];
          } else {
            // A stream add-on answers with the title itself (TorBox,
            // Torrentio…): only YouTube entries or links labelled as a
            // trailer count, never "the first playable stream".
            candidates = [
              if (data['streams'] is List)
                for (final row in data['streams'])
                  if (row is Map)
                    if (ArchiveStream.fromJson(row) case final stream?)
                      if (stream.ytId != null || _labelledTrailer(row)) stream
            ];
          }
          if (candidates.isNotEmpty) return candidates.first.playbackUri;
        } catch (_) {/* A failing add-on does not block the next source. */}
      }
    }
    // Cinemeta's meta carries the trailers Stremio itself shows
    // (trailerStreams / trailers with YouTube ids) — no add-on needed.
    try {
      final data = await _get(
          Uri.parse('https://v3-cinemeta.strem.io/meta/$type/$imdb.json'));
      final meta = data['meta'];
      if (meta is Map && meta['id'] == imdb) {
        for (final id in TrailerLinks.fromMetadata(meta)) {
          return _youtube(id);
        }
      }
    } catch (_) {/* No trailer rather than a wrong one. */}
    return null;
  }

  static bool _labelledTrailer(Map row) => [row['name'], row['title']]
      .any((v) => v is String && v.toLowerCase().contains('trailer'));

  Future<String?> _imdb(TrailerRequest r) async {
    final type = r.series ? 'series' : 'movie';
    var imdb = r.imdbId;
    if (imdb != null && RegExp(r'^tt\d+$').hasMatch(imdb)) return imdb;
    if (r.tmdbKey.trim().isNotEmpty &&
        RegExp(r'^[1-9]\d*$').hasMatch(r.tmdbId ?? '')) {
      try {
        final data = await _get(Uri.https(
            'api.themoviedb.org',
            '/3/${r.series ? 'tv' : 'movie'}/${r.tmdbId}/external_ids',
            {'api_key': r.tmdbKey}));
        final id = data['imdb_id'];
        if (id is String && RegExp(r'^tt\d+$').hasMatch(id)) return id;
      } catch (_) {/* Strict catalog identity can still resolve the title. */}
    }
    imdb = null;
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
    return imdb != null && RegExp(r'^tt\d+$').hasMatch(imdb) ? imdb : null;
  }

  static String normalizeTitle(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
