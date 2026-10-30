import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/archive_models.dart';
import '../utils/display_title.dart';

class ArchivePerson {
  const ArchivePerson(
      {required this.id, required this.name, this.image, this.role});
  final int id;
  final String name;
  final String? image;
  final String? role;
}

class ArchiveDiscovery {
  const ArchiveDiscovery(
      {this.collectionName,
      this.collection = const [],
      this.related = const [],
      this.cast = const []});
  final String? collectionName;
  final List<ArchiveMeta> collection;
  final List<ArchiveMeta> related;
  final List<ArchivePerson> cast;
}

/// On-demand metadata only, using the viewer's existing TMDB key. Never searches
/// a whole provider library or opens streams while browsing recommendations.
class ArchiveDiscoveryService {
  ArchiveDiscoveryService({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, Map<String, dynamic>> _cache = {};
  void dispose() => _client.close();

  Future<Map<String, dynamic>> _get(String path, String key, String language,
      [Map<String, String> extra = const {}]) async {
    final cacheKey = '$key|$language|$path|$extra';
    if (_cache[cacheKey] case final value?) return value;
    final response = await _client
        .get(Uri.https('api.themoviedb.org', '/3/$path',
            {'api_key': key, 'language': language, ...extra}))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw StateError('Metadata unavailable');
    final data = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    if (_cache.length >= 16) _cache.remove(_cache.keys.first);
    _cache[cacheKey] = data;
    return data;
  }

  static String? _image(Object? path, {bool backdrop = false}) =>
      path is String && path.startsWith('/')
          ? 'https://image.tmdb.org/t/p/${backdrop ? 'w780' : 'w342'}$path'
          : null;

  static ArchiveMeta? _title(Map row, {ArchiveType? type}) {
    if (row['adult'] == true || row['id'] is! num) return null;
    final kind = type ??
        (row['media_type'] == 'movie'
            ? ArchiveType.movie
            : row['media_type'] == 'tv'
                ? ArchiveType.series
                : null);
    if (kind == null) return null;
    final name = row['title'] ?? row['name'];
    if (name is! String || name.isEmpty) return null;
    final date = '${row['release_date'] ?? row['first_air_date'] ?? ''}';
    return ArchiveMeta(
        id: 'tmdb:${(row['id'] as num).toInt()}',
        type: kind,
        name: name,
        imdbId: row['imdb_id'] is String ? row['imdb_id'] : null,
        posterUrl: _image(row['poster_path']),
        backgroundUrl: _image(row['backdrop_path'], backdrop: true),
        year: date.length >= 4 ? date.substring(0, 4) : null,
        description: row['overview'] as String?);
  }

  static List<ArchiveMeta> _titles(Object? list, {ArchiveType? type}) {
    final seen = <String>{};
    return [
      for (final row in list is List ? list : const [])
        if (row is Map)
          if (_title(row, type: type) case final meta?)
            if (seen.add('${meta.type.wire}:${meta.id}')) meta
    ].take(20).toList();
  }

  static String titleKey(String name) => cleanDisplayTitle(name)
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  static List<ArchivePerson> _cast(Object? credits) => <ArchivePerson>[
        for (final person in credits is Map && credits['cast'] is List
            ? credits['cast']
            : const [])
          if (person is Map && person['id'] is num && person['name'] is String)
            ArchivePerson(
                id: (person['id'] as num).toInt(),
                name: person['name'],
                image: _image(person['profile_path']),
                role:
                    person['character'] is String ? person['character'] : null),
      ].take(12).toList();

  /// IPTV details: just this title's cast, never collections/recommendations.
  /// Without a provider TMDB id, require one exact title/year search result.
  Future<List<ArchivePerson>> castForTitle(
      ArchiveMeta meta, String key, String language) async {
    if (key.trim().isEmpty || meta.wireType != null) return const [];
    final type = meta.type == ArchiveType.movie ? 'movie' : 'tv';
    final id = await tmdbIdFor(meta, key, language);
    if (id == null) return const [];
    return _cast(await _get('$type/$id/credits', key, language));
  }

  /// [meta]'s TMDB id: its own `tmdb:` id, else the single exact title/year
  /// search result (null when none or several match). Also how a provider
  /// show without ids gets Skip intro (series page).
  Future<String?> tmdbIdFor(
      ArchiveMeta meta, String key, String language) async {
    if (key.trim().isEmpty || meta.wireType != null) return null;
    final type = meta.type == ArchiveType.movie ? 'movie' : 'tv';
    var id = RegExp(r'^tmdb:([1-9]\d*)$').firstMatch(meta.id)?.group(1);
    if (id == null) {
      final year = meta.year ??
          RegExp(r'\(((?:19|20)\d{2})\)').firstMatch(meta.name)?.group(1) ??
          RegExp(r'\s((?:19|20)\d{2})$')
              .firstMatch(cleanDisplayTitle(meta.name))
              ?.group(1);
      var title = cleanDisplayTitle(meta.name);
      if (year != null) {
        title = title.replaceFirst(RegExp('\\s+$year\$'), '').trim();
      }
      if (title.isEmpty) return null;
      final found = await _get('search/$type', key, language, {
        'query': title,
        'include_adult': 'false',
        if (year != null)
          type == 'movie' ? 'year' : 'first_air_date_year': year,
      });
      final results =
          (found['results'] is List ? found['results'] as List : const [])
              .whereType<Map>()
              .where((row) {
        final date = row[type == 'movie' ? 'release_date' : 'first_air_date'];
        return row['adult'] != true &&
            row['id'] is num &&
            (row['id'] as num).toInt() > 0 &&
            [
              row['title'],
              row['original_title'],
              row['name'],
              row['original_name']
            ]
                .whereType<String>()
                .any((name) => titleKey(name) == titleKey(title)) &&
            (year == null || date is String && date.startsWith('$year-'));
      }).toList();
      final ids = results.map((row) => (row['id'] as num).toInt()).toSet();
      if (ids.length != 1) return null;
      id = '${ids.single}';
    }
    return id;
  }

  Future<ArchiveDiscovery> discover(
      ArchiveMeta meta, String key, String language) async {
    if (key.trim().isEmpty || meta.wireType != null) {
      return const ArchiveDiscovery();
    }
    final type = meta.type == ArchiveType.movie ? 'movie' : 'tv';
    String? id = RegExp(r'^tmdb:(\d+)$').firstMatch(meta.id)?.group(1);
    if (id == null && meta.imdb != null) {
      final found = await _get(
          'find/${meta.imdb}', key, language, {'external_source': 'imdb_id'});
      final matches = found[type == 'movie' ? 'movie_results' : 'tv_results'];
      if (matches is List && matches.isNotEmpty && matches.first is Map) {
        id = '${matches.first['id']}';
      }
    }
    if (id == null || !RegExp(r'^\d+$').hasMatch(id)) {
      return const ArchiveDiscovery();
    }
    final details = await _get('$type/$id', key, language,
        {'append_to_response': 'credits,recommendations,similar,external_ids'});
    final credits = details['credits'];
    final cast = _cast(credits);
    List<ArchiveMeta> list(String name) =>
        _titles(details[name] is Map ? details[name]['results'] : null,
            type: meta.type);
    final related = list('recommendations');
    var collection = <ArchiveMeta>[];
    String? collectionName;
    final group = details['belongs_to_collection'];
    if (group is Map && group['id'] is num) {
      // Optional enrichment cannot discard already-usable cast/recommendations.
      try {
        final result = await _get('collection/${group['id']}', key, language);
        collectionName = result['name'] as String?;
        collection = _titles(result['parts'], type: ArchiveType.movie)
          ..sort((a, b) => (a.year ?? '').compareTo(b.year ?? ''));
      } catch (_) {/* Keep the other sections. */}
    }
    bool different(ArchiveMeta item) => item.id != 'tmdb:$id';
    return ArchiveDiscovery(
        collectionName: collectionName,
        collection: collection.where(different).toList(),
        related: (related.isEmpty ? list('similar') : related)
            .where(different)
            .toList(),
        cast: cast);
  }

  Future<List<ArchiveMeta>> credits(
      ArchivePerson person, String key, String language) async {
    final data =
        await _get('person/${person.id}/combined_credits', key, language);
    return _titles(data['cast']);
  }

  /// Resolve only the selected recommendation, avoiding one request per card.
  Future<ArchiveMeta> identify(
      ArchiveMeta item, String key, String language) async {
    if (item.imdb != null || !item.id.startsWith('tmdb:')) return item;
    final type = item.type == ArchiveType.movie ? 'movie' : 'tv';
    final data =
        await _get('$type/${item.id.substring(5)}/external_ids', key, language);
    final imdb = data['imdb_id'];
    if (imdb is! String || !RegExp(r'^tt\d+$').hasMatch(imdb)) return item;
    return ArchiveMeta.fromJson(
        {...item.toJson(), 'id': imdb, 'imdb_id': imdb})!;
  }
}
