import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/episode_airing.dart';
import 'storage_service.dart';

/// A show the viewer asked to hear about ("Notify me" on its page): an IPTV
/// series (provider playlist + series id) or a Media Hub show (add-on
/// manifest + its meta preview). [lastSeason]/[lastEpisode] is the newest
/// episode already known; anything newer becomes an [EpisodeNotice].
class FollowedShow {
  FollowedShow({
    required this.key,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.playlistId,
    this.seriesId,
    this.categoryId,
    this.tmdbId,
    this.sourceUrl,
    this.meta,
    this.imdbId,
    this.lastSeason,
    this.lastEpisode,
    this.checkedAt,
    this.next,
  });

  final String key;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;

  // IPTV series.
  final String? playlistId;
  final int? seriesId;
  final String? categoryId;
  final String? tmdbId;

  // Media Hub show: the source's manifest URL and its preview meta (no
  // episode list).
  final String? sourceUrl;
  final Map<String, dynamic>? meta;
  final String? imdbId;

  int? lastSeason;
  int? lastEpisode;
  DateTime? checkedAt;

  /// The next scheduled episode, when the metadata knows one ("Airs in 5
  /// days" on Home).
  EpisodeAiring? next;

  bool get isMediaHub => sourceUrl != null;

  static String iptvKey(String playlistId, int seriesId) =>
      'iptv:$playlistId:$seriesId';
  static String hubKey(String sourceUrl, String metaId) =>
      'hub:$sourceUrl|$metaId';

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        if (posterUrl != null) 'poster': posterUrl,
        if (backdropUrl != null) 'backdrop': backdropUrl,
        if (playlistId != null) 'playlist': playlistId,
        if (seriesId != null) 'series': seriesId,
        if (categoryId != null) 'category': categoryId,
        if (tmdbId != null) 'tmdb': tmdbId,
        if (sourceUrl != null) 'src': sourceUrl,
        if (meta != null) 'meta': meta,
        if (imdbId != null) 'imdb': imdbId,
        if (lastSeason != null) 's': lastSeason,
        if (lastEpisode != null) 'e': lastEpisode,
        if (checkedAt != null) 'checked': checkedAt!.toIso8601String(),
        if (next != null) ...{
          'next': next!.dateOnly
              ? next!.date.toIso8601String().substring(0, 10)
              : next!.date.toUtc().toIso8601String(),
          if (next!.season != null) 'ns': next!.season,
          if (next!.episode != null) 'ne': next!.episode,
        },
      };

  static FollowedShow? fromJson(Object? j) {
    if (j is! Map) return null;
    final key = j['key']?.toString();
    final title = j['title']?.toString();
    if (key == null || title == null) return null;
    int? number(Object? v) => v is int ? v : int.tryParse('${v ?? ''}');
    return FollowedShow(
      key: key,
      title: title,
      posterUrl: j['poster']?.toString(),
      backdropUrl: j['backdrop']?.toString(),
      playlistId: j['playlist']?.toString(),
      seriesId: number(j['series']),
      categoryId: j['category']?.toString(),
      tmdbId: j['tmdb']?.toString(),
      sourceUrl: j['src']?.toString(),
      meta: j['meta'] is Map ? Map<String, dynamic>.from(j['meta']) : null,
      imdbId: j['imdb']?.toString(),
      lastSeason: number(j['s']),
      lastEpisode: number(j['e']),
      checkedAt: DateTime.tryParse('${j['checked'] ?? ''}'),
      next: EpisodeAiring.parse(j['next']?.toString(),
          season: number(j['ns']), episode: number(j['ne'])),
    );
  }
}

/// "Show ABC - S1 E3 is available": one per show (a newer one replaces it),
/// until the viewer opens the show or dismisses it.
class EpisodeNotice {
  const EpisodeNotice({
    required this.showKey,
    required this.title,
    required this.season,
    required this.episode,
    required this.at,
    this.count = 1,
    this.episodeTitle,
  });

  final String showKey;
  final String title;
  final int season;
  final int episode;
  final DateTime at;

  /// New episodes since the last known one (a whole season dropped at once).
  final int count;
  final String? episodeTitle;

