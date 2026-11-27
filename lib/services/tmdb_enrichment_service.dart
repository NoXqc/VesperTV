import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/xtream_series.dart';
import 'archive_discovery_service.dart';
import 'catalog_database.dart';
import 'storage_service.dart';

/// One TMDB trending/popular result — see
/// [TmdbEnrichmentService.fetchTrendingMovies]/[fetchTrendingSeries].
typedef TmdbTrendingItem = ({
  String tmdbId,
  String title,
  String? originalTitle,
  DateTime? releaseDate,
  String? posterUrl,
  String? backdropUrl,
});

/// Fetches each title's real-world release date from TMDB (The Movie
/// Database) and caches it — see `Channel.releaseDate`'s doc comment for
/// why this exists as a separate lookup instead of just using the
/// provider's own `added`/`last_modified` field.
///
/// Deliberately narrow about when this runs at all: only ever called for
/// whatever category a user actually opens via "Expand catalog"
/// (`GroupCatalogScreen`), never proactively for a whole catalog or for a
/// hidden group — a hidden group is never opened in the first place, so it
/// never reaches this. A provider's VOD/series catalog can run to tens or
/// hundreds of thousands of items; enriching all of it eagerly would mean
/// that many individual TMDB requests, which is exactly the kind of
/// unbounded background cost this app has been bitten by before (see the
/// EPG hidden-groups fix this same session). Scoping to "only what's
/// actually being looked at right now" keeps this bounded to a single
/// category's worth of items (typically tens to a few hundred) no matter
/// how large the provider's full catalog is.
class TmdbEnrichmentService {
  TmdbEnrichmentService(this._storage, this._db,
      {http.Client? client, DateTime Function()? now})
      : _client = client ?? _sharedClient,
        _now = now ?? DateTime.now;

  final StorageService _storage;
  final CatalogDatabase _db;
  final http.Client _client;
  final DateTime Function() _now;

  static const _base = 'https://api.themoviedb.org/3';

  /// TMDB's own image CDN — `w500` is a good balance for a TV poster grid
  /// (noticeably sharper than most providers' own art without pulling full
  /// originals). See `Channel.posterUrl`'s doc comment: this rides along in
  /// the exact same response the title lookup ([_lookup]) already reads for
  /// [Channel.releaseDate]/[XtreamSeries.releaseDate], at no extra request.
  static const _imageBase = 'https://image.tmdb.org/t/p/w500';

  /// Backdrops are landscape key-art, shown much larger (a full-bleed hero
  /// banner) than a poster-grid thumbnail ever is — `w1280` instead of
  /// `w500` so it doesn't visibly upscale/blur at that size. See
  /// `Channel.backdropUrl`'s doc comment for why this exists as a
  /// separate field from [_imageBase]'s poster at all.
  static const _backdropImageBase = 'https://image.tmdb.org/t/p/w1280';

  /// Lookups in flight at once, as a pool: each worker takes the next title
  /// as soon as it's done (5 per batch with a pause after each waited for
  /// every batch's slowest answer). TMDB allows about 40 requests a second
  /// per address; 8 at ~150-300 ms each stays under it, and a 429 pauses
  /// every worker ([_getJson]).
  static const _concurrency = 8;

  /// A title TMDB had nothing (or only part) for is asked again after this.
  static const recheckAfter = Duration(days: 30);

  /// One client for every lookup: its connections stay open between them
  /// (`http.get` made a new connection and TLS handshake per request).
  static final _sharedClient = http.Client();

  /// True when a title still needs TMDB: no date or no poster yet, and not
  /// asked in the last [recheckAfter] (owner, 2026-11-26: the TMDB sort
  /// looked the same titles up at every Expand catalog open).
  @visibleForTesting
  static bool needsLookup(DateTime? releaseDate, String? posterUrl,
          int? checkedMs, DateTime now) =>
      (releaseDate == null || posterUrl == null) &&
      (checkedMs == null ||
          now.millisecondsSinceEpoch - checkedMs > recheckAfter.inMilliseconds);

