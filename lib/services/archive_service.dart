import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/archive_models.dart';
import '../models/channel.dart';
import '../utils/title_search.dart';
import 'archive_api_service.dart';
import 'archive_cache.dart';
import 'media_server_api.dart';
import 'storage_service.dart';
import 'tracker_api.dart';

/// One row of the Archive browse: a source's catalog and its titles, or
/// (with [searchQuery]) that catalog's results for a search.
class ArchiveRow {
  const ArchiveRow({
    required this.source,
    required this.catalog,
    required this.items,
    this.searchQuery,
    this.itemSources,
    this.isFavorites = false,
  });

  final ArchiveSource source;
  final ArchiveCatalog catalog;
  final List<ArchiveMeta> items;
  final String? searchQuery;

  /// Set on the watched-history and Favourites rows, whose titles come
  /// from several sources: the source of each item (else every item is
  /// [source]'s).
  final List<ArchiveSource>? itemSources;

  /// The Favourites row (also carries [itemSources]).
  final bool isFavorites;

  ArchiveSource sourceAt(int i) => itemSources?[i] ?? source;

  bool get isSearch => searchQuery != null;
  bool get isHistory => itemSources != null && !isFavorites;

  String get key => isFavorites
      ? 'favorites|${catalog.type.wire}'
      : isHistory
          ? 'history|${catalog.type.wire}'
          : isSearch
              ? 'search|${ArchiveService._rowKey(source, catalog)}'
              : ArchiveService._rowKey(source, catalog);

  /// The row header: the catalog's own name, or the source name when the
  /// catalog has none. Provider row names ("Popular") and search rows are
  /// translated by the screen.
  String get title => catalog.name.isEmpty ? source.name : catalog.name;
}

/// One stream offered for a title, with the source that offered it.
class ArchiveStreamOption {
  const ArchiveStreamOption({required this.source, required this.stream});

  final ArchiveSource source;
  final ArchiveStream stream;
}

/// The Archive tab's state: the user's sources (Settings > Archive
/// sources), their catalog rows (cache first, then network), and turning
/// a picked title into a [Channel] the existing player can play.
///
/// Sources are any server that follows the Stremio add-on REST schema
/// (see [ArchiveApiService]) — the app ships none, so nothing is
/// contacted until the user adds one. Only direct http(s) streams are
/// used; torrent/debrid entries are ignored on purpose.
class ArchiveService extends ChangeNotifier {
  ArchiveService(this._storage,
      {ArchiveApiService? api,
      ArchiveCache? cache,
      MediaServerApi? servers,
      TrackerApi? trackers})
      : _api = api ?? ArchiveApiService(diagnostics: debugPrint),
        _cache = cache ?? ArchiveCache(),
        _servers = servers ?? MediaServerApi(),
        _trackers = trackers ?? TrackerApi();

  final StorageService _storage;
  final ArchiveApiService _api;
  final ArchiveCache _cache;
  bool get autoPlayLargest => _storage.getArchiveAutoLargest();
  Future<void> setAutoPlayLargest(bool value) async {
    await _storage.setArchiveAutoLargest(value);
    _notify();
  }

  /// Jellyfin/Emby sources ([ArchiveSource.server]) go here instead of
  /// [_api]; everything else (rows, cache, search, history, Play) is the
  /// same for both kinds of source.
  final MediaServerApi _servers;

  /// Trakt/Simkl accounts ([ArchiveSource.tracker]): their lists are rows.
  final TrackerApi _trackers;

  Future<List<ArchiveMeta>> _page(ArchiveSource s, ArchiveCatalog c,
      {int skip = 0, String? search}) async {
    final watch = Stopwatch()..start();
    final kind = s.tracker != null
        ? 'tracker'
        : s.server != null
            ? 'server'
            : 'addon';
    try {
      final List<ArchiveMeta> items;
      if (s.tracker != null) {
        if (search != null) return const [];
        final login = await _freshTracker(s);
        items = await _trackers.fetchCatalog(login, c, skip: skip);
      } else {
        items = s.server != null
            ? await _servers.fetchCatalog(s, c, skip: skip, search: search)
            : await _api.fetchCatalog(s.catalogBaseUrl, c,
                skip: skip, search: search);
      }
      final art = items.where((m) => m.posterUrl?.isNotEmpty ?? false).length;
      debugPrint('ArchiveRow: source=${s.key} kind=$kind type=${c.wire} '
          'items=${items.length} posters=$art missing=${items.length - art} '
          'fetchMs=${watch.elapsedMilliseconds}');
      return items;
    } catch (error) {
      debugPrint(
          'ArchiveRow: source=${s.key} kind=$kind failed=${error.runtimeType} '
          'fetchMs=${watch.elapsedMilliseconds}');
      rethrow;
    }
  }

