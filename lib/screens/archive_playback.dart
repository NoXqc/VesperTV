import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/channel.dart';
import '../models/series_details.dart';
import '../models/xtream_series.dart';
import '../services/archive_service.dart';
import '../services/archive_playback_sources.dart';
import '../services/archive_resume_source.dart';
import '../services/archive_stream_size.dart';
import '../services/storage_service.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import '../services/tracker_api.dart';
import '../services/archive_ready_watch.dart';
import '../services/stream_resolver.dart';
import '../services/watch_tracker.dart';
import '../widgets/tv_menu_tile.dart';
import '../widgets/roll_down_menu.dart';
import 'desktop_player_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'youtube_playback.dart';

/// Starting playback of Archive titles, shared by the movie page
/// (`ArchiveDetailScreen`) and Archive shows, which open the regular
/// [SeriesDetailScreen] through [openArchiveSeries].
///
/// Play asks the source(s) for every direct stream: one plays at once,
/// several open [pickArchiveStream]. An episode's queue (Next, auto-
/// advance) holds placeholder channels without a URL; the resolver handed
/// to the player looks the next one's streams up when it's due and keeps
/// to the pick made here — same source, same stream name (quality) when
/// it has one — via [preferredArchiveStream].

/// The stream list for a title with several: each row shows the stream's
/// `name` (source, quality) over its `title` (file, size, language). Null
/// when dismissed with Back.
Future<ArchiveStreamOption?> pickArchiveStream(
    BuildContext context, List<ArchiveStreamOption> options) {
  final manySources =
      options.map((o) => o.source.manifestUrl).toSet().length > 1;
  return showModalBottomSheet<ArchiveStreamOption>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    isScrollControlled: true,
    constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8, maxWidth: 760),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(tr('Choose a stream'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final o = options[i];
                final name = o.stream.name ??
                    o.stream.title?.split('\n').first ??
                    tr('Stream {n}', {'n': i + 1});
                final details = [
                  if (o.stream.name != null && o.stream.title != null)
                    o.stream.title!,
                  if (manySources) o.source.name,
                ].join('\n');
                return TvMenuTile(
                  autofocus: i == 0,
                  icon: Icons.play_circle_outline,
                  title: name,
                  titleMaxLines: 2,
                  subtitle: details.isEmpty ? null : details,
                  onTap: () => Navigator.of(sheetContext).pop(o),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// The option of [options] closest to [previous]: same source and same
/// stream name, else the same source's first, else the first of all.
ArchiveStreamOption preferredArchiveStream(
    List<ArchiveStreamOption> options, ArchiveStreamOption? previous) {
  if (previous == null) return options.first;
  final sameSource = options
      .where((o) => o.source.manifestUrl == previous.source.manifestUrl)
      .toList();
  final name = previous.stream.name;
  if (name != null) {
    for (final o in sameSource) {
      if (o.stream.name == name) return o;
    }
  }
  return sameSource.firstOrNull ?? options.first;
}

/// The link the player gets: an add-on stream's redirect chain followed
/// once ([resolveRedirects] — every request the player makes for a big file
/// then goes straight to the CDN). A media server's link is direct already.
/// [_track] keeps the original link: `ArchiveReadyWatch` must re-ask the
/// add-on, not the "being downloaded" clip it redirected to.
Future<String> _playUrl(ArchiveStreamOption o) => o.source.server != null
    ? Future.value(o.stream.url)
    : resolveRedirects(o.stream.url);

/// Lets the players report this title to Trakt/Simkl (by IMDb id; titles
/// without one aren't reported). See `WatchTracker`. Also lets them tell a
/// source's "being downloaded" clip from the title (`ArchiveReadyWatch`).
void _track(Channel channel, ArchiveMeta meta, ArchiveVideo? episode) {
  ArchiveReadyWatch.instance
      .register(channel.id, metaId: meta.id, url: channel.url);
  final imdb = meta.imdb;
  if (imdb == null) return;
  WatchTracker.instance.register(
      channel.id,
      episode == null
          ? TrackedItem.movie(imdb)
          : TrackedItem.episode(imdb,
              season: episode.season, episode: episode.episode));
}

void _noStream(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(tr('No playable stream for this title.')),
    backgroundColor: Colors.red.shade900,
  ));
}

/// Looks up [meta]'s (or its [episode]'s) streams, lets the user pick when
/// there are several, and plays it. With [queue] (every episode, in order,
/// as placeholders) and [videosById] (their [ArchiveVideo]s by channel id)
/// the player's Next / auto-advance continue with the same source.
Future<void> playArchiveTitle(
  BuildContext context, {
  required ArchiveSource source,
  required ArchiveMeta meta,
  ArchiveVideo? episode,
  List<Channel>? queue,
  Map<String, ArchiveVideo> videosById = const {},
}) async {
  final service = context.read<ArchiveService>();
  final playback = context.read<PlaybackService>();
  final storage = context.read<StorageService>();
  final resumeSource = ArchiveResumeSource(
      storage,
      service
          .channelFor(source, meta, const ArchiveStream(), episode: episode)
          .id);
  List<ArchiveStreamOption> options;
  try {
    options = await service.streams(source, meta, episode: episode);
  } catch (_) {
    options = const [];
  }
  if (!context.mounted) return;
  if (options.isEmpty) return _noStream(context);
  final restored = await resumeSource.restore(options);
  if (!context.mounted || !resumeSource.isCurrent) {
    return;
  }
  options = restored.options;
  if (options.isEmpty) return _noStream(context);
  // Resume the exact prior choice; absent/unavailable choices use the picker.
  var picked = restored.picked ??
      (storage.getArchiveAutoLargest()
          ? largestArchiveStream(options)
          : null) ??
      (options.length == 1
          ? options.single
          : await pickArchiveStream(context, options));
  if (picked == null || !context.mounted || !resumeSource.isCurrent) {
    return;
  }
  if (picked.stream.ytId case final video?) {
    await playYouTubeVideo(context, video, meta.name,
        mediaFileInfo: archiveMediaFileInfo(picked));
    return;
  }
  final tracked = service
      .channelFor(source, meta, picked.stream, episode: episode)
      .copyWith(mediaFileInfo: archiveMediaFileInfo(picked));
  _track(tracked, meta, episode);
  final channel = tracked.copyWith(url: restored.url ?? await _playUrl(picked));
  try {
    await resumeSource.remember(picked);
  } catch (_) {/* Playback still works if preferences cannot be written. */}
  if (!context.mounted || !resumeSource.isCurrent) {
    return;
  }
  // Extras' "Recently watched" row (the show, for an episode).
  unawaited(service.recordWatched(source, meta));

  final selectedStreams = <String, ArchiveStreamOption>{channel.id: picked};

  Future<Channel?> resolve(Channel placeholder) async {
    final video = videosById[placeholder.id];
    if (video == null || !resumeSource.isCurrent) return null;
    final next = await service.streams(source, meta, episode: video);
    if (next.isEmpty) return null;
    final nextResume = ArchiveResumeSource(storage, placeholder.id);
    final restoredNext = await nextResume.restore(next);
    if (!nextResume.isCurrent || restoredNext.options.isEmpty) return null;
    final o = restoredNext.picked ??
        (storage.getArchiveAutoLargest()
            ? largestArchiveStream(restoredNext.options)
            : null) ??
        preferredArchiveStream(restoredNext.options, picked);
    await nextResume.remember(o);
    if (o.stream.ytId != null) return null;
    picked = o; // the episode after follows this one
    selectedStreams[placeholder.id] = o;
    final ch = service
        .channelFor(source, meta, o.stream, episode: video)
        .copyWith(mediaFileInfo: archiveMediaFileInfo(o));
    _track(ch, meta, video);
    return ch.copyWith(url: restoredNext.url ?? await _playUrl(o));
  }

  bool belongs(String id) => id == channel.id || videosById.containsKey(id);
  ArchiveVideo? videoFor(String id) => videosById[id] ?? episode;
  final sources = ArchivePlaybackSources(
    load: (id) async {
      if (!belongs(id) || !resumeSource.isCurrent) return const [];
      final streams =
          await service.streams(source, meta, episode: videoFor(id));
      return resumeSource.isCurrent ? streams : const [];
    },
    current: (id) => selectedStreams[id],
    select: (id, option) async {
      if (!belongs(id) || !resumeSource.isCurrent) return null;
      final url = await _playUrl(option);
      if (!resumeSource.isCurrent) return null;
      return service
          .channelFor(source, meta, option.stream, episode: videoFor(id))
          .copyWith(url: url, mediaFileInfo: archiveMediaFileInfo(option));
    },
    remember: (id, option) async {
      if (!belongs(id) || !resumeSource.isCurrent) return;
      selectedStreams[id] = option;
      picked = option; // subsequent episodes follow this source/quality
      final tracked = service.channelFor(source, meta, option.stream,
          episode: videoFor(id));
      _track(tracked, meta, videoFor(id));
      try {
        await ArchiveResumeSource(storage, id).remember(option);
      } catch (_) {/* A preference failure must not prevent playback. */}
    },
  );

  final hasQueue = queue != null && queue.isNotEmpty;
  // Same split as MovieDetailScreen._play: Windows has its own player.
  if (Platform.isWindows) {
    DesktopMiniPlayer.instance.clear();
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DesktopPlayerScreen(
              channel: channel,
              sources: sources,
              queue: hasQueue ? queue : null,
              resolveQueued: hasQueue ? resolve : null,
            )));
  } else {
    playback.setUpNextQueue(hasQueue ? queue : null,
        resolve: hasQueue ? resolve : null);
    // Awaited so PlayerScreen's own play() doesn't race this one (see
    // TvHomeScreen._selectChannel).
    await playback.play(channel);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlayerScreen(channel: channel, sources: sources)));
  }
}

