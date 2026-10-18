/// Data models for the Archive tab: public-domain film/series sources that
/// speak the Stremio add-on REST schema (`manifest.json`,
/// `/catalog/{type}/{id}.json`, `/meta/{type}/{id}.json`,
/// `/stream/{type}/{id}.json`). Any source following that schema works —
/// the app ships none hard-wired; the user adds the ones they like in
/// Settings > Archive sources (see `ArchiveService`).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The two content types the Archive tab browses. [wire] is the schema's
/// own `type` string.
enum ArchiveType {
  movie('movie'),
  series('series');

  const ArchiveType(this.wire);
  final String wire;

  static ArchiveType? fromWire(String? s) => switch (s) {
        'movie' => ArchiveType.movie,
        'series' => ArchiveType.series,
        _ => null,
      };
}

/// One catalog a source's manifest lists, e.g. `{type: movie, id: pd_noir,
/// name: Film Noir}`. Only catalogs that need no `extra` argument (search
/// or genre are optional or absent) are kept — those are the ones that can
/// be shown as a plain row.
class ArchiveCatalog {
  const ArchiveCatalog({
    required this.type,
    required this.id,
    required this.name,
    this.extra = const {},
    this.searchable = false,
  });

  final ArchiveType type;
  final String id;
  final String name;

  /// Fixed extra arguments sent with every page, e.g. `{genre: 2026}` for
  /// the provider's "New" row (its `year` catalog requires a year).
  final Map<String, String> extra;

  /// The catalog takes the schema's optional `search` extra.
  final bool searchable;

  /// [id] plus [extra]: unique per row, used for cache rows and row keys.
  String get slug => extra.isEmpty
      ? id
      : '$id?${[
          for (final e in extra.entries) '${e.key}=${e.value}'
        ].join('&')}';

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'id': id,
        'name': name,
        if (extra.isNotEmpty) 'fixedExtra': extra,
        if (searchable) 'searchable': true,
      };

  /// Reads both a manifest entry (`extra: [{name: search}, …]`) and the
  /// stored form ([toJson]).
  static ArchiveCatalog? fromJson(Map<String, dynamic> j) {
    final type = ArchiveType.fromWire(j['type']?.toString());
    final id = j['id']?.toString();
    if (type == null || id == null || id.isEmpty) return null;
    final fixed = j['fixedExtra'];
    return ArchiveCatalog(
      type: type,
      id: id,
      name: (j['name']?.toString() ?? '').trim(),
      extra: fixed is Map
          ? {for (final e in fixed.entries) '${e.key}': '${e.value}'}
          : const {},
      searchable: j['searchable'] == true ||
          (j['extra'] as List? ?? const [])
              .any((e) => e is Map && e['name'] == 'search') ||
          (j['extraSupported'] as List? ?? const []).contains('search'),
    );
  }
}

/// The public catalog provider that fills the grids for stream-only
/// sources: add-ons keyed on IMDB ids (`tt…`) that, as the add-on SDK
/// allows, ship no `/catalog/` or `/meta/` of their own. Posters, titles
/// and episode lists come from here; only `/stream/` goes to the source.
class ArchiveCatalogProvider {
  static const baseUrl = 'https://v3-cinemeta.strem.io';
  static const name = 'Cinemeta';

  /// The rows a stream-only source shows, for the [types] it streams:
  /// Popular (also the one searched), New (this year's titles — the
  /// provider's `year` catalog needs the year) and Featured (by rating).
  /// Names are translated where they're shown.
  static List<ArchiveCatalog> catalogsFor(Iterable<ArchiveType> types,
      {DateTime? now}) {
    final year = '${(now ?? DateTime.now()).year}';
    return [
      for (final t in ArchiveType.values)
        if (types.contains(t)) ...[
          ArchiveCatalog(type: t, id: 'top', name: 'Popular', searchable: true),
          ArchiveCatalog(
              type: t, id: 'year', name: 'New', extra: {'genre': year}),
          ArchiveCatalog(type: t, id: 'imdbRating', name: 'Featured'),
        ],
    ];
  }
}

