import '../widgets/archive_discovery_panel.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/archive_library.dart';
import '../models/channel.dart';
import '../models/series_details.dart';
import '../models/xtream_series.dart';
import '../services/archive_service.dart';
import '../services/episode_alerts.dart';
import '../services/missing_episodes.dart';
import '../services/archive_playback_sources.dart';
import '../services/archive_resume_source.dart';
import '../services/archive_stream_size.dart';
import '../services/storage_service.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import '../services/recording_service.dart';
import '../services/tracker_api.dart';
import '../services/archive_ready_watch.dart';
import '../services/stream_resolver.dart';
import '../services/watch_tracker.dart';
import '../services/vesper_ai/watch_list.dart';
import '../widgets/archive_stream_picker.dart';
import '../services/archive_stream_session.dart';
import '../services/archive_playback_preferences.dart';
import '../services/stream_headers.dart';
import '../widgets/roll_down_menu.dart';
import 'desktop_player_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'youtube_playback.dart';
import '../utils/desktop_platform.dart';

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
        BuildContext context, List<ArchiveStreamOption> options,
        {ArchiveStreamSession? session,
        Future<ArchiveStreamOption?> Function(List<ArchiveStreamOption>)?
            autoSelect,
        ValueListenable<String?>? notice}) =>
    showModalBottomSheet<ArchiveStreamOption>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8, maxWidth: 900),
        builder: (_) => ArchiveStreamPicker(
            options: options,
            session: session,
            autoSelect: autoSelect,
            notice: notice));

/// The option of [options] closest to [previous]: same source and same
/// stream name, else the same source's first, else the first of all.
ArchiveStreamOption preferredArchiveStream(
    List<ArchiveStreamOption> options, ArchiveStreamOption? previous) {
  if (previous == null) return options.first;
  final sameSource = options
      .where((o) => o.source.manifestUrl == previous.source.manifestUrl)
      .toList();
  final group = previous.stream.bingeGroup;
  if (group != null && group.isNotEmpty) {
    for (final o in sameSource) {
      if (o.stream.bingeGroup == group) return o;
    }
  }
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
Future<ResolvedLink> _resolve(ArchiveStreamOption o) => o.source.server != null
    ? Future.value(ResolvedLink(o.stream.url))
    : resolveLink(o.stream.url, headers: o.stream.requestHeaders);

/// [archiveProviderFailed]: the link answered with the provider's error
/// clip. Said plainly instead of playing a clip that looks like our error.
void _providerFailed(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:
        Text(tr('This link failed at the provider. Choose another stream.')),
    backgroundColor: Colors.red.shade900,
  ));
}

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

