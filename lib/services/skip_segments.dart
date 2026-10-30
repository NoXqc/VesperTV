import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What a skip button jumps over.
enum SkipKind { intro, recap, outro }

class SkipSegment {
  const SkipSegment(this.kind, this.start, this.end);
  final SkipKind kind;
  final Duration start;
  final Duration end;

  bool contains(Duration position) => position >= start && position < end;

  @override
  bool operator ==(Object other) =>
      other is SkipSegment &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}

/// Intro / recap / credits times for TV episodes from IntroDB
/// (https://introdb.app): a free community database, no key, asked by the
/// show's IMDb id + season + episode. The same source Nuvio uses.
///
/// Only the IMDb id, season and episode are sent (never a stream link).
/// Answers are kept for the session; a failure or an episode nobody has
/// timed yet is simply no button. A provider show with only a TMDB id is
/// looked up through the viewer's own TMDB key (external_ids), like
/// trailers do.
class SkipSegments {
  SkipSegments({http.Client? client}) : _client = client ?? http.Client();

  static final instance = SkipSegments();

  final http.Client _client;
  static const _timeout = Duration(seconds: 8);
  static final _imdbPattern = RegExp(r'^tt\d+$');

  final Map<String, Future<List<SkipSegment>>> _cache = {};
  final Map<String, Future<String?>> _imdbOfTmdb = {};

  Future<List<SkipSegment>> forEpisode({
    String? imdb,
    String? tmdb,
    required int season,
    required int episode,
    String? tmdbKey,
  }) async {
    var id = imdb != null && _imdbPattern.hasMatch(imdb) ? imdb : null;
    final hasKey = (tmdbKey ?? '').trim().isNotEmpty;
    if (id == null && tmdb != null && hasKey) {
      id = await (_imdbOfTmdb[tmdb] ??= _showImdb(tmdb, tmdbKey!.trim()));
    }
    // Send log: why an episode has no button (ids, key, IntroDB answer).
    final tag = 'SkipIntro: S${season}E$episode imdb=${imdb ?? '-'} '
        'tmdb=${tmdb ?? '-'} key=${hasKey ? 'yes' : 'no'} -> ${id ?? 'no imdb'}';
    if (id == null || season < 0 || episode <= 0) {
      debugPrint(tag);
      return const [];
    }
    final segments =
        await (_cache['$id:$season:$episode'] ??= _fetch(id, season, episode));
    debugPrint('$tag segments=${segments.map((s) => s.kind.name).join(',')}');
    return segments;
  }

  Future<String?> _showImdb(String tmdb, String key) async {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(tmdb)) return null;
    try {
      final res = await _client
          .get(Uri.https('api.themoviedb.org', '/3/tv/$tmdb/external_ids',
              {'api_key': key}))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final id = (jsonDecode(res.body) as Map)['imdb_id'];
      return id is String && _imdbPattern.hasMatch(id) ? id : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<SkipSegment>> _fetch(String imdb, int season, int episode) async {
    try {
      final res = await _client
          .get(Uri.https('api.introdb.app', '/segments', {
            'imdb_id': imdb,
            'season': '$season',
            'episode': '$episode',
          }))
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return body is Map ? parse(body) : const [];
    } catch (_) {
      return const [];
    }
  }

  /// IntroDB's `{intro, recap, outro: {start_sec, end_sec | start_ms,
  /// end_ms}}`, sorted by start. Nonsense ranges (end before start, shorter
  /// than 3 s, longer than 10 min) are dropped.
  static List<SkipSegment> parse(Map body) {
    final out = <SkipSegment>[];
    for (final (key, kind) in const [
      ('intro', SkipKind.intro),
      ('recap', SkipKind.recap),
      ('outro', SkipKind.outro),
    ]) {
      final s = body[key];
      if (s is! Map) continue;
      final start = _ms(s['start_sec'], s['start_ms']);
      final end = _ms(s['end_sec'], s['end_ms']);
      if (start == null || end == null || start < 0) continue;
      final length = end - start;
      if (length < 3000 || length > 600000) continue;
      out.add(SkipSegment(
          kind, Duration(milliseconds: start), Duration(milliseconds: end)));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  static int? _ms(Object? seconds, Object? millis) {
    if (seconds is num && seconds.isFinite) return (seconds * 1000).round();
    if (millis is num && millis.isFinite) return millis.round();
    return null;
  }
}