/// A source the user added: its manifest plus whether it's switched on.
class ArchiveSource {
  const ArchiveSource({
    required this.manifestUrl,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.catalogs = const [],
    this.catalogProviderUrl,
    this.enabled = true,
  });

  final String manifestUrl;
  final String name;
  final String description;
  final String? logoUrl;
  final List<ArchiveCatalog> catalogs;

  /// Set for a stream-only source: where its [catalogs] and metas are
  /// fetched from ([ArchiveCatalogProvider.baseUrl]). Null when the source
  /// serves its own catalogs.
  final String? catalogProviderUrl;
  final bool enabled;

  bool get streamOnly => catalogProviderUrl != null;

  /// Where its resources live: the manifest URL minus `/manifest.json`.
  String get baseUrl {
    final u = manifestUrl.trim();
    return u.endsWith('/manifest.json')
        ? u.substring(0, u.length - '/manifest.json'.length)
        : u.replaceAll(RegExp(r'/+$'), '');
  }

  /// Where `/catalog/` and `/meta/` live: the provider for a stream-only
  /// source, else the source itself. `/stream/` always uses [baseUrl].
  String get catalogBaseUrl => catalogProviderUrl ?? baseUrl;

  /// Short stable key for cache rows and channel ids (the manifest URL can
  /// be long; ids only need to be unique per install).
  /// sha1, not `hashCode`: it's persisted (cache rows, resume positions).
  String get key =>
      sha1.convert(utf8.encode(manifestUrl)).toString().substring(0, 12);

  ArchiveSource copyWith({bool? enabled, List<ArchiveCatalog>? catalogs}) =>
      ArchiveSource(
        manifestUrl: manifestUrl,
        name: name,
        description: description,
        logoUrl: logoUrl,
        catalogs: catalogs ?? this.catalogs,
        catalogProviderUrl: catalogProviderUrl,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'url': manifestUrl,
        'name': name,
        'description': description,
        'logo': logoUrl,
        'catalogs': [for (final c in catalogs) c.toJson()],
        if (catalogProviderUrl != null) 'catalogProvider': catalogProviderUrl,
        'enabled': enabled,
      };

  factory ArchiveSource.fromJson(Map<String, dynamic> j) {
    final stored = [
      for (final c in (j['catalogs'] as List? ?? const []))
        if (c is Map)
          if (ArchiveCatalog.fromJson(Map<String, dynamic>.from(c))
              case final cat?)
            cat,
    ];
    final provider = j['catalogProvider'] as String?;
    return ArchiveSource(
      manifestUrl: j['url'] as String,
      name: (j['name'] as String?) ?? j['url'] as String,
      description: (j['description'] as String?) ?? '',
      logoUrl: j['logo'] as String?,
      // A stream-only source's rows are re-derived from its types, so new
      // provider rows (and next year's "New") reach sources added earlier.
      catalogs: provider == null
          ? stored
          : ArchiveCatalogProvider.catalogsFor(
              {for (final c in stored) c.type}),
      catalogProviderUrl: provider,
      enabled: j['enabled'] != false,
    );
  }
}

/// One title in a catalog (the schema's "meta preview"), or the full meta
/// when it came from `/meta/` (then [videos] is filled for a series).
class ArchiveMeta {
  const ArchiveMeta({
    required this.id,
    required this.type,
    required this.name,
    this.posterUrl,
    this.backgroundUrl,
    this.year,
    this.description,
    this.genres = const [],
    this.runtime,
    this.rating,
    this.cast = const [],
    this.director = const [],
    this.videos = const [],
  });

  final String id;
  final ArchiveType type;
  final String name;
  final String? posterUrl;
  final String? backgroundUrl;

  /// `releaseInfo` as sources send it: "1931", or "1959-1964" for a series.
  final String? year;
  final String? description;
  final List<String> genres;
  final String? runtime;