  String get code => 'S$season E$episode';

  Map<String, dynamic> toJson() => {
        'show': showKey,
        'title': title,
        's': season,
        'e': episode,
        'at': at.toIso8601String(),
        if (count > 1) 'n': count,
        if (episodeTitle != null) 'et': episodeTitle,
      };

  static EpisodeNotice? fromJson(Object? j) {
    if (j is! Map) return null;
    final show = j['show']?.toString();
    final title = j['title']?.toString();
    final s = j['s'], e = j['e'];
    final at = DateTime.tryParse('${j['at'] ?? ''}');
    if (show == null || title == null || s is! int || e is! int || at == null) {
      return null;
    }
    return EpisodeNotice(
        showKey: show,
        title: title,
        season: s,
        episode: e,
        at: at,
        count: j['n'] is int ? j['n'] : 1,
        episodeTitle: j['et']?.toString());
  }
}

/// What a lookup found for a show right now.
class EpisodeStatus {
  const EpisodeStatus(
      {this.season, this.episode, this.episodeTitle, this.next, this.count});

  /// Newest episode available to watch (season 0 specials ignored).
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final EpisodeAiring? next;

  /// Available (season, episode) pairs, to count how many are new.
  final List<(int, int)>? count;
}

int compareEpisode(int s1, int e1, int s2, int e2) =>
    s1 != s2 ? s1.compareTo(s2) : e1.compareTo(e2);

/// "Notify me" for TV shows (IPTV and Media Hub), per viewer. Checks the
/// followed shows at launch and every few hours while the app runs; a newer
/// episode becomes a Home card and, on Android, a system notification.
/// Lookups are wired in by `main.dart` ([lookup]); this class only keeps
/// the list, the baselines and the notices.
class EpisodeAlerts extends ChangeNotifier {
  EpisodeAlerts(this.storage, {DateTime Function()? now})
      : now = now ?? DateTime.now {
    loadViewer();
  }

  final StorageService storage;
  final DateTime Function() now;

  /// Shows are re-checked at most this often (a launch inside it skips).
  static const checkEvery = Duration(hours: 3);

  Future<EpisodeStatus?> Function(FollowedShow show)? lookup;

  /// Android system notification (phone shade / TV); null elsewhere.
  Future<void> Function(EpisodeNotice notice)? systemNotify;

  /// Headless Android commits use a guarded compare-and-set against the disk
  /// snapshot. A foreground launch invalidates that worker's right to commit.
  Future<void> Function(String viewerId, String data)? persist;
  Future<bool> Function()? canCheck;
  Future<void> Function()? beforeCheck;

  static bool isDue(FollowedShow show, DateTime now) =>
      show.checkedAt == null || now.difference(show.checkedAt!) >= checkEvery;

  /// Refresh after another engine has written while the app was stopped.
  Future<void> refreshFromDisk() async {
    await _write;
    final revision = _revision;
    await storage.reloadPreferences();
    if (!_disposed && revision == _revision) {
      loadViewer(force: true);
      _changed();
    }
  }

  int _revision = 0;

  final Map<String, FollowedShow> _shows = {};
  final Map<String, EpisodeNotice> _notices = {};
  String? viewerId;
  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;
  Future<void> _write = Future.value();

  List<FollowedShow> get shows {
    loadViewer();
    return _shows.values.toList();
  }

  /// Newest first.
  List<EpisodeNotice> get notices {
    loadViewer();
    return _notices.values.toList()..sort((a, b) => b.at.compareTo(a.at));
  }

  FollowedShow? show(String key) {
    loadViewer();
    return _shows[key];
  }

  bool isFollowing(String key) {
    loadViewer();
    return _shows.containsKey(key);
  }