  // ---- Trakt / Simkl -------------------------------------------------------

  /// [s]'s login, refreshed (and saved) first when it's about to expire.
  Future<TrackerLogin> _freshTracker(ArchiveSource s) async {
    final login = s.tracker!;
    if (!login.needsRefresh) return login;
    final fresh = await _trackers.refresh(login);
    await _saveSources([
      for (final x in sources)
        x.manifestUrl == s.manifestUrl ? x.copyWith(tracker: fresh) : x,
    ]);
    return fresh;
  }

  /// The connected tracker account of [kind], if any.
  ArchiveSource? trackerSource(TrackerKind kind) =>
      sources.where((s) => s.tracker?.kind == kind).firstOrNull;

  /// Every enabled account's login, fresh — what `WatchTracker` reports to.
  Future<List<TrackerLogin>> trackerLogins() async {
    final out = <TrackerLogin>[];
    for (final s in enabledSources) {
      if (s.tracker == null) continue;
      try {
        out.add(await _freshTracker(s));
      } catch (e) {
        debugPrint('ArchiveService: ${s.name} token refresh failed: $e');
      }
    }
    return out;
  }

  /// Adds (or replaces: one account per tracker) a signed-in account.
  Future<ArchiveSource> addTracker(TrackerLogin login) async {
    final source = ArchiveSource(
      manifestUrl: '${login.kind.name}://account',
      name: login.kind.label,
      description: login.userName,
      catalogs: TrackerApi.catalogsFor(login.kind),
      tracker: login,
    );
    await _saveSources([
      for (final s in sources)
        if (s.tracker?.kind != login.kind) s,
      source,
    ]);
    unawaited(refresh(force: true));
    return source;
  }

  /// Every Archive [Channel] uses this playlist id; `PlaybackService.play`
  /// lets it through (no playlist profile backs it).
  static const playlistId = 'archive';

  /// A cached catalog younger than this isn't refetched on open.
  static const _staleAfter = Duration(hours: 12);

  /// Pages fetched per catalog (sources usually send 100 per page).
  static const _pagesPerCatalog = 2;

  final Map<String, List<ArchiveMeta>> _items = {};
  bool _loadedFromCache = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _forceRefreshAgain = false;
  String? lastError;

  bool get refreshing => _refreshing;

  // ---- sources ------------------------------------------------------------

