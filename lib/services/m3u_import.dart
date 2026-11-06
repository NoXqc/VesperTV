import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/channel.dart';
import '../models/xtream_series.dart';
import 'catalog_database.dart';
import 'm3u_parser.dart';

/// An M3U list stored the way an Xtream catalog is: live channels in
/// memory, movies and episodes in [CatalogDatabase] (episodes grouped into
/// shows). LOG-ELUGMN: a 1.28M-entry list (334 MB) held whole in memory
/// took ~1.3 GB, every launch re-read all of it (~2.5 min on a Formuler)
/// and the remote lagged. The list is read once per download, on a
/// background isolate, without holding its movies and episodes; a launch
/// reads back only the live channels ([readCatalog]).
class M3uImport {
  /// Downloads (or reads, for a `file:` link) [url] and stores it. The
  /// live channels and the movie / show group lists are also written to
  /// [catalogPath] for the next launch. Rows of a previous import stay
  /// until this one completes, so a failed refresh keeps the catalog.
  static Future<M3uImported> run(String url,
      {required String playlistId,
      required CatalogDatabase catalog,
      required String catalogPath,
      Set<String> favorites = const {},
      Set<String> favoriteSeries = const {},
      Map<String, String> epgOverrides = const {},
      void Function(int bytes)? onProgress}) async {
    // Opened (and upgraded) here first: the isolate only joins it.
    await catalog.ping();
    final job = _Job(
      url: url,
      playlistId: playlistId,
      dbPath: await catalog.path,
      catalogPath: catalogPath,
      token: RootIsolateToken.instance,
      ffi: _usesFfi,
      favorites: favorites,
      favoriteSeries: favoriteSeries,
      epgOverrides: epgOverrides,
      mark: DateTime.now().microsecondsSinceEpoch,
    );
    final progress = ReceivePort();
    progress.listen((bytes) => onProgress?.call(bytes as int));
    try {
      return await _inIsolate(job, progress.sendPort);
    } catch (e) {
      throw M3uParser.friendlyError(e);
    } finally {
      progress.close();
      catalog.writeGeneration++;
    }
  }

  /// The live channels and group lists a previous [run] saved.
  static Future<M3uImported> readCatalog(String catalogPath,
          {Set<String> favorites = const {},
          Map<String, String> epgOverrides = const {}}) =>
      _readInIsolate(catalogPath, favorites, epgOverrides);

  static Future<M3uImported> _readInIsolate(String path, Set<String> favorites,
          Map<String, String> epgOverrides) =>
      Isolate.run(() async {
        final imported = await _readCatalog(path);
        for (final c in imported.live.channels) {
          c.isFavorite = favorites.contains(c.id);
          c.epgIdOverride = epgOverrides[c.rawId];
        }
        return imported;
      });

  /// Windows/Linux (and tests) reach SQLite through FFI; Android, iOS and
  /// macOS through the sqflite plugin, which a background isolate joins
  /// with the root isolate's token.
  static bool get _usesFfi =>
      Platform.isWindows ||
      Platform.isLinux ||
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Its own function so the isolate's closure only captures what it is
  /// given (see [M3uParser.fetchAndParseInBackground]).
  static Future<M3uImported> _inIsolate(_Job job, SendPort progress) =>
      Isolate.run(() => _import(job, progress));

  static Future<M3uImported> _import(_Job job, SendPort progress) async {
    final token = job.token;
    if (token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    }
    if (job.ffi) {
      sqfliteFfiInit();
      // In this isolate: its own connection, closed at the end.
      databaseFactory = databaseFactoryFfiNoIsolate;
    }
    final db = CatalogDatabase(databasePath: job.dbPath, resetOnFailure: false);
    final total = Stopwatch()..start();
    try {
      await db.bulkWrites(true);
      final store = _Store(job, db);
      await M3uParser.fetchAndParse(job.url,
          playlistId: job.playlistId,
          onBytes: progress.send,
          onEntry: store.add);
      await store.flush();
      final read = total.elapsedMilliseconds;
      await db.finishM3uImport(job.playlistId, job.mark);
      final live = Channel.withUniqueIds(store.live);
      for (final c in live) {
        c.isFavorite = job.favorites.contains(c.id);
        c.epgIdOverride = job.epgOverrides[c.rawId];
      }
      final result = M3uImported(
        live: M3uList(live),
        vodGroups: store.vodGroups.toList(),
        seriesGroups: store.seriesGroups.toList(),
        counts: {
          'tv': live.length,
          'vod': store.movies,
          'series': store.episodes,
          'shows': store.shows.length,
        },
        timings:
            'read+sort ${read - store.waitedForDb.elapsedMilliseconds} ms, '
            'waited for db ${store.waitedForDb.elapsedMilliseconds} ms, '
            'db writing ${store.writing.elapsedMilliseconds} ms, '
            'cleanup ${total.elapsedMilliseconds - read} ms',
      );
      await _writeCatalog(job.catalogPath, result);
      return result;
    } finally {
      await db.bulkWrites(false);
      // The plugin's connection is the UI isolate's too: never closed here.
      if (job.ffi) await db.close();
    }
  }