/// Opens an Archive show on the regular [SeriesDetailScreen]: the meta
/// (provider's or the source's own) becomes its episodes and details, and
/// Play goes through [playArchiveTitle] with the whole show as the queue.
Future<void> openArchiveSeries(
    BuildContext context, ArchiveSource source, ArchiveMeta preview) {
  final service = context.read<ArchiveService>();
  var meta = preview;
  final videosById = <String, ArchiveVideo>{};

  Future<SeriesEpisodesResult> load() async {
    meta = await service.meta(source, preview) ?? preview;
    final episodes = <int, List<Channel>>{};
    final details = <String, EpisodeDetails>{};
    videosById.clear();
    for (final v in meta.videos) {
      final placeholder = service
          .channelFor(source, meta, const ArchiveStream(url: ''), episode: v);
      videosById[placeholder.id] = v;
      episodes.putIfAbsent(v.season, () => []).add(placeholder);
      details[placeholder.id] = EpisodeDetails(
        season: v.season,
        episodeNumber: v.episode,
        title: v.title.isEmpty ? null : v.title,
        plot: v.overview,
        airDate: v.released,
      );
    }
    final runtime =
        int.tryParse(RegExp(r'\d+').firstMatch(meta.runtime ?? '')?[0] ?? '');
    return (
      episodes: episodes,
      plot: meta.description,
      details: SeriesDetails(
        trailers: source.suppliesOwnMetadata ? meta.trailers : const [],
        trailerStreams:
            source.suppliesOwnMetadata ? meta.trailerStreams : const [],
        backdropUrls: [if (meta.backgroundUrl != null) meta.backgroundUrl!],
        coverUrl: meta.posterUrl,
        genre: meta.genres.isEmpty ? null : meta.genres.join(', '),
        cast: meta.cast.isEmpty ? null : meta.cast.join(', '),
        director: meta.director.isEmpty ? null : meta.director.join(', '),
        releaseDate: meta.year,
        rating: meta.rating,
        episodeRunTimeMinutes: runtime,
        episodes: details,
      ),
    );
  }

  Future<void> play(Channel episode, List<Channel> all) async {
    final video = videosById[episode.id];
    if (video == null) return;
    await playArchiveTitle(context,
        source: source,
        meta: meta,
        episode: video,
        queue: all,
        videosById: videosById);
  }

  return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(
            series: XtreamSeries(
              seriesId: 0,
              playlistId: ArchiveService.playlistId,
              name: preview.name,
              categoryId: ArchiveService.playlistId,
              coverUrl: preview.posterUrl,
              posterUrl: preview.posterUrl,
              backdropUrl: preview.backgroundUrl,
            ),
            loadEpisodes: load,
            playEpisode: play,
            showFavorite: false,
            imdbId: preview.imdb,
            sourceLabel: source.name,
          )));
}

/// Hold OK on a Media Hub title: Recently watched = out of the history,
/// any other row = into / out of Favourites (with a short confirmation).
Future<void> holdArchiveTitle(BuildContext context, ArchiveRow row,
    ArchiveSource source, ArchiveMeta meta) async {
  final service = context.read<ArchiveService>();
  if (row.isHistory) {
    final confirmed = await showRollDownMenu<bool>(context,
        anchor: Rect.fromLTWH(MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height * .3, 0, 0),
        centered: true,
        width: 380,
        title: tr('Remove "{title}" from history?', {'title': meta.name}),
        items: [
          RollDownMenuItem(
              value: false,
              icon: Icons.close,
              label: tr('Cancel'),
              selected: true),
          RollDownMenuItem(
              value: true,
              icon: Icons.history,
              label: tr('Remove from history')),
        ]);
    if (confirmed == true && context.mounted) {
      await service.removeFromHistory(source, meta);
    }
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final added = await service.toggleFavorite(source, meta);
  messenger.showSnackBar(SnackBar(
    content:
        Text(added ? tr('Added to Favorites') : tr('Removed from Favorites')),
    duration: const Duration(seconds: 2),
  ));
}
