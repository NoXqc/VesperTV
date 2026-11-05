import 'dart:io';

import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/episode_airing.dart';
import '../models/xtream_series.dart';
import 'archive_service.dart';
import 'episode_air_date_service.dart';
import 'episode_alerts.dart';
import 'playlist_manager.dart';
import 'storage_service.dart';

/// Wires [EpisodeAlerts] to the app: how a followed show's newest episode is
/// found (IPTV: the provider's own episode list, so "available" means it
/// can be played here; Media Hub: the show's metadata, aired episodes only)
/// and how Android shows a system notification.
class EpisodeAlertLookup {
  EpisodeAlertLookup(this.storage, this.playlist, this.archive);

  final StorageService storage;
  final PlaylistManager playlist;
  final ArchiveService archive;

  static const _channel = MethodChannel('vespertv/notify');

  void attach(EpisodeAlerts alerts) {
    alerts.lookup = lookup;
    if (Platform.isAndroid) alerts.systemNotify = notify;
  }

  Future<EpisodeStatus?> lookup(FollowedShow show) =>
      show.isMediaHub ? _mediaHub(show) : _iptv(show);

  Future<EpisodeStatus?> _iptv(FollowedShow show) async {
    final playlistId = show.playlistId, seriesId = show.seriesId;
    if (playlistId == null || seriesId == null) return null;
    final series = XtreamSeries(
        seriesId: seriesId,
        playlistId: playlistId,
        name: show.title,
        categoryId: show.categoryId ?? '',
        coverUrl: show.posterUrl,
        tmdbId: show.tmdbId);
    final result = await playlist.loadSeriesEpisodes(series);
    // Playlist disabled or not loaded yet: no answer (not "no episodes").
    if (result.episodes.isEmpty) return null;
    final pairs = <(int, int)>[];
    (int, int)? best;
    String? bestTitle;
    for (final MapEntry(key: seasonKey, value: list)
        in result.episodes.entries) {
      for (final (i, c) in list.indexed) {
        final d = result.details?.episodes[c.id];
        final season = d?.season ?? seasonKey;
        if (season <= 0) continue;
        final number = d?.episodeNumber ?? i + 1;
        pairs.add((season, number));
        if (best == null ||
            compareEpisode(season, number, best.$1, best.$2) > 0) {
          best = (season, number);
          bestTitle = d?.title;
        }
      }
    }
    EpisodeAiring? next;
    try {
      next = await EpisodeAirDateService.instance.resolve(
          details: result.details,
          tmdbId: show.tmdbId,
          tmdbKey: storage.getTmdbApiKey() ?? '');
    } catch (_) {}
    return EpisodeStatus(
        season: best?.$1,
        episode: best?.$2,
        episodeTitle: bestTitle,
        next: _after(next, best),
        count: pairs);
  }

  Future<EpisodeStatus?> _mediaHub(FollowedShow show) async {
    final url = show.sourceUrl, raw = show.meta;
    if (url == null || raw == null) return null;
    ArchiveSource? source;
    for (final s in archive.sources) {
      if (s.manifestUrl == url) source = s;
    }
    final preview = ArchiveMeta.fromJson(raw);
    if (source == null || preview == null) return null;
    final meta = await archive.meta(source, preview);
    if (meta == null || meta.videos.isEmpty) return null;
    final now = DateTime.now();
    final pairs = <(int, int)>[];
    (int, int)? best;
    String? bestTitle;
    final upcoming = <EpisodeAiring>[];
    for (final v in meta.videos) {
      if (v.season <= 0 || v.episode <= 0) continue;
      final airing =
          EpisodeAiring.parse(v.released, season: v.season, episode: v.episode);
      if (airing != null && airing.unreleased(now)) {
        upcoming.add(airing);
        continue;
      }
      pairs.add((v.season, v.episode));
      if (best == null ||
          compareEpisode(v.season, v.episode, best.$1, best.$2) > 0) {
        best = (v.season, v.episode);
        bestTitle = v.title.isEmpty ? null : v.title;
      }
    }
    return EpisodeStatus(
        season: best?.$1,
        episode: best?.$2,
        episodeTitle: bestTitle,
        next: EpisodeAiring.next(upcoming, now),
        count: pairs);
  }

  /// A schedule only counts when it is after the newest available episode.
  static EpisodeAiring? _after(EpisodeAiring? next, (int, int)? best) {
    if (next == null || best == null) return next;
    final s = next.season, e = next.episode;
    if (s == null || e == null) return next;
    return compareEpisode(s, e, best.$1, best.$2) > 0 ? next : null;
  }

  Future<void> notify(EpisodeNotice notice) async {
    final text = notice.count > 1
        ? tr('{count} new episodes - {code} is available',
            {'count': '${notice.count}', 'code': notice.code})
        : tr('{code} is available', {'code': notice.code});
    await _channel.invokeMethod('episode', {
      'id': notice.showKey.hashCode & 0x7fffffff,
      'title': notice.title,
      'text': text,
      'channel': tr('New episodes'),
    });
  }

  /// Android 13+ asks for the notification permission once, when the viewer
  /// first taps Notify me.
  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }
}
