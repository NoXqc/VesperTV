import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/xtream_series.dart';
import '../services/archive_service.dart';
import '../services/launcher_channels.dart';
import '../services/playback_service.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// Opens a TV launcher card ([LauncherChannels]) the way the same title
/// opens from Home's rows: an IPTV movie or show on its page, a Media Hub
/// title resumed (or its page, from the Watch list or a new episode), a
/// favourite channel full screen. Over whatever was open, like a fresh pick.
Future<void> openLauncherCard(NavigatorState nav, LauncherCard card) async {
  nav.popUntil((r) => r.isFirst);
  final context = nav.context;
  if (card.hubItem case final item?) {
    await openArchiveContinuation(context, item);
    return;
  }
  if (card.hubTitle case final title?) {
    final source = context
        .read<ArchiveService>()
        .enabledSources
        .where((s) => s.manifestUrl == title.sourceUrl)
        .firstOrNull;
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr("This title's Media Hub source is not available."))));
      return;
    }
    if (title.meta.type == ArchiveType.series) {
      await openArchiveSeries(context, source, title.meta);
    } else {
      await nav.push(MaterialPageRoute(
          builder: (_) =>
              ArchiveDetailScreen(source: source, preview: title.meta)));
    }
    return;
  }
  if (card.followed case final show?) {
    if (show.isMediaHub) {
      final source = context
          .read<ArchiveService>()
          .enabledSources
          .where((s) => s.manifestUrl == show.sourceUrl)
          .firstOrNull;
      final meta = show.meta == null ? null : ArchiveMeta.fromJson(show.meta!);
      if (source == null || meta == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr("This show's Media Hub source was removed."))));
        return;
      }
      await openArchiveSeries(context, source, meta);
      return;
    }
    final playlistId = show.playlistId, seriesId = show.seriesId;
    if (playlistId == null || seriesId == null) return;
    await nav.push(MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(
            series: XtreamSeries(
                seriesId: seriesId,
                playlistId: playlistId,
                name: show.title,
                categoryId: show.categoryId ?? '',
                coverUrl: show.posterUrl,
                backdropUrl: show.backdropUrl,
                tmdbId: show.tmdbId))));
    return;
  }
  if (card.series case final series?) {
    await nav.push(
        MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)));
    return;
  }
  final channel = card.channel;
  if (channel == null) return;
  if (channel.isLive) {
    // Awaited: PlayerScreen's own play() must find it current (as Home).
    await context.read<PlaybackService>().play(channel);
    await nav
        .push(PlayerPageRoute(builder: (_) => PlayerScreen(channel: channel)));
    return;
  }
  await nav.push(
      MaterialPageRoute(builder: (_) => MovieDetailScreen(channel: channel)));
}