  /// Fills in [Channel.releaseDate] / [Channel.posterUrl] /
  /// [Channel.backdropUrl] for the [items] that still need it
  /// ([needsLookup]) and saves the answer with when it was asked
  /// ([Channel.tmdbCheckedMs]), found or not, so the next open skips them;
  /// a content update keeps all of it (`CatalogDatabase`). Only a title
  /// TMDB didn't answer for (network, key, rate limit) is asked again next
  /// time. [onProgress] fires after every title (hit or miss), so a caller
  /// can show real "X of Y" progress.
  Future<void> enrichVod(List<Channel> items,
      {void Function(int done, int total)? onProgress}) async {
    final key = _storage.getTmdbApiKey();
    final now = _now();
    final pending = items
        .where((c) =>
            needsLookup(c.releaseDate, c.posterUrl, c.tmdbCheckedMs, now))
        .toList();
    if (key == null || key.isEmpty || pending.isEmpty) {
      onProgress?.call(0, 0);
      return;
    }
    await _enrich(pending, 'movies', items.length, onProgress, (c) async {
      final art = await _lookup(c.name, c.tmdbId, key, isMovie: true);
      final at = _now().millisecondsSinceEpoch;
      if (art?.releaseDate case final d?) c.releaseDate = d;
      if (art?.posterUrl case final p?) c.posterUrl = p;
      if (art?.backdropUrl case final b?) c.backdropUrl = b;
      c.tmdbCheckedMs = at;
      unawaited(_db
          .setVodTmdb(c.id,
              releaseDate: art?.releaseDate,
              posterUrl: art?.posterUrl,
              backdropUrl: art?.backdropUrl,
              checkedMs: at)
          .catchError((Object _) {}));
      return art != null;
    });
  }

  /// Same as [enrichVod] for series (`/tv/{id}`, `first_air_date`).
  Future<void> enrichSeries(List<XtreamSeries> items,
      {void Function(int done, int total)? onProgress}) async {
    final key = _storage.getTmdbApiKey();
    final now = _now();
    final pending = items
        .where((s) =>
            needsLookup(s.releaseDate, s.posterUrl, s.tmdbCheckedMs, now))
        .toList();
    if (key == null || key.isEmpty || pending.isEmpty) {
      onProgress?.call(0, 0);
      return;
    }
    await _enrich(pending, 'shows', items.length, onProgress, (s) async {
      final art = await _lookup(s.name, s.tmdbId, key, isMovie: false);
      final at = _now().millisecondsSinceEpoch;
      if (art?.releaseDate case final d?) s.releaseDate = d;
      if (art?.posterUrl case final p?) s.posterUrl = p;
      if (art?.backdropUrl case final b?) s.backdropUrl = b;
      s.tmdbCheckedMs = at;
      unawaited(_db
          .setSeriesTmdb(s.id,
              releaseDate: art?.releaseDate,
              posterUrl: art?.posterUrl,
              backdropUrl: art?.backdropUrl,
              checkedMs: at)
          .catchError((Object _) {}));
      return art != null;
    });
  }