  static Future<void> _writeCatalog(String path, M3uImported result) async {
    final part = File('$path.part');
    final sink = part.openWrite();
    try {
      sink.write('{"v":1,"vodGroups":${jsonEncode(result.vodGroups)},'
          '"seriesGroups":${jsonEncode(result.seriesGroups)},'
          '"counts":${jsonEncode(result.counts)},"live":[');
      var first = true;
      for (final c in result.live.channels) {
        if (!first) sink.write(',');
        first = false;
        sink.write(jsonEncode(c.toJson()));
      }
      sink.write(']}');
      await sink.close();
      await part.rename(path);
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      rethrow;
    }
  }

  static Future<M3uImported> _readCatalog(String path) async {
    final json = jsonDecode(await File(path).readAsString()) as Map;
    return M3uImported(
      live: M3uList([
        for (final c in json['live'] as List)
          Channel.fromJson(c as Map<String, dynamic>)
      ]),
      vodGroups: [...(json['vodGroups'] as List).cast<String>()],
      seriesGroups: [...(json['seriesGroups'] as List).cast<String>()],
      counts: (json['counts'] as Map).cast<String, int>(),
    );
  }

  /// "Show S01 E02", "Show.S01E02", "Show - S1 EP2 - Title", and a year
  /// as the season: "MythBusters - S2003E05" (each line was a show of its
  /// own: ~9,600 single-episode "shows" in the owner's list).
  static final RegExp _seasonEpisode = RegExp(
      r'^(.*?)[\s._\-|:]*\b[Ss](\d{1,4})[\s._\-]*[Ee][Pp]?\s*(\d{1,4})(?!\d)');

  /// "Show 1x02".
  static final RegExp _crossEpisode =
      RegExp(r'^(.*?)[\s._\-|:]*\b(\d{1,2})[xX](\d{1,3})(?!\d)');

  /// "Show Season 2 Episode 5", "Show - Series 3, Ep 4" (and the French,
  /// Spanish, German and Italian words).
  static final RegExp _seasonWords = RegExp(
      r'^(.*?)[\s._\-|:(]*\b(?:season|series|saison|temporada|staffel|stagione)'
      r'\s*(\d{1,4})[\s._\-|:,]*(?:episode|épisode|episodio|folge|ep\.?|e)'
      r'\s*(\d{1,4})(?!\d)',
      caseSensitive: false);

  /// A daily show by air date: "Emmerdale - 2004-07-07" (each date was a
  /// show of its own: 19,685 "shows" in a provider's Prime Video group,
  /// 3,513 on its Xtream side). Season = year, episode = month and day.
  static final RegExp _airDate = RegExp(
      r'^(.*?)[\s._\-|:(]*\b((?:19|20)\d{2})[-./](\d{1,2})[-./](\d{1,2})(?!\d)');

  /// The same, day first: "Show - 07.07.2004", "Show 7/7/2004".
  static final RegExp _airDateDayFirst = RegExp(
      r'^(.*?)[\s._\-|:(]*\b(\d{1,2})[-./](\d{1,2})[-./]((?:19|20)\d{2})(?!\d)');

  static const _months =
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?'
      r'|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?'
      r'|dec(?:ember)?)\.?';

  /// "Show - 7 July 2004", "Show - 7th Jul 2004".
  static final RegExp _airDateDayMonth = RegExp(
      r'^(.*?)[\s._\-|:(]*\b(\d{1,2})(?:st|nd|rd|th)?\s+' +
          _months +
          r',?\s+((?:19|20)\d{2})(?!\d)',
      caseSensitive: false);

  /// "Show - July 7, 2004", "Show - Jul 7th 2004".
  static final RegExp _airDateMonthDay = RegExp(
      r'^(.*?)[\s._\-|:(]*\b' +
          _months +
          r'\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+((?:19|20)\d{2})(?!\d)',
      caseSensitive: false);

  /// "Show - Episode 12", "Show Ep 12", "Show E12", "Show - Part 2" (no
  /// season).
  static final RegExp _episodeOnly = RegExp(
      r'^(.*?)[\s._\-|:]*\b(?:[Ee]pisode|[Ee]p\.?|[Ee]|[Pp]art|[Pp]t\.?)\s*'
      r'(\d{1,4})(?!\d)');