  void loadViewer({bool force = false}) {
    final id = storage.getActiveViewerId();
    if (!force && viewerId == id) return;
    viewerId = id;
    _shows.clear();
    _notices.clear();
    try {
      final raw = jsonDecode(storage.getEpisodeAlerts(viewerId: id) ?? '{}');
      if (raw is Map) {
        for (final s in raw['shows'] as List? ?? const []) {
          if (FollowedShow.fromJson(s) case final show?) {
            _shows[show.key] = show;
          }
        }
        for (final n in raw['notices'] as List? ?? const []) {
          if (EpisodeNotice.fromJson(n) case final notice?
              when _shows.containsKey(notice.showKey)) {
            _notices[notice.showKey] = notice;
          }
        }
      }
    } catch (_) {/* A stale/corrupt preference must not prevent startup. */}
  }

  Future<void> _save() {
    final viewer = viewerId;
    final data = jsonEncode({
      'shows': [for (final s in _shows.values) s.toJson()],
      'notices': [for (final n in _notices.values) n.toJson()],
    });
    _write = _write.catchError((Object _) {}).then((_) async {
      if (persist case final save?) {
        await save(viewer!, data);
      } else {
        await storage.setEpisodeAlerts(data, viewerId: viewer);
      }
    });
    return _write;
  }

  void _changed() {
    _revision++;
    if (!_disposed) notifyListeners();
  }

  /// Follows [show]; its current newest episode (looked up now) is the
  /// baseline, so only later ones alert.
  Future<void> follow(FollowedShow show) async {
    loadViewer();
    _shows[show.key] = show;
    _changed();
    await _save();
    unawaited(_check(show, silent: true));
  }

  Future<void> unfollow(String key) async {
    loadViewer();
    _shows.remove(key);
    _notices.remove(key);
    _changed();
    await _save();
  }

  /// The viewer opened the show or dismissed its card.
  Future<void> dismiss(String key) async {
    if (_notices.remove(key) == null) return;
    _changed();
    await _save();
  }

  /// Checks at launch (after the app has settled), then every [checkEvery].
  void start() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 20), () {
      unawaited(checkAll());
      _timer = Timer.periodic(checkEvery, (_) => unawaited(checkAll()));
    });
  }

  Future<void> checkAll({bool force = false}) async {
    if (_checking || lookup == null || _disposed) return;
    _checking = true;
    try {
      await beforeCheck?.call();
      loadViewer();
      final viewer = viewerId;
      for (final show in _shows.values.toList()) {
        if (_disposed || viewer != storage.getActiveViewerId()) return;
        if (canCheck != null && !await canCheck!()) return;
        if (!force && !isDue(show, now())) continue;
        await _check(show);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _check(FollowedShow show, {bool silent = false}) async {
    final viewer = viewerId;
    EpisodeStatus? status;
    try {
      status = await lookup?.call(show);
    } catch (e) {
      debugPrint('EpisodeAlerts: ${show.title}: $e');
    }
    if (_disposed ||
        viewer != storage.getActiveViewerId() ||
        !identical(_shows[show.key], show) ||
        status == null) {
      return;
    }
    if (canCheck != null && !await canCheck!()) return;
    if (_disposed ||
        viewer != storage.getActiveViewerId() ||
        !identical(_shows[show.key], show)) {
      return;
    }
    show.checkedAt = now();
    show.next = status.next;
    EpisodeNotice? pending;
    final s = status.season, e = status.episode;
    if (s != null && e != null) {
      final known = show.lastSeason != null && show.lastEpisode != null;
      final newer = known &&
          compareEpisode(s, e, show.lastSeason!, show.lastEpisode!) > 0;
      if (newer && !silent) {
        final count = status.count
                ?.where((p) =>
                    compareEpisode(
                        p.$1, p.$2, show.lastSeason!, show.lastEpisode!) >
                    0)
                .length ??
            1;
        final notice = EpisodeNotice(
            showKey: show.key,
            title: show.title,
            season: s,
            episode: e,
            at: now(),
            count: count < 1 ? 1 : count,
            episodeTitle: status.episodeTitle);
        _notices[show.key] = notice;
        pending = notice;
      }
      if (!known || newer) {
        show.lastSeason = s;
        show.lastEpisode = e;
      }
    }
    _changed();
    // Persist the baseline before notifying, so a new engine cannot repeat it.
    await _save();
    if (pending != null && !_disposed) {
      try {
        await systemNotify?.call(pending);
      } catch (_) {
        /* The Home notice remains when OS notification is denied. */
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
