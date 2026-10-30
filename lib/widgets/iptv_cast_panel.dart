import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../services/archive_discovery_service.dart';
import '../services/playlist_manager.dart';
import '../services/storage_service.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/series_detail_screen.dart';
import 'archive_discovery_panel.dart';

/// Reuses Media Hub's portraits, person credits and remote navigation, while
/// resolving selected credits only against the viewer's IPTV playlists.
class IptvCastPanel extends StatelessWidget {
  const IptvCastPanel(
      {super.key,
      required this.id,
      required this.title,
      required this.series,
      this.tmdbId,
      this.year,
      required this.entryNode,
      required this.onReturn,
      this.discovery});
  final String id, title;
  final bool series;
  final String? tmdbId;
  final int? year;
  final FocusNode entryNode;
  final VoidCallback onReturn;
  final ArchiveDiscoveryService? discovery;

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final viewer = storage.viewerGeneration;
    return ArchiveDiscoveryPanel.iptvCast(
        meta: ArchiveMeta(
            id: RegExp(r'^[1-9]\d*$').hasMatch(tmdbId ?? '')
                ? 'tmdb:$tmdbId'
                : 'iptv:$id',
            name: title,
            type: series ? ArchiveType.series : ArchiveType.movie,
            year: year?.toString()),
        entryNode: entryNode,
        onReturn: onReturn,
        discovery: discovery,
        openTitle: (meta) => _open(context, storage, viewer, meta));
  }

  static bool _matches(
      ArchiveMeta meta, String name, String? tmdb, DateTime? releaseDate) {
    final id = meta.id.startsWith('tmdb:') ? meta.id.substring(5) : null;
    if (RegExp(r'^[1-9]\d*$').hasMatch(tmdb ?? '')) return tmdb == id;
    if (ArchiveDiscoveryService.titleKey(name) !=
        ArchiveDiscoveryService.titleKey(meta.name)) {
      return false;
    }
    final year = releaseDate?.year.toString() ??
        RegExp(r'\b(?:19|20)\d{2}\b').firstMatch(name)?.group(0);
    return meta.year == null || year == meta.year;
  }

  static Future<void> _open(BuildContext context, StorageService storage,
      int viewer, ArchiveMeta meta) async {
    if (!context.mounted || storage.viewerGeneration != viewer) return;
    final playlist = context.read<PlaylistManager>();
    final ids =
        playlist.profiles.where((p) => p.enabled).map((p) => p.id).toList();
    try {
      Widget? page;
      if (meta.type == ArchiveType.movie) {
        final rows = await playlist.searchVisibleVod(meta.name, ids, limit: 40);
        if (!context.mounted || storage.viewerGeneration != viewer) return;
        final matches = [...rows, ...playlist.visibleChannels(category: 'vod')]
            .where((c) =>
                ids.contains(c.playlistId) &&
                _matches(meta, c.name, c.tmdbId, c.releaseDate));
        if (matches.firstOrNull case final movie?) {
          page = MovieDetailScreen(channel: movie);
        }
      } else {
        final rows =
            await playlist.searchVisibleSeries(meta.name, ids, limit: 40);
        if (!context.mounted || storage.viewerGeneration != viewer) return;
        final matches = [...rows, ...playlist.visibleSeries()].where((s) =>
            ids.contains(s.playlistId) &&
            _matches(meta, s.name, s.tmdbId, s.releaseDate));
        if (matches.firstOrNull case final show?) {
          page = SeriesDetailScreen(series: show);
        }
      }
      if (!context.mounted || storage.viewerGeneration != viewer) return;
      if (page == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('No matching title found in your playlists.'))));
      } else {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => page!));
      }
    } catch (_) {
      if (context.mounted && storage.viewerGeneration == viewer) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Could not load this title. Try again.'))));
      }
    }
  }
}
