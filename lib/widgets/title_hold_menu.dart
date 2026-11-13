import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/channel.dart';
import '../models/series_details.dart';
import '../models/xtream_series.dart';
import '../services/archive_service.dart';
import '../services/playlist_manager.dart';
import '../services/storage_service.dart';
import '../services/tracker_api.dart';
import '../services/tracker_sync.dart';
import 'glass_menu.dart';
import 'hold_to_activate.dart';
import 'tv_dialog_option.dart';

/// Hold OK on a movie / show poster (Movies, TV Shows, Expand catalog,
/// Search, Media Hub): favourite plus watched / unwatched. Holding used to
/// toggle the favourite at once, and only episodes (on the show page) could
/// be marked watched (owner, 2026-11-13).
enum TitleHoldAction { favorite, watched, unwatched }

/// [watched] is the movie's state; null for a show, which offers both
/// (whether every episode is watched isn't known before loading them).
Future<TitleHoldAction?> showTitleHoldMenu(
  BuildContext context, {
  required String title,
  required bool isFavorite,
  bool? watched,
}) {
  final show = watched == null;
  return showGlassMenu<TitleHoldAction>(
    context: context,
    builder: (ctx) => SwallowHeldActivate(
      child: GlassMenuDialog(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, TitleHoldAction.favorite),
            child: Text(isFavorite
                ? tr('Remove from Favourites')
                : tr('Add to Favourites')),
          ),
          if (show || watched == false)
            TvDialogOption(
              onPressed: () => Navigator.pop(ctx, TitleHoldAction.watched),
              child: Text(show
                  ? tr('Mark every episode watched')
                  : tr('Mark as watched')),
            ),
          if (show || watched == true)
            TvDialogOption(
              onPressed: () => Navigator.pop(ctx, TitleHoldAction.unwatched),
              child: Text(show
                  ? tr('Mark every episode unwatched')
                  : tr('Mark as unwatched')),
            ),
          TvDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    ),
  );
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

/// Marks one IPTV movie (or M3U title) watched / unwatched here and on
/// Trakt / Simkl (by the provider's TMDB id).
Future<void> setMovieWatched(BuildContext context, Channel movie,
    {required bool watched}) async {
  final storage = context.read<StorageService>();
  final tmdb = movie.tmdbId;
  if (tmdb != null && tmdb.isNotEmpty) {
    unawaited(TrackerSync.instance
        .setWatched(TrackedItem.movie(null, tmdb: tmdb), watched: watched));
  }
  await TrackerSync.setLocalWatched(storage, movie.id, watched: watched);
  if (context.mounted) {
    _toast(
        context, watched ? tr('Marked as watched') : tr('Marked as unwatched'));
  }
}

/// Every episode of an IPTV show (loads them first, like the show page).
Future<void> setSeriesWatched(BuildContext context, XtreamSeries series,
    {required bool watched}) async {
  final storage = context.read<StorageService>();
  final playlist = context.read<PlaylistManager>();
  final SeriesEpisodesResult result;
  try {
    result = await playlist.loadSeriesEpisodes(series);
  } catch (_) {
    if (context.mounted) _toast(context, tr("Couldn't load the episodes"));
    return;
  }
  final details = result.details?.episodes ?? const {};
  final perSeason = <int, List<int>>{};
  var n = 0;
  for (final entry in result.episodes.entries) {
    for (final e in entry.value) {
      final d = details[e.id];
      await TrackerSync.setLocalWatched(storage, e.id,
          watched: watched, durationSeconds: d?.durationSeconds ?? 0);
      n++;
      if (d?.episodeNumber case final number?) {
        (perSeason[d!.season] ??= []).add(number);
      }
    }
  }
  final tmdb = series.tmdbId;
  if (tmdb != null && tmdb.isNotEmpty) {
    for (final s in perSeason.entries) {
      unawaited(TrackerSync.instance.setSeasonWatched(
          TrackedItem.movie(null, tmdb: tmdb), s.key, s.value,
          watched: watched));
    }
  }
  if (context.mounted) _episodesToast(context, n, watched);
}

/// A Media Hub movie, or every episode of a Media Hub show.
Future<void> setHubTitleWatched(
    BuildContext context, ArchiveSource source, ArchiveMeta meta,
    {required bool watched}) async {
  final storage = context.read<StorageService>();
  final service = context.read<ArchiveService>();
  final imdb = meta.imdb;
  if (meta.type != ArchiveType.series) {
    if (imdb != null) {
      unawaited(TrackerSync.instance
          .setWatched(TrackedItem.movie(imdb), watched: watched));
    }
    await TrackerSync.setLocalWatched(
        storage, ArchiveService.channelId(source, meta.id, episode: false),
        watched: watched);
    if (context.mounted) {
      _toast(context,
          watched ? tr('Marked as watched') : tr('Marked as unwatched'));
    }
    return;
  }
  final full = await service.meta(source, meta);
  final videos = full?.videos ?? const <ArchiveVideo>[];
  if (videos.isEmpty) {
    if (context.mounted) _toast(context, tr("Couldn't load the episodes"));
    return;
  }
  final perSeason = <int, List<int>>{};
  for (final v in videos) {
    await TrackerSync.setLocalWatched(
        storage, ArchiveService.channelId(source, v.id, episode: true),
        watched: watched);
    if (v.season > 0 && v.episode > 0) {
      (perSeason[v.season] ??= []).add(v.episode);
    }
  }
  if (imdb != null) {
    for (final s in perSeason.entries) {
      unawaited(TrackerSync.instance.setSeasonWatched(
          TrackedItem.movie(imdb), s.key, s.value,
          watched: watched));
    }
  }
  if (context.mounted) _episodesToast(context, videos.length, watched);
}

void _episodesToast(BuildContext context, int n, bool watched) => _toast(
    context,
    tr(
        watched
            ? '{count} episodes marked as watched'
            : '{count} episodes marked as unwatched',
        {'count': n}));

/// The whole hold for a Media Hub poster: the menu, then the favourite
/// toggle or the watched mark.
Future<void> holdHubTitleMenu(
    BuildContext context, ArchiveSource source, ArchiveMeta meta) async {
  final service = context.read<ArchiveService>();
  final storage = context.read<StorageService>();
  final movie = meta.type != ArchiveType.series;
  final action = await showTitleHoldMenu(context,
      title: meta.name,
      isFavorite: service.isFavorite(source, meta),
      watched: movie
          ? storage.isFullyWatched(
              ArchiveService.channelId(source, meta.id, episode: false))
          : null);
  if (!context.mounted || action == null) return;
  if (action == TitleHoldAction.favorite) {
    final added = await service.toggleFavorite(source, meta);
    if (context.mounted) {
      _toast(context,
          added ? tr('Added to Favorites') : tr('Removed from Favorites'));
    }
    return;
  }
  await setHubTitleWatched(context, source, meta,
      watched: action == TitleHoldAction.watched);
}