/// Looks up [meta]'s (or its [episode]'s) streams, lets the user pick when
/// there are several, and plays it. With [queue] (every episode, in order,
/// as placeholders) and [videosById] (their [ArchiveVideo]s by channel id)
/// the player's Next / auto-advance continue with the same source.
/// [chosen] plays that stream without the list (Vesper AI's media_hub).
Future<void> playArchiveTitle(
  BuildContext context, {
  required ArchiveSource source,
  required ArchiveMeta meta,
  ArchiveVideo? episode,
  List<Channel>? queue,
  Map<String, ArchiveVideo> videosById = const {},
  ArchiveStreamOption? chosen,
}) async {
  final service = context.read<ArchiveService>();
  final playback = context.read<PlaybackService>();
  final storage = context.read<StorageService>();
  final resumeSource = ArchiveResumeSource(
      storage,
      service
          .channelFor(source, meta, const ArchiveStream(), episode: episode)
          .id);
  final session = service.searchStreams(source, meta, episode: episode);
  ArchiveResumeChoice? savedChoice;
  final notice = ValueNotifier<String?>(null);
  var picked = chosen ??
      await pickArchiveStream(context, session.options,
          session: session, notice: notice, autoSelect: (options) async {
        if (!resumeSource.isCurrent) return null;
        savedChoice = await resumeSource.restore(options);
        if (!resumeSource.isCurrent) return null;
        final usable = savedChoice!.options;
        for (final option in options) {
          if (!usable.contains(option)) session.exclude(option);
        }
        // Resuming a stream the user picked that can't be found again: ask,
        // don't guess (the largest file looked like the app ignored the pick,
        // LOG-3NEYPN; owner, 2026-11-07).
        if (savedChoice!.picked == null &&
            const {
              ArchiveResumeReason.unmatched,
              ArchiveResumeReason.unavailable,
              ArchiveResumeReason.missingSource,
            }.contains(savedChoice!.reason)) {
          notice.value = tr(
              "Couldn't replay the stream you picked. Choose one to resume.");
          return null;
        }
        final prefs = ArchivePlaybackPreferences.read(storage);
        // Largest file before Auto-play: the narrower choice wins, as in
        // hubBestStream (an AI app's "best").
        return savedChoice!.picked ??
            (storage.getArchiveAutoLargest()
                ? largestArchiveStream(prefs.bestLanguage(prefs.ranked(usable)))
                : null) ??
            (prefs.autoPlay ? prefs.ranked(usable).firstOrNull : null) ??
            (usable.length == 1 && prefs.ranked(usable).isNotEmpty
                ? usable.single
                : null);
      });
  notice.dispose();
  if (picked == null || !context.mounted || !resumeSource.isCurrent) return;
  var options = session.options;
  final restored = savedChoice ??
      ArchiveResumeChoice(options, reason: ArchiveResumeReason.notResuming);
  String? resolvedUrl =
      identical(restored.picked, picked) ? restored.url : null;
  Map<String, String>? resolvedHeaders;
  // A link that failed at the provider: say so and offer the others.
  while (resolvedUrl == null && picked!.stream.ytId == null) {
    final link = await _resolve(picked);
    if (!context.mounted || !resumeSource.isCurrent) return;
    if (!archiveProviderFailed(picked, link.url, link.totalBytes)) {
      resolvedUrl = link.url;
      resolvedHeaders = link.headers;
      break;
    }
    _providerFailed(context);
    session.exclude(picked);
    options = session.options;
    if (options.isEmpty && !session.loading) return;
    picked = await pickArchiveStream(context, options, session: session);
    if (picked == null || !context.mounted || !resumeSource.isCurrent) {
      return;
    }
  }
  final first = picked!;
  if (first.stream.ytId case final video?) {
    await playYouTubeVideo(context, video, meta.name,
        mediaFileInfo: archiveMediaFileInfo(first));
    return;
  }
  final tracked = service
      .channelFor(source, meta, first.stream, episode: episode)
      .copyWith(mediaFileInfo: archiveMediaFileInfo(first));
  _track(tracked, meta, episode);
  final channel = tracked.copyWith(
      url: resolvedUrl,
      httpHeaders: resolvedHeaders ??
          redirectedStreamHeaders(
              first.stream.requestHeaders,
              Uri.parse(first.stream.url),
              Uri.parse(resolvedUrl ?? first.stream.url)));
  resumeSource.traceChoice(restored, first,
      resolvedUrl: channel.url,
      via: identical(chosen, first)
          ? 'ai'
          : restored.picked != null
              ? 'resume'
              : storage.getArchiveAutoLargest() &&
                      identical(largestArchiveStream(options), first)
                  ? 'largest'
                  : options.length == 1
                      ? 'single'
                      : 'picker');
  try {
    await resumeSource.remember(first);
  } catch (_) {/* Playback still works if preferences cannot be written. */}
  if (!context.mounted || !resumeSource.isCurrent) {
    return;
  }
  // Extras' "Recently watched" row (the show, for an episode).
  unawaited(service.recordWatched(source, meta, episode: episode));

  final selectedStreams = <String, ArchiveStreamOption>{channel.id: first};

  Future<Channel?> resolve(Channel placeholder) async {
    final video = videosById[placeholder.id];
    if (video == null || !resumeSource.isCurrent) return null;
    final next = await service.streams(source, meta, episode: video);
    if (next.isEmpty) return null;
    final nextResume = ArchiveResumeSource(storage, placeholder.id);
    final restoredNext = await nextResume.restore(next);
    if (!nextResume.isCurrent || restoredNext.options.isEmpty) return null;
    final prefs = ArchivePlaybackPreferences.read(storage);
    final acceptable = prefs.ranked(restoredNext.options);
    ArchiveStreamOption? o = restoredNext.picked;
    if (o == null && acceptable.isNotEmpty) {
      final group = picked?.stream.bingeGroup;
      if (group != null && group.isNotEmpty) {
        o = acceptable
            .where((v) =>
                v.source.key == picked!.source.key &&
                v.stream.bingeGroup == group)
            .firstOrNull;
        if (o == null && context.mounted) {
          o = await pickArchiveStream(context, restoredNext.options);
        }
      } else {
        o = storage.getArchiveAutoLargest()
            ? largestArchiveStream(prefs.bestLanguage(acceptable))
            : preferredArchiveStream(acceptable, picked);
      }
    }
    if (o == null && context.mounted) {
      o = await pickArchiveStream(context, restoredNext.options);
    }
    if (o == null || !nextResume.isCurrent) return null;
    await nextResume.remember(o);
    if (o.stream.ytId != null) return null;
    picked = o; // the episode after follows this one
    selectedStreams[placeholder.id] = o;
    final ch = service
        .channelFor(source, meta, o.stream, episode: video)
        .copyWith(mediaFileInfo: archiveMediaFileInfo(o));
    _track(ch, meta, video);
    final nextLink = restoredNext.url == null ? await _resolve(o) : null;
    final nextUrl = restoredNext.url ?? nextLink!.url;
    final nextChannel = ch.copyWith(
        url: nextUrl,
        httpHeaders: nextLink?.headers ??
            redirectedStreamHeaders(o.stream.requestHeaders,
                Uri.parse(o.stream.url), Uri.parse(nextUrl)));
    unawaited(service.recordWatched(source, meta, episode: video));
    nextResume.traceChoice(restoredNext, o,
        resolvedUrl: nextChannel.url,
        via: restoredNext.picked != null
            ? 'resume'
            : storage.getArchiveAutoLargest() &&
                    identical(largestArchiveStream(restoredNext.options), o)
                ? 'largest'
                : 'nextEpisode');
    return nextChannel;
  }

  bool belongs(String id) => id == channel.id || videosById.containsKey(id);
  ArchiveVideo? videoFor(String id) => videosById[id] ?? episode;
  final sources = ArchivePlaybackSources(
    search: (id) => belongs(id) && resumeSource.isCurrent
        ? service.searchStreams(source, meta, episode: videoFor(id))
        : null,
    load: (id) async {
      if (!belongs(id) || !resumeSource.isCurrent) return const [];
      final streams =
          await service.streams(source, meta, episode: videoFor(id));
      return resumeSource.isCurrent ? streams : const [];
    },
    current: (id) => selectedStreams[id],
    select: (id, option) async {
      if (!belongs(id) || !resumeSource.isCurrent) return null;
      final link = await _resolve(option);
      final url = link.url;
      if (!resumeSource.isCurrent) return null;
      return service
          .channelFor(source, meta, option.stream, episode: videoFor(id))
          .copyWith(
              url: url,
              mediaFileInfo: archiveMediaFileInfo(option),
              httpHeaders: link.headers);
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
  if (isDesktop) {
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
    await Navigator.of(context).push(PlayerPageRoute(
        builder: (_) => PlayerScreen(channel: channel, sources: sources)));
  }
}

/// Download (Android): the stream is chosen like Play's, minus the saved
/// resume pick — Largest file, Auto-play or a single stream choose by
/// themselves, else the list asks. Episodes after the first keep to its
/// source and quality, like Up Next. The add-on's own link is kept (not
/// where it redirects): a debrid link expires, the add-on hands out a
/// fresh one when the download starts. Null when the list was dismissed.
Future<List<DownloadItem>?> archiveDownloadItems(
  BuildContext context, {
  required ArchiveSource source,
  required ArchiveMeta meta,
  List<ArchiveVideo> episodes = const [],
}) async {
  final service = context.read<ArchiveService>();
  final storage = context.read<StorageService>();
  final prefs = ArchivePlaybackPreferences.read(storage);
  final runtime =
      int.tryParse(RegExp(r'\d+').firstMatch(meta.runtime ?? '')?[0] ?? '');
  ArchiveStreamOption? automatic(List<ArchiveStreamOption> options) {
    final usable = prefs.ranked(options);
    return (storage.getArchiveAutoLargest()
            ? largestArchiveStream(prefs.bestLanguage(usable))
            : null) ??
        (prefs.autoPlay ? usable.firstOrNull : null) ??
        (options.length == 1 && usable.isNotEmpty ? options.single : null);
  }

  String two(int n) => n.toString().padLeft(2, '0');
  final items = <DownloadItem>[];
  ArchiveStreamOption? first;
  var skipped = 0;
  for (final video in episodes.isEmpty ? <ArchiveVideo?>[null] : episodes) {
    ArchiveStreamOption? o;
    if (first == null) {
      final session = service.searchStreams(source, meta, episode: video);
      o = await pickArchiveStream(context, session.options,
          session: session, autoSelect: (options) async => automatic(options));
      if (o == null || !context.mounted) return null;
      first = o;
    } else {
      final next = await service.streams(source, meta, episode: video);
      final acceptable = prefs.ranked(next);
      final group = first.stream.bingeGroup;
      o = (group != null && group.isNotEmpty
              ? acceptable
                  .where((v) =>
                      v.source.key == first!.source.key &&
                      v.stream.bingeGroup == group)
                  .firstOrNull
              : null) ??
          (storage.getArchiveAutoLargest()
              ? largestArchiveStream(prefs.bestLanguage(acceptable))
              : null) ??
          (acceptable.isEmpty
              ? null
              : preferredArchiveStream(acceptable, first));
      if (!context.mounted) return null;
    }
    if (o == null || o.stream.ytId != null || o.stream.url.isEmpty) {
      skipped++;
      continue;
    }
    final id = service
        .channelFor(source, meta, const ArchiveStream(), episode: video)
        .id;
    items.add(DownloadItem(
      sourceId: id,
      title: video == null
          ? meta.name
          : 'S${two(video.season)}E${two(video.episode)}'
              '${video.title.isEmpty ? '' : ' · ${video.title}'}',
      group: video == null ? '' : meta.name,
      url: o.stream.url,
      headers: o.stream.requestHeaders,
      poster: meta.posterUrl,
      durationSec: (runtime ?? 0) * 60,
      totalBytes: archiveMediaFileInfo(o).sizeBytes ?? 0,
    ));
  }
  if (skipped > 0 && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
            '{n} without a downloadable stream, left out.', {'n': skipped}))));
  }
  return items;
}