  static int _monthOf(String name) =>
      const [
        'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
        'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
      ].indexOf(name.substring(0, 3).toLowerCase()) +
      1;

  /// The show an episode line belongs to, with its season and episode.
  /// A name with no pattern is a show of its own (season 1, ep. 1).
  /// Providers name episodes many ways, so every common one is tried; the
  /// show name is what comes before it ([showKeyOf] joins spellings).
  static ({String show, int season, int episode}) episodeOf(String name) {
    String show(String raw) {
      var s = raw.replaceAll(RegExp(r'[\s._\-|:(,]+$'), '').trim();
      // "Breaking.Bad" / "Breaking_Bad": a scene-style name.
      if (!s.contains(' ')) s = s.replaceAll(RegExp(r'[._]+'), ' ');
      return s.isEmpty ? name.trim() : s;
    }

    final m = _seasonEpisode.firstMatch(name) ??
        _crossEpisode.firstMatch(name) ??
        _seasonWords.firstMatch(name);
    if (m != null) {
      return (
        show: show(m.group(1)!),
        season: int.parse(m.group(2)!),
        episode: int.parse(m.group(3)!),
      );
    }
    final date = _airDate.firstMatch(name);
    if (date != null) {
      return (
        show: show(date.group(1)!),
        season: int.parse(date.group(2)!),
        episode: int.parse(date.group(3)!) * 100 + int.parse(date.group(4)!),
      );
    }
    final dayFirst = _airDateDayFirst.firstMatch(name);
    if (dayFirst != null) {
      var day = int.parse(dayFirst.group(2)!);
      var month = int.parse(dayFirst.group(3)!);
      // 12/31/2004: month first (US) when the day can't be a month.
      if (month > 12 && day <= 12) (day, month) = (month, day);
      return (
        show: show(dayFirst.group(1)!),
        season: int.parse(dayFirst.group(4)!),
        episode: month * 100 + day,
      );
    }
    final dayMonth = _airDateDayMonth.firstMatch(name);
    if (dayMonth != null) {
      return (
        show: show(dayMonth.group(1)!),
        season: int.parse(dayMonth.group(4)!),
        episode:
            _monthOf(dayMonth.group(3)!) * 100 + int.parse(dayMonth.group(2)!),
      );
    }
    final monthDay = _airDateMonthDay.firstMatch(name);
    if (monthDay != null) {
      return (
        show: show(monthDay.group(1)!),
        season: int.parse(monthDay.group(4)!),
        episode:
            _monthOf(monthDay.group(2)!) * 100 + int.parse(monthDay.group(3)!),
      );
    }
    final only = _episodeOnly.firstMatch(name);
    if (only != null && only.group(1)!.trim().isNotEmpty) {
      return (
        show: show(only.group(1)!),
        season: 1,
        episode: int.parse(only.group(2)!),
      );
    }
    return (show: name.trim(), season: 1, episode: 1);
  }

  /// What makes two show names the same show: case, dots, underscores and
  /// repeated spaces don't count ("Breaking.Bad" = "breaking bad").
  static String showKeyOf(String show) =>
      show.toLowerCase().replaceAll(RegExp(r'[\s._]+'), ' ').trim();