  /// Runs [one] over [pending] with [_concurrency] workers; [one] is true
  /// when TMDB had the title and throws when TMDB didn't answer. One Send
  /// log line at the end.
  Future<void> _enrich<T>(
      List<T> pending,
      String what,
      int shown,
      void Function(int done, int total)? onProgress,
      Future<bool> Function(T item) one) async {
    final watch = Stopwatch()..start();
    var next = 0, done = 0, found = 0, missing = 0, failed = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final item = pending[next++];
        try {
          (await one(item)) ? found++ : missing++;
        } catch (_) {
          // A dead key, the network, a rate limit that didn't pass: asked
          // again next time. Never an error on a poster grid.
          failed++;
        } finally {
          done++;
          onProgress?.call(done, pending.length);
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(_concurrency, pending.length); i++) worker()
    ]);
    debugPrint('TmdbEnrich: $what ${pending.length} of $shown looked up in '
        '${watch.elapsedMilliseconds} ms (found $found, not on TMDB $missing, '
        'no answer $failed)');
  }

  /// TMDB's date, poster and backdrop for a title: by the provider's TMDB id
  /// (one request), else a title search, whose top result already carries
  /// them (one request; the details used to be asked as well). Null = TMDB
  /// has no such title. Throws when TMDB didn't answer. A searched id is
  /// never stamped into [Channel.tmdbId]: that stays the provider's own,
  /// which Trakt / Simkl and Skip intro trust (a top search result can be
  /// another film of the same name).
  Future<({DateTime? releaseDate, String? posterUrl, String? backdropUrl})?>
      _lookup(String rawTitle, String? providerId, String apiKey,
          {required bool isMovie}) async {
    final id = providerId?.trim();
    if (id != null && id.isNotEmpty && id != '0') {
      final data = await _getJson(
          '${isMovie ? 'movie' : 'tv'}/${Uri.encodeComponent(id)}',
          {'api_key': apiKey});
      if (data != null) return _artOf(data, isMovie: isMovie);
      // 404: the provider's id isn't one of TMDB's (or another kind): search.
    }
    final cleaned = _cleanTitleForSearch(rawTitle);
    if (cleaned.title.isEmpty) return null;
    final data = await _getJson(isMovie ? 'search/movie' : 'search/tv', {
      'api_key': apiKey,
      'query': cleaned.title,
      if (cleaned.year != null)
        (isMovie ? 'year' : 'first_air_date_year'): cleaned.year.toString(),
    });
    final results = data?['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      return null;
    }
    return _artOf(results.first as Map, isMovie: isMovie);
  }

  static ({DateTime? releaseDate, String? posterUrl, String? backdropUrl})
      _artOf(Map data, {required bool isMovie}) {
    final rawDate =
        '${(isMovie ? data['release_date'] : data['first_air_date']) ?? ''}';
    final posterPath = data['poster_path'];
    final backdropPath = data['backdrop_path'];
    return (
      releaseDate: rawDate.isNotEmpty ? DateTime.tryParse(rawDate) : null,
      posterUrl: posterPath is String && posterPath.isNotEmpty
          ? '$_imageBase$posterPath'
          : null,
      backdropUrl: backdropPath is String && backdropPath.isNotEmpty
          ? '$_backdropImageBase$backdropPath'
          : null,
    );
  }

  /// When a 429 asked every lookup to wait (real time).
  static DateTime? _pausedUntil;

  /// [path]'s JSON, or null on a 404. A 429 pauses every lookup
  /// (Retry-After, else 2 s, at most 10) and tries again, twice at most.
  /// Anything else throws.
  Future<Map<String, dynamic>?> _getJson(
      String path, Map<String, String> query) async {
    final uri = Uri.parse('$_base/$path').replace(queryParameters: query);
    for (var attempt = 0;; attempt++) {
      final wait = _pausedUntil?.difference(DateTime.now());
      if (wait != null && wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      switch (response.statusCode) {
        case 200:
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) return data;
          throw const FormatException('TMDB answered something else');
        case 404:
          return null;
        case 429 when attempt < 2:
          final seconds =
              int.tryParse(response.headers['retry-after'] ?? '') ?? 2;
          _pausedUntil =
              DateTime.now().add(Duration(seconds: seconds.clamp(1, 10)));
        default:
          throw Exception('TMDB HTTP ${response.statusCode}');
      }
    }
  }

  /// A leading provider tag ("FR - ", "4K-EN-HDR - " — one or more dash/
  /// underscore-joined alphanumeric segments followed by " - "), a
  /// trailing year in parentheses (captured separately as a search hint,
  /// not left in the query text), and any number of trailing bracketed
  /// tags ("[MULTI-SUB]", "[VF]"). Best-effort, not exhaustive — provider
  /// naming varies, but TMDB's own search ranking tolerates an imperfect
  /// query far better than it tolerates searching for the raw decorated
  /// string wholesale.
  static final RegExp _leadingProviderTag =
      RegExp(r'^[A-Za-z0-9]+(?:[-_][A-Za-z0-9]+)*\s*-\s*');
  static final RegExp _trailingBracketTag = RegExp(r'\s*\[[^\]]*\]\s*$');
  static final RegExp _trailingYear = RegExp(r'\s*\((\d{4})\)\s*$');

  ({String title, int? year}) _cleanTitleForSearch(String raw) {
    var title = raw;
    while (true) {
      final stripped = title.replaceFirst(_trailingBracketTag, '');
      if (stripped == title) break;
      title = stripped;
    }
    int? year;
    final yearMatch = _trailingYear.firstMatch(title);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1)!);
      title = title.replaceFirst(_trailingYear, '');
    }
    title = title.replaceFirst(_leadingProviderTag, '');
    return (title: title.trim(), year: year);
  }

  /// TMDB's own "what's actually popular right now" list — a completely
  /// different signal from everything else in this file, which only ever
  /// enriches titles the *provider's own catalog* already decided to
  /// surface (by category, or by its own `added`/`last_modified` field).
  /// Built for `PlaylistManager.refreshWhatsNewTmdbIfDue`'s curated
  /// "What's New" rebuild: reported directly, with a screenshot, that
  /// sorting by provider-reported recency surfaced obscure/mislabeled
  /// titles and literal sports-event listings nobody recognized, while a
  /// competing app's "New"/trending view (also TMDB-backed) read as
  /// entirely familiar titles. `/trending/movie/week` over `/popular` —
  /// weekly trending tracks what's *actually* being watched/talked about
  /// right now; `/popular` skews toward whatever's broadly well-known
  /// forever (old franchise entries keep outranking anything new).
  /// [page] is 1-indexed, 20 results each, matching TMDB's own paging.
  Future<List<TmdbTrendingItem>> fetchTrendingMovies(String apiKey,
          {int page = 1}) =>
      _fetchTrending('movie', apiKey, page: page);

  Future<List<TmdbTrendingItem>> fetchTrendingSeries(String apiKey,
          {int page = 1}) =>
      _fetchTrending('tv', apiKey, page: page);

  Future<List<TmdbTrendingItem>> _fetchTrending(String mediaType, String apiKey,
      {required int page}) async {
    try {
      final uri = Uri.parse('$_base/trending/$mediaType/week')
          .replace(queryParameters: {'api_key': apiKey, 'page': '$page'});
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final id = item['id']?.toString();
            final title = (mediaType == 'movie' ? item['title'] : item['name'])
                ?.toString();
            final original = (mediaType == 'movie'
                    ? item['original_title']
                    : item['original_name'])
                ?.toString();
            final rawDate = (mediaType == 'movie'
                    ? item['release_date']
                    : item['first_air_date'])
                ?.toString();
            final posterPath = item['poster_path'] as String?;
            final backdropPath = item['backdrop_path'] as String?;
            return (
              tmdbId: id ?? '',
              title: title ?? '',
              originalTitle: original,
              releaseDate: (rawDate != null && rawDate.isNotEmpty)
                  ? DateTime.tryParse(rawDate)
                  : null,
              posterUrl: (posterPath != null && posterPath.isNotEmpty)
                  ? '$_imageBase$posterPath'
                  : null,
              backdropUrl: (backdropPath != null && backdropPath.isNotEmpty)
                  ? '$_backdropImageBase$backdropPath'
                  : null,
            );
          })
          .where((item) => item.tmdbId.isNotEmpty && item.title.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Strips the same provider decorations [_cleanTitleForSearch] does,
  /// for the *other* direction: matching a clean TMDB title against the
  /// catalog's own decorated provider titles (`PlaylistManager`'s
  /// trending-match pass). Exposed publicly since that matching happens
  /// one layer up, against `CatalogDatabase` directly, not through this
  /// service.
  String cleanTitleForMatching(String raw) => _cleanTitleForSearch(raw).title;

  /// TMDB's own title, original title and year for [tmdbId] (one request),
  /// or null. `PlaylistManager` uses it to check what an earlier What's New
  /// pass stamped onto a catalog title.
  Future<({String title, String? originalTitle, int? year})?> fetchTitle(
      String tmdbId, String apiKey,
      {required bool isMovie}) async {
    try {
      final path = isMovie ? 'movie' : 'tv';
      final uri = Uri.parse('$_base/$path/$tmdbId?api_key=$apiKey');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final title = (isMovie ? data['title'] : data['name'])?.toString() ?? '';
      if (title.isEmpty) return null;
      final date =
          (isMovie ? data['release_date'] : data['first_air_date'])?.toString();
      return (
        title: title,
        originalTitle:
            (isMovie ? data['original_title'] : data['original_name'])
                ?.toString(),
        year: DateTime.tryParse(date ?? '')?.year,
      );
    } catch (_) {
      return null;
    }
  }

  /// A year the provider wrote in the name: "Hexed (1993)", "[2025]" or a
  /// trailing "- 1988".
  static final RegExp _yearInName =
      RegExp(r'[(\[]((?:19|20)\d{2})[)\]]|\s[-–]\s*((?:19|20)\d{2})\s*$');
  static final RegExp _trailingDashYear =
      RegExp(r'\s[-–]\s*(?:19|20)\d{2}\s*$');

  static int? yearInName(String name) {
    final m = _yearInName.firstMatch(name);
    if (m == null) return null;
    return int.parse(m.group(1) ?? m.group(2)!);
  }

  /// [ArchiveDiscoveryService.titleKey], also without a trailing "- 1988".
  static String titleKey(String name) => ArchiveDiscoveryService.titleKey(
      name.replaceFirst(_trailingDashYear, ''));

  /// Whether the catalog title [name] is the TMDB title [tmdbTitle] /
  /// [originalTitle]: the same cleaned title, years at most one apart when
  /// both are known, and no different TMDB id on the catalog side.
  ///
  /// What's New used to take the first catalog search hit for each word of
  /// a trending title (cillfog, 2026-11-26: "The Odyssey" (2026) landed on
  /// "The Navigator: A Medieval Odyssey - 1988", "Steps" on "The Fantastic
  /// 4: First Steps", "Hexed" (2026) on "Hexed (1993)") and stamped its
  /// poster, date and id there. So the catalog's year comes from its name
  /// first, and an id equal to [tmdbId] proves nothing on its own: it may
  /// be such a stamp.
  static bool sameTitle({
    required String tmdbId,
    required String tmdbTitle,
    String? originalTitle,
    int? tmdbYear,
    required String name,
    String? otherTmdb,
    DateTime? otherDate,
  }) {
    final other = otherTmdb?.trim() ?? '';
    if (other.isNotEmpty && other != tmdbId) return false;
    final key = titleKey(name);
    if (key.isEmpty) return false;
    final keys = {
      titleKey(tmdbTitle),
      if (originalTitle != null) titleKey(originalTitle),
    }..remove('');
    if (!keys.contains(key)) return false;
    final year = yearInName(name) ?? otherDate?.year;
    return tmdbYear == null || year == null || (tmdbYear - year).abs() <= 1;
  }
}
