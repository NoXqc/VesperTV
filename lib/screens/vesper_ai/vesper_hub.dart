import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/archive_models.dart';
import '../../models/channel.dart';
import '../../services/archive_service.dart';
import '../../services/vesper_ai/vesper_tools.dart';
import '../../services/vesper_ai/watch_list.dart';
import '../archive_playback.dart';

/// [VesperHub] on the app's [ArchiveService]: search and streams like the
/// Media Hub tab's, and Play like a title's page ([playArchiveTitle], so
/// resume, Next episode and the source drawer all work the same).
class AppVesperHub implements VesperHub {
  AppVesperHub({required this.navigatorKey, required this.archive});

  final GlobalKey<NavigatorState> navigatorKey;
  final ArchiveService archive;

  NavigatorState get _nav =>
      navigatorKey.currentState ??
      (throw VesperToolError('The app is still starting.'));

  ArchiveSource _source(HubTitle title) {
    for (final s in archive.enabledSources) {
      if (s.manifestUrl == title.sourceUrl) return s;
    }
    throw VesperToolError("This title's Media Hub source is not available.");
  }

  @override
  Future<List<HubTitle>> search(String query,
      {ArchiveType? type, int limit = 8}) async {
    final found = <HubTitle>[];
    final seen = <String>{};
    for (final t in type == null ? ArchiveType.values : [type]) {
      for (final row in await archive.searchRows(t, query, underOther: false)) {
        for (final meta in row.items) {
          // The same title from several sources (Cinemeta rows, add-ons):
          // once, from the first source that has it.
          if (seen.add('${meta.wire}|${meta.id}')) {
            found.add(HubTitle(row.source.manifestUrl, meta));
          }
        }
      }
    }
    // Closest names first; titles found under another name (a provider's
    // alias) keep their place after them.
    final ranked = rankByName(found, query, (h) => h.meta.name, limit: limit);
    return [
      ...ranked,
      ...found.where((h) => !ranked.contains(h)),
    ].take(limit).toList();
  }

  @override
  Future<HubTitle?> details(HubTitle title) async {
    final ArchiveSource source;
    try {
      source = _source(title);
    } on VesperToolError {
      return null;
    }
    final meta = await archive.meta(source, title.meta);
    return HubTitle(title.sourceUrl, meta ?? title.meta);
  }

  @override
  Future<List<ArchiveStreamOption>> streams(HubTitle title,
          {ArchiveVideo? episode}) =>
      archive.streams(_source(title), title.meta, episode: episode);

  @override
  Future<String> play(HubTitle title,
      {ArchiveVideo? episode, ArchiveStreamOption? option}) async {
    final source = _source(title);
    var meta = title.meta;
    // An episode plays with the show's aired episodes as its queue, like
    // Continue watching, so Next episode works.
    final queue = <Channel>[];
    final videos = <String, ArchiveVideo>{};
    if (episode != null) {
      if (meta.videos.isEmpty) meta = await archive.meta(source, meta) ?? meta;
      for (final video in meta.videos) {
        final date = DateTime.tryParse(video.released ?? '');
        if (date != null && date.isAfter(DateTime.now())) continue;
        final placeholder = archive
            .channelFor(source, meta, const ArchiveStream(), episode: video);
        queue.add(placeholder);
        videos[placeholder.id] = video;
      }
    }
    // Over whatever is open (the panel included), like a fresh pick.
    final context = (_nav..popUntil((r) => r.isFirst)).context;
    if (!context.mounted) throw VesperToolError('The app is still starting.');
    // Not awaited: it returns when the viewer leaves the player.
    unawaited(playArchiveTitle(context,
            source: source,
            meta: meta,
            episode: episode,
            queue: episode == null ? null : queue,
            videosById: videos,
            chosen: option)
        .catchError((Object e) => debugPrint('VesperHub: play failed: $e')));
    return archive
        .channelFor(source, meta, const ArchiveStream(), episode: episode)
        .id;
  }

  @override
  Future<void> openShow(HubTitle show) async {
    final nav = _nav;
    final source = _source(show);
    nav.popUntil((r) => r.isFirst);
    unawaited(openArchiveSeries(nav.context, source, show.meta));
  }

  @override
  List<(HubTitle, ArchiveVideo?)> continueWatching() => [
        for (final type in ArchiveType.values)
          for (final item in archive.continueWatching(type))
            (HubTitle(item.source.manifestUrl, item.meta), item.episode),
      ];
}