Future<void> openArchiveContinuation(
    BuildContext context, ArchiveContinueItem item) async {
  if (item.upcoming ||
      (item.meta.type == ArchiveType.series && item.episode == null)) {
    await openArchiveSeries(context, item.source, item.meta);
    return;
  }
  final service = context.read<ArchiveService>();
  final videos = <String, ArchiveVideo>{};
  final queue = <Channel>[];
  for (final video in item.meta.videos) {
    final date = DateTime.tryParse(video.released ?? '');
    if (date != null && date.isAfter(DateTime.now())) continue;
    final channel = service.channelFor(
        item.source, item.meta, const ArchiveStream(),
        episode: video);
    queue.add(channel);
    videos[channel.id] = video;
  }
  await playArchiveTitle(context,
      source: item.source,
      meta: item.meta,
      episode: item.episode,
      queue: queue,
      videosById: videos);
}

/// Opens an Archive show on the regular [SeriesDetailScreen]: the meta
/// (provider's or the source's own) becomes its episodes and details, and
/// Play goes through [playArchiveTitle] with the whole show as the queue.
Future<void> openArchiveSeries(
    BuildContext context, ArchiveSource source, ArchiveMeta preview) {
  final service = context.read<ArchiveService>();
  var meta = preview;
  final videosById = <String, ArchiveVideo>{};

  final tmdbKey = context.read<StorageService>().getTmdbApiKey() ?? '';

  Future<SeriesEpisodesResult> load() async {
    meta = await service.meta(source, preview) ?? preview;
    // Cinemeta can be days behind on new episodes (a daily soap's newest
    // one); stream-only add-ons already stream them.
    final missing = source.suppliesOwnMetadata || source.server != null
        ? const <ArchiveVideo>[]
        : await MissingEpisodes.instance.find(meta, tmdbKey: tmdbKey).timeout(
            const Duration(seconds: 8),
            onTimeout: () => const <ArchiveVideo>[]);
    final episodes = <int, List<Channel>>{};
    final details = <String, EpisodeDetails>{};
    videosById.clear();
    for (final v in [...meta.videos, ...missing]) {
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
        queue: all.where((channel) {
          final date =
              DateTime.tryParse(videosById[channel.id]?.released ?? '');
          return date == null || !date.isAfter(DateTime.now());
        }).toList(),
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
              posterUrl: preview.originalPosterUrl,
              backdropUrl: preview.backgroundUrl,
            ),
            loadEpisodes: load,
            playEpisode: play,
            downloadEpisodes: (context, episodes) => archiveDownloadItems(
                context,
                source: source,
                meta: meta,
                episodes: [
                  for (final e in episodes)
                    if (videosById[e.id] case final v?) v,
                ]),
            showFavorite: false,
            imdbId: preview.imdb,
            sourceLabel: source.name,
            watchListItem:
                WatchListItem(hub: HubTitle(source.manifestUrl, preview)),
            followTarget: () => FollowedShow(
                key: FollowedShow.hubKey(source.manifestUrl, preview.id),
                title: preview.name,
                posterUrl: preview.posterUrl,
                backdropUrl: preview.backgroundUrl,
                sourceUrl: source.manifestUrl,
                meta: preview.toJson(),
                imdbId: preview.imdb),
            discoveryBuilder: (entry, back) => ArchiveDiscoveryPanel(
                source: source,
                meta: preview,
                entryNode: entry,
                onReturn: back),
          )));
}

/// Hold OK on a Media Hub title: Recently watched = out of the history,
/// any other row = into / out of Favourites (with a short confirmation).
Future<void> holdArchiveTitle(BuildContext context, ArchiveRow row,
    ArchiveSource source, ArchiveMeta meta) async {
  final service = context.read<ArchiveService>();
  if (row.isHistory || row.continuations != null) {
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
