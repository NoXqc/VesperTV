/// Media Hub collections (owner, 2026-11-11, from a Nuvio setup): a row of
/// tiles on the Media Hub tab ("Streaming": Netflix, Prime Video…), each
/// tile a folder of add-on catalogs that opens its own page. The format is
/// Nuvio's collections export, so community packs import as they are:
///
/// ```json
/// [{"id": "…", "title": "🎬 Streaming", "folders": [
///   {"id": "…", "title": "Netflix", "tileShape": "LANDSCAPE",
///    "coverImageUrl": "…webp", "focusGifUrl": "…webp",
///    "titleLogoUrl": "…", "heroBackdropUrl": "…",
///    "catalogSources": [{"addonId": "aio-metadata",
///      "catalogId": "tmdb.discover.movie.streaming.netflix",
///      "type": "movie", "genre": "None"}]}]}]
/// ```
///
/// Older exports name the list `sources` and add `provider: "addon"`. The
/// catalogs themselves come from the user's own add-ons (AIOMetadata):
/// a tile whose catalogs aren't installed is left out.
library;

/// The tile's shape on the Media Hub tab.
enum HubTileShape {
  /// 16:9, as wide as a focused wide card.
  landscape,

  /// A poster's 2:3.
  poster,

  /// 1:1.
  square;

  static HubTileShape parse(Object? v) => switch (v?.toString().toUpperCase()) {
        'POSTER' || 'PORTRAIT' => poster,
        'SQUARE' => square,
        _ => landscape,
      };

  String get wire => name.toUpperCase();
}

/// One catalog a folder shows: [catalogId] of the add-on whose manifest
/// id is [addonId], of [type] (`movie`, `series`…), narrowed to [genre]
/// when set.
class HubCollectionSource {
  const HubCollectionSource({
    required this.addonId,
    required this.catalogId,
    required this.type,
    this.genre,
  });

  final String addonId;
  final String catalogId;
  final String type;
  final String? genre;

  static HubCollectionSource? fromJson(Object? j) {
    if (j is! Map) return null;
    // Only add-on catalogs: Nuvio's other providers have no add-on here.
    final provider = j['provider']?.toString();
    if (provider != null && provider != 'addon') return null;
    final catalogId = j['catalogId']?.toString().trim() ?? '';
    // Some exports write the plural ("movies": antonangel/nuvio-template);
    // add-ons name their catalogs' types movie / series.
    final type = switch (j['type']?.toString().trim() ?? '') {
      'movies' => 'movie',
      'shows' || 'tv shows' => 'series',
      final t => t,
    };
    if (catalogId.isEmpty || type.isEmpty) return null;
    final genre = j['genre']?.toString().trim();
    return HubCollectionSource(
      addonId: j['addonId']?.toString().trim() ?? '',
      catalogId: catalogId,
      type: type,
      genre: genre == null || genre.isEmpty || genre == 'None' ? null : genre,
    );
  }

  Map<String, dynamic> toJson() => {
        'addonId': addonId,
        'catalogId': catalogId,
        'type': type,
        if (genre != null) 'genre': genre,
      };
}

/// One tile: its pictures and the catalogs its page lists.
class HubFolder {
  const HubFolder({
    required this.id,
    required this.title,
    required this.sources,
    this.shape = HubTileShape.landscape,
    this.hideTitle = false,
    this.coverUrl,
    this.focusUrl,
    this.logoUrl,
    this.backdropUrl,
    this.emoji,
  });

  final String id;
  final String title;
  final List<HubCollectionSource> sources;
  final HubTileShape shape;

  /// The picture already shows the name (a logo cover): no label under it.
  final bool hideTitle;

  /// The still picture.
  final String? coverUrl;

  /// The animated picture (Nuvio's "focus GIF", an animated WebP) shown
  /// while the tile is focused.
  final String? focusUrl;

  /// The folder page's title logo and backdrop.
  final String? logoUrl;
  final String? backdropUrl;

  /// Shown when there is no picture.
  final String? emoji;

  static String? _url(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.startsWith('http://') || s.startsWith('https://') ? s : null;
  }