  /// A show's id from its group and name (FNV-1a): the same show keeps
  /// its id, and so its favourite, across refreshes.
  static int showIdOf(String group, String show) {
    var hash = 0x811c9dc5;
    for (final unit in '$group\u0000${showKeyOf(show)}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// What an import (or a launch's [M3uImport.readCatalog]) hands the
/// session: the live channels, and the movie / show groups in playlist
/// order. [counts]: 'tv', 'vod' (movies), 'series' (episodes), 'shows'.
class M3uImported {
  M3uImported(
      {required this.live,
      required this.vodGroups,
      required this.seriesGroups,
      required this.counts,
      this.timings = ''});

  final M3uList live;
  final List<String> vodGroups;
  final List<String> seriesGroups;
  final Map<String, int> counts;

  /// Where an import's time went, for the M3uLoad log line (not saved).
  final String timings;
}

class _Job {
  _Job({
    required this.url,
    required this.playlistId,
    required this.dbPath,
    required this.catalogPath,
    required this.token,
    required this.ffi,
    required this.favorites,
    required this.favoriteSeries,
    required this.epgOverrides,
    required this.mark,
  });

  final String url;
  final String playlistId;
  final String dbPath;
  final String catalogPath;
  final RootIsolateToken? token;
  final bool ffi;
  final Set<String> favorites;
  final Set<String> favoriteSeries;
  final Map<String, String> epgOverrides;
  final int mark;
}

/// Sorts entries as they are read: live ones kept, movies and episodes
/// written in batches.
class _Store {
  _Store(this.job, this.db);

  final _Job job;
  final CatalogDatabase db;
  final List<Channel> live = [];
  final Set<String> vodGroups = {};
  final Set<String> seriesGroups = {};
  int movies = 0;
  int episodes = 0;

  /// Show key -> its id ([M3uImport.showIdOf], moved on a collision).
  final Map<String, int> shows = {};
  final Set<int> _showIds = {};

  /// Group title -> tab, for links that don't say ([M3uParser.groupCategory]).
  final Map<String, String> _tabOfGroup = {};

  /// Ids of on-demand entries from a tvg-id (`ch_N` ones are unique).
  final Set<String> _ids = {};

  List<Map<String, Object?>> _vod = [];
  List<Map<String, Object?>> _series = [];
  List<Map<String, Object?>> _episodes = [];

  static const _batch = 4000;

  Future<void>? add(Channel c) {
    final tab = M3uParser.xtreamOnDemandTab(c.url) ??
        (_tabOfGroup[c.group] ??= M3uParser.groupCategory(c.group));
    if (tab == 'tv') {
      live.add(c);
      return null;
    }
    final entry = _unique(c);
    if (tab == 'vod') {
      vodGroups.add(entry.group);
      entry.isFavorite = job.favorites.contains(entry.id);
      _vod.add(
          CatalogDatabase.vodRow(entry.group, entry, importMark: job.mark));
      movies++;
    } else {
      seriesGroups.add(entry.group);
      final ep = M3uImport.episodeOf(entry.name);
      final key = '${entry.group}\u0000${M3uImport.showKeyOf(ep.show)}';
      var id = shows[key];
      if (id == null) {
        id = M3uImport.showIdOf(entry.group, ep.show);
        while (!_showIds.add(id!)) {
          id = (id + 1) & 0x7fffffff;
        }
        shows[key] = id;
        final show = XtreamSeries(
          seriesId: id,
          playlistId: job.playlistId,
          name: ep.show,
          categoryId: entry.group,
          coverUrl: entry.logoUrl,
        );
        show.isFavorite = job.favoriteSeries.contains(show.id);
        _series.add(
            CatalogDatabase.seriesRow(entry.group, show, importMark: job.mark));
      }
      _episodes.add(CatalogDatabase.episodeRow(entry,
          seriesId: id,
          season: ep.season,
          episode: ep.episode,
          importMark: job.mark));
      episodes++;
    }
    return _vod.length + _series.length + _episodes.length >= _batch
        ? _write()
        : null;
  }

  /// The batch being written. The list is read on while it is (the
  /// plugin writes on its own thread): reading only waits when the next
  /// batch is ready before this one is stored.
  Future<void>? _writing;

  /// Time the read waited for a write, and time spent writing.
  final Stopwatch waitedForDb = Stopwatch();
  final Stopwatch writing = Stopwatch();

  Future<void> _write() async {
    final previous = _writing;
    if (previous != null) {
      waitedForDb.start();
      await previous;
      waitedForDb.stop();
    }
    if (_vod.isEmpty && _series.isEmpty && _episodes.isEmpty) return;
    final vod = _vod, series = _series, eps = _episodes;
    _vod = [];
    _series = [];
    _episodes = [];
    writing.start();
    final next = db
        .writeM3uRows(vod: vod, series: series, episodes: eps)
        .whenComplete(writing.stop);
    // Its error reaches the next [_write] / [flush], not the zone.
    next.ignore();
    _writing = next;
  }

  /// Stores what is left and waits for every write.
  Future<void> flush() async {
    await _write();
    final last = _writing;
    _writing = null;
    if (last != null) {
      waitedForDb.start();
      await last;
      waitedForDb.stop();
    }
  }

  /// Same renaming as [Channel.withUniqueIds], for entries that are never
  /// all in memory at once: a repeated tvg-id gets its link's file name.
  Channel _unique(Channel c) {
    if (c.rawId.startsWith('ch_') || _ids.add(c.id)) return c;
    final segments = Uri.tryParse(c.url)?.pathSegments ?? const <String>[];
    var key = segments.isEmpty ? '' : segments.last;
    final dot = key.lastIndexOf('.');
    if (dot > 0) key = key.substring(0, dot);
    final base = key.isEmpty ? '${c.rawId}#' : '${c.rawId}#$key';
    var raw = base;
    for (var n = 2; !_ids.add('${c.playlistId}::$raw'); n++) {
      raw = '$base~$n';
    }
    return c.copyWith(
        id: '${c.playlistId}::$raw', rawId: raw, epgKey: c.epgKey ?? c.rawId);
  }
}
