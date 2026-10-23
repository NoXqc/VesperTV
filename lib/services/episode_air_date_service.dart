import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/episode_airing.dart';
import '../models/series_details.dart';

/// Uses supplied episode dates first, then existing metadata services by exact
/// identity only. Never receives a playlist URL, provider login or watch state.
class EpisodeAirDateService {
  EpisodeAirDateService({http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  static final instance = EpisodeAirDateService();
  final http.Client _client;
  final DateTime Function() _now;
  final _cache = <String, ({DateTime until, List<EpisodeAiring> entries})>{};
  final _pending = <String, Future<List<EpisodeAiring>>>{};

  Future<EpisodeAiring?> resolve({
    SeriesDetails? details,
    String? imdbId,
    String? tmdbId,
    String tmdbKey = '',
  }) async {
    final supplied = [
      for (final e in details?.episodes.values ?? <EpisodeDetails>[])
        if (EpisodeAiring.parse(e.airDate,
                season: e.season, episode: e.episodeNumber)
            case final date?)
          date,
    ];
    final local = EpisodeAiring.next(supplied, _now());
    if (local != null) return local;
    final imdb = RegExp(r'^tt\d+$').hasMatch(imdbId ?? '') ? imdbId : null;
    final tmdb = RegExp(r'^[1-9]\d*$').hasMatch(tmdbId ?? '') &&
            tmdbKey.trim().isNotEmpty
        ? tmdbId
        : null;
    if (imdb == null && tmdb == null) return null;
    final key = jsonEncode([imdb, tmdb, tmdbKey.hashCode]);
    final cached = _cache[key];
    if (cached != null && cached.until.isAfter(_now())) {
      return EpisodeAiring.next(cached.entries, _now());
    }
    final entries = await _pending.putIfAbsent(
        key,
        () => _fetch(imdb, tmdb, tmdbKey).then((entries) {
              if (_cache.length >= 128) _cache.remove(_cache.keys.first);
              _cache[key] = (
                until:
                    _now().add(Duration(minutes: entries.isEmpty ? 10 : 360)),
                entries: entries
              );
              return entries;
            }).whenComplete(() {
              _pending.remove(key);
            }));
    return EpisodeAiring.next(entries, _now());
  }

  Future<Map> _get(Uri uri) async {
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return {};
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data is Map ? data : {};
    } catch (_) {
      return {}; // Metadata failures must never interrupt the show or Play.
    }
  }

  Future<List<EpisodeAiring>> _fetch(
      String? imdb, String? tmdb, String key) async {
    if (tmdb != null) {
      final data = await _get(
          Uri.https('api.themoviedb.org', '/3/tv/$tmdb', {'api_key': key}));
      final next = data['next_episode_to_air'];
      if (data['id']?.toString() == tmdb && next is Map) {
        final date = EpisodeAiring.parse(next['air_date']?.toString(),
            season: _number(next['season_number']),
            episode: _number(next['episode_number']));
        if (date != null && date.upcoming(_now())) return [date];
      }
    }
    if (imdb == null) return [];
    final meta = (await _get(
        Uri.https('v3-cinemeta.strem.io', '/meta/series/$imdb.json')))['meta'];
    if (meta is! Map ||
        meta['id'] != imdb ||
        (meta['type'] != null && meta['type'] != 'series')) {
      return [];
    }
    final videos = meta['videos'];
    if (videos is! List) return [];
    return [
      for (final video in videos.whereType<Map>())
        if (EpisodeAiring.parse(video['released']?.toString(),
                season: _number(video['season']),
                episode: _number(video['episode']))
            case final date?)
          date,
    ];
  }

  static int? _number(Object? value) => int.tryParse(value?.toString() ?? '');
}