  static HubFolder? fromJson(Object? j) {
    if (j is! Map) return null;
    final title = j['title']?.toString().trim() ?? '';
    final sources = [
      for (final s in (j['catalogSources'] ?? j['sources']) is List
          ? (j['catalogSources'] ?? j['sources']) as List
          : const [])
        if (HubCollectionSource.fromJson(s) case final source?) source,
    ];
    if (title.isEmpty || sources.isEmpty) return null;
    return HubFolder(
      id: j['id']?.toString() ?? title,
      title: title,
      sources: sources,
      shape: HubTileShape.parse(j['tileShape']),
      hideTitle: j['hideTitle'] == true,
      coverUrl: _url(j['coverImageUrl']),
      // A focus picture switched off in Nuvio stays still here too.
      focusUrl: j['focusGifEnabled'] == false ? null : _url(j['focusGifUrl']),
      logoUrl: _url(j['titleLogoUrl']),
      backdropUrl: _url(j['heroBackdropUrl']),
      emoji: (j['coverEmoji']?.toString().trim().isNotEmpty ?? false)
          ? j['coverEmoji'].toString().trim()
          : null,
    );
  }

  HubFolder copyWith({String? title, List<HubCollectionSource>? sources}) =>
      HubFolder(
        id: id,
        title: title ?? this.title,
        sources: sources ?? this.sources,
        shape: shape,
        hideTitle: hideTitle,
        coverUrl: coverUrl,
        focusUrl: focusUrl,
        logoUrl: logoUrl,
        backdropUrl: backdropUrl,
        emoji: emoji,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tileShape': shape.wire,
        'hideTitle': hideTitle,
        if (coverUrl != null) 'coverImageUrl': coverUrl,
        if (focusUrl != null) 'focusGifUrl': focusUrl,
        'focusGifEnabled': focusUrl != null,
        if (logoUrl != null) 'titleLogoUrl': logoUrl,
        if (backdropUrl != null) 'heroBackdropUrl': backdropUrl,
        if (emoji != null) 'coverEmoji': emoji,
        'catalogSources': [for (final s in sources) s.toJson()],
      };
}

/// One row of tiles on the Media Hub tab.
class HubCollection {
  const HubCollection({
    required this.id,
    required this.title,
    required this.folders,
    this.enabled = true,
    this.onHome = false,
    this.link,
  });

  final String id;

  /// As written in the file, emoji included ("🎬 Streaming").
  final String title;
  final List<HubFolder> folders;

  /// Shown on the Media Hub tab (Settings > Media Hub sources > Collections).
  final bool enabled;

  /// Its tiles also show on Home (owner, 2026-11-11: "if a user chose so").
  final bool onHome;

  /// Where it was imported from (Update reads it again).
  final String? link;

  /// [title] without its leading emoji: the row header ("Streaming").
  String get label {
    final clean =
        title.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
    return clean.isEmpty ? title : clean;
  }

  HubCollection copyWith(
          {bool? enabled, bool? onHome, List<HubFolder>? folders}) =>
      HubCollection(
        id: id,
        title: title,
        folders: folders ?? this.folders,
        enabled: enabled ?? this.enabled,
        onHome: onHome ?? this.onHome,
        link: link,
      );

  static HubCollection? fromJson(Object? j, {String? link}) {
    if (j is! Map) return null;
    final title = j['title']?.toString().trim() ?? '';
    final folders = [
      for (final f in j['folders'] is List ? j['folders'] as List : const [])
        if (HubFolder.fromJson(f) case final folder?) folder,
    ];
    if (title.isEmpty || folders.isEmpty) return null;
    return HubCollection(
      id: j['id']?.toString() ?? title,
      title: title,
      folders: folders,
      enabled: j['enabled'] != false,
      onHome: j['home'] == true,
      link: j['link']?.toString() ?? link,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'enabled': enabled,
        if (onHome) 'home': true,
        if (link != null) 'link': link,
        'folders': [for (final f in folders) f.toJson()],
      };

  /// Every collection in a Nuvio export: a list of collections, an object
  /// with `collections`, or one collection. Empty when it isn't one.
  static List<HubCollection> parseExport(Object? json, {String? link}) {
    final list = json is List
        ? json
        : json is Map && json['collections'] is List
            ? json['collections'] as List
            : json is Map && json['folders'] is List
                ? [json]
                : const [];
    return [
      for (final c in list)
        if (HubCollection.fromJson(c, link: link) case final collection?)
          collection,
    ];
  }

  /// A link to a `.json` that isn't an add-on manifest: maybe a
  /// collections file (the Add field and the phone page try it as one).
  static bool isFileLink(String text) {
    final t = text.trim();
    return RegExp(r'^https?://\S+\.json(\?\S*)?$').hasMatch(t) &&
        !t.contains('manifest.json');
  }

  /// A GitHub page link to a file, as its raw file (people copy the page).
  static String rawLink(String link) {
    final m = RegExp(r'^https?://github\.com/([^/]+)/([^/]+)/blob/(.+)$')
        .firstMatch(link.trim());
    return m == null
        ? link.trim()
        : 'https://raw.githubusercontent.com/${m[1]}/${m[2]}/${m[3]}';
  }
}