  /// `imdbRating` as sent ("8.9"); only on full metas from the provider.
  final String? rating;
  final List<String> cast;
  final List<String> director;

  /// Episodes, only on a series' full meta.
  final List<ArchiveVideo> videos;

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static List<String> _strs(Object? v) => [
        for (final x in (v is List ? v : const []))
          if (_str(x) case final s?) s,
      ];

  static ArchiveMeta? fromJson(Map<String, dynamic> j,
      {ArchiveType? fallbackType}) {
    final id = _str(j['id']);
    final name = _str(j['name']);
    final type = ArchiveType.fromWire(j['type']?.toString()) ?? fallbackType;
    if (id == null || name == null || type == null) return null;
    return ArchiveMeta(
      id: id,
      type: type,
      name: name,
      posterUrl: _str(j['poster']),
      backgroundUrl: _str(j['background']),
      year: _str(j['releaseInfo']) ?? _str(j['year']),
      description: _str(j['description']),
      genres: _strs(j['genres']),
      runtime: _str(j['runtime']),
      rating: _str(j['imdbRating']),
      cast: _strs(j['cast']),
      director: _strs(j['director']),
      videos: [
        for (final v in (j['videos'] as List? ?? const []))
          if (v is Map)
            if (ArchiveVideo.fromJson(Map<String, dynamic>.from(v))
                case final video?)
              video,
      ]..sort((a, b) {
          final s = a.season.compareTo(b.season);
          return s != 0 ? s : a.episode.compareTo(b.episode);
        }),
    );
  }

  /// What the cache stores: the preview fields only (no episode list).
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        'name': name,
        if (posterUrl != null) 'poster': posterUrl,
        if (backgroundUrl != null) 'background': backgroundUrl,
        if (year != null) 'releaseInfo': year,
        if (description != null) 'description': description,
        if (genres.isNotEmpty) 'genres': genres,
        if (runtime != null) 'runtime': runtime,
      };
}

/// One episode of a series meta. [id] is what `/stream/series/` takes —
/// usually `{seriesId}:{season}:{episode}`, but sources may use their own.
class ArchiveVideo {
  const ArchiveVideo({
    required this.id,
    required this.title,
    required this.season,
    required this.episode,
    this.thumbnailUrl,
    this.overview,
    this.released,
  });

  final String id;
  final String title;
  final int season;
  final int episode;
  final String? thumbnailUrl;
  final String? overview;

  /// Air date as sent (usually ISO 8601).
  final String? released;

  static ArchiveVideo? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    int toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final season = toInt(j['season']);
    final episode = toInt(j['episode'] ?? j['number']);
    return ArchiveVideo(
      id: id,
      title: (j['title'] ?? j['name'] ?? '').toString().trim(),
      season: season,
      episode: episode,
      thumbnailUrl: ArchiveMeta._str(j['thumbnail']),
      overview: ArchiveMeta._str(j['overview'] ?? j['description']),
      released: ArchiveMeta._str(j['released'] ?? j['firstAired']),
    );
  }
}

/// One playable stream from `/stream/`. Only direct http(s) URLs are kept —
/// torrent (`infoHash`), YouTube (`ytId`) and `externalUrl` entries are
/// dropped by [ArchiveApiService.fetchStreams]: the app plays files, it
/// doesn't fetch torrents.
class ArchiveStream {
  const ArchiveStream(
      {required this.url, this.name, this.title, this.subtitleUrl});

  final String url;

  /// The schema's `name`: usually the source plus quality ("My Source 4K").
  final String? name;

  /// The schema's `title` (or `description`): file, size, language… — may
  /// span several lines.
  final String? title;

  /// `name` + `title` on one line, e.g. "Internet Archive · 512Kb MPEG4".
  String? get label {
    final s = [name, title?.replaceAll(RegExp(r'\s*\n\s*'), ' ')]
        .whereType<String>()
        .join(' · ');
    return s.isEmpty ? null : s;
  }

  /// First subtitle the stream carries, if any (`subtitles[0].url`).
  final String? subtitleUrl;
}