  List<ArchiveSource> get sources {
    final raw = _storage.getArchiveSourcesJson();
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          if (ArchiveSource.fromJson(Map<String, dynamic>.from(j as Map))
              case final s)
            // A tracker's rows are always the current set (accounts added
            // before "Continue watching" existed get it too).
            s.tracker == null
                ? s
                : s.copyWith(catalogs: TrackerApi.catalogsFor(s.tracker!.kind)),
      ];
    } catch (_) {
      return const [];
    }
  }

  List<ArchiveSource> get enabledSources =>
      sources.where((s) => s.enabled).toList();

  bool get showCinemetaCatalog => _storage.getArchiveCinemetaCatalog();

  Future<void> setShowCinemetaCatalog(bool on) async {
    await _storage.setArchiveCinemetaCatalog(on);
    _search.clear();
    _genre.clear();
    _notify();
    if (on) await refresh();
  }

  // Hide only the automatic browse/search catalogs. Stream resolution and
  // metadata still use these enabled sources, including saved titles.
  bool _showCatalogs(ArchiveSource source) =>
      showCinemetaCatalog ||
      !source.streamOnly ||
      source.catalogProviderUrl != ArchiveCatalogProvider.baseUrl;

  Future<void> _saveSources(List<ArchiveSource> list) async {
    await _storage
        .setArchiveSourcesJson(jsonEncode([for (final s in list) s.toJson()]));
    _notify();
  }

  /// Custom sources can replace their catalog ids without changing the
  /// manifest link. Re-read their definitions on open and explicit Refresh,
  /// keeping the saved definition if the source cannot answer.
  Future<void> _recheckCustomSources() async {
    for (final s in sources) {
      if (!s.enabled ||
          s.streamOnly ||
          s.server != null ||
          s.tracker != null ||
          s.catalogs.isEmpty ||
          !s.catalogs.any((c) => c.wireType != null)) {
        continue;
      }
      await _refreshManifest(s);
    }
  }

  Future<void> _refreshManifest(ArchiveSource s) async {
    try {
      final fresh = await _api
          .fetchManifest(s.manifestUrl)
          .timeout(const Duration(seconds: 10));
      // Settings may have changed while the network request was pending.
      // Never resurrect a removed source or overwrite its current choices.
      final current = sources;
      final index = current.indexWhere((p) => p.manifestUrl == s.manifestUrl);
      if (index < 0) return;
      final saved = current[index];
      current[index] = fresh.copyWith(
          enabled: saved.enabled, otherChoice: saved.otherChoice);
      if (jsonEncode(current[index].toJson()) != jsonEncode(saved.toJson())) {
        await _saveSources(current);
      }
      debugPrint('ArchiveManifest: source=${s.key} '
          'catalogs=${fresh.catalogs.length} '
          'custom=${fresh.catalogs.where((c) => c.wireType != null).length} '
          'genres=${fresh.catalogs.expand((c) => c.genres).toSet().length} checked');
    } catch (e) {
      debugPrint('ArchiveManifest: source=${s.key} '
          'failed=${e.runtimeType}; keeping saved catalogs');
    }
  }

  final Map<String, Future<void>> _searchManifestChecks = {};

  /// Upgrade old saved manifests without requiring removal/re-addition.
  /// Both global search types share the request; failed sources keep working.
  Future<void> _upgradeSearchCatalogs(bool other) async {
    for (final s in enabledSources) {
      if (s.searchCatalogsChecked ||
          s.server != null ||
          s.tracker != null ||
          s.underOther != other ||
          !_showCatalogs(s)) {
        continue;
      }
      await _searchManifestChecks.putIfAbsent(s.key, () => _refreshManifest(s));
    }
  }

  /// Checks [link]'s manifest without adding it (same errors as
  /// [addSource]) — an import checks every link first, then adds them in
  /// one save with [addCheckedSources].
  Future<ArchiveSource> checkSource(String link) => _api.fetchManifest(link);

  /// Adds sources from [checkSource] in one save and one refresh; a link
  /// already in the list is left out. Returns the ones added.
  Future<List<ArchiveSource>> addCheckedSources(
      List<ArchiveSource> found) async {
    final list = sources;
    final have = {for (final s in list) s.manifestUrl};
    final added = [
      for (final s in found)
        if (have.add(s.manifestUrl)) s,
    ];
    if (added.isEmpty) return added;
    await _saveSources([...list, ...added]);
    unawaited(refresh(force: true));
    return added;
  }

  /// True when [link] (normalized like a manifest URL) is already a source.
  bool hasSource(String link) {
    final url = ArchiveApiService.normalizeManifestUrl(link);
    return sources.any((s) => s.manifestUrl == url);
  }

  /// Checks [link]'s manifest and adds it. Throws [ArchiveApiException]
  /// (bad link, no streams/catalogs) or [StateError] (already added).
  Future<ArchiveSource> addSource(String link) async {
    final source = await _api.fetchManifest(link);
    final list = sources;
    if (list.any((s) => s.manifestUrl == source.manifestUrl)) {
      throw StateError('already added');
    }
    await _saveSources([...list, source]);
    unawaited(refresh(force: true));
    return source;
  }

  /// Signs in to a Jellyfin/Emby server and adds it (signing in again as
  /// the same user replaces the old login). Throws
  /// [MediaServerLoginException] (wrong user/password),
  /// [MediaServerNoLibraryException] or [ArchiveApiException] (no server
  /// there).
  Future<ArchiveSource> addMediaServer(
      String address, String userName, String password) async {
    final source = await _servers.connect(address, userName, password);
    final list = sources;
    final at = list.indexWhere((s) => s.manifestUrl == source.manifestUrl);
    await _saveSources(at < 0
        ? [...list, source]
        : [for (var i = 0; i < list.length; i++) i == at ? source : list[i]]);
    unawaited(refresh(force: true));
    return source;
  }

  /// The source's "Show under Other" switch (see [ArchiveSource.underOther]).
  Future<void> setUnderOther(ArchiveSource source, bool on) => _saveSources([
        for (final s in sources)
          s.manifestUrl == source.manifestUrl ? s.copyWith(otherChoice: on) : s,
      ]);

  Future<void> setEnabled(ArchiveSource source, bool on) => _saveSources([
        for (final s in sources)
          s.manifestUrl == source.manifestUrl ? s.copyWith(enabled: on) : s,
      ]);

  Future<void> removeSource(ArchiveSource source) async {
    await _saveSources(
        sources.where((s) => s.manifestUrl != source.manifestUrl).toList());
    _items.removeWhere((k, _) => k.startsWith('${source.key}|'));
    await _cache.deleteSource(source.key);
    _notify();
  }

  /// Removes every source and its cached rows (Clear archives).
  Future<void> clearAll() async {
    await _saveSources(const []);
    _items.clear();
    await _cache.clear();
    _notify();
  }

  // ---- catalog rows -------------------------------------------------------

  static String _rowKey(ArchiveSource s, ArchiveCatalog c) =>
      '${s.key}|${c.wire}|${c.slug}';

  /// Catalogs of [type] to read, one per distinct row: a provider catalog
  /// shared by several stream-only sources is listed once (Play still
  /// asks every stream-only source — see [streams]). While a genre is
  /// picked ([setGenre]) only the catalogs offering it are listed, narrowed
  /// to it; [filtered] false lists the plain ones (search ignores genre).
  ///
  /// A source [ArchiveSource.underOther] (custom-type catalogs by default,
  /// or the user's switch) has its catalogs listed only while the
  /// [otherGenre] filter is picked, and then alone — search follows the
  /// same split.
  List<(ArchiveSource, ArchiveCatalog)> _catalogs(ArchiveType type,
      {bool filtered = true,
      bool? underOther,
      bool includeSearchOnly = false}) {
    final other = underOther ?? _genre[type] == otherGenre;
    final genre = filtered && !other ? _genre[type] : null;
    final shown = <String>{};
    return [
      for (final s in enabledSources)
        if (_showCatalogs(s))
          for (final base in s.catalogs)
            if (base.type == type &&
                s.underOther == other &&
                (includeSearchOnly || !base.searchOnly))
              if (genre == null ? base : base.withGenre(genre) case final c?)
                if (!s.streamOnly ||
                    shown.add('${s.catalogBaseUrl}|${c.wire}|${c.slug}'))
                  (s, c),
    ];
  }

  // ---- genre filter -------------------------------------------------------

  /// The genre picked per type (rail "Genre"), kept for the session.
  final Map<ArchiveType, String> _genre = {};

  /// The "Other" pick in the genre filter: shows the catalogs of custom
  /// types (not movie/series) instead of the regular rows. Not a real
  /// genre name, so it can't collide with one.
  static const otherGenre = '\u0001other';

  String? genre(ArchiveType type) => _genre[type];

  /// Every genre a regular catalog of [type] can be narrowed to, in the
  /// order the sources list them, then [otherGenre] when an enabled source
  /// shown under Other has catalogs browsed under [type].
  List<String> genres(ArchiveType type) {
    final regular = <String>{};
    var other = false;
    for (final s in enabledSources) {
      if (!_showCatalogs(s)) continue;
      for (final c in s.catalogs) {
        if (c.type != type) continue;
        if (s.underOther) {
          other = true;
        } else if (!c.searchOnly) {
          regular.addAll(c.genres);
        }
      }
    }
    return [...regular, if (other) otherGenre];
  }

  /// Narrows [type]'s rows to [genre] (null = all): the rows offering it
  /// are shown from cache at once and fetched behind when stale.
  Future<void> setGenre(ArchiveType type, String? genre) async {
    if (_genre[type] == genre) return;
    if (genre == null) {
      _genre.remove(type);
    } else {
      _genre[type] = genre;
    }
    _notify();
    if (genre == null) return;
    for (final (s, c) in _catalogs(type)) {
      final key = _rowKey(s, c);
      if (_items.containsKey(key)) continue;
      try {
        _items[key] = await _cache.read(s.key, c);
      } catch (e) {
        debugPrint('ArchiveService: cache read failed: ${e.runtimeType}');
      }
    }
    _notify();
    await refresh();
  }

  /// The current search per type: its query and result rows.
  final Map<ArchiveType, (String, List<ArchiveRow>)> _search = {};
  bool _searching = false;
  bool get searching => _searching;
  String? searchQuery(ArchiveType type) => _search[type]?.$1;

  /// Searches every searchable catalog of [type] (the provider's Popular
  /// for stream-only sources). The results become the first rows.
  ///
  /// Punctuation/spacing, accents and partial words share [TitleSearch]
  /// matching. Provider aliases are retained; non-searchable sources use
  /// their loaded/cached rows. One results row per source (stream-only
  /// sources sharing the provider count as one).
  Future<void> search(ArchiveType type, String query) async {
    final q = query.trim();
    if (q.isEmpty) return clearSearch(type);
    unawaited(_rememberSearch(type, q));
    _searching = true;
    _search[type] = (q, const []);
    _notify();
    var out = const <ArchiveRow>[];
    try {
      out = await searchRows(type, q);
    } finally {
      // A newer search (or a clear) replaced this one: drop these results.
      if (_search[type]?.$1 == q) _search[type] = (q, out);
      _searching = false;
      _notify();
    }
  }

  /// The search itself, one row per source (stream-only sources sharing a
  /// provider = one row), without touching this tab's search state — the
  /// app's global Search uses it too ([underOther] false there: Other
  /// stays behind its filter). Null [underOther] = the tab's current split.
  Future<List<ArchiveRow>> searchRows(ArchiveType type, String q,
      {bool? underOther}) async {
    final search = TitleSearch(q);
    if (search.isEmpty) return const [];
    await _upgradeSearchCatalogs(underOther ?? _genre[type] == otherGenre);
    final out = <ArchiveRow>[];
    final groups = <String, List<(ArchiveSource, ArchiveCatalog)>>{};
    for (final sc in _catalogs(type,
        filtered: false, underOther: underOther, includeSearchOnly: true)) {
      final s = sc.$1;
      groups
          .putIfAbsent(
              s.streamOnly ? s.catalogBaseUrl : s.manifestUrl, () => [])
          .add(sc);
    }
    for (final group in groups.values) {
      final found = <ArchiveMeta>[];
      final providerMatches = <ArchiveMeta>[];
      for (final (s, c) in group) {
        if (!c.searchable) continue;
        final variants = search.remoteQueries(q);
        final replies = await Future.wait([
          for (final variant in variants)
            (() async {
              try {
                final items = await _page(s, c, search: variant.text);
                return variant.broad
                    ? items.where((m) => search.matches(m.name)).toList()
                    : items;
              } catch (e) {
                debugPrint(
                    'ArchiveService: search source=${s.key} failed=${e.runtimeType}');
                return <ArchiveMeta>[];
              }
            })(),
        ]);
        for (var i = 0; i < replies.length; i++) {
          found.addAll(replies[i]);
          if (!variants[i].broad) providerMatches.addAll(replies[i]);
        }
      }
      for (final (s, c) in group) {
        if (c.searchOnly) continue;
        final key = _rowKey(s, c);
        if (!_items.containsKey(key)) {
          try {
            _items[key] = await _cache.read(s.key, c);
          } catch (e) {
            debugPrint('ArchiveService: search cache failed=${e.runtimeType}');
          }
        }
        found.addAll(_items[key] ?? const []);
      }
      final items = rankSearch(q, found);
      // Providers may match original/translated titles or aliases that aren't
      // in the displayed name. Preserve those after the direct title matches.
      final seen = {for (final item in items) item.id};
      items.addAll(providerMatches.where((m) => seen.add(m.id)));
      if (items.isEmpty) continue;
      final (s, c) =
          group.firstWhere((sc) => sc.$2.searchable, orElse: () => group.first);
      out.add(ArchiveRow(source: s, catalog: c, items: items, searchQuery: q));
    }
    return out;
  }

  void clearSearch(ArchiveType type) {
    if (_search.remove(type) != null) _notify();
  }

  bool canSearch(ArchiveType type) =>
      _catalogs(type, includeSearchOnly: true).isNotEmpty;

  // ---- recent searches ----------------------------------------------------

  static const _recentSearchMax = 8;

  Map<String, dynamic> _recentSearchMap() {
    try {
      final raw = _storage.getArchiveRecentSearchesJson();
      return raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  /// The last searches of [type], newest first (each category its own).
  List<String> recentSearches(ArchiveType type) => [
        for (final q in (_recentSearchMap()[type.wire] as List? ?? const []))
          '$q',
      ];

  Future<void> _rememberSearch(ArchiveType type, String query) async {
    final lower = query.toLowerCase();
    final list = [
      query,
      ...recentSearches(type).where((q) => q.toLowerCase() != lower),
    ].take(_recentSearchMax).toList();
    await _storage.setArchiveRecentSearchesJson(
        jsonEncode({..._recentSearchMap(), type.wire: list}));
  }

  Future<void> forgetRecentSearches(ArchiveType type) async {
    await _storage.setArchiveRecentSearchesJson(
        jsonEncode({..._recentSearchMap()}..remove(type.wire)));
    _notify();
  }

  // ---- favourites ---------------------------------------------------------

  /// Titles kept in Favourites (both categories together).
  static const _favoritesMax = 200;

  List<Map<String, dynamic>> _favoriteEntries() =>
      _decodeEntries(_storage.getArchiveFavoritesJson());

  static bool _sameTitle(
          Map<String, dynamic> e, ArchiveSource source, ArchiveMeta meta) =>
      e['src'] == source.manifestUrl && (e['meta'] as Map?)?['id'] == meta.id;

  bool isFavorite(ArchiveSource source, ArchiveMeta meta) =>
      _favoriteEntries().any((e) => _sameTitle(e, source, meta));

  /// Hold OK on a title: into Favourites (front of the row), or out again.
  /// Returns true when it is now a favourite.
  Future<bool> toggleFavorite(ArchiveSource source, ArchiveMeta meta) async {
    final entries = _favoriteEntries();
    final had = entries.any((e) => _sameTitle(e, source, meta));
    final next = had
        ? entries.where((e) => !_sameTitle(e, source, meta)).toList()
        : [
            {'src': source.manifestUrl, 'meta': meta.toJson()},
            ...entries,
          ].take(_favoritesMax).toList();
    await _storage
        .setArchiveFavoritesJson(next.isEmpty ? null : jsonEncode(next));
    _notify();
    return !had;
  }

  // ---- watched history ----------------------------------------------------

  /// Titles kept in the history (both categories together).
  static const _historyMax = 40;

  List<Map<String, dynamic>> _historyEntries() =>
      _decodeEntries(_storage.getArchiveHistoryJson());

  static List<Map<String, dynamic>> _decodeEntries(String? raw) {
    try {
      if (raw == null) return [];
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Called when a title (a movie, or a show's episode) starts playing: it
  /// moves to the front of its category's "Recently watched" row.
  Future<void> recordWatched(ArchiveSource source, ArchiveMeta meta) async {
    final entries = [
      {'src': source.manifestUrl, 'meta': meta.toJson()},
      ..._historyEntries().where((e) => !(e['src'] == source.manifestUrl &&
          (e['meta'] as Map?)?['id'] == meta.id)),
    ].take(_historyMax).toList();
    await _storage.setArchiveHistoryJson(jsonEncode(entries));
    _notify();
  }

  Future<void> removeFromHistory(ArchiveSource source, ArchiveMeta meta) async {
    final entries = _historyEntries()
        .where((e) => !(e['src'] == source.manifestUrl &&
            (e['meta'] as Map?)?['id'] == meta.id))
        .toList();
    await _storage
        .setArchiveHistoryJson(entries.isEmpty ? null : jsonEncode(entries));
    _notify();
  }

  /// Every played title (movies and shows), newest first, whose source is
  /// still enabled and not under Other — the Home page's Continue watching.
  List<({ArchiveSource source, ArchiveMeta meta})> recentlyWatched() {
    final byUrl = {for (final s in enabledSources) s.manifestUrl: s};
    return [
      for (final e in _historyEntries())
        if (byUrl[e['src']] case final source? when !source.underOther)
          if (e['meta'] case final Map m)
            if (ArchiveMeta.fromJson(Map<String, dynamic>.from(m))
                case final meta?)
              (source: source, meta: meta),
    ];
  }

  /// "Recently watched" for [type]: played titles whose source is still
  /// enabled, newest first. Not narrowed by the genre filter.
  ArchiveRow? _historyRow(ArchiveType type) => _savedRow(
      type,
      _historyEntries(),
      ArchiveCatalog(type: type, id: 'history', name: 'Recently watched'));

  /// "Favourites" for [type], newest first — like [_historyRow].
  ArchiveRow? _favoritesRow(ArchiveType type) => _savedRow(
      type,
      _favoriteEntries(),
      ArchiveCatalog(type: type, id: 'favorites', name: 'Favourites'),
      favorites: true);

  ArchiveRow? _savedRow(ArchiveType type, List<Map<String, dynamic>> entries,
      ArchiveCatalog catalog,
      {bool favorites = false}) {
    final byUrl = {for (final s in enabledSources) s.manifestUrl: s};
    final items = <ArchiveMeta>[];
    final sources = <ArchiveSource>[];
    for (final e in entries) {
      final source = byUrl[e['src']];
      final m = e['meta'];
      if (source == null || m is! Map) continue;
      final meta = ArchiveMeta.fromJson(Map<String, dynamic>.from(m));
      if (meta == null || meta.type != type) continue;
      // An Other source's titles only under the Other filter, like its rows.
      if (source.underOther != (_genre[type] == otherGenre)) continue;
      items.add(meta);
      sources.add(source);
    }
    if (items.isEmpty) return null;
    return ArchiveRow(
      source: sources.first,
      catalog: catalog,
      items: items,
      itemSources: sources,
      isFavorites: favorites,
    );
  }

  /// Direct title matches, ignoring separators/accents and allowing all
  /// query words in any order. Title prefixes first, then substrings, then
  /// separate word matches, retaining source relevance within each rank.
  static List<ArchiveMeta> rankSearch(
      String query, Iterable<ArchiveMeta> items) {
    final search = TitleSearch(query);
    if (search.isEmpty) return [];
    final ranked = <int, List<ArchiveMeta>>{};
    final seen = <String>{};
    for (final m in items) {
      final rank = search.rank(m.name);
      if (rank != null && seen.add(m.id)) {
        ranked.putIfAbsent(rank, () => []).add(m);
      }
    }
    return [for (var rank = 0; rank <= 3; rank++) ...?ranked[rank]];
  }

  /// Rows of [type] from every enabled source, in source then manifest
  /// order. Rows not loaded yet (or empty) are left out, and so is a
  /// provider row an earlier stream-only source already shows (Play still
  /// asks every stream-only source — see [resolve]).
  List<ArchiveRow> rows(ArchiveType type) => [
        ...?_search[type]?.$2,
        if (_favoritesRow(type) case final favorites?) favorites,
        if (_historyRow(type) case final history?) history,
        for (final (s, c) in _catalogs(type))
          if (_items[_rowKey(s, c)] case final items? when items.isNotEmpty)
            ArchiveRow(source: s, catalog: c, items: items),
      ];

  final Set<String> _loadingMore = {};
  final Set<String> _exhausted = {};

  /// Appends [row]'s next page (called as focus nears its end), so a row
  /// keeps scrolling past the pages [refresh] fetched. Not cached: a
  /// refresh starts the row over.
  Future<void> loadMore(ArchiveRow row) async {
    final key = row.key;
    if (row.isSearch ||
        row.itemSources != null ||
        _exhausted.contains(key) ||
        !_loadingMore.add(key)) {
      return;
    }
    try {
      final have = _items[key] ?? const <ArchiveMeta>[];
      final batch = await _page(row.source, row.catalog, skip: have.length);
      final seen = {for (final m in have) m.id};
      final fresh = batch.where((m) => seen.add(m.id)).toList();
      if (fresh.isEmpty) {
        _exhausted.add(key);
      } else {
        _items[key] = [...have, ...fresh];
        _notify();
      }
    } catch (e) {
      debugPrint('ArchiveService: more of $key failed: $e');
    } finally {
      _loadingMore.remove(key);
    }
  }

  bool hasAny(ArchiveType type) =>
      enabledSources.any(
          (s) => _showCatalogs(s) && s.catalogs.any((c) => c.type == type)) ||
      _favoritesRow(type) != null ||
      _historyRow(type) != null;

  /// Call when the Archive tab opens: draws the cached rows at once, then
  /// refreshes stale catalogs behind them.
  Future<void> open() async {
    if (!_loadedFromCache) {
      _loadedFromCache = true;
      await _recheckCustomSources();
      for (final type in ArchiveType.values) {
        for (final (s, c) in _catalogs(type)) {
          try {
            _items[_rowKey(s, c)] = await _cache.read(s.key, c);
          } catch (e) {
            debugPrint('ArchiveService: cache read failed: ${e.runtimeType}');
          }
        }
      }
      _notify();
    }
    unawaited(refresh());
  }

  /// Refetches catalogs older than [_staleAfter] (all of them with
  /// [force]). A failing source keeps its cached rows.
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) {
      // A genre picked mid-refresh adds rows the running pass won't reach.
      _refreshAgain = true;
      _forceRefreshAgain |= force;
      return;
    }
    _refreshing = true;
    lastError = null;
    _notify();
    try {
      if (force) await _recheckCustomSources();
      for (final type in ArchiveType.values) {
        for (final (s, c) in _catalogs(type)) {
          final key = _rowKey(s, c);
          if (!force) {
            final at = await _cache.fetchedAt(s.key, c);
            if (at != null &&
                DateTime.now().difference(at) < _staleAfter &&
                (_items[key]?.isNotEmpty ?? false)) {
              continue;
            }
          }
          try {
            final items = <ArchiveMeta>[];
            final seen = <String>{};
            for (var page = 0; page < _pagesPerCatalog; page++) {
              final batch = await _page(s, c, skip: items.length);
              final fresh = batch.where((m) => seen.add(m.id)).toList();
              if (fresh.isEmpty) break;
              items.addAll(fresh);
              if (batch.length < 50) break; // a short page = the last one
            }
            _items[key] = items;
            _exhausted.remove(key);
            await _cache.write(s.key, c, items);
            _notify();
          } catch (e) {
            lastError = '${s.name}: $e';
            debugPrint('ArchiveService: ${s.name}/${c.slug} failed: $e');
          }
        }
      }
    } finally {
      _refreshing = false;
      _notify();
    }
    if (_refreshAgain) {
      _refreshAgain = false;
      final forceAgain = _forceRefreshAgain;
      _forceRefreshAgain = false;
      await refresh(force: forceAgain);
    }
  }

  // ---- details + playback -------------------------------------------------

  static String _rawId(ArchiveSource source, String videoId,
          {required bool episode}) =>
      'arc_${episode ? 'ep' : 'vod'}_${source.key}_$videoId';

  /// The [Channel.id] [channelFor] gives a title — known before resolving, so
  /// detail pages can show saved progress (StorageService positions).
  static String channelId(ArchiveSource source, String videoId,
          {required bool episode}) =>
      '$playlistId::${_rawId(source, videoId, episode: episode)}';

  Future<ArchiveMeta?> meta(ArchiveSource source, ArchiveMeta preview) =>
      // A tracker's or list-only source's titles are IMDb ids: the
      // provider has their metas.
      source.tracker != null || source.listOnly
          ? _api.fetchMeta(
              ArchiveCatalogProvider.baseUrl, preview.type, preview.id)
          : source.server != null
              ? _servers.fetchMeta(source, preview)
              : _api.fetchMeta(source.catalogBaseUrl, preview.type, preview.id,
                  wire: preview.wire);

  /// The sources asked for a title's streams: [source] itself, then — for
  /// a title from the public provider — every other enabled stream-only
  /// source on the same provider, since they share the same IMDB ids.
  List<ArchiveSource> _streamSources(ArchiveSource source) => [
        // A tracker list or list-only add-on has no streams: every
        // stream-only add-on is asked, like for the provider's own rows
        // (same IMDb ids).
        if (source.tracker != null || source.listOnly)
          for (final s in enabledSources)
            if (s.streamOnly) s,
        if (source.tracker == null && !source.listOnly) source,
        if (source.streamOnly)
          for (final s in enabledSources)
            if (s.streamOnly &&
                s.manifestUrl != source.manifestUrl &&
                s.catalogBaseUrl == source.catalogBaseUrl)
              s,
      ];

  /// Every direct http(s) stream for [meta] (a movie) or one of its
  /// [episode]s, in source then server order — the detail page plays a
  /// single one at once and lets the user pick when there are several
  /// (quality, language…). Each source is asked at its own `/stream/` with
  /// the title's id (`tt…`, or `tt…:{season}:{episode}` for a provider
  /// episode); a failing source is skipped, and its error rethrown only
  /// when no source answered with anything.
  Future<List<ArchiveStreamOption>> streams(
    ArchiveSource source,
    ArchiveMeta meta, {
    ArchiveVideo? episode,
  }) async {
    final videoId = episode?.id ?? meta.id;
    final out = <ArchiveStreamOption>[];
    final urls = <String>{};
    Object? error;
    final titleKey =
        sha1.convert(utf8.encode(videoId)).toString().substring(0, 12);
    for (final s in _streamSources(source)) {
      try {
        final streams = s.server != null
            ? _servers.streams(s, videoId)
            : await _api.fetchStreams(s.baseUrl, meta.type, videoId,
                wire: meta.wire);
        debugPrint('ArchiveStreams: source=${s.key} title=$titleKey '
            'type=${meta.wire} playable=${streams.length}');
        for (final st in streams) {
          if (urls.add(st.identity)) {
            out.add(ArchiveStreamOption(source: s, stream: st));
          }
        }
      } catch (e) {
        error ??= e;
        debugPrint('ArchiveStreams: source=${s.key} title=$titleKey '
            'type=${meta.wire} failed=${e.runtimeType}'
            '${e is ArchiveApiException && e.statusCode != null ? ' http=${e.statusCode}' : ''}');
      }
    }
    if (out.isEmpty && error != null) throw error;
    return out;
  }

  /// The [Channel] that plays [stream] for [meta] or its [episode]. Its id
  /// comes from [source] (the row the title was opened from), not from the
  /// stream picked, so progress is kept whichever stream plays.
  Channel channelFor(
    ArchiveSource source,
    ArchiveMeta meta,
    ArchiveStream stream, {
    ArchiveVideo? episode,
  }) {
    final videoId = episode?.id ?? meta.id;
    final rawId = _rawId(source, videoId, episode: episode != null);
    return Channel(
      id: '$playlistId::$rawId',
      rawId: rawId,
      playlistId: playlistId,
      name: episode == null
          ? meta.name
          : 'S${episode.season.toString().padLeft(2, '0')}'
              'E${episode.episode.toString().padLeft(2, '0')}'
              '${episode.title.isEmpty ? '' : ' - ${episode.title}'}',
      group: meta.name,
      url: stream.url,
      logoUrl: episode?.thumbnailUrl ?? meta.posterUrl,
      subtitleUrl: stream.subtitleUrl,
      posterUrl: meta.posterUrl,
      backdropUrl: meta.backgroundUrl,
      seriesName: episode == null ? null : meta.name,
      seriesCoverUrl: episode == null ? null : meta.posterUrl,
    );
  }

  /// notifyListeners, deferred out of a build phase (see CLAUDE.md:
  /// never notify mid-build).
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}
